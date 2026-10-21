/** Synthetic contract coverage for the isolated INF-18/INF-20/INF-21 guard. */

import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

import {
  AccountDeletionLedgerConflictError,
  type AcceptAccountDeletionBarrier,
  type AccountDeletionBarrierReference,
  type AccountDeletionLedger,
  type RegistrationBlocker,
  type RegistrationLedgerKey,
  type SubjectLedgerKey,
  type SubjectTombstone,
} from "../src/account_deletion/account_deletion_ledger.js";
import {
  AccountDeletionGuard,
  AccountDeletionGuardUnavailableError,
} from "../src/account_deletion/account_deletion_guard.js";
import {
  NodeHmacSha256Generator,
  PseudonymousEmailIdentifierService,
  PseudonymousSubjectIdentifierService,
  type HmacSha256KeyProvider,
} from "../src/account_deletion/pseudonymous_identity.js";

class FixtureKeys implements HmacSha256KeyProvider<Uint8Array> {
  constructor(private readonly fail = false) {}

  async getKey(version: string): Promise<Uint8Array> {
    if (this.fail) throw new Error("Synthetic key failure.");
    return new Uint8Array(32).fill(version === "v1" ? 0x11 : 0x22);
  }
}

class MutableClock {
  constructor(public value: Date) {}
  now(): Date {
    return new Date(this.value);
  }
}

class MemoryLedger implements AccountDeletionLedger {
  readonly requests = new Map<string, AccountDeletionBarrierReference>();
  readonly subjects = new Map<SubjectLedgerKey, SubjectTombstone>();
  readonly registrations = new Map<
    RegistrationLedgerKey,
    RegistrationBlocker
  >();
  failReads = false;

  async findSubjectTombstones(
    keys: readonly SubjectLedgerKey[],
  ): Promise<readonly SubjectTombstone[]> {
    if (this.failReads) throw new Error("Synthetic ledger failure.");
    return keys.flatMap((key) => {
      const value = this.subjects.get(key);
      return value ? [value] : [];
    });
  }

  async findRegistrationBlockers(
    keys: readonly RegistrationLedgerKey[],
  ): Promise<readonly RegistrationBlocker[]> {
    if (this.failReads) throw new Error("Synthetic ledger failure.");
    return keys.flatMap((key) => {
      const value = this.registrations.get(key);
      return value ? [value] : [];
    });
  }

  async acceptBarrier(
    input: AcceptAccountDeletionBarrier,
  ): Promise<AccountDeletionBarrierReference> {
    const existing = this.requests.get(input.reference.deletionId);
    if (existing) {
      if (
        existing.subjectKey !== input.reference.subjectKey ||
        existing.registrationKey !== input.reference.registrationKey
      ) {
        throw new AccountDeletionLedgerConflictError();
      }
      return existing;
    }
    if (this.subjects.has(input.reference.subjectKey)) {
      throw new AccountDeletionLedgerConflictError();
    }
    const blocker = this.registrations.get(input.reference.registrationKey);
    if (blocker && blocker.blockedUntil > input.acceptedAt) {
      throw new AccountDeletionLedgerConflictError();
    }
    this.requests.set(input.reference.deletionId, input.reference);
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
  ): Promise<void> {
    const item = this.subjects.get(reference.subjectKey);
    if (!item || item.deletionId !== reference.deletionId) {
      throw new AccountDeletionLedgerConflictError();
    }
    this.subjects.set(reference.subjectKey, {
      ...item,
      state: "deleted",
      updatedAt: completedAt,
    });
  }
}

const acceptedAt = new Date("2030-01-01T00:00:00.000Z");
const syntheticSubject = "00000000-0000-4000-8000-000000000001";
const syntheticEmail = "fixture.user+qa@example.test";

function fixture(
  ledger = new MemoryLedger(),
  clock = new MutableClock(acceptedAt),
  keyProvider: HmacSha256KeyProvider<Uint8Array> = new FixtureKeys(),
  writeVersion = "v1",
  readVersions: readonly string[] = ["v1"],
) {
  const hmac = new NodeHmacSha256Generator();
  return {
    clock,
    guard: new AccountDeletionGuard(
      ledger,
      new PseudonymousEmailIdentifierService(keyProvider, hmac),
      new PseudonymousSubjectIdentifierService(keyProvider, hmac),
      { writeVersion, readVersions },
      clock,
    ),
    ledger,
  };
}

test("INF-20 blocks day 29 and permits the exact day-30 boundary and day 31", async () => {
  const { clock, guard } = fixture();
  await guard.acceptDeletionBarrier({
    deletionId: "deletion-0001",
    canonicalSubject: syntheticSubject,
    verifiedEmail: syntheticEmail,
  });

  clock.value = new Date("2030-01-30T23:59:59.999Z");
  assert.equal(
    (await guard.evaluateRegistration(syntheticEmail)).state,
    "registration_blocked",
  );
  clock.value = new Date("2030-01-31T00:00:00.000Z");
  assert.deepEqual(await guard.evaluateRegistration(syntheticEmail), {
    state: "active",
  });
  clock.value = new Date("2030-02-01T00:00:00.000Z");
  assert.equal(
    (await guard.evaluateRegistration(syntheticEmail)).state,
    "active",
  );
});

test("INF-18 denies pending and deleted subjects even after stale data restoration", async () => {
  const { guard } = fixture();
  const reference = await guard.acceptDeletionBarrier({
    deletionId: "deletion-0002",
    canonicalSubject: syntheticSubject,
    verifiedEmail: syntheticEmail,
  });

  assert.equal(
    (await guard.evaluateIdentity(syntheticSubject)).state,
    "deletion_pending",
  );
  await guard.markDeleted(reference);
  // A restored PostgreSQL workspace is deliberately not an input to the ledger.
  assert.equal(
    (await guard.evaluateIdentity(syntheticSubject)).state,
    "deleted",
  );
});

test("INF-20 handles repeated and simultaneous requests idempotently", async () => {
  const { guard, ledger } = fixture();
  const request = {
    deletionId: "deletion-0003",
    canonicalSubject: syntheticSubject,
    verifiedEmail: syntheticEmail,
  };
  const [first, second] = await Promise.all([
    guard.acceptDeletionBarrier(request),
    guard.acceptDeletionBarrier(request),
  ]);

  assert.deepEqual(first, second);
  assert.equal(ledger.requests.size, 1);
  assert.equal(ledger.subjects.size, 1);
  assert.equal(ledger.registrations.size, 1);
});

test("INF-20 rejects concurrent identities for an active registration blocker", async () => {
  const { guard } = fixture();
  const results = await Promise.allSettled([
    guard.acceptDeletionBarrier({
      deletionId: "deletion-0004",
      canonicalSubject: "synthetic-subject-a",
      verifiedEmail: syntheticEmail,
    }),
    guard.acceptDeletionBarrier({
      deletionId: "deletion-0005",
      canonicalSubject: "synthetic-subject-b",
      verifiedEmail: syntheticEmail,
    }),
  ]);

  assert.equal(results.filter((item) => item.status === "fulfilled").length, 1);
  const rejected = results.find((item) => item.status === "rejected");
  assert.ok(rejected?.reason instanceof AccountDeletionLedgerConflictError);
});

test("RNF-09 fails closed for DynamoDB and HMAC failures without identity data", async () => {
  const ledger = new MemoryLedger();
  ledger.failReads = true;
  const ledgerFailure =
    fixture(ledger).guard.evaluateIdentity(syntheticSubject);
  await assert.rejects(ledgerFailure, AccountDeletionGuardUnavailableError);

  const hmacFailure = fixture(
    new MemoryLedger(),
    new MutableClock(acceptedAt),
    new FixtureKeys(true),
  ).guard.evaluateRegistration(syntheticEmail);
  await assert.rejects(hmacFailure, AccountDeletionGuardUnavailableError);
  await assert.rejects(hmacFailure, (error: unknown) => {
    assert.ok(error instanceof Error);
    assert.doesNotMatch(error.message, /fixture|example|synthetic/iu);
    return true;
  });
});

test("INF-20 reads old HMAC versions after key rotation", async () => {
  const ledger = new MemoryLedger();
  const original = fixture(ledger).guard;
  await original.acceptDeletionBarrier({
    deletionId: "deletion-0006",
    canonicalSubject: syntheticSubject,
    verifiedEmail: syntheticEmail,
  });
  const rotated = fixture(
    ledger,
    new MutableClock(new Date("2030-01-02T00:00:00.000Z")),
    new FixtureKeys(),
    "v2",
    ["v2", "v1"],
  ).guard;

  assert.equal(
    (await rotated.evaluateIdentity(syntheticSubject)).state,
    "deletion_pending",
  );
  assert.equal(
    (await rotated.evaluateRegistration(syntheticEmail)).state,
    "registration_blocked",
  );
});

test("02E-02B guard remains independent from trial and Unlimited QA", async () => {
  const source = await readFile(
    new URL(
      "../src/account_deletion/account_deletion_guard.ts",
      import.meta.url,
    ),
    "utf8",
  );
  assert.doesNotMatch(source, /entitlement|trial_leads|FOLOO_UNLIMITED/iu);
  assert.doesNotMatch(
    source,
    /from ["'][^"']*(?:transport|principal|cognito)[^"']*["']/iu,
  );
});
