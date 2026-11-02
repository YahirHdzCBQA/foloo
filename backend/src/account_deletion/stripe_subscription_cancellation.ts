/**
 * Bridges STORE-02 to the private Stripe Billing Lambda.
 * It derives provider references from the authenticated owner in PostgreSQL;
 * no Stripe identifier crosses the mobile/web contract or enters receipts.
 */

import type { Pool } from "pg";

import type { BillingProvider } from "../billing/billing_provider_contract.js";
import { AccountDeletionDependencyUnavailableError } from "./account_deletion_workflow.js";
import type { SubscriptionCancellationPort } from "./account_deletion_workflow.js";

type SubscriptionBinding = Readonly<{
  status: "none" | "trial" | "trial_exhausted" | "active" | "expired";
  customerId: string | null;
  subscriptionId: string | null;
}>;

/** Confirms that Stripe will not renew before destructive stages can start. */
export class StripeSubscriptionCancellation implements SubscriptionCancellationPort {
  constructor(
    private readonly pool: Pool,
    private readonly provider: BillingProvider,
  ) {}

  async cancelRenewal(input: {
    requestId: string;
    ownerSubject: string;
  }): Promise<"not_applicable" | "confirmed" | "pending"> {
    const binding = await this.binding(input.ownerSubject);
    if (!binding || binding.status !== "active") return "not_applicable";
    if (!binding.customerId || !binding.subscriptionId) {
      throw new AccountDeletionDependencyUnavailableError("payments");
    }
    try {
      const result = await this.provider.invoke({
        action: "cancelSubscriptionRenewal",
        customerId: binding.customerId,
        subscriptionId: binding.subscriptionId,
        idempotencyKey: `account-deletion-${input.requestId}`,
      });
      if (!("cancellationStatus" in result)) {
        throw new Error("Billing provider returned an incompatible result.");
      }
      return result.cancellationStatus;
    } catch (error) {
      if (error instanceof AccountDeletionDependencyUnavailableError) {
        throw error;
      }
      throw new AccountDeletionDependencyUnavailableError("payments");
    }
  }

  private async binding(
    ownerSubject: string,
  ): Promise<SubscriptionBinding | null> {
    const result = await this.pool.query<SubscriptionBinding>(
      `SELECT a.subscription_status AS status,
              a.stripe_customer_id AS "customerId",
              a.stripe_subscription_id AS "subscriptionId"
       FROM accounts a
       JOIN app_users u ON u.id=a.owner_user_id
       WHERE u.cognito_sub=$1 AND a.kind='personal' AND a.deleted_at IS NULL`,
      [ownerSubject],
    );
    if ((result.rowCount ?? result.rows.length) > 1) {
      throw new AccountDeletionDependencyUnavailableError("payments");
    }
    return result.rows[0] ?? null;
  }
}
