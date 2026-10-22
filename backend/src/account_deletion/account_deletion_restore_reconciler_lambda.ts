/** Manual, disabled-by-default restore reconciliation entry point. */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { KMSClient } from "@aws-sdk/client-kms";
import { SQSClient } from "@aws-sdk/client-sqs";

import { databasePool } from "../persistence/database.js";
import { AccountDeletionGuard } from "./account_deletion_guard.js";
import { AccountDeletionRestoreReconciler } from "./account_deletion_restore_reconciler.js";
import {
  ConfiguredKmsHmacKeyProvider,
  KmsHmacSha256Generator,
  SqsRestoreErasureDispatcher,
} from "./aws_account_deletion_adapters.js";
import { DynamoAccountDeletionLedger } from "./dynamodb_account_deletion_ledger.js";
import {
  PseudonymousEmailIdentifierService,
  PseudonymousSubjectIdentifierService,
} from "./pseudonymous_identity.js";

export async function handler(event: { recoveryRunId?: string } = {}) {
  if (process.env.FOLOO_ACCOUNT_DELETION_RECONCILER_ENABLED !== "true") {
    throw new Error("Account deletion restore reconciler is disabled.");
  }
  const table = required("ACCOUNT_DELETION_TABLE_NAME");
  const keyArn = required("ACCOUNT_DELETION_HMAC_KEY_ARN");
  const version = required("ACCOUNT_DELETION_HMAC_KEY_VERSION");
  const recoveryRunId = event.recoveryRunId;
  if (!recoveryRunId) throw new Error("recoveryRunId is required.");
  const keys = new ConfiguredKmsHmacKeyProvider({ [version]: keyArn });
  const hmac = new KmsHmacSha256Generator(new KMSClient({}));
  const guard = new AccountDeletionGuard(
    new DynamoAccountDeletionLedger(new DynamoDBClient({}), table),
    new PseudonymousEmailIdentifierService(keys, hmac),
    new PseudonymousSubjectIdentifierService(keys, hmac),
    { writeVersion: version, readVersions: [version] },
  );
  return new AccountDeletionRestoreReconciler(
    await databasePool(),
    guard,
    new SqsRestoreErasureDispatcher(
      new SQSClient({}),
      required("ACCOUNT_DELETION_QUEUE_URL"),
    ),
  ).reconcile(recoveryRunId);
}

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is required.`);
  return value;
}
