/**
 * Persistence-neutral contract for Account Deletion barriers and tombstones.
 * It keeps temporary registration blocking separate from durable subject
 * protection and has no connection to Foloo's request runtime (INF-18–INF-21).
 */

import type {
  PseudonymousEmailIdentifier,
  PseudonymousSubjectIdentifier,
} from "./pseudonymous_identity.js";

export const ACCOUNT_DELETION_REGISTRATION_BLOCK_DAYS = 30;

export type AccountDeletionState = "pending" | "deleted";

export type SubjectLedgerKey = string & { readonly __subjectLedgerKey: true };
export type RegistrationLedgerKey = string & {
  readonly __registrationLedgerKey: true;
};

export type SubjectTombstone = Readonly<{
  key: SubjectLedgerKey;
  deletionId: string;
  state: AccountDeletionState;
  createdAt: Date;
  updatedAt: Date;
}>;

export type RegistrationBlocker = Readonly<{
  key: RegistrationLedgerKey;
  deletionId: string;
  blockedUntil: Date;
  createdAt: Date;
}>;

export type AccountDeletionBarrierReference = Readonly<{
  deletionId: string;
  subjectKey: SubjectLedgerKey;
  registrationKey: RegistrationLedgerKey;
}>;

export type AcceptAccountDeletionBarrier = Readonly<{
  reference: AccountDeletionBarrierReference;
  acceptedAt: Date;
  blockedUntil: Date;
}>;

/** Atomic ledger operations required before Account Deletion can be wired. */
export interface AccountDeletionLedger {
  findSubjectTombstones(
    keys: readonly SubjectLedgerKey[],
  ): Promise<readonly SubjectTombstone[]>;

  findRegistrationBlockers(
    keys: readonly RegistrationLedgerKey[],
  ): Promise<readonly RegistrationBlocker[]>;

  /**
   * Atomically records the request, durable subject tombstone and temporary
   * email blocker. Repeating the same reference must be a no-op.
   */
  acceptBarrier(
    input: AcceptAccountDeletionBarrier,
  ): Promise<AccountDeletionBarrierReference>;

  /** Atomically moves the durable request and subject tombstone to deleted. */
  markDeleted(
    reference: AccountDeletionBarrierReference,
    completedAt: Date,
  ): Promise<void>;
}

export class AccountDeletionLedgerConflictError extends Error {
  constructor() {
    super("Account deletion barrier conflicts with an existing record.");
    this.name = "AccountDeletionLedgerConflictError";
  }
}

export function subjectLedgerKey(
  identifier: PseudonymousSubjectIdentifier,
): SubjectLedgerKey {
  return `SUB#${identifier.identityPolicy}#${identifier.keyVersion}#${identifier.digest}` as SubjectLedgerKey;
}

export function registrationLedgerKey(
  identifier: PseudonymousEmailIdentifier,
): RegistrationLedgerKey {
  return `REG#${identifier.canonicalizationPolicy}#${identifier.keyVersion}#${identifier.digest}` as RegistrationLedgerKey;
}
