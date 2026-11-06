/** FL-021/STORE-02D boundary tests for plan source and Stripe cancellation. */

import assert from "node:assert/strict";
import test from "node:test";

import type { Pool } from "pg";

import { AccountDeletionDependencyUnavailableError } from "../src/account_deletion/account_deletion_workflow.js";
import { PostgresAccountDeletionRuntime } from "../src/account_deletion/postgres_account_deletion_runtime.js";

function runtime(row: Record<string, unknown>) {
  const pool = {
    async query() {
      return { rows: [row], rowCount: 1 };
    },
  } as unknown as Pool;
  return new PostgresAccountDeletionRuntime(pool);
}

test("FREE and administrative PRO do not require Stripe cancellation", async () => {
  const free = await runtime({
    subscription_status: "trial_exhausted",
    entitlement_source: "trial",
    stripe_customer_id: null,
    stripe_subscription_id: null,
  }).summary("subject-free");
  assert.equal(free.cancellationRequired, false);

  const administrative = await runtime({
    subscription_status: "active",
    entitlement_source: "administrative",
    stripe_customer_id: null,
    stripe_subscription_id: null,
  }).summary("subject-administrative");
  assert.equal(administrative.cancellationRequired, false);
});

test("Stripe PRO requires cancellation only with a coherent binding", async () => {
  const stripe = await runtime({
    subscription_status: "active",
    entitlement_source: "stripe",
    stripe_customer_id: "cus_synthetic",
    stripe_subscription_id: "sub_synthetic",
  }).summary("subject-stripe");
  assert.equal(stripe.cancellationRequired, true);

  await assert.rejects(
    runtime({
      subscription_status: "active",
      entitlement_source: "stripe",
      stripe_customer_id: "cus_synthetic",
      stripe_subscription_id: null,
    }).summary("subject-inconsistent"),
    AccountDeletionDependencyUnavailableError,
  );
  await assert.rejects(
    runtime({
      subscription_status: "active",
      entitlement_source: "legacy_active",
      stripe_customer_id: null,
      stripe_subscription_id: null,
    }).summary("subject-legacy"),
    AccountDeletionDependencyUnavailableError,
  );
});
