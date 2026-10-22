/**
 * Enforces the Cognito client boundary after API Gateway has verified JWT
 * signature, issuer, expiry and audience. Web access remains constrained to
 * the DEV QA subjects authorized for opaque Web Sessions.
 */

import type { APIGatewayProxyEventV2WithJWTAuthorizer } from "aws-lambda";

import { unauthorized } from "../application/errors.js";
import { webQaSubjectHash } from "./web_qa_identity.js";

export type ApiClientAccessPolicy = Readonly<{
  issuer: string;
  mobileClientId: string;
  webClientId: string;
  webSessionsEnabled: boolean;
  allowedWebSubjectHashes: ReadonlySet<string>;
}>;

export type ApiClientAccessGuard = Readonly<{
  assertAllowed(event: APIGatewayProxyEventV2WithJWTAuthorizer): void;
}>;

export function createApiClientAccessGuard(
  policy: ApiClientAccessPolicy,
  now: () => Date = () => new Date(),
): ApiClientAccessGuard {
  if (
    policy.issuer.length === 0 ||
    policy.mobileClientId.length === 0 ||
    policy.webClientId.length === 0 ||
    policy.mobileClientId === policy.webClientId ||
    [...policy.allowedWebSubjectHashes].some(
      (value) => !/^[A-Za-z0-9_-]{43}$/u.test(value),
    ) ||
    (policy.webSessionsEnabled && policy.allowedWebSubjectHashes.size === 0)
  ) {
    throw new Error("API client access policy is invalid.");
  }
  return {
    assertAllowed(event) {
      const method = event.requestContext.http.method.toUpperCase();
      const path = event.rawPath.replace(/\/$/, "");
      if (isPublicRoute(method, path)) return;

      const claims = event.requestContext.authorizer?.jwt?.claims;
      if (
        !claims ||
        claims.token_use !== "access" ||
        claims.iss !== policy.issuer
      ) {
        throw unauthorized();
      }
      const expiresAt = numericClaim(claims.exp);
      if (expiresAt === undefined || expiresAt <= now().getTime() / 1000) {
        throw unauthorized();
      }
      const subject = claims.sub;
      const clientId = claims.client_id;
      if (
        typeof subject !== "string" ||
        subject.trim().length === 0 ||
        subject.length > 2048 ||
        typeof clientId !== "string"
      ) {
        throw unauthorized();
      }
      if (clientId === policy.mobileClientId) return;
      if (
        clientId !== policy.webClientId ||
        !policy.webSessionsEnabled ||
        !policy.allowedWebSubjectHashes.has(webQaSubjectHash(subject))
      ) {
        throw unauthorized();
      }
    },
  };
}

function numericClaim(value: unknown): number | undefined {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : undefined;
}

function isPublicRoute(method: string, path: string): boolean {
  return (
    (method === "POST" && path === "/v1/account-deletion-status") ||
    (method === "GET" && /^\/v1\/email\/oauth\/callback\/[^/]+$/u.test(path))
  );
}
