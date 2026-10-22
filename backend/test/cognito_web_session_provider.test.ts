/** Cognito boundary tests for refresh validation and Google PKCE parameters. */

import assert from "node:assert/strict";
import test from "node:test";

import type { CognitoIdentityProviderClient } from "@aws-sdk/client-cognito-identity-provider";

import { AwsCognitoWebSessionProvider } from "../src/web_auth/cognito_web_session_provider.js";

const issuer =
  "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_synthetic";
const clientId = "synthetic-public-client";

function jwt(overrides: Record<string, unknown> = {}): string {
  const claims = {
    sub: "synthetic-subject",
    iss: issuer,
    client_id: clientId,
    token_use: "access",
    exp: 2_000_000_000,
    auth_time: 1_900_000_000,
    ...overrides,
  };
  return `header.${Buffer.from(JSON.stringify(claims)).toString("base64url")}.signature`;
}

function provider(
  send: (command: unknown) => Promise<unknown>,
  request: typeof fetch = fetch,
): AwsCognitoWebSessionProvider {
  return new AwsCognitoWebSessionProvider(
    { send } as unknown as CognitoIdentityProviderClient,
    {
      clientId,
      issuer,
      domain: "synthetic.auth.us-east-1.amazoncognito.com",
      callbackUrl: "https://foloo.io/api/auth/google/callback",
    },
    request,
  );
}

test("AUT-18 refresh uses GetTokensFromRefreshToken and validates audience", async () => {
  let input: unknown;
  const subject = provider(async (command) => {
    input = (command as { input: unknown }).input;
    return { AuthenticationResult: { AccessToken: jwt() } };
  });
  const result = await subject.refresh("synthetic-refresh-token");
  assert.equal(result.subject, "synthetic-subject");
  assert.deepEqual(input, {
    ClientId: clientId,
    RefreshToken: "synthetic-refresh-token",
  });

  const invalid = provider(async () => ({
    AuthenticationResult: { AccessToken: jwt({ client_id: "wrong-client" }) },
  }));
  await assert.rejects(
    invalid.refresh("synthetic-refresh-token"),
    /claims are invalid/u,
  );
});

test("AUT-10 identity exposes only a Cognito-verified email", async () => {
  let input: unknown;
  const subject = provider(async (command) => {
    input = (command as { input: unknown }).input;
    return {
      UserAttributes: [
        { Name: "sub", Value: "synthetic-subject" },
        { Name: "email", Value: "qa@example.invalid" },
        { Name: "email_verified", Value: "true" },
      ],
    };
  });
  assert.deepEqual(await subject.identity(jwt()), {
    sub: "synthetic-subject",
    email: "qa@example.invalid",
    emailVerified: true,
  });
  assert.deepEqual(input, { AccessToken: jwt() });

  const unverified = provider(async () => ({
    UserAttributes: [
      { Name: "sub", Value: "synthetic-subject" },
      { Name: "email", Value: "unverified@example.invalid" },
      { Name: "email_verified", Value: "false" },
    ],
  }));
  assert.deepEqual(await unverified.identity(jwt()), {
    sub: "synthetic-subject",
    email: null,
    emailVerified: false,
  });
});

test("AUT-10 identity rejects a Cognito subject mismatch", async () => {
  const subject = provider(async () => ({
    UserAttributes: [{ Name: "sub", Value: "other-subject" }],
  }));
  await assert.rejects(subject.identity(jwt()), /does not match/u);
});

test("AUT-10 federated identity uses OAuth userInfo without a Cognito admin scope", async () => {
  let requestedUrl = "";
  let authorization = "";
  const request = (async (
    input: Parameters<typeof fetch>[0],
    init?: RequestInit,
  ) => {
    requestedUrl = String(input);
    authorization = String(
      init?.headers && (init.headers as Record<string, string>).authorization,
    );
    return new Response(
      JSON.stringify({
        sub: "synthetic-subject",
        email: "federated@example.invalid",
        email_verified: true,
      }),
      { status: 200, headers: { "content-type": "application/json" } },
    );
  }) as typeof fetch;
  const subject = provider(async () => {
    throw new Error("GetUser must not be used for an OAuth access token.");
  }, request);

  assert.deepEqual(
    await subject.identity(jwt({ scope: "openid email profile" })),
    {
      sub: "synthetic-subject",
      email: "federated@example.invalid",
      emailVerified: true,
    },
  );
  assert.equal(
    requestedUrl,
    "https://synthetic.auth.us-east-1.amazoncognito.com/oauth2/userInfo",
  );
  assert.equal(
    authorization,
    `Bearer ${jwt({ scope: "openid email profile" })}`,
  );
});

test("AUT-04 Google authorization remains code grant with PKCE and no Microsoft", () => {
  const url = new URL(
    provider(async () => ({})).googleAuthorizationUrl({
      state: "synthetic-state",
      codeChallenge: "synthetic-challenge",
    }),
  );
  assert.equal(url.pathname, "/oauth2/authorize");
  assert.equal(url.searchParams.get("response_type"), "code");
  assert.equal(url.searchParams.get("identity_provider"), "Google");
  assert.equal(url.searchParams.get("prompt"), "select_account");
  assert.equal(url.searchParams.get("code_challenge_method"), "S256");
  assert.equal(
    url.searchParams.get("redirect_uri"),
    "https://foloo.io/api/auth/google/callback",
  );
  assert.doesNotMatch(url.toString(), /Microsoft/u);
});

test("AUT-04 code exchange validates the Cognito response before session creation", async () => {
  let posted = "";
  const request = (async (
    _input: Parameters<typeof fetch>[0],
    init?: RequestInit,
  ) => {
    posted = String(init?.body);
    return new Response(
      JSON.stringify({
        access_token: jwt(),
        refresh_token: "synthetic-refresh-token",
      }),
      { status: 200, headers: { "content-type": "application/json" } },
    );
  }) as typeof fetch;
  const result = await provider(
    async () => ({}),
    request,
  ).exchangeAuthorizationCode("synthetic-code", "synthetic-verifier");
  assert.equal(result.refreshToken, "synthetic-refresh-token");
  assert.match(posted, /grant_type=authorization_code/u);
  assert.match(posted, /code_verifier=synthetic-verifier/u);
  assert.match(
    posted,
    /redirect_uri=https%3A%2F%2Ffoloo.io%2Fapi%2Fauth%2Fgoogle%2Fcallback/u,
  );
  assert.doesNotMatch(posted, /client_secret/u);
});
