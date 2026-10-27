/** Coverage for native and federated Cognito Account Deletion barriers. */

import assert from "node:assert/strict";
import test from "node:test";

import {
  CognitoAccountAccessDeniedError,
  CognitoAccountAccessProtection,
} from "../src/account_deletion/cognito_account_access.js";
import type { AccountDeletionGuardDecision } from "../src/account_deletion/account_deletion_guard.js";

import { validateCognitoGuardTriggerContext } from "../src/account_deletion/cognito_trigger_context.js";

const active: AccountDeletionGuardDecision = { state: "active" };
const pending: AccountDeletionGuardDecision = {
  state: "deletion_pending",
  deletionId: "11111111-1111-4111-8111-111111111111",
};
const blocked: AccountDeletionGuardDecision = {
  state: "registration_blocked",
  blockedUntil: new Date("2035-02-01T00:00:00.000Z"),
};

function protection(input?: {
  identity?: AccountDeletionGuardDecision;
  registration?: AccountDeletionGuardDecision;
  failure?: Error;
}) {
  return new CognitoAccountAccessProtection({
    async evaluateIdentity() {
      if (input?.failure) throw input.failure;
      return input?.identity ?? active;
    },
    async evaluateRegistration() {
      if (input?.failure) throw input.failure;
      return input?.registration ?? active;
    },
  });
}

test("AUT-18 native authentication is allowed only after verified-email checks", async () => {
  await protection().assertPostAuthentication({
    subject: "synthetic-subject",
    email: "fixture@example.test",
    emailVerified: true,
  });
  await assert.rejects(
    protection().assertPostAuthentication({
      subject: "synthetic-subject",
      email: "fixture@example.test",
      emailVerified: false,
    }),
    CognitoAccountAccessDeniedError,
  );
});

test("INF-18 old subjects and the 30-day registration barrier both deny authentication", async () => {
  await assert.rejects(
    protection({ identity: pending }).assertPostAuthentication({
      subject: "deleted-subject",
      email: "fixture@example.test",
      emailVerified: true,
    }),
    CognitoAccountAccessDeniedError,
  );
  await assert.rejects(
    protection({ registration: blocked }).assertPostAuthentication({
      subject: "new-subject",
      email: "fixture@example.test",
      emailVerified: true,
    }),
    CognitoAccountAccessDeniedError,
  );
});

test("AUT-18 federated signup uses only verified email evidence", async () => {
  await protection().assertFederatedRegistration({
    email: "federated@example.test",
    emailVerified: true,
  });
  await assert.rejects(
    protection({ registration: blocked }).assertFederatedRegistration({
      email: "federated@example.test",
      emailVerified: true,
    }),
    CognitoAccountAccessDeniedError,
  );
  await assert.rejects(
    protection().assertFederatedRegistration({
      email: "federated@example.test",
      emailVerified: false,
    }),
    CognitoAccountAccessDeniedError,
  );
});

test("RNF-09 guard failures remain fail-closed without leaking identity data", async () => {
  const failure = protection({ failure: new Error("fixture@example.test") });
  await assert.rejects(
    failure.assertPostAuthentication({
      subject: "synthetic-subject",
      email: "fixture@example.test",
      emailVerified: true,
    }),
    (error: unknown) => {
      assert.ok(error instanceof Error);
      assert.doesNotMatch(error.message, /fixture|example|synthetic/iu);
      return true;
    },
  );
});

test("AUT-21/INF-18 normalized Google still reaches the registration barrier and fails closed", async () => {
  for (const provider of ["google", "Google", "GOOGLE", "gOoGlE"]) {
    validateCognitoGuardTriggerContext(
      {
        userPoolId: "us-east-1_fixture",
        triggerSource: "PreSignUp_ExternalProvider",
        userName: `${provider}_fixture`,
        callerContext: { clientId: "web-client" },
        request: { userAttributes: {} },
      },
      "pre-sign-up",
      {
        COGNITO_USER_POOL_ID: "us-east-1_fixture",
        COGNITO_ALLOWED_APP_CLIENT_IDS: "web-client",
        COGNITO_ALLOWED_FEDERATED_PROVIDERS: "Google",
      },
    );
    const input = { email: "federated@example.test", emailVerified: true };
    await protection().assertFederatedRegistration(input);
    for (const denied of [
      protection({ registration: blocked }),
      protection({ registration: pending }),
      protection({ failure: new Error("ledger unavailable") }),
    ]) {
      await assert.rejects(
        denied.assertFederatedRegistration(input),
        CognitoAccountAccessDeniedError,
      );
    }
    await assert.rejects(
      protection({ identity: pending }).assertPostAuthentication({
        ...input,
        subject: "deleted-subject",
      }),
      CognitoAccountAccessDeniedError,
    );
  }
});
