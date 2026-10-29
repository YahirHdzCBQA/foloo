/**
 * HTTP contract adapter for STORE-02 Account Deletion.
 * It trusts only API Gateway JWT claims for identity and authentication age.
 */

import type {
  APIGatewayProxyEventV2WithJWTAuthorizer,
  APIGatewayProxyStructuredResultV2,
} from "aws-lambda";
import { z } from "zod";

import { ApplicationError, unauthorized } from "../application/errors.js";
import { authenticatedSubject } from "../auth/authenticated_identity.js";
import type { PseudonymousSubjectIdentifierService } from "./pseudonymous_identity.js";
import type { AccountDeletionAdmissionGuard } from "./account_deletion_admission.js";
import type { VerifiedCognitoEmailResolver } from "./verified_cognito_email.js";
import {
  AccountDeletionWorkflow,
  verifyRecentAuthentication,
  type AccountDeletionRecord,
} from "./account_deletion_workflow.js";

const createSchema = z.object({
  locale: z.enum(["es", "en"]),
  requestedExport: z.boolean().default(false),
});
const confirmSchema = z.object({
  acknowledgementVersion: z.string().min(1).max(64),
  irreversibleAccepted: z.literal(true),
  discardUnsyncedAccepted: z.boolean(),
  cancelRenewalAccepted: z.boolean(),
});
const receiptSchema = z.object({ receipt: z.string().min(32).max(512) });
const requestIdSchema = z.uuid();
const idempotencyKeySchema = z.string().min(8).max(128);

export interface AccountDeletionHttpController {
  handle(
    event: APIGatewayProxyEventV2WithJWTAuthorizer,
  ): Promise<APIGatewayProxyStructuredResultV2 | undefined>;
}

export class DisabledAccountDeletionHttpController implements AccountDeletionHttpController {
  async handle(
    event: APIGatewayProxyEventV2WithJWTAuthorizer,
  ): Promise<APIGatewayProxyStructuredResultV2 | undefined> {
    if (!event.rawPath.startsWith("/v1/account-deletion")) return undefined;
    throw new ApplicationError(
      "account_deletion_unavailable",
      503,
      "Account deletion is not enabled in this environment.",
    );
  }
}

export class WorkflowAccountDeletionHttpController<
  KeyHandle,
> implements AccountDeletionHttpController {
  constructor(
    private readonly workflow: AccountDeletionWorkflow<KeyHandle>,
    private readonly subjectIdentifiers: PseudonymousSubjectIdentifierService<KeyHandle>,
    private readonly keyVersion: string,
    private readonly maximumAuthenticationAgeMs: number,
    private readonly admissionGuard: AccountDeletionAdmissionGuard,
    private readonly verifiedEmailResolver: VerifiedCognitoEmailResolver,
    private readonly intakeEnabled = false,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async handle(
    event: APIGatewayProxyEventV2WithJWTAuthorizer,
  ): Promise<APIGatewayProxyStructuredResultV2 | undefined> {
    const method = event.requestContext.http.method.toUpperCase();
    const path = event.rawPath.replace(/\/$/, "");
    if (!path.startsWith("/v1/account-deletion")) return undefined;

    if (method === "POST" && path === "/v1/account-deletion-status") {
      const payload = receiptSchema.parse(readBody(event));
      const record = await this.workflow.byReceipt(payload.receipt);
      if (!record) {
        throw new ApplicationError(
          "deletion_status_not_found",
          404,
          "Deletion status was not found.",
        );
      }
      return response(200, { data: publicStatus(record) });
    }

    const subject = authenticatedSubject(event);
    this.admissionGuard.assertAllowed(subject);
    const ownerKey = (
      await this.subjectIdentifiers.identify(subject, this.keyVersion)
    ).digest;
    const recent = recentAuthentication(
      event,
      this.now(),
      this.maximumAuthenticationAgeMs,
    );

    if (
      method === "POST" &&
      path === "/v1/account-deletion-reauthentication/verify"
    ) {
      return response(200, {
        data: {
          recent: recent.recent,
          reauthenticationRequired: !recent.recent,
          validUntil: recent.validUntil?.toISOString() ?? null,
        },
      });
    }
    if (method === "GET" && path === "/v1/account-deletion-requests/current") {
      const record = await this.workflow.current(ownerKey);
      return response(200, { data: record ? publicStatus(record) : null });
    }
    if (method === "POST" && path === "/v1/account-deletion-requests") {
      this.assertIntakeEnabled();
      const payload = createSchema.parse(readBody(event));
      const result = await this.workflow.preflight({
        ownerSubject: subject,
        ownerKey,
        idempotencyKey: requiredHeader(event, "idempotency-key"),
        locale: payload.locale,
        requestedExport: payload.requestedExport,
        recentAuthentication: recent.recent,
      });
      return response(201, {
        data: {
          requestId: result.record.requestId,
          status: result.record.status,
          expiresAt: result.record.expiresAt.toISOString(),
          pendingSyncCount: result.pendingSyncCount,
          exportAvailable: result.exportAvailable,
          subscription: serializeSubscription(result.record),
        },
      });
    }
    const confirmMatch =
      /^\/v1\/account-deletion-requests\/([^/]+)\/confirm$/.exec(path);
    if (method === "POST" && confirmMatch?.[1]) {
      this.assertIntakeEnabled();
      const payload = confirmSchema.parse(readBody(event));
      const email = await this.verifiedEmailResolver.resolve({
        accessToken: bearerAccessToken(event),
        expectedSubject: subject,
        scopes: authenticatedScopes(event),
      });
      const result = await this.workflow.confirm({
        requestId: requestIdSchema.parse(confirmMatch[1]),
        ownerSubject: subject,
        verifiedEmail: email,
        ownerKey,
        recentAuthentication: recent.recent,
        irreversibleAccepted: payload.irreversibleAccepted,
        discardUnsyncedAccepted: payload.discardUnsyncedAccepted,
        cancelRenewalAccepted: payload.cancelRenewalAccepted,
        confirmationIdempotencyKey: requiredHeader(event, "idempotency-key"),
      });
      return response(202, {
        data: {
          requestId: result.record.requestId,
          status: result.record.status,
          acceptedAt: result.record.acceptedAt?.toISOString(),
          receipt: result.receipt,
          receiptExpiresAt: result.record.receiptExpiresAt?.toISOString(),
        },
      });
    }
    throw new ApplicationError("route_not_found", 404, "Route was not found.");
  }

  private assertIntakeEnabled(): void {
    if (this.intakeEnabled) return;
    throw new ApplicationError(
      "account_deletion_intake_unavailable",
      503,
      "New account deletion requests are not being accepted.",
    );
  }
}

function bearerAccessToken(
  event: APIGatewayProxyEventV2WithJWTAuthorizer,
): string {
  const authorization = Object.entries(event.headers).find(
    ([key]) => key.toLowerCase() === "authorization",
  )?.[1];
  const match = /^Bearer ([^\s]+)$/u.exec(authorization ?? "");
  if (!match?.[1]) throw unauthorized();
  return match[1];
}

function authenticatedScopes(
  event: APIGatewayProxyEventV2WithJWTAuthorizer,
): readonly string[] {
  const values = new Set<string>();
  const authorizerScopes = event.requestContext.authorizer.jwt.scopes;
  if (Array.isArray(authorizerScopes)) {
    for (const value of authorizerScopes) values.add(value);
  }
  const claim = event.requestContext.authorizer.jwt.claims.scope;
  if (typeof claim === "string") {
    for (const value of claim.split(" ")) {
      if (value.length > 0) values.add(value);
    }
  }
  return [...values];
}

function recentAuthentication(
  event: APIGatewayProxyEventV2WithJWTAuthorizer,
  now: Date,
  maximumAgeMs: number,
) {
  const claim = event.requestContext.authorizer.jwt.claims.auth_time;
  const seconds =
    typeof claim === "number"
      ? claim
      : typeof claim === "string"
        ? Number.parseInt(claim, 10)
        : Number.NaN;
  return verifyRecentAuthentication({
    authenticatedAt: Number.isFinite(seconds) ? new Date(seconds * 1000) : null,
    now,
    maximumAge: { milliseconds: maximumAgeMs },
  });
}

function requiredHeader(
  event: APIGatewayProxyEventV2WithJWTAuthorizer,
  name: string,
): string {
  const target = name.toLowerCase();
  const value = Object.entries(event.headers).find(
    ([key]) => key.toLowerCase() === target,
  )?.[1];
  return idempotencyKeySchema.parse(value);
}

function readBody(event: APIGatewayProxyEventV2WithJWTAuthorizer): unknown {
  if (!event.body) return {};
  const raw = event.isBase64Encoded
    ? Buffer.from(event.body, "base64").toString("utf8")
    : event.body;
  try {
    return JSON.parse(raw) as unknown;
  } catch {
    throw new ApplicationError(
      "invalid_json",
      400,
      "Request body must be valid JSON.",
    );
  }
}

function publicStatus(record: AccountDeletionRecord) {
  return {
    requestId: record.requestId,
    status: record.status,
    updatedAt: record.updatedAt.toISOString(),
    completedAt: record.completedAt?.toISOString() ?? null,
    supportCode: record.supportCode,
  };
}

function serializeSubscription(record: AccountDeletionRecord) {
  return {
    ...record.subscription,
    currentPeriodEnd:
      record.subscription.currentPeriodEnd?.toISOString() ?? null,
  };
}

function response(
  statusCode: number,
  body: unknown,
): APIGatewayProxyStructuredResultV2 {
  return {
    statusCode,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
    body: JSON.stringify(body),
  };
}
