/** Disabled-by-default AWS entry point for the durable deletion queue. */

import type { SQSHandler } from "aws-lambda";

import { databasePool } from "../persistence/database.js";
import { createAccountDeletionWorker } from "./account_deletion_worker.js";
import { composeAccountDeletionWorker } from "./account_deletion_composition.js";

let workerPromise:
  Promise<ReturnType<typeof createAccountDeletionWorker>> | undefined;

async function initialize() {
  const required = (name: string): string => {
    const value = process.env[name];
    if (!value) throw new Error(`${name} is required.`);
    return value;
  };
  const pool = await databasePool();
  const runtime = composeAccountDeletionWorker(pool, {
    tableName: required("ACCOUNT_DELETION_TABLE_NAME"),
    hmacKeyArn: required("ACCOUNT_DELETION_HMAC_KEY_ARN"),
    hmacKeyVersion: required("ACCOUNT_DELETION_HMAC_KEY_VERSION"),
    recipientKeyArn: required("ACCOUNT_DELETION_RECIPIENT_KEY_ARN"),
    queueUrl: required("ACCOUNT_DELETION_QUEUE_URL"),
    notificationFunctionName: required(
      "ACCOUNT_DELETION_NOTIFICATION_FUNCTION_NAME",
    ),
    notificationMode: notificationMode(),
    emailProviderFunctionName: required("EMAIL_PROVIDER_FUNCTION_NAME"),
    cognitoFinalizerFunctionName: required("COGNITO_FINALIZER_FUNCTION_NAME"),
    mediaBucketName: required("MEDIA_BUCKET_NAME"),
    maximumAuthenticationAgeMs: 300_000,
    environment: required("FOLOO_ENVIRONMENT"),
    normalAccessEnabled:
      process.env.FOLOO_ACCOUNT_DELETION_NORMAL_ACCESS_ENABLED === "true",
    qaAccessEnabled: required("FOLOO_ACCOUNT_DELETION_QA_ENABLED") === "true",
    intakeEnabled: false,
    qaAllowedSubjectHashes: new Set(
      (process.env.ACCOUNT_DELETION_QA_SUBJECT_HASHES ?? "")
        .split(",")
        .filter(Boolean),
    ),
  });
  return createAccountDeletionWorker(runtime.workflow, runtime.restoreRecovery);
}

export const handler: SQSHandler = async (event) => {
  if (process.env.FOLOO_ACCOUNT_DELETION_WORKER_ENABLED !== "true") {
    // A disabled queue should remain empty. Returning failures is fail-closed
    // if a message is delivered by configuration error and drives it to DLQ.
    return {
      batchItemFailures: event.Records.map((record) => ({
        itemIdentifier: record.messageId,
      })),
    };
  }
  workerPromise ??= initialize();
  return (await workerPromise)(event);
};

function notificationMode(): "disabled" | "ses" {
  const value = process.env.ACCOUNT_DELETION_NOTIFICATION_MODE ?? "disabled";
  if (value !== "disabled" && value !== "ses") {
    throw new Error("ACCOUNT_DELETION_NOTIFICATION_MODE is invalid.");
  }
  return value;
}
