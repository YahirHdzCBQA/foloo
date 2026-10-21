/**
 * Owner-scoped PostgreSQL erasure adapter for the future deletion worker.
 * It derives the personal workspace from Cognito `sub`, locks it, and deletes
 * only that ownership graph. This module is not wired into runtime.
 */

import type { Pool } from "pg";

import type { PostgresErasurePort } from "./staged_account_deletion_executor.js";

export class PostgresOwnerErasure implements PostgresErasurePort {
  constructor(private readonly pool: Pool) {}

  async objectKeys(ownerSubject: string): Promise<readonly string[]> {
    const result = await this.pool.query<{ storage_object_key: string }>(
      `SELECT storage_object_key FROM (
         SELECT m.storage_object_key
         FROM app_users u
         JOIN workspace_members wm ON wm.user_id=u.id AND wm.role='owner'
         JOIN workspaces w ON w.id=wm.workspace_id AND w.deleted_at IS NULL
         JOIN accounts a ON a.id=w.account_id AND a.owner_user_id=u.id
           AND a.kind='personal' AND a.deleted_at IS NULL
         JOIN lead_media m ON m.workspace_id=w.id
         WHERE u.cognito_sub=$1 AND m.storage_object_key IS NOT NULL
         UNION
         SELECT c.storage_object_key
         FROM app_users u
         JOIN workspace_members wm ON wm.user_id=u.id AND wm.role='owner'
         JOIN workspaces w ON w.id=wm.workspace_id AND w.deleted_at IS NULL
         JOIN accounts a ON a.id=w.account_id AND a.owner_user_id=u.id
           AND a.kind='personal' AND a.deleted_at IS NULL
         JOIN content_files c ON c.workspace_id=w.id
         WHERE u.cognito_sub=$1 AND c.storage_object_key IS NOT NULL
       ) owner_objects`,
      [ownerSubject],
    );
    return result.rows.map((row) => row.storage_object_key);
  }

  async deleteOwnerData(ownerSubject: string): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      const scope = await client.query<{
        user_id: string;
        account_id: string;
        workspace_id: string;
      }>(
        `SELECT u.id AS user_id,a.id AS account_id,w.id AS workspace_id
         FROM app_users u
         JOIN accounts a ON a.owner_user_id=u.id AND a.kind='personal'
           AND a.deleted_at IS NULL
         JOIN workspaces w ON w.account_id=a.id AND w.deleted_at IS NULL
         JOIN workspace_members wm ON wm.workspace_id=w.id AND wm.user_id=u.id
           AND wm.role='owner'
         WHERE u.cognito_sub=$1
         FOR UPDATE OF u,a,w`,
        [ownerSubject],
      );
      if (scope.rowCount === 0) {
        await client.query("COMMIT");
        return;
      }
      if (scope.rowCount !== 1) {
        throw new Error("Account deletion ownership graph is ambiguous.");
      }
      const owner = scope.rows[0]!;
      const workspaceTables = [
        "email_send_intents",
        "email_follow_ups",
        "email_unsubscribe_tokens",
        "email_owner_opt_outs",
        "email_opt_outs",
        "email_oauth_states",
        "email_connections",
        "event_email_templates",
        "email_templates",
        "idempotency_records",
        "lead_media",
        "leads",
        "content_files",
        "events",
        "seller_profiles",
        "workspace_members",
      ] as const;
      for (const table of workspaceTables) {
        await client.query(`DELETE FROM ${table} WHERE workspace_id=$1`, [
          owner.workspace_id,
        ]);
      }
      await client.query("DELETE FROM workspaces WHERE id=$1", [
        owner.workspace_id,
      ]);
      await client.query(
        "DELETE FROM accounts WHERE id=$1 AND owner_user_id=$2",
        [owner.account_id, owner.user_id],
      );
      await client.query(
        "DELETE FROM app_users WHERE id=$1 AND cognito_sub=$2",
        [owner.user_id, ownerSubject],
      );
      await client.query("COMMIT");
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  }

  async hasOwnerData(ownerSubject: string): Promise<boolean> {
    const result = await this.pool.query<{ exists: boolean }>(
      "SELECT EXISTS(SELECT 1 FROM app_users WHERE cognito_sub=$1) AS exists",
      [ownerSubject],
    );
    return result.rows[0]?.exists ?? false;
  }
}
