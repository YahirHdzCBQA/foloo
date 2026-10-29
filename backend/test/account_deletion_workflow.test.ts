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
  AccountDeletionConfirmationConflictError,
  AccountDeletionQuiescencePendingError,
  AccountDeletionWorkflow,
  accountDeletionWriteQuiescenceMs,
  UnavailableSubscriptionCancellation,
  verifyRecentAuthentication,
  type AccountDeletionExecutor,
  type AccountDeletionDispatcher,
  type AccountDeletionNotifier,
  type AccountDeletionRecipientVault,
  type AccountDeletionRecord,
  type AccountDeletionWorkflowStore,
} from "../src/account_deletion/account_deletion_workflow.js";
import { AccountDeletionOutboxRecovery } from "../src/account_deletion/account_deletion_outbox_recovery.js";
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
  failAccepted = false;
  failCompleted = false;
  async requestAccepted() {
    this.accepted += 1;
    if (this.failAccepted) throw new Error("synthetic notification outage");
  }
  async deletionCompleted() {
    this.completed += 1;
    if (this.failCompleted) throw new Error("synthetic notification outage");
  }
}

class RecipientVault implements AccountDeletionRecipientVault {
  private value:
    { requestId: string; ownerSubject: string; receipt: string } | undefined;

  async capture(input: {
    requestId: string;
    ownerSubject: string;
    receipt: string;
  }) {
    this.value ??= input;
    return this.value.receipt;
  }

  async recoverReceipt(requestId: string) {
    if (this.value?.requestId !== requestId) throw new Error("missing receipt");
    return this.value.receipt;
  }

  async recoverOwnerSubject(requestId: string) {
    if (this.value?.requestId !== requestId) throw new Error("missing owner");
    return this.value.ownerSubject;
  }
}

class Dispatcher implements AccountDeletionDispatcher {
  attempts = 0;
  delivered = 0;
  fail = false;

  async dispatch() {
    this.attempts += 1;
    if (this.fail) throw new Error("synthetic SQS outage");
    this.delivered += 1;
  }
}

const now = new Date("2032-04-01T12:00:00.000Z");
const subject = "00000000-0000-4000-8000-000000000123";
const email = "synthetic.user+deletion@example.test";

function fixture(input?: {
  pending?: number;
  store?: AccountDeletionWorkflowStore;
  subscription?: "none" | "active";
  dispatcher?: AccountDeletionDispatcher;
  recipientVault?: AccountDeletionRecipientVault;
  notifier?: Notifier;
}) {
  let clockNow = new Date(now);
  const ledger = new MemoryLedger();
  const keys = new Keys();
  const hmac = new NodeHmacSha256Generator();
  const guard = new AccountDeletionGuard(
    ledger,
    new PseudonymousEmailIdentifierService(keys, hmac),
    new PseudonymousSubjectIdentifierService(keys, hmac),
    { writeVersion: "test-v1", readVersions: ["test-v1"] },
    { now: () => new Date(clockNow) },
  );
  const executor = new Executor();
  const notifier = input?.notifier ?? new Notifier();
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
    { now: () => new Date(clockNow) },
    input?.dispatcher,
    input?.recipientVault,
  );
  return {
    executor,
    guard,
    ledger,
    notifier,
    workflow,
    advance(milliseconds: number) {
      clockNow = new Date(clockNow.getTime() + milliseconds);
    },
  };
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
    confirmationIdempotencyKey: "confirmation-key-0001",
  });
  harness.advance(accountDeletionWriteQuiescenceMs);
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

test("RNF-10 concurrent confirmation keeps one receipt and one accepted transition", async () => {
  const store = new InMemoryAccountDeletionWorkflowStore();
  const vault = new RecipientVault();
  const dispatcher = new Dispatcher();
  const harness = fixture({ store, recipientVault: vault, dispatcher });
  const preflight = await harness.workflow.preflight({
    ownerSubject: subject,
    ownerKey: "owner-concurrent",
    idempotencyKey: "preflight-concurrent",
    locale: "es",
    requestedExport: false,
    recentAuthentication: true,
  });
  const confirmation = {
    requestId: preflight.record.requestId,
    ownerSubject: subject,
    verifiedEmail: email,
    ownerKey: "owner-concurrent",
    recentAuthentication: true,
    irreversibleAccepted: true,
    discardUnsyncedAccepted: false,
    cancelRenewalAccepted: false,
    confirmationIdempotencyKey: "confirmation-concurrent",
  };
  const [first, second] = await Promise.all([
    harness.workflow.confirm(confirmation),
    harness.workflow.confirm(confirmation),
  ]);
  assert.equal(first.receipt, second.receipt);
  assert.equal(first.record.requestId, second.record.requestId);
  assert.equal(harness.notifier.accepted, 1);
  assert.equal(
    (await store.findCurrent("owner-concurrent"))?.status,
    "requested",
  );
  assert.equal(
    (await store.findCurrent("owner-concurrent"))?.dispatchStatus,
    "dispatched",
  );
});

test("RNF-10 a different confirmation idempotency key cannot create a second receipt", async () => {
  const store = new InMemoryAccountDeletionWorkflowStore();
  const vault = new RecipientVault();
  const harness = fixture({ store, recipientVault: vault });
  const preflight = await harness.workflow.preflight({
    ownerSubject: subject,
    ownerKey: "owner-conflict",
    idempotencyKey: "preflight-conflict",
    locale: "es",
    requestedExport: false,
    recentAuthentication: true,
  });
  const base = {
    requestId: preflight.record.requestId,
    ownerSubject: subject,
    verifiedEmail: email,
    ownerKey: "owner-conflict",
    recentAuthentication: true,
    irreversibleAccepted: true,
    discardUnsyncedAccepted: false,
    cancelRenewalAccepted: false,
  };
  await harness.workflow.confirm({
    ...base,
    confirmationIdempotencyKey: "confirmation-original",
  });
  await assert.rejects(
    harness.workflow.confirm({
      ...base,
      confirmationIdempotencyKey: "confirmation-different",
    }),
    AccountDeletionConfirmationConflictError,
  );
});

test("INF-17 SQS outage leaves durable outbox recoverable without a new receipt", async () => {
  const store = new InMemoryAccountDeletionWorkflowStore();
  const vault = new RecipientVault();
  const failing = new Dispatcher();
  failing.fail = true;
  const harness = fixture({
    store,
    recipientVault: vault,
    dispatcher: failing,
  });
  const preflight = await harness.workflow.preflight({
    ownerSubject: subject,
    ownerKey: "owner-outbox",
    idempotencyKey: "preflight-outbox",
    locale: "en",
    requestedExport: false,
    recentAuthentication: true,
  });
  const accepted = await harness.workflow.confirm({
    requestId: preflight.record.requestId,
    ownerSubject: subject,
    verifiedEmail: email,
    ownerKey: "owner-outbox",
    recentAuthentication: true,
    irreversibleAccepted: true,
    discardUnsyncedAccepted: false,
    cancelRenewalAccepted: false,
    confirmationIdempotencyKey: "confirmation-outbox",
  });
  assert.equal(accepted.record.status, "requested");
  assert.equal((await store.pendingDispatches(10)).length, 1);

  const recoveredDispatcher = new Dispatcher();
  const result = await new AccountDeletionOutboxRecovery(
    store,
    recoveredDispatcher,
    vault,
  ).recover();
  assert.deepEqual(result, { inspected: 1, dispatched: 1, failed: 0 });
  assert.equal(recoveredDispatcher.delivered, 1);
  assert.equal((await store.pendingDispatches(10)).length, 0);
  assert.equal(
    (await store.findByRequestId(preflight.record.requestId))?.dispatchStatus,
    "dispatched",
  );
  assert.equal(
    await vault.recoverReceipt(preflight.record.requestId),
    accepted.receipt,
  );
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
      confirmationIdempotencyKey: "confirmation-key-0002",
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

test("INF-19 notification outages never block receipt/status or regress completion", async () => {
  const notifier = new Notifier();
  notifier.failAccepted = true;
  notifier.failCompleted = true;
  const harness = fixture({ notifier });
  const preflight = await harness.workflow.preflight({
    ownerSubject: subject,
    ownerKey: "owner-without-email",
    idempotencyKey: "request-without-email",
    locale: "es",
    requestedExport: false,
    recentAuthentication: true,
  });
  const accepted = await harness.workflow.confirm({
    requestId: preflight.record.requestId,
    ownerSubject: subject,
    verifiedEmail: email,
    ownerKey: "owner-without-email",
    recentAuthentication: true,
    irreversibleAccepted: true,
    discardUnsyncedAccepted: false,
    cancelRenewalAccepted: false,
    confirmationIdempotencyKey: "confirmation-without-email",
  });
  assert.equal(accepted.record.status, "requested");
  assert.equal(
    (await harness.workflow.byReceipt(accepted.receipt))?.status,
    "requested",
  );

  harness.advance(accountDeletionWriteQuiescenceMs);
  const completed = await harness.workflow.process({
    requestId: accepted.record.requestId,
    ownerSubject: subject,
  });
  assert.equal(completed.status, "completed");
  assert.equal(
    (await harness.workflow.byReceipt(accepted.receipt))?.status,
    "completed",
  );
  assert.equal(notifier.accepted, 1);
  assert.equal(notifier.completed, 1);
});

test("INF-17 inventory waits until every previously issued S3 upload URL expires", async () => {
  const harness = fixture();
  const preflight = await harness.workflow.preflight({
    ownerSubject: subject,
    ownerKey: "owner-quiescence",
    idempotencyKey: "request-quiescence",
    locale: "es",
    requestedExport: false,
    recentAuthentication: true,
  });
  const accepted = await harness.workflow.confirm({
    requestId: preflight.record.requestId,
    ownerSubject: subject,
    verifiedEmail: email,
    ownerKey: "owner-quiescence",
    recentAuthentication: true,
    irreversibleAccepted: true,
    discardUnsyncedAccepted: false,
    cancelRenewalAccepted: false,
    confirmationIdempotencyKey: "confirmation-quiescence",
  });
  await assert.rejects(
    harness.workflow.process({
      requestId: accepted.record.requestId,
      ownerSubject: subject,
    }),
    AccountDeletionQuiescencePendingError,
  );
  assert.equal(harness.executor.executions, 0);
  harness.advance(accountDeletionWriteQuiescenceMs);
  const completed = await harness.workflow.process({
    requestId: accepted.record.requestId,
    ownerSubject: subject,
  });
  assert.equal(completed.status, "completed");
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
      confirmationIdempotencyKey: "confirmation-key-0003",
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
      confirmationIdempotencyKey: "confirmation-key-0004",
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
    confirmationIdempotencyKey: null,
    dispatchStatus: "not_required",
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

test("AUT-18 normal HTTP admission keeps owner binding, freshness and acknowledgement controls", async () => {
  const { WorkflowAccountDeletionHttpController } =
    await import("../src/account_deletion/account_deletion_http.js");
  const { createAccountDeletionAdmissionGuard } =
    await import("../src/account_deletion/account_deletion_admission.js");
  const { apiEvent } = await import("./helpers.js");
  const harness = fixture({ recipientVault: new RecipientVault() });
  const controller = new WorkflowAccountDeletionHttpController(
    harness.workflow,
    {
      async identify(s: string) {
        return { digest: "owner-" + s, keyVersion: "v1" };
      },
    } as unknown as PseudonymousSubjectIdentifierService<Uint8Array>,
    "v1",
    300000,
    createAccountDeletionAdmissionGuard({
      environment: "dev",
      normalAccessEnabled: true,
      qaEnabled: false,
      qaAllowedSubjectHashes: new Set(),
    }),
    {
      async resolve() {
        return email;
      },
    },
    true,
    () => new Date(now),
  );
  const make = (
    s: string,
    path: string,
    body: unknown,
    key: string,
    fresh = true,
  ) => {
    const e = apiEvent({
      subject: s,
      method: "POST",
      path,
      body,
      idempotencyKey: key,
      accessToken: "synthetic-access-token",
    });
    e.requestContext.authorizer.jwt.claims.auth_time =
      Math.floor(now.getTime() / 1000) - (fresh ? 0 : 301);
    return e;
  };
  const invalidToken = make(
    subject,
    "/v1/account-deletion-requests",
    { locale: "es" },
    "invalid-token-key",
  );
  invalidToken.requestContext.authorizer.jwt.claims.token_use = "id";
  await assert.rejects(() => controller.handle(invalidToken));
  await assert.rejects(() =>
    controller.handle(
      make(
        "",
        "/v1/account-deletion-requests",
        { locale: "es" },
        "no-subject-key",
      ),
    ),
  );
  const create = () =>
    controller.handle(
      make(
        subject,
        "/v1/account-deletion-requests",
        {
          locale: "es",
          ownerSubject: "another-owner",
          workspaceId: "other-workspace",
        },
        "normal-preflight-key",
      ),
    );
  await assert.rejects(() =>
    controller.handle(
      make(
        subject,
        "/v1/account-deletion-requests",
        { locale: "es" },
        "stale-preflight-key",
        false,
      ),
    ),
  );
  const first = await create();
  const data = JSON.parse(first!.body as string).data;
  assert.equal(
    (await harness.workflow.current("owner-" + subject))?.requestId,
    data.requestId,
  );
  assert.equal(await harness.workflow.current("owner-another-owner"), null);
  assert.equal(
    JSON.parse((await create())!.body as string).data.requestId,
    data.requestId,
  );
  const path = "/v1/account-deletion-requests/" + data.requestId + "/confirm";
  const ack = {
    acknowledgementVersion: "test-v1",
    irreversibleAccepted: true,
    discardUnsyncedAccepted: false,
    cancelRenewalAccepted: false,
  };
  await assert.rejects(() =>
    controller.handle(make("another-owner", path, ack, "other-confirm-key")),
  );
  await assert.rejects(() =>
    controller.handle(make(subject, path, ack, "stale-confirm-key", false)),
  );
  await assert.rejects(() =>
    controller.handle(
      make(
        subject,
        path,
        { ...ack, irreversibleAccepted: false },
        "false-confirm-key",
      ),
    ),
  );
  const accepted = await controller.handle(
    make(subject, path, ack, "normal-confirm-key"),
  );
  assert.equal(accepted!.statusCode, 202);
  const replay = await controller.handle(
    make(subject, path, ack, "normal-confirm-key"),
  );
  assert.equal(replay!.body, accepted!.body);
  const receipt = JSON.parse(accepted!.body as string).data.receipt;
  const closed = new WorkflowAccountDeletionHttpController(
    harness.workflow,
    {} as PseudonymousSubjectIdentifierService<Uint8Array>,
    "v1",
    300000,
    createAccountDeletionAdmissionGuard({
      environment: "dev",
      normalAccessEnabled: false,
      qaEnabled: false,
      qaAllowedSubjectHashes: new Set(),
    }),
    {
      async resolve() {
        throw new Error("must not run");
      },
    },
    true,
    () => new Date(now),
  );
  const status = await closed.handle(
    apiEvent({
      method: "POST",
      path: "/v1/account-deletion-status",
      body: { receipt },
    }),
  );
  assert.equal(status!.statusCode, 200);
  await assert.rejects(() =>
    closed.handle(
      make(
        subject,
        "/v1/account-deletion-requests",
        { locale: "es" },
        "closed-preflight-key",
      ),
    ),
  );
  // Accepted work continues without admitting any new request.
  harness.advance(accountDeletionWriteQuiescenceMs);
  assert.equal(
    (
      await harness.workflow.process({
        requestId: data.requestId,
        ownerSubject: subject,
      })
    ).status,
    "completed",
  );
});
