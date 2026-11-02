/** Operational SLA, retry and alert-deduplication coverage for STORE-02D C. */

import assert from "node:assert/strict";
import test from "node:test";

import {
  AccountDeletionOperationalReconciler,
  type AccountDeletionOperationalAlertSink,
  type AccountDeletionOperationalMilestone,
} from "../src/account_deletion/account_deletion_operational_reconciler.js";
import {
  accountDeletionOperationalDeadline,
  type AccountDeletionRecord,
} from "../src/account_deletion/account_deletion_workflow.js";
import { InMemoryAccountDeletionWorkflowStore } from "../src/account_deletion/in_memory_account_deletion_workflow_store.js";

const acceptedAt = new Date("2035-01-01T08:30:00.000Z");
const requestId = "11111111-1111-4111-8111-111111111111";

function record(
  status: AccountDeletionRecord["status"] = "requested",
): AccountDeletionRecord {
  return {
    requestId,
    ownerKey: "opaque-owner-key",
    idempotencyKey: "synthetic-idempotency-key",
    locale: "es",
    requestedExport: false,
    status,
    createdAt: acceptedAt,
    expiresAt: new Date(acceptedAt.getTime() + 60_000),
    acceptedAt,
    operationalDeadline: accountDeletionOperationalDeadline(acceptedAt),
    updatedAt: acceptedAt,
    completedAt: status === "completed" ? acceptedAt : null,
    receiptHash: "a".repeat(64),
    receiptExpiresAt: new Date(acceptedAt.getTime() + 30 * 86_400_000),
    supportCode: status === "blocked" ? "dependency_payments" : null,
    barrier: {
      deletionId: requestId,
      subjectKey: "SUB#test#v1#opaque" as never,
      registrationKey: "REG#test#v1#opaque" as never,
    },
    confirmationIdempotencyKey: "synthetic-confirmation-key",
    dispatchStatus: "dispatched",
    subscription: {
      status: "active",
      cancellationRequired: true,
      planDisplayName: "Foloo",
      currentPeriodEnd: null,
    },
  };
}

class Alerts implements AccountDeletionOperationalAlertSink {
  readonly milestones: AccountDeletionOperationalMilestone[] = [];
  async emit(input: { milestone: AccountDeletionOperationalMilestone }) {
    this.milestones.push(input.milestone);
  }
}

async function harness(status: AccountDeletionRecord["status"], now: Date) {
  const store = new InMemoryAccountDeletionWorkflowStore();
  const initial = { ...record(), status: "awaiting_confirmation" as const };
  await store.createPreflight(initial);
  await store.acceptConfirmation(record("requested"));
  if (status !== "requested") await store.update(record(status));
  const dispatched: string[] = [];
  const alerts = new Alerts();
  const reconciler = new AccountDeletionOperationalReconciler(
    store,
    {
      async dispatch(input) {
        dispatched.push(input.requestId);
      },
    },
    {
      async capture() {
        throw new Error("not used");
      },
      async recoverReceipt() {
        throw new Error("not used");
      },
      async recoverOwnerSubject() {
        return "synthetic-owner-subject";
      },
    },
    alerts,
    { now: () => now },
  );
  return { store, reconciler, dispatched, alerts };
}

test("INF-15 persists a deadline exactly 15 days after durable acceptance", () => {
  assert.equal(
    accountDeletionOperationalDeadline(acceptedAt).toISOString(),
    "2035-01-16T08:30:00.000Z",
  );
});

test("INF-15 emits preventive day 10/day 13 and critical day 15 alerts once", async () => {
  const testHarness = await harness(
    "blocked",
    new Date(acceptedAt.getTime() + 15 * 86_400_000),
  );
  const first = await testHarness.reconciler.reconcile();
  const replay = await testHarness.reconciler.reconcile();
  assert.deepEqual(testHarness.alerts.milestones, [
    "day_10",
    "day_13",
    "day_15",
  ]);
  assert.equal(first.overdue, 1);
  assert.equal(first.blocked, 1);
  assert.equal(first.failed, 1);
  assert.equal(first.redispatched, 1);
  assert.equal(replay.alerts, 0);
  assert.equal(replay.redispatched, 0);
});

test("RNF-10 concurrent reconciliation dispatches a blocked request once per lease", async () => {
  const testHarness = await harness(
    "blocked",
    new Date(acceptedAt.getTime() + 11 * 86_400_000),
  );
  await Promise.all([
    testHarness.reconciler.reconcile(),
    testHarness.reconciler.reconcile(),
  ]);
  assert.equal(testHarness.dispatched.length, 1);
  assert.deepEqual(testHarness.alerts.milestones, ["day_10"]);
});

test("INF-15 never reconciles completed workflows", async () => {
  const testHarness = await harness(
    "completed",
    new Date(acceptedAt.getTime() + 20 * 86_400_000),
  );
  const result = await testHarness.reconciler.reconcile();
  assert.equal(result.inspected, 0);
  assert.equal(testHarness.dispatched.length, 0);
  assert.equal(testHarness.alerts.milestones.length, 0);
});
