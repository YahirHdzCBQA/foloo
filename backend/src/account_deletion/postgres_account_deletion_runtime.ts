/** PostgreSQL barrier, inventory and restore-reconciliation adapters. */

import type { Pool } from "pg";

import { ApplicationError } from "../application/errors.js";
import type {
  AccountDeletionInventory,
  AccountDeletionOperationalBarrier,
  SubscriptionCancellationPort,
  SubscriptionSummary,
} from "./account_deletion_workflow.js";

export class PostgresAccountDeletionRuntime
  implements
    AccountDeletionInventory,
    AccountDeletionOperationalBarrier,
    SubscriptionCancellationPort
{
  constructor(private readonly pool: Pool) {}

  async pendingSyncCount(): Promise<number> {
    // Outbox is device-local. Flutter contributes its actual pending count.
    return 0;
  }

  async exportAvailable(): Promise<boolean> {
    return true;
  }

  async summary(ownerSubject: string): Promise<SubscriptionSummary> {
    const result = await this.pool.query<{
      subscription_status: SubscriptionSummary["status"];
    }>(
      `SELECT a.subscription_status
       FROM accounts a JOIN app_users u ON u.id=a.owner_user_id
       WHERE u.cognito_sub=$1 AND a.kind='personal' AND a.deleted_at IS NULL`,
      [ownerSubject],
    );
    const status = result.rows[0]?.subscription_status ?? "none";
    return {
      status,
      cancellationRequired: status === "active",
      planDisplayName: null,
      currentPeriodEnd: null,
    };
  }

  async cancelRenewal(ownerSubject: string): Promise<"not_applicable"> {
    const summary = await this.summary(ownerSubject);
    if (summary.cancellationRequired) {
      throw new ApplicationError(
        "subscription_cancellation_unavailable",
        409,
        "Subscription cancellation requires the approved Stripe integration.",
      );
    }
    return "not_applicable";
  }

  async markPending(input: {
    requestId: string;
    ownerSubject: string;
    acceptedAt: Date;
  }): Promise<void> {
    const result = await this.pool.query(
      `UPDATE app_users SET deletion_request_id=$2,deletion_pending_at=$3
       WHERE cognito_sub=$1
         AND (deletion_request_id IS NULL OR deletion_request_id=$2)`,
      [input.ownerSubject, input.requestId, input.acceptedAt],
    );
    if (result.rowCount !== 1) {
      throw new Error(
        "PostgreSQL account deletion barrier was not established.",
      );
    }
  }

  async assertActive(ownerSubject: string): Promise<void> {
    try {
      await this.pool.query("SELECT assert_account_active($1)", [ownerSubject]);
    } catch (error) {
      if ((error as { code?: string; message?: string }).code === "P0001") {
        throw new ApplicationError(
          "account_deletion_pending",
          423,
          "Account deletion is pending.",
        );
      }
      throw error;
    }
  }

  async reapplyPendingBarrier(input: {
    ownerSubject: string;
    requestId: string;
    acceptedAt: Date;
  }): Promise<void> {
    await this.pool.query(
      `UPDATE app_users SET deletion_request_id=$2,deletion_pending_at=$3
       WHERE cognito_sub=$1`,
      [input.ownerSubject, input.requestId, input.acceptedAt],
    );
  }
}
