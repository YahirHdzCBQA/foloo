/** Resolves one verified Cognito identity for the private entitlement boundary.
 * It has no VPC/database access and returns only the ownership subject required
 * by the administrative service (MON-21, AUT-10).
 */

import { CognitoIdentityProviderClient } from "@aws-sdk/client-cognito-identity-provider";
import type { Handler } from "aws-lambda";

import {
  lookupVerifiedAdministrativeIdentity,
  lookupVerifiedAdministrativeIdentityBySubject,
} from "./cognito_administrative_identity.js";

type IdentityLookup = (
  email: string,
) => Promise<{ subject: string; email: string; emailVerified: true }>;

type SubjectLookup = (
  subject: string,
) => Promise<{ subject: string; email: string; emailVerified: true }>;

export function createAdministrativeIdentityHandler(
  lookup: IdentityLookup,
  lookupBySubject?: SubjectLookup,
) {
  return async (event: unknown) => {
    try {
      const request = identityRequest(event);
      const identity =
        request.kind === "email"
          ? await lookup(request.value)
          : await requiredSubjectLookup(lookupBySubject)(request.value);
      return {
        ok: true as const,
        subject: identity.subject,
        email: identity.email,
        emailVerified: true as const,
      };
    } catch {
      return { ok: false as const, errorCode: "identity_not_verified" };
    }
  };
}

let runtimeHandler: ReturnType<typeof createAdministrativeIdentityHandler>;

export const handler: Handler = async (event) => {
  runtimeHandler ??= createAdministrativeIdentityHandler(
    async (email) => {
      const userPoolId = requiredEnvironment("COGNITO_USER_POOL_ID");
      const region = requiredEnvironment("AWS_REGION");
      return lookupVerifiedAdministrativeIdentity(
        new CognitoIdentityProviderClient({ region }),
        userPoolId,
        email,
      );
    },
    async (subject) => {
      const userPoolId = requiredEnvironment("COGNITO_USER_POOL_ID");
      const region = requiredEnvironment("AWS_REGION");
      return lookupVerifiedAdministrativeIdentityBySubject(
        new CognitoIdentityProviderClient({ region }),
        userPoolId,
        subject,
      );
    },
  );
  return runtimeHandler(event);
};

function identityRequest(event: unknown): {
  kind: "email" | "subject";
  value: string;
} {
  if (
    !isRecord(event) ||
    Object.keys(event).some((key) => key !== "email" && key !== "subject")
  ) {
    throw new Error("Identity request is invalid.");
  }
  const hasEmail = typeof event.email === "string";
  const hasSubject = typeof event.subject === "string";
  if (hasEmail === hasSubject) {
    throw new Error("Identity request is invalid.");
  }
  return hasEmail
    ? { kind: "email", value: event.email as string }
    : { kind: "subject", value: event.subject as string };
}

function requiredSubjectLookup(
  lookup: SubjectLookup | undefined,
): SubjectLookup {
  if (!lookup) throw new Error("Subject lookup is unavailable.");
  return lookup;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function requiredEnvironment(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required.`);
  return value;
}
