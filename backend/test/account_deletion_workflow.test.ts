/** Synthetic end-to-end coverage for STORE-02 without AWS or real identities. */

import assert from "node:assert/strict";
import test from "node:test";

import {
  AccountDeletionGuard,
  AccountDeletionGuardUnavailableError,
} from "../src/account_deletion/account_deletion_guard.js";
import {
  type AcceptAccountDeletionBarrier,
  type AccountDeletionBarrierReference,
  type AccountDeletionLedger,
  type RegistrationBlocker,
  type RegistrationLedgerKey,
  type SubjectLedgerKey,
  type SubjectTombstone,
} from "../src/account_deletion/account_deletion_ledger.js";
import {
  accountDeletionCompletedEmail,
  accountDeletionRequestEmail,
} from "../src/account_deletion/account_deletion_email.js";
import {
  AccountDeletionWorkflow,
  UnavailableSubscriptionCancellation,
  verifyRecentAuthentication,
  type AccountDeletionExecutor,
  type AccountDeletionNotifier,
  type AccountDeletionRecord,
  type AccountDeletionWorkflowStore,
} from "../src/account_deletion/account_deletion_workflow.js";
import { InMemoryAccountDeletionWorkflowStore } from "../src/account_deletion/in_memory_account_deletion_workflow_store.js";
import {
  NodeHmacSha256Generator,
  PseudonymousEmailIdentifierService,
  PseudonymousSubjectIdentifierService,
  type HmacSha256KeyProvider,
} from "../src/account_deletion/pseudonymous_identity.js";

class Keys implements HmacSha256KeyProvider<Uint8Array> {
  async getKey(): Promise<Uint8Array> {
    return new Uint8Array(32).fill(7);
  }
}

class MemoryLedger implements AccountDeletionLedger {
  subjects = new Map<SubjectLedgerKey, SubjectTombstone>();
  registrations = new Map<RegistrationLedgerKey, RegistrationBlocker>();
  fail = false;

  async findSubjectTombstones(keys: readonly SubjectLedgerKey[]) {
    if (this.fail) throw new Error("synthetic dynamodb failure");
    return keys.flatMap((key) => this.subjects.get(key) ?? []);
  }

  async findRegistrationBlockers(keys: readonly RegistrationLedgerKey[]) {
    if (this.fail) throw new Error("synthetic dynamodb failure");
    return keys.flatMap((key) => this.registrations.get(key) ?? []);
  }

  async acceptBarrier(input: AcceptAccountDeletionBarrier) {
    if (this.fail) throw new Error("synthetic dynamodb failure");
    this.subjects.set(input.reference.subjectKey, {
      key: input.reference.subjectKey,
      deletionId: input.reference.deletionId,
      state: "pending",
      createdAt: input.acceptedAt,
      updatedAt: input.acceptedAt,
    });
    this.registrations.set(input.reference.registrationKey, {
      key: input.reference.registrationKey,
      deletionId: input.reference.deletionId,
      blockedUntil: input.blockedUntil,
      createdAt: input.acceptedAt,
    });
    return input.reference;
  }

  async markDeleted(
    reference: AccountDeletionBarrierReference,
    completedAt: Date,
  ) {
    if (this.fail) throw new Error("synthetic dynamodb failure");
    const current = this.subjects.get(reference.subjectKey);
    if (!current) throw new Error("missing synthetic tombstone");
    this.subjects.set(reference.subjectKey, {
      ...current,
      state: "deleted",
      updatedAt: completedAt,
    });
  }
}

class Executor implements AccountDeletionExecutor {
  executions = 0;
  verified = true;
  fail = false;

  async execute() {
    this.executions += 1;
    if (this.fail) throw new Error("synthetic S3/PostgreSQL failure");
  }
  async verify() {
    return this.verified;
  }
}

class Notifier implements AccountDeletionNotifier {
  accepted = 0;
  completed = 0;
  async requestAccepted() {
    this.accepted += 1;
  }
  async deletionCompleted() {
    this.completed += 1;
  }
}

const now = new Date("2032-04-01T12:00:00.000Z");
const subject = "00000000-0000-4000-8000-000000000123";
const email = "synthetic.user+deletion@example.test";

function fixture(input?: {
  pending?: number;
  store?: AccountDeletionWorkflowStore;
  subscription?: "none" | "active";
}) {
  const ledger = new MemoryLedger();
  const keys = new Keys();
  const hmac = new NodeHmacSha256Generator();
  const guard = new AccountDeletionGuard(
    ledger,
    new PseudonymousEmailIdentifierService(keys, hmac),
    new PseudonymousSubjectIdentifierService(keys, hmac),
    { writeVersion: "test-v1", readVersions: ["test-v1"] },
    { now: () => new Date(now) },
  );
  const executor = new Executor();
  const notifier = new Notifier();
  const workflow = new AccountDeletionWorkflow(
    input?.store ?? new InMemoryAccountDeletionWorkflowStore(),
    guard,
    {
      async pendingSyncCount() {
        return input?.pending ?? 0;
      },
      async exportAvailable() {
        return true;
      },
    },
    new UnavailableSubscriptionCancellation(input?.subscription ?? "none"),
    executor,
    notifier,
    { now: () => new Date(now) },
  );
  return { executor, guard, ledger, notifier, workflow };
}

async function acceptedWorkflow(input?: { pending?: number }) {
  const harness = fixture(input);
  const preflight = await harness.workflow.preflight({
    ownerSubject: subject,
    ownerKey: "owner-hmac",
    idempotencyKey: "request-key-0001",
    locale: "es",
    requestedExport: false,
    recentAuthentication: true,
  });
  const accepted = await harness.workflow.confirm({
    requestId: preflight.record.requestId,
    ownerSubject: subject,
    verifiedEmail: email,
    ownerKey: "owner-hmac",
    recentAuthentication: true,
    irreversibleAccepted: true,
    discardUnsyncedAccepted: (input?.pending ?? 0) > 0,
    cancelRenewalAccepted: false,
  });
  return { ...harness, ...accepted };
}

test("AUT-18 creates an idempotent preflight for Free users with any lead count", async () => {
  for (const pending of [0, 5, 10]) {
    const { workflow } = fixture({ pending });
    const request = {
      ownerSubject: subject,
      ownerKey: `owner-${pending}`,
      idempotencyKey: `preflight-${pending}-key`,
      locale: "es" as const,
      requestedExport: true,
      recentAuthentication: true,
    };
    const first = await workflow.preflight(request);
    const replay = await workflow.preflight(request);
    assert.equal(first.record.requestId, replay.record.requestId);
    assert.equal(first.pendingSyncCount, pending);
  }
});

test("AUT-19 rejects expired authentication and missing offline-loss consent", async () => {
  const { workflow } = fixture({ pending: 2 });
  await assert.rejects(
    workflow.preflight({
      ownerSubject: subject,
      ownerKey: "owner-hmac",
      idempotencyKey: "reauth-key-0001",
      locale: "en",
      requestedExport: false,
      recentAuthentication: false,
    }),
    /Recent authentication/,
  );
  const preflight = await workflow.preflight({
    ownerSubject: subject,
    ownerKey: "owner-hmac",
    idempotencyKey: "reauth-key-0002",
    locale: "en",
    requestedExport: false,
    recentAuthentication: true,
  });
  await assert.rejects(
    workflow.confirm({
      requestId: preflight.record.requestId,
      ownerSubject: subject,
      verifiedEmail: email,
      ownerKey: "owner-hmac",
      recentAuthentication: true,
      irreversibleAccepted: true,
      discardUnsyncedAccepted: false,
      cancelRenewalAccepted: false,
    }),
    /Pending local changes/,
  );
});

test("INF-19 completes only after executor verification and exposes receipt status", async () => {
  const harness = await acceptedWorkflow();
  assert.equal(harness.notifier.accepted, 1);
  const completed = await harness.workflow.process({
    requestId: harness.record.requestId,
    ownerSubject: subject,
  });
  assert.equal(completed.status, "completed");
  assert.equal(harness.notifier.completed, 1);
  assert.equal(
    (await harness.workflow.byReceipt(harness.receipt))?.status,
    "completed",
  );
  assert.equal(
    (await harness.guard.evaluateIdentity(subject)).state,
    "deleted",
  );
});

test("INF-19 keeps a partial failure blocked and permits a later retry", async () => {
  const harness = await acceptedWorkflow();
  harness.executor.fail = true;
  await assert.rejects(
    harness.workflow.process({
      requestId: harness.record.requestId,
      ownerSubject: subject,
    }),
    /synthetic S3\/PostgreSQL failure/,
  );
  assert.equal(
    (await harness.workflow.current("owner-hmac"))?.status,
    "blocked",
  );
  harness.executor.fail = false;
  const retried = await harness.workflow.process({
    requestId: harness.record.requestId,
    ownerSubject: subject,
  });
  assert.equal(retried.status, "completed");
  assert.equal(harness.executor.executions, 2);
});

test("RNF-09 fails closed when DynamoDB barrier acceptance fails", async () => {
  const harness = fixture();
  const preflight = await harness.workflow.preflight({
    ownerSubject: subject,
    ownerKey: "owner-hmac",
    idempotencyKey: "dynamo-fail-key",
    locale: "es",
    requestedExport: false,
    recentAuthentication: true,
  });
  harness.ledger.fail = true;
  await assert.rejects(
    harness.workflow.confirm({
      requestId: preflight.record.requestId,
      ownerSubject: subject,
      verifiedEmail: email,
      ownerKey: "owner-hmac",
      recentAuthentication: true,
      irreversibleAccepted: true,
      discardUnsyncedAccepted: false,
      cancelRenewalAccepted: false,
    }),
    AccountDeletionGuardUnavailableError,
  );
});

test("FL-021 dependency never reports an active Stripe subscription canceled", async () => {
  const { workflow } = fixture({ subscription: "active" });
  const preflight = await workflow.preflight({
    ownerSubject: subject,
    ownerKey: "owner-pro",
    idempotencyKey: "active-pro-key",
    locale: "es",
    requestedExport: false,
    recentAuthentication: true,
  });
  await assert.rejects(
    workflow.confirm({
      requestId: preflight.record.requestId,
      ownerSubject: subject,
      verifiedEmail: email,
      ownerKey: "owner-pro",
      recentAuthentication: true,
      irreversibleAccepted: true,
      discardUnsyncedAccepted: false,
      cancelRenewalAccepted: true,
    }),
    /payments/,
  );
});

test("AUT-19 recent-auth boundary is inclusive and server-derived", () => {
  const authenticatedAt = new Date("2032-04-01T11:55:00.000Z");
  assert.equal(
    verifyRecentAuthentication({
      authenticatedAt,
      now,
      maximumAge: { milliseconds: 5 * 60 * 1000 },
    }).recent,
    true,
  );
  assert.equal(
    verifyRecentAuthentication({
      authenticatedAt,
      now: new Date(now.getTime() + 1),
      maximumAge: { milliseconds: 5 * 60 * 1000 },
    }).recent,
    false,
  );
});

test("AUT-21 renders safe bilingual request and completion emails", () => {
  const request = accountDeletionRequestEmail("es", "support@example.test");
  const completed = accountDeletionCompletedEmail("en", "support@example.test");
  assert.match(request.plainBody, /está en proceso/);
  assert.doesNotMatch(request.plainBody, /00000000|synthetic\.user/);
  assert.match(completed.plainBody, /is complete/);
  assert.match(completed.htmlBody, /margin:0 0 12px/);
});

test("workflow store never exposes another owner's current request", async () => {
  const store = new InMemoryAccountDeletionWorkflowStore();
  const record = {
    requestId: "00000000-0000-4000-8000-000000000321",
    ownerKey: "owner-a",
    idempotencyKey: "owner-scope-key",
    locale: "es",
    requestedExport: false,
    status: "awaiting_confirmation",
    createdAt: now,
    expiresAt: now,
    acceptedAt: null,
    updatedAt: now,
    completedAt: null,
    receiptHash: null,
    receiptExpiresAt: null,
    supportCode: null,
    barrier: null,
    subscription: {
      status: "none",
      cancellationRequired: false,
      planDisplayName: null,
      currentPeriodEnd: null,
    },
  } satisfies AccountDeletionRecord;
  await store.createPreflight(record);
  assert.equal(await store.findCurrent("owner-b"), null);
});
