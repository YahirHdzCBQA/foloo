/**
 * DEV-only destructive-QA boundary for Account Deletion.
 * It is intentionally independent from Web Sessions and stores only
 * domain-separated hashes of synthetic Cognito subjects (AUT-18/RNF-09).
 */

import { createHash } from "node:crypto";

import { ApplicationError } from "../application/errors.js";

const subjectHashPattern = /^[A-Za-z0-9_-]{43}$/u;

export type AccountDeletionQaAccessConfiguration = Readonly<{
  environment: string;
  enabled: boolean;
  allowedSubjectHashes: ReadonlySet<string>;
}>;

export type AccountDeletionQaAccessGuard = Readonly<{
  assertAllowed(subject: string): void;
}>;

export function accountDeletionQaSubjectHash(subject: string): string {
  if (subject.trim().length === 0 || subject.length > 2048) {
    throw new Error("Account Deletion QA subject is invalid.");
  }
  return createHash("sha256")
    .update("foloo-account-deletion-qa\0", "utf8")
    .update(subject, "utf8")
    .digest("base64url");
}

/** Builds a fail-closed guard: the temporary DEV exercise admits exactly D. */
export function createAccountDeletionQaAccessGuard(
  configuration: AccountDeletionQaAccessConfiguration,
): AccountDeletionQaAccessGuard {
  const hashes = [...configuration.allowedSubjectHashes];
  if (
    !configuration.enabled ||
    configuration.environment !== "dev" ||
    hashes.length !== 1 ||
    !subjectHashPattern.test(hashes[0] ?? "")
  ) {
    throw new Error("Account Deletion destructive QA access is not safe.");
  }
  return {
    assertAllowed(subject) {
      if (
        !configuration.allowedSubjectHashes.has(
          accountDeletionQaSubjectHash(subject),
        )
      ) {
        throw new ApplicationError(
          "account_deletion_qa_forbidden",
          403,
          "Account deletion is not available for this identity.",
        );
      }
    },
  };
}
