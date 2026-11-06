/** PostgreSQL barrier, inventory and restore-reconciliation adapters. */

import type { Pool } from "pg";

import { ApplicationError } from "../application/errors.js";
import { AccountDeletionDependencyUnavailableError } from "./account_deletion_workflow.js";
import type {
  AccountDeletionInventory,
  AccountDeletionOperationalBarrier,
  SubscriptionInventory,
  SubscriptionSummary,
} from "./account_deletion_workflow.js";

export class PostgresAccountDeletionRuntime
  implements
    AccountDeletionInventory,
    AccountDeletionOperationalBarrier,
    SubscriptionInventory
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
      entitlement_source: string;
      stripe_customer_id: string | null;
      stripe_subscription_id: string | null;
    }>(
      `SELECT a.subscription_status,a.entitlement_source,
              a.stripe_customer_id,a.stripe_subscription_id
       FROM accounts a JOIN app_users u ON u.id=a.owner_user_id
       WHERE u.cognito_sub=$1 AND a.kind='personal' AND a.deleted_at IS NULL`,
      [ownerSubject],
    );
    const account = result.rows[0];
    const status = account?.subscription_status ?? "none";
    const stripeActive =
      status === "active" && account?.entitlement_source === "stripe";
    if (
      status === "active" &&
      account?.entitlement_source !== "administrative" &&
      (!stripeActive ||
        !account.stripe_customer_id ||
        !account.stripe_subscription_id)
    ) {
      throw new AccountDeletionDependencyUnavailableError("payments");
    }
    return {
      status,
      cancellationRequired:
        stripeActive &&
        Boolean(account.stripe_customer_id) &&
        Boolean(account.stripe_subscription_id),
      planDisplayName: null,
      currentPeriodEnd: null,
    };
  }

  async markPending(input: {
    requestId: string;
    ownerSubject: string;
    acceptedAt: Date;
  }): Promise<void> {
    await this.pool.query("SELECT mark_account_deletion_pending($1,$2,$3)", [
      input.ownerSubject,
      input.requestId,
      input.acceptedAt,
    ]);
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
    await this.markPending(input);
  }
}
