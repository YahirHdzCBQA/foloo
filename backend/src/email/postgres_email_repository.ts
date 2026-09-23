/** PostgreSQL email adapter; every protected operation is workspace-scoped. */

import type pg from "pg";
import { ApplicationError, notFound } from "../application/errors.js";
import type { Principal } from "../domain/models.js";
import type {
  EmailProviderName,
  EmailSendState,
  HistoricalAttachment,
} from "../domain/email_follow_ups.js";
import type {
  EmailRepository,
  FollowUpContext,
  OAuthState,
  SafeEmailConnection,
  StoredSendIntent,
} from "./email_repository.js";

export class PostgresEmailRepository implements EmailRepository {
  constructor(private readonly pool: pg.Pool) {}

  async connection(principal: Principal): Promise<SafeEmailConnection | null> {
    const result = await this.pool.query<SafeEmailConnection>(
      `SELECT id, provider, sender_address AS "senderAddress", status,
              updated_at AS "updatedAt"
       FROM email_connections WHERE workspace_id=$1 AND owner_user_id=$2
       ORDER BY updated_at DESC LIMIT 1`,
      [principal.workspaceId, principal.userId],
    );
    return result.rows[0] ?? null;
  }

  async beginOAuth(
    principal: Principal,
    provider: EmailProviderName,
    stateHash: string,
    encryptedFlow: string,
    redirectUri: string,
  ) {
    await this.pool.query(
      `INSERT INTO email_oauth_states
       (state_hash,workspace_id,owner_user_id,provider,code_verifier_ciphertext,
        redirect_uri,expires_at)
       VALUES ($1,$2,$3,$4,$5,$6,now()+interval '10 minutes')`,
      [
        stateHash,
        principal.workspaceId,
        principal.userId,
        provider,
        Buffer.from(encryptedFlow, "base64"),
        redirectUri,
      ],
    );
  }

  async consumeOAuthState(stateHash: string): Promise<OAuthState> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const result = await client.query<{
        workspace_id: string;
        owner_user_id: string;
        provider: EmailProviderName;
        code_verifier_ciphertext: Buffer;
        redirect_uri: string;
        subject: string;
        account_id: string;
      }>(
        `UPDATE email_oauth_states s SET consumed_at=now()
         FROM app_users u, workspaces w
         WHERE s.state_hash=$1 AND s.consumed_at IS NULL AND s.expires_at>now()
           AND u.id=s.owner_user_id AND w.id=s.workspace_id
         RETURNING s.workspace_id,s.owner_user_id,s.provider,
           s.code_verifier_ciphertext,s.redirect_uri,u.cognito_sub AS subject,
           w.account_id`,
        [stateHash],
      );
      const row = result.rows[0];
      if (!row)
        throw new ApplicationError(
          "invalid_oauth_state",
          400,
          "Authorization link is invalid or expired.",
        );
      await client.query("COMMIT");
      return {
        principal: {
          subject: row.subject,
          userId: row.owner_user_id,
          accountId: row.account_id,
          workspaceId: row.workspace_id,
        },
        provider: row.provider,
        encryptedFlow: row.code_verifier_ciphertext.toString("base64"),
        redirectUri: row.redirect_uri,
      };
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  }

  async connect(
    state: OAuthState,
    input: {
      providerSubject: string;
      senderAddress: string;
      encryptedCredentials: string;
    },
  ): Promise<SafeEmailConnection> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      await client.query(
        `UPDATE email_connections SET status='disconnected',disconnected_at=now()
         WHERE workspace_id=$1 AND owner_user_id=$2
           AND status IN ('connected','reconnect_required')`,
        [state.principal.workspaceId, state.principal.userId],
      );
      const result = await client.query<SafeEmailConnection>(
        `INSERT INTO email_connections
         (workspace_id,owner_user_id,provider,provider_subject,sender_address,
          encrypted_credentials,credential_key_id,status)
         VALUES ($1,$2,$3,$4,$5,$6,'foloo-email-kms','connected')
         RETURNING id,provider,sender_address AS "senderAddress",status,
                   updated_at AS "updatedAt"`,
        [
          state.principal.workspaceId,
          state.principal.userId,
          state.provider,
          input.providerSubject,
          input.senderAddress,
          Buffer.from(input.encryptedCredentials, "base64"),
        ],
      );
      await client.query("COMMIT");
      return result.rows[0]!;
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  }

  async disconnect(principal: Principal) {
    await this.pool.query(
      `UPDATE email_connections SET status='disconnected',disconnected_at=now()
       WHERE workspace_id=$1 AND owner_user_id=$2 AND status<>'disconnected'`,
      [principal.workspaceId, principal.userId],
    );
  }

  async followUpContext(
    principal: Principal,
    leadId: string,
  ): Promise<FollowUpContext> {
    const result = await this.pool.query<{
      lead_id: string;
      event_id: string | null;
      origin: "event" | "direct";
      recipient_address: string | null;
      first_name: string;
      last_name: string | null;
      company: string;
      position: string | null;
      event_name: string | null;
      place: string | null;
      seller_name: string | null;
      seller_company: string | null;
      content_file_ids: string[];
      content_names: string[];
    }>(
      `SELECT l.id AS lead_id,l.event_id,l.origin,l.email AS recipient_address,l.first_name,
              l.last_name,l.company,l.position,e.name AS event_name,l.place,
              p.name AS seller_name,p.company AS seller_company,
              l.content_file_ids,l.content_names
       FROM leads l LEFT JOIN events e ON e.workspace_id=l.workspace_id AND e.id=l.event_id
       LEFT JOIN seller_profiles p ON p.workspace_id=l.workspace_id AND p.user_id=$2
       WHERE l.workspace_id=$1 AND l.id=$3 AND l.deleted_at IS NULL`,
      [principal.workspaceId, principal.userId, leadId],
    );
    const row = result.rows[0];
    if (!row) throw notFound("Lead");
    const attachmentRows = row.content_file_ids.length
      ? await this.pool.query<
          HistoricalAttachment & {
            deletedAt: string | null;
            uploadStatus: string;
          }
        >(
          `SELECT snapshot.id,snapshot.name,
                  COALESCE(c.byte_size,0)::int AS "byteSize",'application/pdf'::text AS "contentType",
                  (c.id IS NOT NULL AND c.deleted_at IS NULL AND c.upload_status='available'
                   AND c.storage_object_key IS NOT NULL) AS available,
                  c.storage_object_key AS "storageObjectKey"
           FROM unnest($2::uuid[],$3::text[]) AS snapshot(id,name)
           LEFT JOIN content_files c ON c.workspace_id=$1 AND c.id=snapshot.id`,
          [principal.workspaceId, row.content_file_ids, row.content_names],
        )
      : { rows: [] as HistoricalAttachment[] };
    return {
      leadId: row.lead_id,
      eventId: row.event_id,
      origin: row.origin,
      recipientAddress: row.recipient_address,
      contentFileIds: row.content_file_ids,
      contentNames: row.content_names,
      attachments: attachmentRows.rows,
      values: {
        nombre: row.first_name,
        apellido: row.last_name ?? "",
        empresa: row.company,
        puesto: row.position ?? "",
        evento: row.event_name ?? "",
        lugar: row.place ?? "",
        contenido: row.content_names.join(", "),
        nombreVendedor: row.seller_name ?? "",
        empresaVendedor: row.seller_company ?? "",
      },
    };
  }

  async createFollowUp(
    principal: Principal,
    input: {
      id: string;
      context: FollowUpContext;
      language: "es" | "en";
      subject: string;
      body: string;
      signature: string;
      footer: string;
      plainBody: string;
      htmlBody: string;
    },
  ) {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const inserted = await client.query(
        `INSERT INTO email_follow_ups
       (id,workspace_id,lead_id,owner_user_id,origin,language,recipient_address,
        subject,body,signature,content_file_ids,content_names,plain_body,html_body,
        footer,unsubscribe_token_hash)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11::uuid[],$12::text[],$13,$14,$15,$16)
       ON CONFLICT (id) DO NOTHING RETURNING id`,
        [
          input.id,
          principal.workspaceId,
          input.context.leadId,
          principal.userId,
          input.context.origin,
          input.language,
          input.context.recipientAddress,
          input.subject,
          input.body,
          input.signature,
          input.context.contentFileIds,
          input.context.contentNames,
          input.plainBody,
          input.htmlBody,
          input.footer,
          "",
        ],
      );
      if (!inserted.rows[0]) {
        const existing = await client.query(
          `SELECT id FROM email_follow_ups WHERE workspace_id=$1 AND owner_user_id=$2 AND id=$3`,
          [principal.workspaceId, principal.userId, input.id],
        );
        if (!existing.rows[0]) throw notFound("Email follow-up");
        await client.query("COMMIT");
        return { id: input.id, leadId: input.context.leadId, status: "ready" };
      }
      await client.query("COMMIT");
      return { id: input.id, leadId: input.context.leadId, status: "ready" };
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  }

  async listFollowUps(principal: Principal) {
    const result = await this.pool.query(
      `SELECT f.id,f.lead_id AS "leadId",
              f.recipient_address AS "recipientAddress",f.subject,
              f.plain_body AS "plainBody",f.html_body AS "htmlBody",
              f.content_file_ids AS "contentFileIds",f.content_names AS "contentNames",
              f.language,f.prepared_at AS "preparedAt",
              i.id AS "intentId",i.status,i.connection_id AS "connectionId",
              i.sender_address AS "senderAddress",i.omitted_content_ids AS "omittedContentIds",
              i.parent_intent_id AS "parentIntentId",i.error_code AS "errorCode",
              i.attempt_count AS "attemptCount",i.confirmed_at AS "intentCreatedAt",
              i.updated_at AS "intentUpdatedAt"
       FROM email_follow_ups f LEFT JOIN LATERAL
         (SELECT * FROM email_send_intents x WHERE x.workspace_id=f.workspace_id
          AND x.follow_up_id=f.id ORDER BY x.confirmed_at DESC LIMIT 1) i ON true
       WHERE f.workspace_id=$1 AND f.owner_user_id=$2 ORDER BY f.prepared_at DESC`,
      [principal.workspaceId, principal.userId],
    );
    return result.rows;
  }

  async createIntent(
    principal: Principal,
    input: {
      id: string;
      followUpId: string;
      omittedContentIds: string[];
      parentIntentId?: string;
      kind: "initial" | "manual_resend";
    },
  ): Promise<StoredSendIntent> {
    const result = await this.pool.query<StoredSendIntent>(
      `INSERT INTO email_send_intents
       (id,workspace_id,follow_up_id,connection_id,provider,sender_address,
        recipient_address,subject,plain_body,html_body,attached_content_ids,
        omitted_content_ids,parent_intent_id,last_attempt_kind)
       SELECT $1,f.workspace_id,f.id,c.id,c.provider,c.sender_address,
              f.recipient_address,f.subject,f.plain_body,f.html_body,
              ARRAY(SELECT unnest(f.content_file_ids) EXCEPT SELECT unnest($4::uuid[])),
              $4::uuid[],$5,$6
       FROM email_follow_ups f JOIN email_connections c ON c.workspace_id=f.workspace_id
        AND c.owner_user_id=f.owner_user_id AND c.status='connected'
       WHERE f.workspace_id=$2 AND f.owner_user_id=$3 AND f.id=$7
         AND f.recipient_address IS NOT NULL
       ON CONFLICT (id) DO NOTHING
       RETURNING id,workspace_id AS "workspaceId",follow_up_id AS "followUpId",
         connection_id AS "connectionId",provider,sender_address AS "senderAddress",
         recipient_address AS "recipientAddress",subject,plain_body AS "plainBody",
         html_body AS "htmlBody",attached_content_ids AS "attachedContentIds",
         omitted_content_ids AS "omittedContentIds",status,attempt_count AS "attemptCount",
         error_code AS "errorCode",NULL::text AS "encryptedCredentials"`,
      [
        input.id,
        principal.workspaceId,
        principal.userId,
        input.omittedContentIds,
        input.parentIntentId ?? null,
        input.kind,
        input.followUpId,
      ],
    );
    if (!result.rows[0]) {
      if (input.omittedContentIds.length) {
        await this.pool.query(
          `UPDATE email_send_intents i SET
             omitted_content_ids=$3::uuid[],
             attached_content_ids=ARRAY(
               SELECT unnest(f.content_file_ids)
               EXCEPT SELECT unnest($3::uuid[])
             )
           FROM email_follow_ups f
           WHERE i.workspace_id=$1 AND i.id=$2 AND i.status='pending'
             AND f.workspace_id=i.workspace_id AND f.id=i.follow_up_id`,
          [principal.workspaceId, input.id, input.omittedContentIds],
        );
      }
      return this.intent(principal, input.id);
    }
    return this.intent(principal, input.id);
  }

  async intent(principal: Principal, id: string): Promise<StoredSendIntent> {
    const result = await this.pool.query<StoredSendIntent>(
      `SELECT i.id,i.workspace_id AS "workspaceId",i.follow_up_id AS "followUpId",
        i.connection_id AS "connectionId",i.provider,i.sender_address AS "senderAddress",
        i.recipient_address AS "recipientAddress",i.subject,i.plain_body AS "plainBody",
        i.html_body AS "htmlBody",i.attached_content_ids AS "attachedContentIds",
        i.omitted_content_ids AS "omittedContentIds",i.status,
        i.error_code AS "errorCode",i.attempt_count AS "attemptCount",
        encode(c.encrypted_credentials,'base64') AS "encryptedCredentials"
       FROM email_send_intents i JOIN email_follow_ups f
        ON f.workspace_id=i.workspace_id AND f.id=i.follow_up_id
       LEFT JOIN email_connections c
        ON c.workspace_id=i.workspace_id AND c.id=i.connection_id
       WHERE i.workspace_id=$1 AND i.id=$2 AND f.owner_user_id=$3`,
      [principal.workspaceId, id, principal.userId],
    );
    if (!result.rows[0]) throw notFound("Email intent");
    return result.rows[0];
  }

  async markSending(
    principal: Principal,
    id: string,
    kind: "initial" | "safe_retry" | "manual_resend",
  ) {
    await this.pool.query(
      `UPDATE email_send_intents SET status='sending',request_started_at=now(),
       attempt_count=attempt_count+1,last_attempt_kind=$3,error_code=NULL
       WHERE workspace_id=$1 AND id=$2 AND status IN ('pending','error')`,
      [principal.workspaceId, id, kind],
    );
    return this.intent(principal, id);
  }

  async finishIntent(
    principal: Principal,
    id: string,
    update: {
      status: EmailSendState;
      errorCode?: string;
      providerMessageId?: string;
      encryptedCredentials?: string;
      acceptedSenderAddress?: string;
    },
  ) {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const current = await this.intent(principal, id);
      await client.query(
        `UPDATE email_send_intents SET status=$3,error_code=$4,provider_message_id=$5,
         provider_error_class=$4,accepted_at=CASE WHEN $3='sent' THEN now() ELSE accepted_at END,
         accepted_sender_address=COALESCE($6,accepted_sender_address)
         WHERE workspace_id=$1 AND id=$2`,
        [
          principal.workspaceId,
          id,
          update.status,
          update.errorCode ?? null,
          update.providerMessageId ?? null,
          update.acceptedSenderAddress ?? null,
        ],
      );
      if (update.encryptedCredentials && current.connectionId)
        await client.query(
          `UPDATE email_connections SET encrypted_credentials=$3,credential_version=credential_version+1
           WHERE workspace_id=$1 AND id=$2`,
          [
            principal.workspaceId,
            current.connectionId,
            Buffer.from(update.encryptedCredentials, "base64"),
          ],
        );
      if (update.status === "confirmation_required")
        await client.query(
          `UPDATE email_connections SET updated_at=now() WHERE workspace_id=$1 AND id=$2`,
          [principal.workspaceId, current.connectionId],
        );
      if (update.errorCode === "oauth_revoked" && current.connectionId)
        await client.query(
          `UPDATE email_connections SET status='reconnect_required' WHERE workspace_id=$1 AND id=$2`,
          [principal.workspaceId, current.connectionId],
        );
      await client.query("COMMIT");
      return this.intent(principal, id);
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  }

  async intentAttachments(
    principal: Principal,
    intent: StoredSendIntent,
  ): Promise<HistoricalAttachment[]> {
    if (!intent.attachedContentIds.length) return [];
    const result = await this.pool.query<HistoricalAttachment>(
      `SELECT snapshot.id,snapshot.name,COALESCE(c.byte_size,0)::int AS "byteSize",
       'application/pdf'::text AS "contentType",
       (c.id IS NOT NULL AND c.deleted_at IS NULL AND c.upload_status='available'
        AND c.storage_object_key IS NOT NULL) AS available,
       c.storage_object_key AS "storageObjectKey"
       FROM email_follow_ups f,
       unnest(f.content_file_ids,f.content_names) AS snapshot(id,name)
       LEFT JOIN content_files c ON c.workspace_id=$1 AND c.id=snapshot.id
       WHERE f.workspace_id=$1 AND f.id=$2 AND snapshot.id=ANY($3::uuid[])`,
      [principal.workspaceId, intent.followUpId, intent.attachedContentIds],
    );
    return result.rows;
  }
}
