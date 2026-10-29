/** HTTP contract coverage for cookies, CSRF, disabled mode and BFF allowlisting. */

import assert from "node:assert/strict";
import test from "node:test";
import type { APIGatewayProxyEventV2 } from "aws-lambda";

import { WebSessionCsrfError } from "../src/web_auth/web_session.js";
import { createWebSessionHandler } from "../src/web_auth/web_session_http.js";

const configuration = {
  enabled: true,
  allowedOrigin: "https://foloo.io",
  sessionMaxAgeSeconds: 43_200,
  oauthMaxAgeSeconds: 600,
  folooApiBaseUrl: "https://api.example.test",
  successRedirectPath: "/dashboard",
};

function event(
  method: string,
  rawPath: string,
  overrides: Partial<APIGatewayProxyEventV2> = {},
): APIGatewayProxyEventV2 {
  return {
    version: "2.0",
    routeKey: `${method} ${rawPath}`,
    rawPath,
    rawQueryString: "",
    headers: {},
    requestContext: {
      accountId: "synthetic",
      apiId: "synthetic",
      domainName: "foloo.io",
      domainPrefix: "foloo",
      http: {
        method,
        path: rawPath,
        protocol: "HTTP/1.1",
        sourceIp: "127.0.0.1",
        userAgent: "test",
      },
      requestId: "synthetic-request",
      routeKey: `${method} ${rawPath}`,
      stage: "$default",
      time: "",
      timeEpoch: 0,
    },
    isBase64Encoded: false,
    ...overrides,
  };
}

function sessions() {
  return {
    bootstrapWithRefreshToken: async () => ({
      sessionId: "opaque-session-identifier-synthetic",
      csrfToken: "opaque-csrf-identifier-synthetic",
      expiresAt: new Date("2026-10-23T00:00:00Z"),
      idleExpiresAt: new Date("2026-10-22T12:30:00Z"),
      authenticationTime: new Date("2026-10-22T11:59:00Z"),
    }),
    restore: async (
      _id: string,
      options?: { csrfToken?: string },
    ): Promise<{
      accessToken: string;
      identity: {
        sub: string;
        email: string | null;
        emailVerified: boolean | null;
      };
      csrfToken: string;
      expiresAt: Date;
      idleExpiresAt: Date;
      authenticationTime: Date;
    }> => {
      if (
        options?.csrfToken !== undefined &&
        options.csrfToken !== "opaque-csrf-identifier-synthetic"
      ) {
        const { WebSessionCsrfError } =
          await import("../src/web_auth/web_session.js");
        throw new WebSessionCsrfError();
      }
      return {
        accessToken: "access-token-synthetic",
        identity: {
          sub: "synthetic-subject-a",
          email: "qa@example.invalid",
          emailVerified: true,
        },
        csrfToken: "opaque-csrf-identifier-synthetic",
        expiresAt: new Date("2026-10-23T00:00:00Z"),
        idleExpiresAt: new Date("2026-10-22T12:30:00Z"),
        authenticationTime: new Date("2026-10-22T11:59:00Z"),
      };
    },
    logout: async () => undefined,
    beginGoogleAuthorization: async () => ({
      transactionId: "oauth-transaction-identifier-synthetic",
      authorizationUrl: "https://example.test/authorize",
    }),
    completeGoogleAuthorization: async () => ({
      sessionId: "opaque-session-identifier-synthetic",
      csrfToken: "opaque-csrf-identifier-synthetic",
      expiresAt: new Date("2026-10-23T00:00:00Z"),
      idleExpiresAt: new Date("2026-10-22T12:30:00Z"),
      authenticationTime: new Date("2026-10-22T11:59:00Z"),
    }),
    cancelGoogleAuthorization: async (transactionId: string, state: string) => {
      void transactionId;
      void state;
    },
  };
}

test("AUT-18 disabled mode fails closed before reading credentials", async () => {
  const handler = createWebSessionHandler(
    { sessions: sessions() as never },
    { ...configuration, enabled: false },
  );
  const result = await handler(event("GET", "/api/auth/session"));
  assert.equal(result.statusCode, 503);
  assert.match(String(result.headers?.["cache-control"]), /no-store/u);
});

test("AUT-18 SRP bootstrap returns a secure opaque cookie and no Cognito token", async () => {
  const handler = createWebSessionHandler(
    { sessions: sessions() as never },
    configuration,
  );
  const result = await handler(
    event("POST", "/api/auth/session/srp", {
      headers: { origin: "https://foloo.io" },
      body: JSON.stringify({ refreshToken: "refresh-token-synthetic" }),
    }),
  );
  assert.equal(result.statusCode, 201);
  assert.match(result.cookies?.[0] ?? "", /^__Host-foloo_session=/u);
  assert.match(result.cookies?.[0] ?? "", /Secure; HttpOnly; SameSite=Lax/u);
  assert.doesNotMatch(result.body ?? "", /refresh-token|access-token/u);
});

test("AUT-02 restored session returns verified Cognito identity and Foloo profile", async () => {
  let profileAuthorization = "";
  const handler = createWebSessionHandler(
    {
      sessions: sessions() as never,
      request: (async (
        input: Parameters<typeof fetch>[0],
        init?: RequestInit,
      ) => {
        assert.equal(String(input), "https://api.example.test/v1/profile");
        profileAuthorization = String(
          (init?.headers as Record<string, string>)?.authorization,
        );
        return Response.json({ data: { name: "QA Foloo" } });
      }) as typeof fetch,
    },
    configuration,
  );
  const result = await handler(
    event("GET", "/api/auth/session", {
      cookies: ["__Host-foloo_session=opaque-session-identifier-synthetic"],
    }),
  );
  assert.equal(result.statusCode, 200);
  assert.equal(profileAuthorization, "Bearer access-token-synthetic");
  const body = JSON.parse(result.body ?? "{}") as {
    identity?: Record<string, unknown>;
  };
  assert.deepEqual(body.identity, {
    sub: "synthetic-subject-a",
    email: "qa@example.invalid",
    emailVerified: true,
    displayName: "QA Foloo",
  });
  assert.doesNotMatch(result.body ?? "", /access-token-synthetic/u);
});

test("AUT-02 absent optional identity attributes remain explicit nulls", async () => {
  const subject = sessions();
  subject.restore = async () => ({
    accessToken: "access-token-synthetic",
    identity: {
      sub: "synthetic-subject-a",
      email: null,
      emailVerified: null,
    },
    csrfToken: "opaque-csrf-identifier-synthetic",
    expiresAt: new Date("2026-10-23T00:00:00Z"),
    idleExpiresAt: new Date("2026-10-22T12:30:00Z"),
    authenticationTime: new Date("2026-10-22T11:59:00Z"),
  });
  const handler = createWebSessionHandler(
    {
      sessions: subject as never,
      request: (async () => Response.json({ data: null })) as typeof fetch,
    },
    configuration,
  );
  const result = await handler(
    event("GET", "/api/auth/session", {
      cookies: ["__Host-foloo_session=opaque-session-identifier-synthetic"],
    }),
  );
  const body = JSON.parse(result.body ?? "{}") as {
    identity?: Record<string, unknown>;
  };
  assert.deepEqual(body.identity, {
    sub: "synthetic-subject-a",
    email: null,
    emailVerified: null,
    displayName: null,
  });
});

test("AUT-04 Google callback preserves state boundary and creates only an opaque cookie", async () => {
  const handler = createWebSessionHandler(
    { sessions: sessions() as never },
    configuration,
  );
  const result = await handler(
    event("GET", "/api/auth/google/callback", {
      queryStringParameters: {
        code: "authorization-code-synthetic",
        state: "oauth-state-synthetic",
      },
      cookies: ["__Host-foloo_oauth=oauth-transaction-identifier-synthetic"],
    }),
  );
  assert.equal(result.statusCode, 303);
  assert.equal(result.headers?.location, "/dashboard");
  assert.match(result.cookies?.[0] ?? "", /^__Host-foloo_session=/u);
  assert.match(result.cookies?.[1] ?? "", /Max-Age=0/u);
  assert.doesNotMatch(result.body ?? "", /authorization-code-synthetic/u);
});

test("AUT-04 Google provider cancellation returns safely to login", async () => {
  let cancellation: { transactionId: string; state: string } | undefined;
  const subject = sessions();
  subject.cancelGoogleAuthorization = async (transactionId, state) => {
    cancellation = { transactionId, state };
  };
  const handler = createWebSessionHandler(
    { sessions: subject as never },
    configuration,
  );
  const result = await handler(
    event("GET", "/api/auth/google/callback", {
      queryStringParameters: {
        error: "access_denied",
        error_description: "provider details must not be reflected",
        state: "oauth-state-synthetic",
      },
      cookies: ["__Host-foloo_oauth=oauth-transaction-identifier-synthetic"],
    }),
  );

  assert.equal(result.statusCode, 303);
  assert.equal(result.headers?.location, "/login");
  assert.deepEqual(cancellation, {
    transactionId: "oauth-transaction-identifier-synthetic",
    state: "oauth-state-synthetic",
  });
  assert.equal(result.cookies?.length, 1);
  assert.match(result.cookies?.[0] ?? "", /^__Host-foloo_oauth=;/u);
  assert.match(result.cookies?.[0] ?? "", /Max-Age=0/u);
  assert.doesNotMatch(result.body ?? "", /access_denied|provider details/u);
});

test("AUT-04 Google cancellation without validated state fails closed", async () => {
  const subject = sessions();
  subject.cancelGoogleAuthorization = async () => {
    const { OAuthTransactionError } =
      await import("../src/web_auth/web_session.js");
    throw new OAuthTransactionError();
  };
  const handler = createWebSessionHandler(
    { sessions: subject as never },
    configuration,
  );
  const result = await handler(
    event("GET", "/api/auth/google/callback", {
      queryStringParameters: {
        error: "access_denied",
        error_description: "provider details must not be reflected",
        state: "invalid-oauth-state",
      },
      cookies: ["__Host-foloo_oauth=oauth-transaction-identifier-synthetic"],
    }),
  );

  assert.equal(result.statusCode, 400);
  assert.equal(result.headers?.location, undefined);
  assert.match(result.cookies?.[0] ?? "", /^__Host-foloo_oauth=;/u);
  assert.doesNotMatch(result.body ?? "", /access_denied|provider details/u);
});

test("AUT-18 mutation requires allowed Origin and CSRF", async () => {
  const handler = createWebSessionHandler(
    { sessions: sessions() as never },
    configuration,
  );
  const missingOrigin = await handler(
    event("POST", "/api/auth/session/refresh"),
  );
  assert.equal(missingOrigin.statusCode, 403);
  const wrongCsrf = await handler(
    event("POST", "/api/auth/session/refresh", {
      headers: { origin: "https://foloo.io", "x-csrf-token": "wrong-token" },
      cookies: ["__Host-foloo_session=opaque-session-identifier-synthetic"],
    }),
  );
  assert.equal(wrongCsrf.statusCode, 403);
});

test("AUT-18 BFF exposes only the explicit Account Deletion allowlist", async () => {
  let upstream = "";
  const handler = createWebSessionHandler(
    {
      sessions: sessions() as never,
      request: (async (input: Parameters<typeof fetch>[0]) => {
        upstream = String(input);
        return new Response("{}", {
          status: 200,
          headers: { "content-type": "application/json" },
        });
      }) as typeof fetch,
    },
    configuration,
  );
  const allowed = await handler(
    event("GET", "/api/foloo/v1/account-deletion-requests/current", {
      cookies: ["__Host-foloo_session=opaque-session-identifier-synthetic"],
    }),
  );
  assert.equal(allowed.statusCode, 200);
  assert.equal(
    upstream,
    "https://api.example.test/v1/account-deletion-requests/current",
  );
  const denied = await handler(
    event("GET", "/api/foloo/v1/leads", {
      cookies: ["__Host-foloo_session=opaque-session-identifier-synthetic"],
    }),
  );
  assert.equal(denied.statusCode, 404);
});

test("AUT-18 native reauth HTTP enforces Origin, session cookie and CSRF before accepting evidence", async () => {
  let calls = 0;
  const handler = createWebSessionHandler(
    {
      sessions: {
        ...sessions(),
        beginReauthentication: async (_id: string, csrf: string) => {
          calls++;
          if (csrf !== "correct-csrf") throw new WebSessionCsrfError();
          return {
            transactionId: "synthetic-transaction",
            validAfter: new Date().toISOString(),
          };
        },
      } as never,
    },
    configuration,
  );
  const path = "/api/auth/reauthentication/start";
  const body = JSON.stringify({ provider: "srp" });
  assert.equal((await handler(event("POST", path, { body }))).statusCode, 403);
  assert.equal(
    (
      await handler(
        event("POST", path, {
          body,
          headers: {
            origin: configuration.allowedOrigin,
            "x-csrf-token": "correct-csrf",
          },
        }),
      )
    ).statusCode,
    401,
  );
  assert.equal(calls, 0);
  assert.equal(
    (
      await handler(
        event("POST", path, {
          body,
          headers: { origin: configuration.allowedOrigin },
          cookies: ["__Host-foloo_session=synthetic-original-session"],
        }),
      )
    ).statusCode,
    400,
  );
  assert.equal(
    (
      await handler(
        event("POST", path, {
          body,
          headers: {
            origin: configuration.allowedOrigin,
            "x-csrf-token": "wrong-csrf",
          },
          cookies: ["__Host-foloo_session=synthetic-original-session"],
        }),
      )
    ).statusCode,
    403,
  );
  const ok = await handler(
    event("POST", path, {
      body,
      headers: {
        origin: configuration.allowedOrigin,
        "x-csrf-token": "correct-csrf",
      },
      cookies: ["__Host-foloo_session=synthetic-original-session"],
    }),
  );
  assert.equal(ok.statusCode, 200);
  assert.equal(ok.cookies, undefined);
});

test("AUT-18 native reauth completion returns metadata without changing a cookie", async () => {
  let calls = 0;
  const original = sessions();
  const handler = createWebSessionHandler(
    {
      sessions: {
        ...original,
        completeNativeReauthentication: async (
          _session: string,
          csrf: string,
          transaction: string,
        ) => {
          calls++;
          assert.equal(csrf, "correct-csrf");
          assert.equal(transaction, "synthetic-intent");
          return original.restore("original");
        },
      } as never,
      request: (async () =>
        Response.json({ data: { name: "QA" } })) as typeof fetch,
    },
    configuration,
  );
  const result = await handler(
    event("POST", "/api/auth/reauthentication/srp", {
      headers: {
        origin: configuration.allowedOrigin,
        "x-csrf-token": "correct-csrf",
      },
      cookies: ["__Host-foloo_session=original-session-identifier"],
      body: JSON.stringify({
        transactionId: "synthetic-intent",
        accessToken: "synthetic-access-token",
        refreshToken: "synthetic-refresh-token",
      }),
    }),
  );
  assert.equal(result.statusCode, 200);
  assert.equal(calls, 1);
  assert.equal(result.cookies, undefined);
  assert.equal(JSON.parse(result.body!).authenticated, true);
});
test("AUT-18 Google reauth callback uses fixed account return without replacing session cookie", async () => {
  const handler = createWebSessionHandler(
    {
      sessions: {
        ...sessions(),
        completeGoogleAuthorization: async () => ({
          ...(await sessions().bootstrapWithRefreshToken()),
          reauthenticated: true,
        }),
      } as never,
    },
    configuration,
  );
  const result = await handler(
    event("GET", "/api/auth/google/callback", {
      queryStringParameters: {
        code: "synthetic-code",
        state: "synthetic-state",
      },
      cookies: [
        "__Host-foloo_oauth=synthetic-transaction",
        "__Host-foloo_session=synthetic-original",
      ],
    }),
  );
  assert.equal(result.statusCode, 303);
  assert.equal(result.headers?.location, "/settings/account#peligro");
  assert.ok(
    result.cookies?.every((c) => !c.startsWith("__Host-foloo_session=")),
  );
});
