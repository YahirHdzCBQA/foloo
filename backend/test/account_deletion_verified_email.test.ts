/** Security regression coverage for Cognito-backed deletion confirmation. */

import assert from "node:assert/strict";
import test from "node:test";

import type { CognitoIdentityProviderClient } from "@aws-sdk/client-cognito-identity-provider";

import { WorkflowAccountDeletionHttpController } from "../src/account_deletion/account_deletion_http.js";
import { AwsCognitoVerifiedEmailResolver } from "../src/account_deletion/cognito_verified_email_resolver.js";
import type { AccountDeletionWorkflow } from "../src/account_deletion/account_deletion_workflow.js";
import type { PseudonymousSubjectIdentifierService } from "../src/account_deletion/pseudonymous_identity.js";
import {
  CognitoIdentityRejectedError,
  CognitoIdentityUnavailableError,
} from "../src/account_deletion/verified_cognito_email.js";
import { apiEvent } from "./helpers.js";

const endpoint =
  "https://example.auth.us-east-1.amazoncognito.com/oauth2/userInfo";
const subject = "synthetic-cognito-sub-d";
const token = "synthetic-access-token-long-enough";

function cognitoClient(response: unknown): CognitoIdentityProviderClient {
  return {
    async send() {
      if (response instanceof Error) throw response;
      return response;
    },
  } as unknown as CognitoIdentityProviderClient;
}

test("AUT-19 resolves verified email with an access token that has no email claims", async () => {
  const resolver = new AwsCognitoVerifiedEmailResolver(
    cognitoClient({
      UserAttributes: [
        { Name: "sub", Value: subject },
        { Name: "email", Value: "Synthetic.User@example.invalid" },
        { Name: "email_verified", Value: "true" },
      ],
    }),
    endpoint,
  );

  assert.equal(
    await resolver.resolve({
      accessToken: token,
      expectedSubject: subject,
      scopes: [],
    }),
    "synthetic.user@example.invalid",
  );
});

test("AUT-19 controller sends only the Cognito-resolved email to confirmation", async () => {
  let receivedEmail = "";
  let receivedToken = "";
  const now = new Date("2032-01-01T00:00:00.000Z");
  const controller = new WorkflowAccountDeletionHttpController(
    {
      async confirm(input: { verifiedEmail: string }) {
        receivedEmail = input.verifiedEmail;
        return {
          record: {
            requestId: "00000000-0000-4000-8000-000000000222",
            status: "requested",
            acceptedAt: now,
            receiptExpiresAt: new Date("2032-01-02T00:00:00.000Z"),
          },
          receipt: "synthetic-receipt-not-a-real-credential",
        };
      },
    } as unknown as AccountDeletionWorkflow<string>,
    {
      async identify() {
        return { digest: "synthetic-owner-key", keyVersion: "v1" };
      },
    } as unknown as PseudonymousSubjectIdentifierService<string>,
    "v1",
    300_000,
    { assertAllowed() {} },
    {
      async resolve(input) {
        receivedToken = input.accessToken;
        assert.equal(input.expectedSubject, subject);
        return "verified@example.invalid";
      },
    },
    true,
    () => now,
  );

  const response = await controller.handle(
    apiEvent({
      subject,
      method: "POST",
      path: "/v1/account-deletion-requests/00000000-0000-4000-8000-000000000222/confirm",
      idempotencyKey: "synthetic-idempotency-key",
      accessToken: token,
      claims: { auth_time: Math.floor(now.getTime() / 1000) },
      body: {
        acknowledgementVersion: "store-02-v1",
        irreversibleAccepted: true,
        discardUnsyncedAccepted: false,
        cancelRenewalAccepted: false,
        email: "client-controlled@example.invalid",
      },
    }),
  );

  assert.equal(response?.statusCode, 202);
  assert.equal(receivedToken, token);
  assert.equal(receivedEmail, "verified@example.invalid");
});

test("RNF-09 rejects unverified email and a divergent Cognito subject", async () => {
  for (const attributes of [
    [
      { Name: "sub", Value: subject },
      { Name: "email", Value: "synthetic@example.invalid" },
      { Name: "email_verified", Value: "false" },
    ],
    [
      { Name: "sub", Value: "different-synthetic-sub" },
      { Name: "email", Value: "synthetic@example.invalid" },
      { Name: "email_verified", Value: "true" },
    ],
    [
      { Name: "sub", Value: subject },
      { Name: "email_verified", Value: "true" },
    ],
  ]) {
    const resolver = new AwsCognitoVerifiedEmailResolver(
      cognitoClient({ UserAttributes: attributes }),
      endpoint,
    );
    await assert.rejects(
      () =>
        resolver.resolve({
          accessToken: token,
          expectedSubject: subject,
          scopes: [],
        }),
      CognitoIdentityRejectedError,
    );
  }
});

test("AUT-19 maps invalid or expired access tokens to unauthenticated", async () => {
  for (const name of ["NotAuthorizedException", "TokenExpiredException"]) {
    const failure = new Error("synthetic Cognito rejection");
    failure.name = name;
    const resolver = new AwsCognitoVerifiedEmailResolver(
      cognitoClient(failure),
      endpoint,
    );
    await assert.rejects(
      () =>
        resolver.resolve({
          accessToken: token,
          expectedSubject: subject,
          scopes: [],
        }),
      CognitoIdentityRejectedError,
    );
  }
});

test("RNF-10 fails safely when Cognito attribute resolution is unavailable", async () => {
  const resolver = new AwsCognitoVerifiedEmailResolver(
    cognitoClient(new Error("synthetic transport failure")),
    endpoint,
  );
  await assert.rejects(
    () =>
      resolver.resolve({
        accessToken: token,
        expectedSubject: subject,
        scopes: [],
      }),
    CognitoIdentityUnavailableError,
  );
});

test("AUT-19 OAuth sessions use Cognito userInfo and bind the same subject", async () => {
  let authorization = "";
  const resolver = new AwsCognitoVerifiedEmailResolver(
    cognitoClient(new Error("GetUser must not run for OAuth")),
    endpoint,
    async (_input, init) => {
      authorization = new Headers(init?.headers).get("authorization") ?? "";
      return Response.json({
        sub: subject,
        email: "oauth@example.invalid",
        email_verified: true,
      });
    },
  );

  assert.equal(
    await resolver.resolve({
      accessToken: token,
      expectedSubject: subject,
      scopes: ["openid", "email"],
    }),
    "oauth@example.invalid",
  );
  assert.equal(authorization, `Bearer ${token}`);
});

test("AUT-19 userInfo rejects invalid tokens and mismatched attributes", async () => {
  for (const response of [
    new Response(null, { status: 401 }),
    Response.json({
      sub: "different-synthetic-sub",
      email: "oauth@example.invalid",
      email_verified: true,
    }),
  ]) {
    const resolver = new AwsCognitoVerifiedEmailResolver(
      cognitoClient({}),
      endpoint,
      async () => response,
    );
    await assert.rejects(
      () =>
        resolver.resolve({
          accessToken: token,
          expectedSubject: subject,
          scopes: ["openid"],
        }),
      CognitoIdentityRejectedError,
    );
  }
});
