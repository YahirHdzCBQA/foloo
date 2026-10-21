/** Reapplies durable Dynamo tombstones after a PostgreSQL snapshot restore. */

import type { Pool } from "pg";

import type { AccountDeletionGuard } from "./account_deletion_guard.js";
import { PostgresAccountDeletionRuntime } from "./postgres_account_deletion_runtime.js";

export class AccountDeletionRestoreReconciler<KeyHandle> {
  constructor(
    private readonly pool: Pool,
    private readonly guard: AccountDeletionGuard<KeyHandle>,
  ) {}

  async reconcile(): Promise<{ inspected: number; fenced: number }> {
    const result = await this.pool.query<{
      cognito_sub: string;
      created_at: Date;
    }>("SELECT cognito_sub,created_at FROM app_users");
    const postgres = new PostgresAccountDeletionRuntime(this.pool);
    let fenced = 0;
    for (const row of result.rows) {
      const decision = await this.guard.evaluateIdentity(row.cognito_sub);
      if (
        decision.state === "deletion_pending" ||
        decision.state === "deleted"
      ) {
        await postgres.reapplyPendingBarrier({
          ownerSubject: row.cognito_sub,
          requestId: decision.deletionId,
          acceptedAt: row.created_at,
        });
        fenced += 1;
      }
    }
    return { inspected: result.rowCount ?? result.rows.length, fenced };
  }
}
