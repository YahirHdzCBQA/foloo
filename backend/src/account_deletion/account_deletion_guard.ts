/**
 * Fail-closed Account Deletion guard built over the isolated ledger contract.
 * It derives versioned pseudonyms without exposing identity values and remains
 * deliberately disconnected from routers, Cognito and workspace provisioning.
 */

import {
  ACCOUNT_DELETION_REGISTRATION_BLOCK_DAYS,
  AccountDeletionLedgerConflictError,
  registrationLedgerKey,
  subjectLedgerKey,
  type AccountDeletionBarrierReference,
  type AccountDeletionLedger,
} from "./account_deletion_ledger.js";
import type {
  PseudonymousEmailIdentifierService,
  PseudonymousSubjectIdentifierService,
} from "./pseudonymous_identity.js";

export type AccountDeletionGuardDecision =
  | Readonly<{ state: "active" }>
  | Readonly<{ state: "deletion_pending" }>
  | Readonly<{ state: "deleted" }>
  | Readonly<{ state: "registration_blocked"; blockedUntil: Date }>;

export interface AccountDeletionClock {
  now(): Date;
}

export class AccountDeletionGuardUnavailableError extends Error {
  constructor() {
    super("Account deletion protection is temporarily unavailable.");
    this.name = "AccountDeletionGuardUnavailableError";
  }
}

type GuardKeyConfiguration = Readonly<{
  writeVersion: string;
  readVersions: readonly string[];
}>;

/**
 * Evaluates durable tombstones and temporary blockers across active HMAC keys.
 * Any storage or pseudonymization failure is fail-closed and never becomes an
 * `active` decision (RNF-09/RNF-10).
 */
export class AccountDeletionGuard<KeyHandle> {
  private readonly readVersions: readonly string[];

  constructor(
    private readonly ledger: AccountDeletionLedger,
    private readonly emailIdentifiers: PseudonymousEmailIdentifierService<KeyHandle>,
    private readonly subjectIdentifiers: PseudonymousSubjectIdentifierService<KeyHandle>,
    private readonly keys: GuardKeyConfiguration,
    private readonly clock: AccountDeletionClock = { now: () => new Date() },
  ) {
    const versions = [...new Set(keys.readVersions)];
    if (!versions.includes(keys.writeVersion))
      versions.unshift(keys.writeVersion);
    if (versions.length === 0) {
      throw new AccountDeletionGuardUnavailableError();
    }
    this.readVersions = Object.freeze(versions);
  }

  async evaluateIdentity(
    canonicalSubject: string,
  ): Promise<AccountDeletionGuardDecision> {
    try {
      const keys = await Promise.all(
        this.readVersions.map(async (version) =>
          subjectLedgerKey(
            await this.subjectIdentifiers.identify(canonicalSubject, version),
          ),
        ),
      );
      const tombstones = await this.ledger.findSubjectTombstones(keys);
      if (tombstones.some((item) => item.state === "deleted")) {
        return { state: "deleted" };
      }
      if (tombstones.some((item) => item.state === "pending")) {
        return { state: "deletion_pending" };
      }
      return { state: "active" };
    } catch {
      throw new AccountDeletionGuardUnavailableError();
    }
  }

  async evaluateRegistration(
    verifiedEmail: string,
  ): Promise<AccountDeletionGuardDecision> {
    try {
      const keys = await Promise.all(
        this.readVersions.map(async (version) =>
          registrationLedgerKey(
            await this.emailIdentifiers.identify(verifiedEmail, version),
          ),
        ),
      );
      const blockers = await this.ledger.findRegistrationBlockers(keys);
      const now = this.clock.now().getTime();
      const active = blockers
        .filter((item) => item.blockedUntil.getTime() > now)
        .sort(
          (left, right) =>
            right.blockedUntil.getTime() - left.blockedUntil.getTime(),
        )[0];
      return active
        ? { state: "registration_blocked", blockedUntil: active.blockedUntil }
        : { state: "active" };
    } catch {
      throw new AccountDeletionGuardUnavailableError();
    }
  }

  async acceptDeletionBarrier(input: {
    deletionId: string;
    canonicalSubject: string;
    verifiedEmail: string;
  }): Promise<AccountDeletionBarrierReference> {
    try {
      const acceptedAt = this.clock.now();
      const [subject, email] = await Promise.all([
        this.subjectIdentifiers.identify(
          input.canonicalSubject,
          this.keys.writeVersion,
        ),
        this.emailIdentifiers.identify(
          input.verifiedEmail,
          this.keys.writeVersion,
        ),
      ]);
      const reference = {
        deletionId: input.deletionId,
        subjectKey: subjectLedgerKey(subject),
        registrationKey: registrationLedgerKey(email),
      };
      return await this.ledger.acceptBarrier({
        reference,
        acceptedAt,
        blockedUntil: new Date(
          acceptedAt.getTime() +
            ACCOUNT_DELETION_REGISTRATION_BLOCK_DAYS * 24 * 60 * 60 * 1000,
        ),
      });
    } catch (error) {
      if (error instanceof AccountDeletionLedgerConflictError) throw error;
      throw new AccountDeletionGuardUnavailableError();
    }
  }

  async markDeleted(reference: AccountDeletionBarrierReference): Promise<void> {
    try {
      await this.ledger.markDeleted(reference, this.clock.now());
    } catch (error) {
      if (error instanceof AccountDeletionLedgerConflictError) throw error;
      throw new AccountDeletionGuardUnavailableError();
    }
  }
}
