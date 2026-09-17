/** PostgreSQL adapter enforcing workspace scope on every resource operation. */

import { createHash } from "node:crypto";

import type pg from "pg";

import {
  ApplicationError,
  conflict,
  notFound,
  revisionConflict,
} from "../application/errors.js";
import type { FolooRepository } from "../application/ports.js";
import type {
  EventInput,
  EventUpdateInput,
  EventDeleteInput,
  ContentInput,
  ContentUpdateInput,
  ContentDeleteInput,
  ContentRecord,
  IdempotentResult,
  LeadInput,
  LeadUpdateInput,
  LeadMediaInput,
  LeadMediaRecord,
  Principal,
  SellerProfileInput,
} from "../domain/models.js";

type Queryable = Pick<pg.Pool, "query">;

export function requestHash(value: unknown): string {
  return createHash("sha256").update(JSON.stringify(value)).digest("hex");
}

export class PostgresFolooRepository implements FolooRepository {
  constructor(private readonly pool: pg.Pool) {}

  async resolvePrincipal(subject: string): Promise<Principal> {
    const result = await this.pool.query<{
      user_id: string;
      account_id: string;
      workspace_id: string;
    }>("SELECT * FROM ensure_personal_workspace($1)", [subject]);
    const row = result.rows[0];
    if (!row) throw new Error("Principal provisioning returned no workspace");
    return {
      subject,
      userId: row.user_id,
      accountId: row.account_id,
      workspaceId: row.workspace_id,
    };
  }

  async getWorkspace(principal: Principal): Promise<unknown> {
    const result = await this.pool.query(
      `SELECT a.id AS "accountId", a.kind, w.id AS "workspaceId", w.name
       FROM workspace_members m
       JOIN workspaces w ON w.id = m.workspace_id AND w.deleted_at IS NULL
       JOIN accounts a ON a.id = w.account_id AND a.deleted_at IS NULL
       WHERE m.user_id = $1 AND w.id = $2`,
      [principal.userId, principal.workspaceId],
    );
    return result.rows[0] ?? null;
  }

  async getProfile(principal: Principal): Promise<unknown | null> {
    const result = await this.pool.query(
      `SELECT name, company, position, phone, photo_url AS "photoUrl",
              revision, updated_at AS "updatedAt"
       FROM seller_profiles WHERE workspace_id = $1 AND user_id = $2 AND deleted_at IS NULL`,
      [principal.workspaceId, principal.userId],
    );
    return result.rows[0] ?? null;
  }

  async saveProfile(
    principal: Principal,
    input: SellerProfileInput,
  ): Promise<unknown> {
    const result = await this.pool.query(
      `INSERT INTO seller_profiles
         (workspace_id, user_id, name, company, position, phone, photo_url)
       VALUES ($1,$2,$3,$4,$5,$6,$7)
       ON CONFLICT (workspace_id) DO UPDATE SET
         name = EXCLUDED.name, company = EXCLUDED.company,
         position = EXCLUDED.position, phone = EXCLUDED.phone,
         photo_url = EXCLUDED.photo_url, deleted_at = NULL
       WHERE seller_profiles.user_id = $2
       RETURNING name, company, position, phone, photo_url AS "photoUrl",
                 revision, updated_at AS "updatedAt"`,
      [
        principal.workspaceId,
        principal.userId,
        input.name,
        input.company,
        input.position ?? null,
        input.phone ?? null,
        input.photoUrl ?? null,
      ],
    );
    const row = result.rows[0];
    if (!row) throw notFound("Profile");
    return row;
  }

  async listEvents(principal: Principal): Promise<unknown[]> {
    const result = await this.pool.query(
      `SELECT id, name, starts_at AS "startsAt", ends_at AS "endsAt", revision,
              deleted_at AS "deletedAt", created_at AS "createdAt", updated_at AS "updatedAt"
       FROM events WHERE workspace_id = $1 ORDER BY starts_at`,
      [principal.workspaceId],
    );
    return result.rows;
  }

  async createEvent(
    principal: Principal,
    input: EventInput,
    key: string,
    hash: string,
  ): Promise<IdempotentResult<unknown>> {
    return this.idempotent(
      principal.workspaceId,
      "create-event",
      key,
      hash,
      async (db) => {
        const result = await db.query(
          `INSERT INTO events (id, workspace_id, name, starts_at, ends_at)
         VALUES ($1,$2,$3,$4,$5)
         RETURNING id, name, starts_at AS "startsAt", ends_at AS "endsAt", revision`,
          [
            input.id,
            principal.workspaceId,
            input.name,
            input.startsAt,
            input.endsAt,
          ],
        );
        return result.rows[0];
      },
    );
  }

  async updateEvent(
    principal: Principal,
    eventId: string,
    input: EventUpdateInput,
    key: string,
    hash: string,
  ): Promise<IdempotentResult<unknown>> {
    return this.idempotent(
      principal.workspaceId,
      "update-event",
      key,
      hash,
      async (db) => {
        const result = await db.query(
          `UPDATE events SET name = $4, starts_at = $5, ends_at = $6
           WHERE workspace_id = $1 AND id = $2 AND revision = $3 AND deleted_at IS NULL
           RETURNING id, name, starts_at AS "startsAt", ends_at AS "endsAt", revision`,
          [
            principal.workspaceId,
            eventId,
            input.revision,
            input.name,
            input.startsAt,
            input.endsAt,
          ],
        );
        if (result.rows[0]) return result.rows[0];
        const found = await db.query(
          `SELECT id FROM events WHERE workspace_id = $1 AND id = $2 AND deleted_at IS NULL`,
          [principal.workspaceId, eventId],
        );
        if (!found.rows[0]) throw notFound("Event");
        throw revisionConflict();
      },
      200,
    );
  }

  async deleteEvent(
    principal: Principal,
    eventId: string,
    input: EventDeleteInput,
    key: string,
    hash: string,
  ): Promise<IdempotentResult<unknown>> {
    return this.idempotent(
      principal.workspaceId,
      "delete-event",
      key,
      hash,
      async (db) => {
        // A tombstone preserves the foreign key and all associated Leads/media.
        const result = await db.query(
          `UPDATE events SET deleted_at = now()
           WHERE workspace_id = $1 AND id = $2 AND revision = $3 AND deleted_at IS NULL
           RETURNING id, revision, deleted_at AS "deletedAt"`,
          [principal.workspaceId, eventId, input.revision],
        );
        if (result.rows[0]) return result.rows[0];
        const found = await db.query(
          `SELECT id, deleted_at FROM events WHERE workspace_id = $1 AND id = $2`,
          [principal.workspaceId, eventId],
        );
        if (!found.rows[0]) throw notFound("Event");
        if (found.rows[0].deleted_at) throw notFound("Event");
        throw revisionConflict();
      },
      200,
    );
  }

  private async validateContentEvents(
    db: Queryable,
    principal: Principal,
    ids: string[],
  ): Promise<void> {
    const unique = [...new Set(ids)];
    if (unique.length === 0) return;
    const result = await db.query(
      `SELECT id FROM events WHERE workspace_id = $1 AND id = ANY($2::uuid[]) AND deleted_at IS NULL`,
      [principal.workspaceId, unique],
    );
    if (result.rows.length !== unique.length) throw notFound("Event");
  }

  async listContent(principal: Principal): Promise<ContentRecord[]> {
    const result = await this.pool.query<ContentRecord>(
      `SELECT id, display_name AS "displayName", file_name AS "fileName",
              byte_size AS "byteSize", all_events AS "allEvents",
              event_ids AS "eventIds", revision, deleted_at AS "deletedAt",
              upload_status AS "uploadStatus", storage_object_key AS "storageObjectKey"
       FROM content_files WHERE workspace_id = $1 ORDER BY created_at DESC`,
      [principal.workspaceId],
    );
    return result.rows;
  }

  async createContent(
    principal: Principal,
    input: ContentInput,
    key: string,
    hash: string,
  ): Promise<IdempotentResult<unknown>> {
    return this.idempotent(
      principal.workspaceId,
      "create-content",
      key,
      hash,
      async (db) => {
        await this.validateContentEvents(db, principal, input.eventIds);
        const result = await db.query(
          `INSERT INTO content_files
          (id, workspace_id, display_name, file_name, byte_size, all_events, event_ids)
         VALUES ($1,$2,$3,$4,$5,$6,$7::uuid[])
         RETURNING id, display_name AS "displayName", revision, upload_status AS "uploadStatus"`,
          [
            input.id,
            principal.workspaceId,
            input.displayName,
            input.fileName,
            input.byteSize,
            input.allEvents,
            [...new Set(input.eventIds)],
          ],
        );
        return result.rows[0];
      },
    );
  }

  async updateContent(
    principal: Principal,
    id: string,
    input: ContentUpdateInput,
    key: string,
    hash: string,
  ): Promise<IdempotentResult<unknown>> {
    return this.idempotent(
      principal.workspaceId,
      "update-content",
      key,
      hash,
      async (db) => {
        const current = await db.query<{ event_ids: string[] }>(
          `SELECT event_ids FROM content_files WHERE workspace_id = $1 AND id = $2 AND deleted_at IS NULL FOR UPDATE`,
          [principal.workspaceId, id],
        );
        if (!current.rows[0]) throw notFound("Content");
        const previous = new Set(current.rows[0].event_ids);
        await this.validateContentEvents(
          db,
          principal,
          input.eventIds.filter((eventId) => !previous.has(eventId)),
        );
        const result = await db.query(
          `UPDATE content_files SET display_name = $4, all_events = $5, event_ids = $6::uuid[]
         WHERE workspace_id = $1 AND id = $2 AND revision = $3 AND deleted_at IS NULL
         RETURNING id, display_name AS "displayName", revision`,
          [
            principal.workspaceId,
            id,
            input.revision,
            input.displayName,
            input.allEvents,
            [...new Set(input.eventIds)],
          ],
        );
        if (!result.rows[0]) throw revisionConflict();
        return result.rows[0];
      },
      200,
    );
  }

  async deleteContent(
    principal: Principal,
    id: string,
    input: ContentDeleteInput,
    key: string,
    hash: string,
  ): Promise<IdempotentResult<unknown>> {
    return this.idempotent(
      principal.workspaceId,
      "delete-content",
      key,
      hash,
      async (db) => {
        const result = await db.query(
          `UPDATE content_files SET deleted_at = now()
         WHERE workspace_id = $1 AND id = $2 AND revision = $3 AND deleted_at IS NULL
         RETURNING id, revision, deleted_at AS "deletedAt"`,
          [principal.workspaceId, id, input.revision],
        );
        if (result.rows[0]) return result.rows[0];
        const found = await db.query(
          `SELECT id FROM content_files WHERE workspace_id = $1 AND id = $2`,
          [principal.workspaceId, id],
        );
        if (!found.rows[0]) throw notFound("Content");
        throw revisionConflict();
      },
      200,
    );
  }

  async prepareContent(
    principal: Principal,
    id: string,
  ): Promise<ContentRecord> {
    const result = await this.pool.query<ContentRecord>(
      `SELECT id, display_name AS "displayName", file_name AS "fileName",
              byte_size AS "byteSize", all_events AS "allEvents", event_ids AS "eventIds",
              revision, deleted_at AS "deletedAt", upload_status AS "uploadStatus",
              storage_object_key AS "storageObjectKey"
       FROM content_files WHERE workspace_id = $1 AND id = $2 AND deleted_at IS NULL`,
      [principal.workspaceId, id],
    );
    if (!result.rows[0]) throw notFound("Content");
    return result.rows[0];
  }

  async confirmContent(
    principal: Principal,
    id: string,
    key: string,
    hash: string,
    objectKey: string,
  ): Promise<IdempotentResult<unknown>> {
    return this.idempotent(
      principal.workspaceId,
      "confirm-content",
      key,
      hash,
      async (db) => {
        const result = await db.query(
          `UPDATE content_files SET storage_object_key = $3, upload_status = 'available', uploaded_at = now()
         WHERE workspace_id = $1 AND id = $2 AND deleted_at IS NULL
         RETURNING id, revision, upload_status AS "uploadStatus"`,
          [principal.workspaceId, id, objectKey],
        );
        if (!result.rows[0]) throw notFound("Content");
        return result.rows[0];
      },
      200,
    );
  }

  async listLeads(principal: Principal): Promise<unknown[]> {
    const result = await this.pool.query(
      `SELECT id, event_id AS "eventId", captured_at AS "capturedAt", origin, place,
              first_name AS "firstName", last_name AS "lastName", position, company,
              email, phone, lead_type AS "leadType", interest, written_note AS "writtenNote",
              commercial_folio AS "commercialFolio",
              content_file_ids AS "contentFileIds", content_names AS "contentNames", revision
       FROM leads WHERE workspace_id = $1 AND deleted_at IS NULL ORDER BY captured_at DESC`,
      [principal.workspaceId],
    );
    return result.rows;
  }

  async createLead(
    principal: Principal,
    input: LeadInput,
    key: string,
    hash: string,
  ): Promise<IdempotentResult<unknown>> {
    return this.idempotent(
      principal.workspaceId,
      "create-lead",
      key,
      hash,
      async (db) => {
        const selected = [...new Set(input.contentFileIds ?? [])];
        const attachments =
          selected.length === 0
            ? []
            : (
                await db.query<{
                  id: string;
                  display_name: string;
                }>(
                  `SELECT id, display_name FROM content_files
            WHERE workspace_id = $1 AND id = ANY($2::uuid[]) AND deleted_at IS NULL`,
                  [principal.workspaceId, selected],
                )
              ).rows;
        if (attachments.length !== selected.length) throw notFound("Content");
        const names = new Map(
          attachments.map((item) => [item.id, item.display_name]),
        );
        const result = await db.query(
          `INSERT INTO leads
          (id, workspace_id, event_id, captured_by_user_id, captured_at, origin, place,
           first_name, last_name, position, company, email, phone, lead_type, interest,
           written_note, commercial_folio, content_file_ids, content_names)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18::uuid[],$19::text[])
         RETURNING id, event_id AS "eventId", captured_at AS "capturedAt", origin,
                   place, first_name AS "firstName", last_name AS "lastName",
                   position, company, email, phone, lead_type AS "leadType", interest,
                   written_note AS "writtenNote", commercial_folio AS "commercialFolio",
                   content_file_ids AS "contentFileIds", content_names AS "contentNames", revision`,
          [
            input.id,
            principal.workspaceId,
            input.eventId ?? null,
            principal.userId,
            input.capturedAt,
            input.origin,
            input.origin === "direct" ? (input.place ?? null) : null,
            input.firstName,
            input.lastName ?? null,
            input.position ?? null,
            input.company,
            input.email ?? null,
            input.phone ?? null,
            input.leadType,
            input.interest,
            input.writtenNote ?? null,
            input.commercialFolio ?? null,
            selected,
            selected.map((id) => names.get(id)!),
          ],
        );
        return result.rows[0];
      },
    );
  }

  async updateLead(
    principal: Principal,
    leadId: string,
    input: LeadUpdateInput,
    key: string,
    hash: string,
  ): Promise<IdempotentResult<unknown>> {
    return this.idempotent(
      principal.workspaceId,
      "update-lead",
      key,
      hash,
      async (db) => {
        const current = await db.query<{ origin: "event" | "direct" }>(
          `SELECT origin FROM leads
           WHERE workspace_id = $1 AND id = $2 AND deleted_at IS NULL
           FOR UPDATE`,
          [principal.workspaceId, leadId],
        );
        const existing = current.rows[0];
        if (!existing) throw notFound("Lead");
        if (existing.origin === "event" && input.place != null) {
          throw new ApplicationError(
            "invalid_lead_update",
            400,
            "Place can only be edited for direct leads.",
          );
        }
        if (existing.origin === "direct" && !input.place) {
          throw new ApplicationError(
            "invalid_lead_update",
            400,
            "Place is required for direct leads.",
          );
        }
        const result = await db.query(
          `UPDATE leads SET
             first_name = $4, last_name = $5, position = $6, company = $7,
             email = $8, phone = $9, lead_type = $10, interest = $11,
             written_note = $12, place = $13
           WHERE workspace_id = $1 AND id = $2 AND revision = $3
             AND deleted_at IS NULL
           RETURNING id, event_id AS "eventId", captured_at AS "capturedAt", origin,
                     place, first_name AS "firstName", last_name AS "lastName",
                     position, company, email, phone, lead_type AS "leadType", interest,
                     written_note AS "writtenNote", commercial_folio AS "commercialFolio",
                     content_file_ids AS "contentFileIds", content_names AS "contentNames", revision`,
          [
            principal.workspaceId,
            leadId,
            input.revision,
            input.firstName,
            input.lastName ?? null,
            input.position ?? null,
            input.company,
            input.email ?? null,
            input.phone ?? null,
            input.leadType,
            input.interest,
            input.writtenNote ?? null,
            existing.origin === "direct" ? input.place : null,
          ],
        );
        const row = result.rows[0];
        if (!row) throw revisionConflict();
        return row;
      },
      200,
    );
  }

  async listLeadMedia(
    principal: Principal,
    leadId: string,
  ): Promise<LeadMediaRecord[]> {
    const result = await this.pool.query<LeadMediaRecord>(
      `SELECT m.id, m.kind, m.content_type AS "contentType", m.byte_size AS "byteSize",
              m.captured_at AS "capturedAt", m.duration_ms AS "durationMs", m.sha256,
              m.storage_object_key AS "storageObjectKey",
              m.upload_status AS "uploadStatus", m.uploaded_at AS "uploadedAt", m.revision
       FROM lead_media m JOIN leads l ON l.id = m.lead_id AND l.workspace_id = m.workspace_id
       WHERE m.workspace_id = $1 AND m.lead_id = $2 AND m.deleted_at IS NULL
         AND l.deleted_at IS NULL ORDER BY m.created_at`,
      [principal.workspaceId, leadId],
    );
    return result.rows;
  }

  async prepareLeadMedia(
    principal: Principal,
    leadId: string,
    input: LeadMediaInput,
    objectKey: string,
  ): Promise<void> {
    const lead = await this.pool.query(
      "SELECT id FROM leads WHERE workspace_id = $1 AND id = $2 AND deleted_at IS NULL",
      [principal.workspaceId, leadId],
    );
    if (!lead.rows[0]) throw notFound("Lead");
    const result = await this.pool.query(
      `INSERT INTO lead_media
        (id, workspace_id, lead_id, kind, content_type, byte_size, captured_at,
         duration_ms, sha256, storage_object_key, upload_status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'pending')
       ON CONFLICT (workspace_id, id) DO UPDATE SET
         kind = EXCLUDED.kind, content_type = EXCLUDED.content_type,
         byte_size = EXCLUDED.byte_size, captured_at = EXCLUDED.captured_at,
         duration_ms = EXCLUDED.duration_ms, sha256 = EXCLUDED.sha256,
         storage_object_key = EXCLUDED.storage_object_key,
         upload_status = CASE WHEN lead_media.upload_status = 'available'
           THEN 'available' ELSE 'pending' END,
         deleted_at = NULL
       WHERE lead_media.lead_id = $3
       RETURNING id`,
      [
        input.id,
        principal.workspaceId,
        leadId,
        input.kind,
        input.contentType,
        input.byteSize,
        input.capturedAt,
        input.durationMs ?? null,
        input.sha256 ?? null,
        objectKey,
      ],
    );
    if (!result.rows[0]) throw notFound("Media");
  }

  async createLeadMedia(
    principal: Principal,
    leadId: string,
    input: LeadMediaInput,
    key: string,
    hash: string,
    objectKey: string,
  ): Promise<IdempotentResult<unknown>> {
    return this.idempotent(
      principal.workspaceId,
      "create-lead-media",
      key,
      hash,
      async (db) => {
        const lead = await db.query(
          "SELECT id FROM leads WHERE workspace_id = $1 AND id = $2 AND deleted_at IS NULL",
          [principal.workspaceId, leadId],
        );
        if (!lead.rows[0]) throw notFound("Lead");
        const result = await db.query(
          `UPDATE lead_media SET upload_status = 'available', uploaded_at = now(),
             storage_object_key = $4
           WHERE workspace_id = $1 AND lead_id = $2 AND id = $3
             AND kind = $5 AND content_type = $6 AND byte_size = $7
             AND captured_at = $8 AND duration_ms IS NOT DISTINCT FROM $9
             AND sha256 IS NOT DISTINCT FROM $10 AND deleted_at IS NULL
         RETURNING id, kind, content_type AS "contentType", byte_size AS "byteSize",
                   captured_at AS "capturedAt", duration_ms AS "durationMs", sha256,
                   storage_object_key AS "storageObjectKey",
                   upload_status AS "uploadStatus", uploaded_at AS "uploadedAt", revision`,
          [
            principal.workspaceId,
            leadId,
            input.id,
            objectKey,
            input.kind,
            input.contentType,
            input.byteSize,
            input.capturedAt,
            input.durationMs ?? null,
            input.sha256 ?? null,
          ],
        );
        const row = result.rows[0];
        if (!row) throw notFound("Prepared media");
        return row;
      },
    );
  }

  private async idempotent<T>(
    workspaceId: string,
    operation: string,
    key: string,
    hash: string,
    execute: (db: Queryable) => Promise<T>,
    responseStatus = 201,
  ): Promise<IdempotentResult<T>> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      // Serializes concurrent retries before either request can create a row.
      await client.query(
        "SELECT pg_advisory_xact_lock(hashtext($1), hashtext($2))",
        [workspaceId, `${operation}:${key}`],
      );
      const existing = await client.query<{
        request_hash: string;
        response_body: T;
      }>(
        `SELECT request_hash, response_body FROM idempotency_records
         WHERE workspace_id = $1 AND operation = $2 AND idempotency_key = $3 FOR UPDATE`,
        [workspaceId, operation, key],
      );
      const stored = existing.rows[0];
      if (stored) {
        if (stored.request_hash !== hash)
          throw conflict(
            "Idempotency key was already used with a different payload.",
          );
        await client.query("COMMIT");
        return { value: stored.response_body, replayed: true };
      }
      const value = await execute(client);
      await client.query(
        `INSERT INTO idempotency_records
          (workspace_id, operation, idempotency_key, request_hash, response_status, response_body)
         VALUES ($1,$2,$3,$4,$5,$6::jsonb)`,
        [
          workspaceId,
          operation,
          key,
          hash,
          responseStatus,
          JSON.stringify(value),
        ],
      );
      await client.query("COMMIT");
      return { value, replayed: false };
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  }
}
