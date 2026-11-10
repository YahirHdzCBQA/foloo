/** Private IAM-only Lambda for audited administrative PRO operations.
 * Cognito verification occurs through a narrowly scoped resolver while all
 * PostgreSQL writes use the dedicated operator role inside the VPC (MON-21).
 */

import { InvokeCommand, LambdaClient } from "@aws-sdk/client-lambda";
import { KMSClient } from "@aws-sdk/client-kms";
import {
  GetSecretValueCommand,
  SecretsManagerClient,
} from "@aws-sdk/client-secrets-manager";
import type { Handler } from "aws-lambda";
import pg from "pg";

import {
  AdministrativeEntitlementService,
  type AdministrativeEntitlementCommand,
  type AdministrativeEntitlementResult,
  type VerifiedCognitoIdentityResolver,
} from "./administrative_entitlement.js";
import {
  EntitlementPreauthorizationService,
  type PreauthorizationCommand,
  type PreauthorizationResult,
} from "./entitlement_preauthorization.js";
import { KmsVerifiedEmailSelector } from "./preauthorization_selector.js";

type ExecuteEntitlement = (
  command: AdministrativeEntitlementCommand | PreauthorizationCommand,
) => Promise<AdministrativeEntitlementResult | PreauthorizationResult>;

export function createAdministrativeEntitlementHandler(
  execute: ExecuteEntitlement,
  operatorActor: string,
) {
  const actor = authorizedRoleArn(operatorActor);
  return async (event: unknown) => {
    try {
      const request = administrativeRequest(event);
      const command:
        AdministrativeEntitlementCommand | PreauthorizationCommand =
        request.action === "status" ||
        request.action === "preauthorization-status"
          ? request
          : { ...request, actor };
      return { ok: true as const, result: await execute(command) };
    } catch {
      return {
        ok: false as const,
        errorCode: "entitlement_operation_failed",
      };
    }
  };
}

let runtimeHandler: ReturnType<typeof createAdministrativeEntitlementHandler>;

export const handler: Handler = async (event) => {
  runtimeHandler ??= await buildRuntimeHandler();
  return runtimeHandler(event);
};

async function buildRuntimeHandler() {
  const region = requiredEnvironment("AWS_REGION");
  const secretArn = requiredEnvironment("DB_ENTITLEMENT_OPERATOR_SECRET_ARN");
  const secretResult = await new SecretsManagerClient({ region }).send(
    new GetSecretValueCommand({ SecretId: secretArn }),
  );
  if (!secretResult.SecretString) {
    throw new Error("Administrative database secret is unavailable.");
  }
  const secret = JSON.parse(secretResult.SecretString) as Partial<{
    username: string;
    password: string;
  }>;
  if (secret.username !== "foloo_entitlement_operator" || !secret.password) {
    throw new Error("Administrative database secret is invalid.");
  }
  const lambda = new LambdaClient({ region });
  const resolverFunctionName = requiredEnvironment(
    "COGNITO_IDENTITY_RESOLVER_FUNCTION_NAME",
  );
  const identities: VerifiedCognitoIdentityResolver = {
    async resolveVerifiedEmail(email) {
      const response = await lambda.send(
        new InvokeCommand({
          FunctionName: resolverFunctionName,
          InvocationType: "RequestResponse",
          Payload: Buffer.from(JSON.stringify({ email })),
        }),
      );
      if (response.FunctionError || !response.Payload) {
        throw new Error("Administrative identity verification failed.");
      }
      const result = JSON.parse(
        Buffer.from(response.Payload).toString("utf8"),
      ) as Partial<{
        ok: boolean;
        subject: string;
        emailVerified: boolean;
      }>;
      if (
        result.ok !== true ||
        result.emailVerified !== true ||
        typeof result.subject !== "string" ||
        !/^[A-Za-z0-9_-]{1,128}$/u.test(result.subject)
      ) {
        throw new Error("Administrative identity verification failed.");
      }
      return { subject: result.subject, emailVerified: true };
    },
  };
  const pool = new pg.Pool({
    host: requiredEnvironment("DB_HOST"),
    port: positivePort(requiredEnvironment("DB_PORT")),
    database: requiredEnvironment("DB_NAME"),
    user: secret.username,
    password: secret.password,
    ssl: { rejectUnauthorized: true },
    max: 1,
    connectionTimeoutMillis: 5_000,
  });
  const service = new AdministrativeEntitlementService(pool, identities);
  const preauthorizations = new EntitlementPreauthorizationService(
    pool,
    new KmsVerifiedEmailSelector(
      new KMSClient({ region }),
      requiredEnvironment("ENTITLEMENT_PREAUTHORIZATION_HMAC_KEY_ARN"),
      requiredEnvironment("ENTITLEMENT_PREAUTHORIZATION_HMAC_KEY_VERSION"),
    ),
  );
  return createAdministrativeEntitlementHandler(
    (command) =>
      isPreauthorizationCommand(command)
        ? preauthorizations.execute(command)
        : service.execute(command),
    requiredEnvironment("ENTITLEMENT_OPERATOR_ACTOR_ARN"),
  );
}

function isPreauthorizationCommand(
  command: AdministrativeEntitlementCommand | PreauthorizationCommand,
): command is PreauthorizationCommand {
  return (
    command.action === "preauthorization-status" ||
    command.action === "preauthorize" ||
    command.action === "revoke-preauthorization"
  );
}

function administrativeRequest(event: unknown):
  | { action: "status"; email: string }
  | { action: "preauthorization-status"; email: string }
  | {
      action: "grant" | "revoke" | "preauthorize" | "revoke-preauthorization";
      email: string;
      reason: string;
    } {
  if (!isRecord(event)) throw new Error("Administrative request is invalid.");
  const allowed = new Set(["action", "email", "reason"]);
  if (Object.keys(event).some((key) => !allowed.has(key))) {
    throw new Error("Administrative request is invalid.");
  }
  const action = event.action;
  const email = event.email;
  if (
    (action !== "status" &&
      action !== "grant" &&
      action !== "revoke" &&
      action !== "preauthorization-status" &&
      action !== "preauthorize" &&
      action !== "revoke-preauthorization") ||
    typeof email !== "string"
  ) {
    throw new Error("Administrative request is invalid.");
  }
  if (action === "status" || action === "preauthorization-status") {
    if (event.reason !== undefined)
      throw new Error("Administrative request is invalid.");
    return { action, email };
  }
  if (typeof event.reason !== "string") {
    throw new Error("Administrative request is invalid.");
  }
  return { action, email, reason: event.reason };
}

function authorizedRoleArn(value: string): string {
  const trimmed = value.trim();
  if (!/^arn:aws:iam::\d{12}:role\/[A-Za-z0-9+=,.@_/-]+$/u.test(trimmed)) {
    throw new Error("ENTITLEMENT_OPERATOR_ACTOR_ARN is invalid.");
  }
  return trimmed;
}

function positivePort(value: string): number {
  const port = Number(value);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error("DB_PORT is invalid.");
  }
  return port;
}

function requiredEnvironment(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required.`);
  return value;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
