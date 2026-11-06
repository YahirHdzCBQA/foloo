/** MON-13/RC-10 tests for the private Stripe cancellation boundary. */

import assert from "node:assert/strict";
import test from "node:test";
import type { Pool } from "pg";

import { AccountDeletionDependencyUnavailableError } from "../src/account_deletion/account_deletion_workflow.js";
import { StripeSubscriptionCancellation } from "../src/account_deletion/stripe_subscription_cancellation.js";
import type {
  BillingCommand,
  BillingProvider,
  BillingProviderResult,
} from "../src/billing/billing_provider_contract.js";

const requestId = "00000000-0000-4000-8000-000000000321";
const ownerSubject = "00000000-0000-4000-8000-000000000123";

class Provider implements BillingProvider {
  readonly commands: BillingCommand[] = [];
  result: BillingProviderResult = { cancellationStatus: "confirmed" };
  fail = false;

  async invoke(command: BillingCommand): Promise<BillingProviderResult> {
    this.commands.push(command);
    if (this.fail) throw new Error("synthetic timeout");
    return this.result;
  }
}

function pool(rows: readonly Record<string, unknown>[]): Pool {
  return {
    async query(sql: string, values: unknown[]) {
      assert.match(sql, /u\.cognito_sub=\$1/u);
      assert.deepEqual(values, [ownerSubject]);
      return { rows, rowCount: rows.length };
    },
  } as unknown as Pool;
}

test("MON-13 Free, trial and inactive PRO do not call Stripe", async () => {
  for (const status of ["none", "trial", "trial_exhausted", "expired"]) {
    const provider = new Provider();
    const cancellation = new StripeSubscriptionCancellation(
      pool([
        {
          status,
          entitlementSource: "trial",
          customerId: null,
          subscriptionId: null,
        },
      ]),
      provider,
    );
    assert.equal(
      await cancellation.cancelRenewal({ requestId, ownerSubject }),
      "not_applicable",
    );
    assert.equal(provider.commands.length, 0);
  }
});

test("MON-13 active PRO uses one server-owned binding and stable idempotency", async () => {
  const provider = new Provider();
  const cancellation = new StripeSubscriptionCancellation(
    pool([
      {
        status: "active",
        entitlementSource: "stripe",
        customerId: "cus_synthetic",
        subscriptionId: "sub_synthetic",
      },
    ]),
    provider,
  );
  assert.equal(
    await cancellation.cancelRenewal({ requestId, ownerSubject }),
    "confirmed",
  );
  assert.deepEqual(provider.commands, [
    {
      action: "cancelSubscriptionRenewal",
      customerId: "cus_synthetic",
      subscriptionId: "sub_synthetic",
      idempotencyKey: `account-deletion-${requestId}`,
    },
  ]);
});

test("MON-13 uncertain timeout fails closed and retry keeps the same key", async () => {
  const provider = new Provider();
  provider.fail = true;
  const cancellation = new StripeSubscriptionCancellation(
    pool([
      {
        status: "active",
        entitlementSource: "stripe",
        customerId: "cus_synthetic",
        subscriptionId: "sub_synthetic",
      },
    ]),
    provider,
  );
  await assert.rejects(
    cancellation.cancelRenewal({ requestId, ownerSubject }),
    AccountDeletionDependencyUnavailableError,
  );
  provider.fail = false;
  assert.equal(
    await cancellation.cancelRenewal({ requestId, ownerSubject }),
    "confirmed",
  );
  assert.equal(provider.commands.length, 2);
  assert.deepEqual(provider.commands[0], provider.commands[1]);
});

test("RNF-09 missing or ambiguous provider binding fails closed", async () => {
  const provider = new Provider();
  for (const rows of [
    [
      {
        status: "active",
        entitlementSource: "stripe",
        customerId: null,
        subscriptionId: null,
      },
    ],
    [
      {
        status: "active",
        entitlementSource: "stripe",
        customerId: "cus_a",
        subscriptionId: "sub_a",
      },
      {
        status: "active",
        entitlementSource: "stripe",
        customerId: "cus_b",
        subscriptionId: "sub_b",
      },
    ],
  ]) {
    const cancellation = new StripeSubscriptionCancellation(
      pool(rows),
      provider,
    );
    await assert.rejects(
      cancellation.cancelRenewal({ requestId, ownerSubject }),
      AccountDeletionDependencyUnavailableError,
    );
  }
  assert.equal(provider.commands.length, 0);
});

test("MON-21 administrative PRO never calls Stripe during deletion", async () => {
  const provider = new Provider();
  const cancellation = new StripeSubscriptionCancellation(
    pool([
      {
        status: "active",
        entitlementSource: "administrative",
        customerId: null,
        subscriptionId: null,
      },
    ]),
    provider,
  );
  assert.equal(
    await cancellation.cancelRenewal({ requestId, ownerSubject }),
    "not_applicable",
  );
  assert.equal(provider.commands.length, 0);
});

test("an unresolved legacy active entitlement fails closed", async () => {
  const provider = new Provider();
  const cancellation = new StripeSubscriptionCancellation(
    pool([
      {
        status: "active",
        entitlementSource: "legacy_active",
        customerId: null,
        subscriptionId: null,
      },
    ]),
    provider,
  );
  await assert.rejects(
    cancellation.cancelRenewal({ requestId, ownerSubject }),
    AccountDeletionDependencyUnavailableError,
  );
  assert.equal(provider.commands.length, 0);
});
