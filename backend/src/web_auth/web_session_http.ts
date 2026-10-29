/**
 * HTTP contract for the disabled-by-default Foloo web-session BFF.
 * It emits only opaque cookies and safe metadata; Cognito credentials remain
 * inside the session service and are attached only to allowlisted API calls.
 */

import type {
  APIGatewayProxyEventV2,
  APIGatewayProxyStructuredResultV2,
} from "aws-lambda";

import {
  OAuthTransactionError,
  WebSessionConcurrencyError,
  WebReauthenticationError,
  WebSessionCsrfError,
  WebSessionService,
  WebSessionUnauthorizedError,
} from "./web_session.js";

const sessionCookieName = "__Host-foloo_session";
const oauthCookieName = "__Host-foloo_oauth";

export type WebSessionHttpConfiguration = Readonly<{
  enabled: boolean;
  allowedOrigin: string;
  sessionMaxAgeSeconds: number;
  oauthMaxAgeSeconds: number;
  folooApiBaseUrl: string;
  successRedirectPath: string;
}>;

type WebSessionDependencies = Readonly<{
  sessions: WebSessionService;
  request?: typeof fetch;
}>;

type ProxyTarget = Readonly<{
  method: string;
  upstreamPath: string;
  csrf: boolean;
}>;

/** Builds a Lambda-compatible handler with injectable network dependencies. */
export function createWebSessionHandler(
  dependencies: WebSessionDependencies,
  configuration: WebSessionHttpConfiguration,
): (
  event: APIGatewayProxyEventV2,
) => Promise<APIGatewayProxyStructuredResultV2> {
  const request = dependencies.request ?? fetch;
  return async (event) => {
    const path = normalizePath(event.rawPath);
    if (!configuration.enabled) {
      return problem(503, "web_session_unavailable");
    }
    try {
      if (event.requestContext.http.method === "POST") {
        assertOrigin(event, configuration.allowedOrigin);
      }

      if (
        path === "/api/auth/reauthentication/start" &&
        method(event) === "POST"
      ) {
        const payload = parseObjectBody(event);
        if (payload.provider !== "srp" && payload.provider !== "google")
          throw new HttpInputError(400, "invalid_provider");
        const result = await dependencies.sessions.beginReauthentication(
          requiredCookie(event, sessionCookieName),
          requiredHeader(event, "x-csrf-token"),
          payload.provider,
        );
        return json(
          200,
          result,
          result.authorizationUrl
            ? [
                secureCookie(
                  oauthCookieName,
                  result.transactionId,
                  configuration.oauthMaxAgeSeconds,
                ),
              ]
            : undefined,
        );
      }
      if (
        path === "/api/auth/reauthentication/srp" &&
        method(event) === "POST"
      ) {
        const payload = parseObjectBody(event);
        const session =
          await dependencies.sessions.completeNativeReauthentication(
            requiredCookie(event, sessionCookieName),
            requiredHeader(event, "x-csrf-token"),
            requiredString(payload, "transactionId"),
            requiredString(payload, "accessToken"),
          );
        return json(200, {
          authenticated: true,
          identity: { ...session.identity, displayName: null },
          csrfToken: session.csrfToken,
          expiresAt: session.expiresAt.toISOString(),
          idleExpiresAt: session.idleExpiresAt.toISOString(),
          authenticationTime: session.authenticationTime.toISOString(),
        });
      }

      if (path === "/api/auth/session/srp" && method(event) === "POST") {
        const payload = parseObjectBody(event);
        const refreshToken = requiredString(payload, "refreshToken");
        const session =
          await dependencies.sessions.bootstrapWithRefreshToken(refreshToken);
        return sessionResponse(201, session, configuration);
      }

      if (path === "/api/auth/google/start" && method(event) === "GET") {
        const authorization =
          await dependencies.sessions.beginGoogleAuthorization();
        return noStore({
          statusCode: 302,
          headers: { location: authorization.authorizationUrl },
          cookies: [
            secureCookie(
              oauthCookieName,
              authorization.transactionId,
              configuration.oauthMaxAgeSeconds,
            ),
          ],
        });
      }

      if (path === "/api/auth/google/callback" && method(event) === "GET") {
        const code = event.queryStringParameters?.code;
        const state = event.queryStringParameters?.state;
        const transactionId = cookie(event, oauthCookieName);
        if (event.queryStringParameters?.error) {
          if (!state || !transactionId) throw new OAuthTransactionError();
          const reauthentication =
            await dependencies.sessions.cancelGoogleAuthorization(
              transactionId,
              state,
            );
          return noStore({
            statusCode: 303,
            headers: {
              location: reauthentication
                ? "/settings/account?reauth=failed#peligro"
                : "/login",
            },
            cookies: [clearCookie(oauthCookieName)],
          });
        }
        if (!code || !state || !transactionId)
          throw new OAuthTransactionError();
        const session = await dependencies.sessions.completeGoogleAuthorization(
          transactionId,
          state,
          code,
          cookie(event, sessionCookieName),
        );
        if (session.reauthenticated)
          return noStore({
            statusCode: 303,
            headers: { location: "/settings/account#peligro" },
            cookies: [clearCookie(oauthCookieName)],
          });
        const response = sessionResponse(303, session, configuration);
        return {
          ...response,
          headers: {
            ...response.headers,
            location: configuration.successRedirectPath,
          },
          cookies: [...(response.cookies ?? []), clearCookie(oauthCookieName)],
        };
      }

      if (path === "/api/auth/session" && method(event) === "GET") {
        const session = await dependencies.sessions.restore(
          requiredCookie(event, sessionCookieName),
        );
        return json(
          200,
          await sessionBody(request, session, configuration.folooApiBaseUrl),
        );
      }

      if (path === "/api/auth/session/refresh" && method(event) === "POST") {
        const session = await dependencies.sessions.restore(
          requiredCookie(event, sessionCookieName),
          {
            csrfToken: requiredHeader(event, "x-csrf-token"),
            forceRefresh: true,
          },
        );
        return json(
          200,
          await sessionBody(request, session, configuration.folooApiBaseUrl),
        );
      }

      if (path === "/api/auth/logout" && method(event) === "POST") {
        await dependencies.sessions.logout(
          requiredCookie(event, sessionCookieName),
          requiredHeader(event, "x-csrf-token"),
        );
        return noStore({
          statusCode: 204,
          cookies: [
            clearCookie(sessionCookieName),
            clearCookie(oauthCookieName),
          ],
        });
      }

      const proxyTarget = allowlistedProxyTarget(path, method(event));
      if (proxyTarget) {
        const session = await dependencies.sessions.restore(
          requiredCookie(event, sessionCookieName),
          proxyTarget.csrf
            ? { csrfToken: requiredHeader(event, "x-csrf-token") }
            : {},
        );
        return proxyToFolooApi(
          request,
          event,
          proxyTarget,
          session.accessToken,
          configuration.folooApiBaseUrl,
        );
      }

      return problem(404, "not_found");
    } catch (error) {
      const clearLogoutCookie =
        path === "/api/auth/logout"
          ? [clearCookie(sessionCookieName), clearCookie(oauthCookieName)]
          : undefined;
      if (error instanceof WebReauthenticationError)
        return noStore({
          statusCode: 303,
          headers: { location: "/settings/account?reauth=failed#peligro" },
          cookies: [clearCookie(oauthCookieName)],
        });
      if (error instanceof WebSessionUnauthorizedError) {
        return problem(401, "web_session_unauthorized", clearLogoutCookie);
      }
      if (error instanceof WebSessionCsrfError) {
        return problem(403, "csrf_validation_failed", clearLogoutCookie);
      }
      if (error instanceof OAuthTransactionError) {
        return problem(400, "oauth_transaction_invalid", [
          clearCookie(oauthCookieName),
        ]);
      }
      if (error instanceof WebSessionConcurrencyError) {
        return problem(409, "web_session_conflict", clearLogoutCookie);
      }
      if (error instanceof HttpInputError) {
        return problem(error.statusCode, error.code, clearLogoutCookie);
      }
      return problem(502, "web_session_provider_error", clearLogoutCookie);
    }
  };
}

/* Bootstrap keeps its existing metadata-only contract; restoration reloads
 * identity from authoritative services instead of trusting browser memory. */
function sessionResponse(
  statusCode: number,
  session: {
    sessionId: string;
    csrfToken: string;
    expiresAt: Date;
    idleExpiresAt: Date;
    authenticationTime: Date;
  },
  configuration: WebSessionHttpConfiguration,
): APIGatewayProxyStructuredResultV2 {
  return json(
    statusCode,
    {
      authenticated: true,
      csrfToken: session.csrfToken,
      expiresAt: session.expiresAt.toISOString(),
      idleExpiresAt: session.idleExpiresAt.toISOString(),
      authenticationTime: session.authenticationTime.toISOString(),
    },
    [
      secureCookie(
        sessionCookieName,
        session.sessionId,
        configuration.sessionMaxAgeSeconds,
      ),
    ],
  );
}

async function sessionBody(
  request: typeof fetch,
  session: {
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
  },
  apiBaseUrl: string,
): Promise<Record<string, unknown>> {
  const displayName = await fetchDisplayName(
    request,
    apiBaseUrl,
    session.accessToken,
  );
  return {
    authenticated: true,
    identity: {
      sub: session.identity.sub,
      email: session.identity.email,
      emailVerified: session.identity.emailVerified,
      displayName,
    },
    csrfToken: session.csrfToken,
    expiresAt: session.expiresAt.toISOString(),
    idleExpiresAt: session.idleExpiresAt.toISOString(),
    authenticationTime: session.authenticationTime.toISOString(),
  };
}

async function fetchDisplayName(
  request: typeof fetch,
  apiBaseUrl: string,
  accessToken: string,
): Promise<string | null> {
  const response = await request(new URL("/v1/profile", apiBaseUrl), {
    method: "GET",
    headers: { authorization: `Bearer ${accessToken}` },
    redirect: "error",
  });
  if (!response.ok) {
    throw new Error("Foloo profile lookup failed.");
  }
  const payload = (await response.json()) as unknown;
  if (!payload || typeof payload !== "object" || !("data" in payload)) {
    throw new Error("Foloo profile response is invalid.");
  }
  const data = payload.data;
  if (data === null) return null;
  if (!data || typeof data !== "object" || !("name" in data)) {
    throw new Error("Foloo profile response is invalid.");
  }
  const name = data.name;
  return typeof name === "string" && name.trim().length > 0 ? name : null;
}

function allowlistedProxyTarget(
  path: string,
  requestMethod: string,
): ProxyTarget | undefined {
  const exact = new Map<string, ProxyTarget>([
    [
      "GET /api/foloo/v1/account-deletion-requests/current",
      {
        method: "GET",
        upstreamPath: "/v1/account-deletion-requests/current",
        csrf: false,
      },
    ],
    [
      "POST /api/foloo/v1/account-deletion-reauthentication/verify",
      {
        method: "POST",
        upstreamPath: "/v1/account-deletion-reauthentication/verify",
        csrf: true,
      },
    ],
    [
      "POST /api/foloo/v1/account-deletion-requests",
      {
        method: "POST",
        upstreamPath: "/v1/account-deletion-requests",
        csrf: true,
      },
    ],
  ]);
  const direct = exact.get(`${requestMethod} ${path}`);
  if (direct) return direct;
  const match =
    /^\/api\/foloo\/v1\/account-deletion-requests\/([0-9a-f-]{36})\/confirm$/u.exec(
      path,
    );
  if (requestMethod === "POST" && match?.[1]) {
    return {
      method: "POST",
      upstreamPath: `/v1/account-deletion-requests/${match[1]}/confirm`,
      csrf: true,
    };
  }
  return undefined;
}

async function proxyToFolooApi(
  request: typeof fetch,
  event: APIGatewayProxyEventV2,
  target: ProxyTarget,
  accessToken: string,
  apiBaseUrl: string,
): Promise<APIGatewayProxyStructuredResultV2> {
  const headers: Record<string, string> = {
    authorization: `Bearer ${accessToken}`,
  };
  for (const name of ["content-type", "idempotency-key"] as const) {
    const value = header(event, name);
    if (value) headers[name] = value;
  }
  const response = await request(new URL(target.upstreamPath, apiBaseUrl), {
    method: target.method,
    headers,
    body: target.method === "GET" ? undefined : decodedBody(event),
    redirect: "error",
  });
  const responseHeaders: Record<string, string> = {};
  for (const name of ["content-type", "retry-after", "idempotency-replayed"]) {
    const value = response.headers.get(name);
    if (value) responseHeaders[name] = value;
  }
  return noStore({
    statusCode: response.status,
    headers: responseHeaders,
    body: await response.text(),
  });
}

function json(
  statusCode: number,
  body: unknown,
  cookies?: string[],
): APIGatewayProxyStructuredResultV2 {
  return noStore({
    statusCode,
    headers: { "content-type": "application/json; charset=utf-8" },
    cookies,
    body: JSON.stringify(body),
  });
}

function problem(
  statusCode: number,
  code: string,
  cookies?: string[],
): APIGatewayProxyStructuredResultV2 {
  return json(statusCode, { code }, cookies);
}

function noStore(
  response: APIGatewayProxyStructuredResultV2,
): APIGatewayProxyStructuredResultV2 {
  return {
    ...response,
    headers: {
      ...response.headers,
      "cache-control": "no-store, max-age=0",
      pragma: "no-cache",
      "x-content-type-options": "nosniff",
    },
  };
}

function secureCookie(name: string, value: string, maxAge: number): string {
  return `${name}=${value}; Path=/; Max-Age=${maxAge}; Secure; HttpOnly; SameSite=Lax`;
}

function clearCookie(name: string): string {
  return `${name}=; Path=/; Max-Age=0; Secure; HttpOnly; SameSite=Lax`;
}

function requiredCookie(event: APIGatewayProxyEventV2, name: string): string {
  const value = cookie(event, name);
  if (!value) throw new WebSessionUnauthorizedError();
  return value;
}

function cookie(
  event: APIGatewayProxyEventV2,
  name: string,
): string | undefined {
  for (const source of [event.cookies?.join(";"), header(event, "cookie")]) {
    if (!source) continue;
    for (const part of source.split(";")) {
      const separator = part.indexOf("=");
      if (separator < 0) continue;
      if (part.slice(0, separator).trim() === name) {
        return part.slice(separator + 1).trim();
      }
    }
  }
  return undefined;
}

function assertOrigin(event: APIGatewayProxyEventV2, expected: string): void {
  if (header(event, "origin") !== expected) {
    throw new HttpInputError(403, "origin_not_allowed");
  }
}

function requiredHeader(event: APIGatewayProxyEventV2, name: string): string {
  const value = header(event, name);
  if (!value) throw new HttpInputError(400, "required_header_missing");
  return value;
}

function header(
  event: APIGatewayProxyEventV2,
  name: string,
): string | undefined {
  const target = name.toLowerCase();
  return Object.entries(event.headers).find(
    ([key]) => key.toLowerCase() === target,
  )?.[1];
}

function parseObjectBody(
  event: APIGatewayProxyEventV2,
): Record<string, unknown> {
  try {
    const parsed = JSON.parse(decodedBody(event)) as unknown;
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new Error("not an object");
    }
    return parsed as Record<string, unknown>;
  } catch {
    throw new HttpInputError(400, "invalid_json");
  }
}

function decodedBody(event: APIGatewayProxyEventV2): string {
  if (!event.body) return "";
  return event.isBase64Encoded
    ? Buffer.from(event.body, "base64").toString("utf8")
    : event.body;
}

function requiredString(object: Record<string, unknown>, name: string): string {
  const value = object[name];
  if (typeof value !== "string" || value.length === 0) {
    throw new HttpInputError(400, "invalid_request");
  }
  return value;
}

function method(event: APIGatewayProxyEventV2): string {
  return event.requestContext.http.method.toUpperCase();
}

function normalizePath(path: string): string {
  return path.length > 1 ? path.replace(/\/$/u, "") : path;
}

class HttpInputError extends Error {
  constructor(
    readonly statusCode: number,
    readonly code: string,
  ) {
    super(code);
    this.name = "HttpInputError";
  }
}
