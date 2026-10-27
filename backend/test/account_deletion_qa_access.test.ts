/** Synthetic coverage for the DEV-only destructive Account Deletion allowlist. */

import assert from "node:assert/strict";
import test from "node:test";

import { ApplicationError } from "../src/application/errors.js";
import {
  accountDeletionQaSubjectHash,
  createAccountDeletionQaAccessGuard,
} from "../src/account_deletion/account_deletion_qa_access.js";
import { WorkflowAccountDeletionHttpController } from "../src/account_deletion/account_deletion_http.js";
import type { AccountDeletionWorkflow } from "../src/account_deletion/account_deletion_workflow.js";
import type { PseudonymousSubjectIdentifierService } from "../src/account_deletion/pseudonymous_identity.js";
import type { VerifiedCognitoEmailResolver } from "../src/account_deletion/verified_cognito_email.js";
import { apiEvent } from "./helpers.js";

const synthetic = {
  a: "synthetic-cognito-sub-a",
  b: "synthetic-cognito-sub-b",
  c: "synthetic-cognito-sub-c",
  d: "synthetic-cognito-sub-d",
  existing: "synthetic-existing-user",
};

const unusedVerifiedEmailResolver: VerifiedCognitoEmailResolver = {
  async resolve() {
    throw new Error("must not run");
  },
};

test("AUT-18 destructive QA admits only synthetic identity D", () => {
  const guard = createAccountDeletionQaAccessGuard({
    environment: "dev",
    enabled: true,
    allowedSubjectHashes: new Set([accountDeletionQaSubjectHash(synthetic.d)]),
  });

  guard.assertAllowed(synthetic.d);
  for (const subject of [
    synthetic.a,
    synthetic.b,
    synthetic.c,
    synthetic.existing,
  ]) {
    assert.throws(
      () => guard.assertAllowed(subject),
      (error) =>
        error instanceof ApplicationError &&
        error.statusCode === 403 &&
        error.code === "account_deletion_qa_forbidden",
    );
  }
});

test("RNF-09 destructive QA fails closed for empty, multiple or production identities", () => {
  const hash = accountDeletionQaSubjectHash(synthetic.d);
  for (const configuration of [
    {
      environment: "dev",
      enabled: false,
      allowedSubjectHashes: new Set([hash]),
    },
    {
      environment: "dev",
      enabled: true,
      allowedSubjectHashes: new Set<string>(),
    },
    {
      environment: "dev",
      enabled: true,
      allowedSubjectHashes: new Set([
        hash,
        accountDeletionQaSubjectHash(synthetic.a),
      ]),
    },
    {
      environment: "prod",
      enabled: true,
      allowedSubjectHashes: new Set([hash]),
    },
    {
      environment: "dev",
      enabled: true,
      allowedSubjectHashes: new Set(["invalid"]),
    },
  ]) {
    assert.throws(
      () => createAccountDeletionQaAccessGuard(configuration),
      /not safe/u,
    );
  }
});

test("RNF-09 destructive QA hash is deterministic, domain-separated and non-PII", () => {
  const first = accountDeletionQaSubjectHash(synthetic.d);
  assert.equal(first, accountDeletionQaSubjectHash(synthetic.d));
  assert.notEqual(first, accountDeletionQaSubjectHash(synthetic.a));
  assert.match(first, /^[A-Za-z0-9_-]{43}$/u);
  assert.equal(first.includes(synthetic.d), false);
});

test("AUT-18 controller rejects A before HMAC, preflight or confirmation", async () => {
  let identityResolutionAttempted = false;
  const qaGuard = createAccountDeletionQaAccessGuard({
    environment: "dev",
    enabled: true,
    allowedSubjectHashes: new Set([accountDeletionQaSubjectHash(synthetic.d)]),
  });
  const controller = new WorkflowAccountDeletionHttpController(
    {} as AccountDeletionWorkflow<string>,
    {
      async identify() {
        identityResolutionAttempted = true;
        throw new Error("must not run");
      },
    } as unknown as PseudonymousSubjectIdentifierService<string>,
    "v1",
    300_000,
    qaGuard,
    unusedVerifiedEmailResolver,
  );
  const event = apiEvent({
    subject: synthetic.a,
    method: "POST",
    path: "/v1/account-deletion-reauthentication/verify",
  });

  await assert.rejects(
    () => controller.handle(event),
    (error) =>
      error instanceof ApplicationError &&
      error.code === "account_deletion_qa_forbidden",
  );
  assert.equal(identityResolutionAttempted, false);
});

test("RNF-09 processing mode blocks new intake without stopping recovery", async () => {
  let preflightAttempted = false;
  const qaGuard = createAccountDeletionQaAccessGuard({
    environment: "dev",
    enabled: true,
    allowedSubjectHashes: new Set([accountDeletionQaSubjectHash(synthetic.d)]),
  });
  const controller = new WorkflowAccountDeletionHttpController(
    {
      async preflight() {
        preflightAttempted = true;
        throw new Error("must not run");
      },
    } as unknown as AccountDeletionWorkflow<string>,
    {
      async identify() {
        return { digest: "owner-key", keyVersion: "v1" };
      },
    } as unknown as PseudonymousSubjectIdentifierService<string>,
    "v1",
    300_000,
    qaGuard,
    unusedVerifiedEmailResolver,
    false,
  );

  await assert.rejects(
    () =>
      controller.handle(
        apiEvent({
          subject: synthetic.d,
          method: "POST",
          path: "/v1/account-deletion-requests",
          idempotencyKey: "synthetic-idempotency-key",
          body: { locale: "en", requestedExport: false },
        }),
      ),
    (error) =>
      error instanceof ApplicationError &&
      error.code === "account_deletion_intake_unavailable" &&
      error.statusCode === 503,
  );
  assert.equal(preflightAttempted, false);
});
