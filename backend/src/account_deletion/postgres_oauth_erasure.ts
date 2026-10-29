/** INF-15 / RNF-09, E-14: erase owner OAuth state without revoking shared grants
 * for server-disconnected connections. Active grants still require revocation.
 */

import type { Pool } from "pg";

import type { EmailProviderName } from "../domain/email_follow_ups.js";
import type { EmailProviderBoundary } from "../email/provider_invoker.js";
import type { OAuthErasurePort } from "./staged_account_deletion_executor.js";

export class PostgresOAuthErasure implements OAuthErasurePort {
  constructor(
    private readonly pool: Pool,
    private readonly provider: EmailProviderBoundary,
  ) {}

  async revokeAndDestroy(ownerSubject: string): Promise<void> {
    const connections = await this.pool.query<{
      workspace_id: string;
      provider: EmailProviderName;
      status: string;
      encrypted_credentials: Buffer;
    }>(
      `SELECT c.workspace_id,c.provider,c.status,c.encrypted_credentials
       FROM email_connections c
       JOIN app_users u ON u.id=c.owner_user_id
       WHERE u.cognito_sub=$1`,
      [ownerSubject],
    );
    // Validate the entire snapshot before any external side effect. Status is
    // read from PostgreSQL, never supplied by the deletion request. STORE-02's
    // accepted-request write barrier prevents reconnecting during erasure.
    if (
      connections.rows.some(
        (connection) =>
          !["connected", "reconnect_required", "disconnected"].includes(
            connection.status,
          ),
      )
    ) {
      throw new Error("OAuth connection state is not supported for erasure.");
    }
    for (const connection of connections.rows) {
      // Revoking a disconnected Google grant can invalidate other Foloo clients
      // using the same external account. Local cleanup below still removes its
      // encrypted credentials and dependent intents; it never retains the row.
      if (connection.status === "disconnected") continue;
      const result = await this.provider.invoke({
        action: "revoke",
        provider: connection.provider,
        encryptedCredentials:
          connection.encrypted_credentials.toString("base64"),
        workspaceId: connection.workspace_id,
      });
      if (!("revoked" in result) || !result.revoked) {
        throw new Error("OAuth provider did not confirm revocation.");
      }
    }
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      // Intents own the restrictive FK to connections and may also reference
      // one another. Deleting the complete owner workspace set in one
      // statement removes both dependency layers before their parent rows.
      await client.query(
        `DELETE FROM email_send_intents i
         USING app_users u,accounts a,workspaces w
         WHERE u.cognito_sub=$1
           AND a.owner_user_id=u.id AND a.kind='personal'
           AND w.account_id=a.id AND i.workspace_id=w.id`,
        [ownerSubject],
      );
      await client.query(
        `DELETE FROM email_oauth_states s USING app_users u
         WHERE s.owner_user_id=u.id AND u.cognito_sub=$1`,
        [ownerSubject],
      );
      await client.query(
        `DELETE FROM email_connections c USING app_users u
         WHERE c.owner_user_id=u.id AND u.cognito_sub=$1`,
        [ownerSubject],
      );
      await client.query("COMMIT");
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  }

  async isDestroyed(ownerSubject: string): Promise<boolean> {
    const result = await this.pool.query<{ exists: boolean }>(
      `SELECT EXISTS(
         SELECT 1 FROM email_connections c
         JOIN app_users u ON u.id=c.owner_user_id
         WHERE u.cognito_sub=$1
         UNION ALL
         SELECT 1 FROM email_oauth_states s
         JOIN app_users u ON u.id=s.owner_user_id
         WHERE u.cognito_sub=$1
       ) AS exists`,
      [ownerSubject],
    );
    return !(result.rows[0]?.exists ?? false);
  }
}
