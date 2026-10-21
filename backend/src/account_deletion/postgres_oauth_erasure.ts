/** Revokes provider access, then destroys owner-scoped OAuth state in Postgres. */

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
      encrypted_credentials: Buffer;
    }>(
      `SELECT c.workspace_id,c.provider,c.encrypted_credentials
       FROM email_connections c
       JOIN app_users u ON u.id=c.owner_user_id
       WHERE u.cognito_sub=$1`,
      [ownerSubject],
    );
    for (const connection of connections.rows) {
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
    await this.pool.query(
      `DELETE FROM email_oauth_states s USING app_users u
       WHERE s.owner_user_id=u.id AND u.cognito_sub=$1`,
      [ownerSubject],
    );
    await this.pool.query(
      `DELETE FROM email_connections c USING app_users u
       WHERE c.owner_user_id=u.id AND u.cognito_sub=$1`,
      [ownerSubject],
    );
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
