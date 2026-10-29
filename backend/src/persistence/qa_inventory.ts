/** WEB-02 / AUT-10, RNF-09, E-14: operator-only synthetic DEV inventory.
 * No provisioning, arbitrary SQL or caller-selected identity; all output is aggregate.
 */
import { createHash, timingSafeEqual } from "node:crypto";
import type { Pool } from "pg";

export function inventorySubject(
  env: NodeJS.ProcessEnv,
  invokedArn: string | undefined,
): string {
  const subject = env.QA_INVENTORY_SUBJECT;
  const allowed = env.QA_INVENTORY_SUBJECT_HASH;
  if (
    env.QA_INVENTORY_ENVIRONMENT !== "dev" ||
    env.AWS_REGION !== "us-east-1" ||
    !invokedArn ||
    !/^arn:aws:lambda:us-east-1:837153590200:function:FolooBackend-dev-MigrationFunction[^:]+(?::[^:]+)?$/.test(
      invokedArn,
    ) ||
    !subject ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(
      subject,
    ) ||
    !allowed ||
    !/^[A-Za-z0-9_-]{43}$/.test(allowed)
  )
    throw new Error("qa_inventory_not_authorized");
  const actual = createHash("sha256")
    .update("foloo-account-deletion-qa\0" + subject)
    .digest("base64url");
  if (!timingSafeEqual(Buffer.from(actual), Buffer.from(allowed)))
    throw new Error("qa_inventory_not_authorized");
  return subject;
}

const tables = [
  "seller_profiles",
  "events",
  "leads",
  "lead_media",
  "content_files",
  "idempotency_records",
  "email_templates",
  "event_email_templates",
  "email_connections",
  "email_oauth_states",
  "email_opt_outs",
  "email_owner_opt_outs",
  "email_unsubscribe_tokens",
  "email_follow_ups",
  "email_send_intents",
] as const;
const countFields = [
  "internalUsers",
  "personalAccounts",
  "livePersonalAccounts",
  "personalWorkspaces",
  "livePersonalWorkspaces",
  "memberships",
  "ownerMemberships",
  ...tables,
] as const;
const boolFields = [
  "internalAccountExists",
  "activeSubscription",
  "stripeCustomerReference",
  "stripeSubscriptionReference",
  "billingEventTimestamp",
  "currentPeriodEndPresent",
] as const;
const statuses = [
  "none",
  "trial",
  "trial_exhausted",
  "active",
  "expired",
] as const;
export type QaInventory = Record<(typeof countFields)[number], number> &
  Record<(typeof boolFields)[number], boolean> & {
    subscriptionStates: string[];
  };

// Static table names only; $1 is the server-pinned Cognito sub. No global Billing scans.
const sql = `WITH target_user AS (SELECT id FROM app_users WHERE cognito_sub=$1),
 owned_accounts AS (SELECT a.* FROM accounts a JOIN target_user u ON a.owner_user_id=u.id WHERE a.kind='personal'),
 owned_workspaces AS (SELECT w.id,w.deleted_at FROM workspaces w JOIN owned_accounts a ON w.account_id=a.id)
 SELECT
 (SELECT count(*) FROM target_user) AS "internalUsers",
 EXISTS(SELECT 1 FROM target_user) AS "internalAccountExists",
 (SELECT count(*) FROM owned_accounts) AS "personalAccounts",
 (SELECT count(*) FROM owned_accounts WHERE deleted_at IS NULL) AS "livePersonalAccounts",
 EXISTS(SELECT 1 FROM owned_accounts WHERE subscription_status='active') AS "activeSubscription",
 EXISTS(SELECT 1 FROM owned_accounts WHERE stripe_customer_id IS NOT NULL) AS "stripeCustomerReference",
 EXISTS(SELECT 1 FROM owned_accounts WHERE stripe_subscription_id IS NOT NULL) AS "stripeSubscriptionReference",
 EXISTS(SELECT 1 FROM owned_accounts WHERE billing_event_at IS NOT NULL) AS "billingEventTimestamp",
 EXISTS(SELECT 1 FROM owned_accounts WHERE current_period_end IS NOT NULL) AS "currentPeriodEndPresent",
 COALESCE((SELECT array_agg(DISTINCT subscription_status::text) FROM owned_accounts), ARRAY[]::text[]) AS "subscriptionStates",
 (SELECT count(*) FROM owned_workspaces) AS "personalWorkspaces",
 (SELECT count(*) FROM owned_workspaces WHERE deleted_at IS NULL) AS "livePersonalWorkspaces",
 (SELECT count(*) FROM workspace_members m JOIN target_user u ON m.user_id=u.id) AS "memberships",
 (SELECT count(*) FROM workspace_members m JOIN target_user u ON m.user_id=u.id
   JOIN owned_workspaces w ON m.workspace_id=w.id WHERE m.role='owner') AS "ownerMemberships",
 ${tables.map((t) => `(SELECT count(*) FROM ${t} d JOIN owned_workspaces w ON d.workspace_id=w.id) AS "${t}"`).join(",\n")}`;

function redact(row: Record<string, unknown> | undefined): QaInventory {
  if (!row) throw new Error("qa_inventory_invalid_result");
  const result: Record<string, unknown> = {};
  for (const k of countFields) {
    const value = row[k];
    if (
      (typeof value !== "string" && typeof value !== "number") ||
      !/^\d+$/.test(String(value)) ||
      !Number.isSafeInteger(Number(value))
    )
      throw new Error("qa_inventory_invalid_result");
    result[k] = Number(value);
  }
  for (const k of boolFields) {
    if (typeof row[k] !== "boolean")
      throw new Error("qa_inventory_invalid_result");
    result[k] = row[k];
  }
  if (
    !Array.isArray(row.subscriptionStates) ||
    row.subscriptionStates.some((s) => !statuses.includes(s))
  )
    throw new Error("qa_inventory_invalid_result");
  result.subscriptionStates = [...row.subscriptionStates];
  return result as QaInventory;
}

export async function inspectSyntheticInventory(
  pool: Pick<Pool, "connect">,
  subject: string,
): Promise<QaInventory> {
  const client = await pool.connect();
  try {
    await client.query(
      "BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY",
    );
    await client.query("SET LOCAL statement_timeout = '5s'");
    await client.query("SET LOCAL lock_timeout = '1s'");
    await client.query("SET LOCAL idle_in_transaction_session_timeout = '5s'");
    const result = await client.query(sql, [subject]);
    const output = redact(result.rows[0]);
    // Never commit this diagnostic transaction, even on success.
    await client.query("ROLLBACK");
    return output;
  } finally {
    // Destroy connection: an aborted/timeout transaction must not enter a pool.
    client.release(true);
  }
}
