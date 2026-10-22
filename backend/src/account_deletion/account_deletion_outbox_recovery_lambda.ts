/** Disabled-by-default scheduled recovery for Account Deletion SQS dispatch. */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { KMSClient } from "@aws-sdk/client-kms";
import { SQSClient } from "@aws-sdk/client-sqs";

import { SqsAccountDeletionDispatcher } from "./aws_account_deletion_adapters.js";
import { AccountDeletionOutboxRecovery } from "./account_deletion_outbox_recovery.js";
import { DynamoAccountDeletionWorkflowStore } from "./dynamodb_account_deletion_workflow_store.js";
import { DynamoKmsDeletionRecipientVault } from "./account_deletion_transactional_email.js";

export async function handler(): Promise<{
  enabled: boolean;
  inspected: number;
  dispatched: number;
  failed: number;
}> {
  if (process.env.FOLOO_ACCOUNT_DELETION_OUTBOX_ENABLED !== "true") {
    return { enabled: false, inspected: 0, dispatched: 0, failed: 0 };
  }
  const tableName = requiredEnvironment("ACCOUNT_DELETION_TABLE_NAME");
  const recovery = new AccountDeletionOutboxRecovery(
    new DynamoAccountDeletionWorkflowStore(new DynamoDBClient({}), tableName),
    new SqsAccountDeletionDispatcher(
      new SQSClient({}),
      requiredEnvironment("ACCOUNT_DELETION_QUEUE_URL"),
    ),
    new DynamoKmsDeletionRecipientVault(
      new DynamoDBClient({}),
      new KMSClient({}),
      tableName,
      requiredEnvironment("ACCOUNT_DELETION_RECIPIENT_KEY_ARN"),
    ),
  );
  return { enabled: true, ...(await recovery.recover()) };
}

function requiredEnvironment(name: string): string {
  const value = process.env[name];
  if (!value?.trim()) throw new Error(`${name} is required.`);
  return value;
}
