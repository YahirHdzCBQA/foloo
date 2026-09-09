/** PostgreSQL adapter enforcing workspace scope on every resource operation. */

import { createHash } from "node:crypto";

import type pg from "pg";

import { conflict, notFound } from "../application/errors.js";
import type { FolooRepository } from "../application/ports.js";
import type {
  EventInput,
  IdempotentResult,
  LeadInput,
  LeadMediaInput,
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
              created_at AS "createdAt", updated_at AS "updatedAt"
       FROM events WHERE workspace_id = $1 AND deleted_at IS NULL ORDER BY starts_at`,
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

  async listLeads(principal: Principal): Promise<unknown[]> {
    const result = await this.pool.query(
      `SELECT id, event_id AS "eventId", captured_at AS "capturedAt", origin, place,
              first_name AS "firstName", last_name AS "lastName", position, company,
              email, phone, lead_type AS "leadType", interest, written_note AS "writtenNote",
              commercial_folio AS "commercialFolio", revision
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
        const result = await db.query(
          `INSERT INTO leads
          (id, workspace_id, event_id, captured_by_user_id, captured_at, origin, place,
           first_name, last_name, position, company, email, phone, lead_type, interest,
           written_note, commercial_folio)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)
         RETURNING id, event_id AS "eventId", captured_at AS "capturedAt", origin,
                   place, first_name AS "firstName", last_name AS "lastName",
                   position, company, email, phone, lead_type AS "leadType", interest,
                   written_note AS "writtenNote", commercial_folio AS "commercialFolio", revision`,
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
          ],
        );
        return result.rows[0];
      },
    );
  }

  async listLeadMedia(
    principal: Principal,
    leadId: string,
  ): Promise<unknown[]> {
    const result = await this.pool.query(
      `SELECT m.id, m.kind, m.content_type AS "contentType", m.byte_size AS "byteSize",
              m.captured_at AS "capturedAt", m.duration_ms AS "durationMs", m.sha256,
              m.revision
       FROM lead_media m JOIN leads l ON l.id = m.lead_id AND l.workspace_id = m.workspace_id
       WHERE m.workspace_id = $1 AND m.lead_id = $2 AND m.deleted_at IS NULL
         AND l.deleted_at IS NULL ORDER BY m.created_at`,
      [principal.workspaceId, leadId],
    );
    return result.rows;
  }

  async createLeadMedia(
    principal: Principal,
    leadId: string,
    input: LeadMediaInput,
    key: string,
    hash: string,
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
          `INSERT INTO lead_media
          (id, workspace_id, lead_id, kind, content_type, byte_size, captured_at, duration_ms, sha256)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
         RETURNING id, kind, content_type AS "contentType", byte_size AS "byteSize",
                   captured_at AS "capturedAt", duration_ms AS "durationMs", sha256, revision`,
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
          ],
        );
        return result.rows[0];
      },
    );
  }

  private async idempotent<T>(
    workspaceId: string,
    operation: string,
    key: string,
    hash: string,
    execute: (db: Queryable) => Promise<T>,
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
         VALUES ($1,$2,$3,$4,201,$5::jsonb)`,
        [workspaceId, operation, key, hash, JSON.stringify(value)],
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
