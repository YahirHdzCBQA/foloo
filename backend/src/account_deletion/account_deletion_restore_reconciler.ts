/** Reapplies durable tombstones and schedules owner-scoped purge after restore. */

import { createHash } from "node:crypto";
import type { Pool } from "pg";

import type { AccountDeletionGuard } from "./account_deletion_guard.js";
import { PostgresAccountDeletionRuntime } from "./postgres_account_deletion_runtime.js";
import type { RestoreRecoveryQueueMessage } from "./aws_account_deletion_adapters.js";

export interface RestoredOwnerErasureScheduler {
  dispatch(message: RestoreRecoveryQueueMessage): Promise<void>;
}

export class AccountDeletionRestoreReconciler<KeyHandle> {
  constructor(
    private readonly pool: Pool,
    private readonly guard: AccountDeletionGuard<KeyHandle>,
    private readonly scheduler: RestoredOwnerErasureScheduler,
  ) {}

  async reconcile(recoveryRunId: string): Promise<{
    inspected: number;
    fenced: number;
    scheduled: number;
  }> {
    requireUuid(recoveryRunId, "recovery run id");
    const result = await this.pool.query<{
      cognito_sub: string;
      created_at: Date;
    }>("SELECT cognito_sub,created_at FROM app_users");
    const postgres = new PostgresAccountDeletionRuntime(this.pool);
    let fenced = 0;
    let scheduled = 0;
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
        await this.scheduler.dispatch({
          mode: "restore_recovery",
          requestId: recoveryRequestId(
            recoveryRunId,
            decision.deletionId,
            row.cognito_sub,
          ),
          deletionId: decision.deletionId,
          ownerSubject: row.cognito_sub,
        });
        scheduled += 1;
      }
    }
    return {
      inspected: result.rowCount ?? result.rows.length,
      fenced,
      scheduled,
    };
  }
}

function recoveryRequestId(
  recoveryRunId: string,
  deletionId: string,
  ownerSubject: string,
): string {
  requireUuid(deletionId, "deletion id");
  const bytes = createHash("sha256")
    .update("foloo-account-deletion-restore-v1\0")
    .update(recoveryRunId)
    .update("\0")
    .update(deletionId)
    .update("\0")
    .update(ownerSubject)
    .digest()
    .subarray(0, 16);
  bytes[6] = (bytes[6]! & 0x0f) | 0x40;
  bytes[8] = (bytes[8]! & 0x3f) | 0x80;
  const hex = bytes.toString("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

function requireUuid(value: string, label: string): void {
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu.test(
      value,
    )
  ) {
    throw new Error(`Invalid ${label}.`);
  }
}
