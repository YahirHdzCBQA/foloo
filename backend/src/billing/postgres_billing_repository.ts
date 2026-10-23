/** MON-16: deduplication and account-only entitlement writes share one transaction. */
import type pg from "pg";
import { ApplicationError } from "../application/errors.js";
import type { z } from "zod";
import {
  billingCheckoutSchema,
  billingEventSchema,
  billingSubscriptionSchema,
} from "../transport/schemas.js";
export type BillingEvent = z.infer<typeof billingEventSchema>;
export type BillingAccount = {
  id: string;
  subscriptionStatus: string;
  customerId: string | null;
};
export interface BillingRepository {
  account(accountId: string): Promise<BillingAccount | undefined>;
  linkCustomer(accountId: string, customerId: string): Promise<string>;
  apply(event: BillingEvent, priceId?: string): Promise<void>;
}
const unavailable = () =>
  new ApplicationError(
    "billing_account_unavailable",
    503,
    "Billing account is temporarily unavailable.",
  );
export class PostgresBillingRepository implements BillingRepository {
  constructor(private readonly pool: pg.Pool) {}
  async account(id: string) {
    return (
      await this.pool.query<BillingAccount>(
        `SELECT id, subscription_status AS "subscriptionStatus", stripe_customer_id AS "customerId" FROM accounts WHERE id=$1 AND deleted_at IS NULL`,
        [id],
      )
    ).rows[0];
  }
  async linkCustomer(id: string, customerId: string) {
    await this.pool.query(
      `UPDATE accounts SET stripe_customer_id=$2, updated_at=now() WHERE id=$1 AND deleted_at IS NULL AND stripe_customer_id IS NULL`,
      [id, customerId],
    );
    const account = await this.account(id);
    if (!account?.customerId) throw unavailable();
    return account.customerId;
  }
  async apply(event: BillingEvent, priceId?: string) {
    const db = await this.pool.connect();
    try {
      await db.query("BEGIN");
      const inserted = await db.query(
        "INSERT INTO billing_events(event_id, type) VALUES ($1,$2) ON CONFLICT DO NOTHING RETURNING event_id",
        [event.id, event.type],
      );
      if (inserted.rowCount) await this.applySnapshot(db, event, priceId);
      await db.query("COMMIT");
    } catch (error) {
      await db.query("ROLLBACK");
      throw error;
    } finally {
      db.release();
    }
  }
  private async applySnapshot(
    db: pg.PoolClient,
    event: BillingEvent,
    priceId?: string,
  ) {
    if (event.type === "checkout.session.completed") {
      const parsed = billingCheckoutSchema.safeParse(event.data.object);
      if (!parsed.success) return; // Includes unrelated mode=payment sessions.
      const session = parsed.data;
      if (
        session.metadata.origin !== "foloo-app" &&
        !(
          priceId &&
          session.line_items?.data.length === 1 &&
          session.line_items.data[0]?.price.id === priceId
        )
      )
        return;
      // Resolve signed metadata through existing ownership; never provision from webhook input.
      const owner = await db.query(
        `SELECT a.id FROM accounts a JOIN app_users u ON u.id=a.owner_user_id WHERE a.id=$1 AND u.cognito_sub=$2 AND a.deleted_at IS NULL FOR UPDATE OF a`,
        [session.client_reference_id, session.metadata.sub],
      );
      if (!owner.rowCount) return;
      const status = ["paid", "no_payment_required"].includes(
        session.payment_status,
      )
        ? "active"
        : null;
      await db.query(
        `UPDATE accounts SET stripe_customer_id=$2, stripe_subscription_id=$3,
        subscription_status=COALESCE($4, subscription_status), billing_event_at=to_timestamp($5),
        entitlement_updated_at=now(), updated_at=now()
        WHERE id=$1 AND deleted_at IS NULL
          AND (stripe_customer_id IS NULL OR stripe_customer_id=$2)
          AND (stripe_subscription_id IS NULL OR stripe_subscription_id=$3 OR subscription_status='expired')
          AND (billing_event_at IS NULL OR billing_event_at <= to_timestamp($5))
          AND NOT (subscription_status='expired' AND stripe_subscription_id IS NOT DISTINCT FROM $3 AND COALESCE($4='active', false) AND COALESCE(billing_event_at >= to_timestamp($5), false))`,
        [
          session.client_reference_id,
          session.customer,
          session.subscription,
          status,
          event.created,
        ],
      );
    } else if (
      [
        "customer.subscription.updated",
        "customer.subscription.deleted",
      ].includes(event.type)
    ) {
      const subscription = billingSubscriptionSchema.parse(event.data.object);
      const account = (
        await db.query<{
          customerId: string | null;
          subscriptionId: string | null;
        }>(
          `SELECT stripe_customer_id AS "customerId", stripe_subscription_id AS "subscriptionId" FROM accounts WHERE (stripe_customer_id=$1 OR id::text=$2) AND deleted_at IS NULL FOR UPDATE`,
          [subscription.customer, subscription.metadata?.accountId ?? ""],
        )
      ).rows[0];
      // Unknown/foreign subscriptions are consumed. Only a known pending binding retries.
      if (!account) return;
      if (account.customerId && account.customerId !== subscription.customer)
        return;
      if (!account.subscriptionId) throw unavailable();
      if (account.subscriptionId !== subscription.id) return;
      const status =
        event.type === "customer.subscription.deleted" ||
        ["canceled", "unpaid"].includes(subscription.status)
          ? "expired"
          : ["active", "trialing"].includes(subscription.status)
            ? "active"
            : null;
      const ends =
        subscription.items?.data.map((item) => item.current_period_end) ?? [];
      const periodEnd =
        subscription.current_period_end ??
        (ends.length ? Math.min(...ends) : null);
      await db.query(
        `UPDATE accounts SET subscription_status=COALESCE($3, subscription_status),
        current_period_end=COALESCE(to_timestamp($4), current_period_end), billing_event_at=to_timestamp($5),
        entitlement_updated_at=now(), updated_at=now()
        WHERE stripe_subscription_id=$1 AND stripe_customer_id=$2 AND deleted_at IS NULL
          AND (billing_event_at IS NULL OR billing_event_at <= to_timestamp($5))
          AND NOT (subscription_status='expired' AND COALESCE($3='active', false) AND COALESCE(billing_event_at >= to_timestamp($5), false))`,
        [
          subscription.id,
          subscription.customer,
          status,
          periodEnd,
          event.created,
        ],
      );
    }
    // invoice.payment_failed alone is not evidence that Stripe exhausted retries (D-03).
  }
}
