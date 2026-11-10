/**
 * Consumes verified Cognito owners from the private entitlement queue.
 * It re-resolves identity server-side and performs one idempotent PostgreSQL
 * transaction; no email or entitlement decision is accepted from Flutter.
 */

import { InvokeCommand, LambdaClient } from "@aws-sdk/client-lambda";
import { KMSClient } from "@aws-sdk/client-kms";
import {
  GetSecretValueCommand,
  SecretsManagerClient,
} from "@aws-sdk/client-secrets-manager";
import type { SQSBatchResponse, SQSEvent } from "aws-lambda";
import pg from "pg";

import {
  AccountProvisioningPendingError,
  EntitlementPreauthorizationService,
} from "./entitlement_preauthorization.js";
import { parseAutomaticEntitlementMessage } from "./automatic_entitlement_enqueue.js";
import { KmsVerifiedEmailSelector } from "./preauthorization_selector.js";

type Evaluate = (subject: string) => Promise<void>;

export function createAutomaticEntitlementWorker(evaluate: Evaluate) {
  return async (event: SQSEvent): Promise<SQSBatchResponse> => {
    const failures: { itemIdentifier: string }[] = [];
    for (const record of event.Records) {
      try {
        const message = parseAutomaticEntitlementMessage(record.body);
        await evaluate(message.subject);
      } catch {
        failures.push({ itemIdentifier: record.messageId });
      }
    }
    return { batchItemFailures: failures };
  };
}

let runtimeHandler: ReturnType<typeof createAutomaticEntitlementWorker>;

export async function handler(event: SQSEvent): Promise<SQSBatchResponse> {
  runtimeHandler ??= await buildRuntimeHandler();
  return runtimeHandler(event);
}

async function buildRuntimeHandler() {
  const region = requiredEnvironment("AWS_REGION");
  const secretResult = await new SecretsManagerClient({ region }).send(
    new GetSecretValueCommand({
      SecretId: requiredEnvironment("DB_ENTITLEMENT_OPERATOR_SECRET_ARN"),
    }),
  );
  if (!secretResult.SecretString)
    throw new Error("Database secret is unavailable.");
  const secret = JSON.parse(secretResult.SecretString) as Partial<{
    username: string;
    password: string;
  }>;
  if (secret.username !== "foloo_entitlement_operator" || !secret.password) {
    throw new Error("Database secret is invalid.");
  }
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
  const preauthorizations = new EntitlementPreauthorizationService(
    pool,
    new KmsVerifiedEmailSelector(
      new KMSClient({ region }),
      requiredEnvironment("ENTITLEMENT_PREAUTHORIZATION_HMAC_KEY_ARN"),
      requiredEnvironment("ENTITLEMENT_PREAUTHORIZATION_HMAC_KEY_VERSION"),
    ),
  );
  const lambda = new LambdaClient({ region });
  const resolverFunctionName = requiredEnvironment(
    "COGNITO_IDENTITY_RESOLVER_FUNCTION_NAME",
  );
  return createAutomaticEntitlementWorker(async (subject) => {
    const response = await lambda.send(
      new InvokeCommand({
        FunctionName: resolverFunctionName,
        InvocationType: "RequestResponse",
        Payload: Buffer.from(JSON.stringify({ subject })),
      }),
    );
    if (response.FunctionError || !response.Payload) {
      throw new Error("Automatic identity verification failed.");
    }
    const result = JSON.parse(
      Buffer.from(response.Payload).toString("utf8"),
    ) as
      | { ok?: false }
      | { ok: true; subject: string; email: string; emailVerified: true };
    if (
      result.ok !== true ||
      result.emailVerified !== true ||
      result.subject !== subject ||
      typeof result.email !== "string"
    ) {
      throw new Error("Automatic identity verification failed.");
    }
    try {
      await preauthorizations.consumeVerifiedIdentity({
        subject: result.subject,
        verifiedEmail: result.email,
      });
    } catch (error) {
      if (error instanceof AccountProvisioningPendingError) throw error;
      throw error;
    }
  });
}

function requiredEnvironment(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required.`);
  return value;
}

function positivePort(value: string): number {
  const port = Number(value);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error("DB_PORT is invalid.");
  }
  return port;
}
