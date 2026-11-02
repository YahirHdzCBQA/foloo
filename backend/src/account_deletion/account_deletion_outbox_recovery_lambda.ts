/** Disabled-by-default scheduled recovery for Account Deletion SQS dispatch. */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { KMSClient } from "@aws-sdk/client-kms";
import { SQSClient } from "@aws-sdk/client-sqs";

import { SqsAccountDeletionDispatcher } from "./aws_account_deletion_adapters.js";
import { AccountDeletionOutboxRecovery } from "./account_deletion_outbox_recovery.js";
import {
  AccountDeletionOperationalReconciler,
  JsonAccountDeletionOperationalAlertSink,
  emitAccountDeletionOperationalMetrics,
} from "./account_deletion_operational_reconciler.js";
import { DynamoAccountDeletionWorkflowStore } from "./dynamodb_account_deletion_workflow_store.js";
import { DynamoKmsDeletionRecipientVault } from "./account_deletion_transactional_email.js";

export async function handler(): Promise<{
  enabled: boolean;
  inspected: number;
  dispatched: number;
  failed: number;
  operationalInspected?: number;
}> {
  if (process.env.FOLOO_ACCOUNT_DELETION_OUTBOX_ENABLED !== "true") {
    return { enabled: false, inspected: 0, dispatched: 0, failed: 0 };
  }
  const tableName = requiredEnvironment("ACCOUNT_DELETION_TABLE_NAME");
  const store = new DynamoAccountDeletionWorkflowStore(
    new DynamoDBClient({}),
    tableName,
  );
  const dispatcher = new SqsAccountDeletionDispatcher(
    new SQSClient({}),
    requiredEnvironment("ACCOUNT_DELETION_QUEUE_URL"),
  );
  const vault = new DynamoKmsDeletionRecipientVault(
    new DynamoDBClient({}),
    new KMSClient({}),
    tableName,
    requiredEnvironment("ACCOUNT_DELETION_RECIPIENT_KEY_ARN"),
  );
  const recovery = new AccountDeletionOutboxRecovery(store, dispatcher, vault);
  const outbox = await recovery.recover();
  const operational = await new AccountDeletionOperationalReconciler(
    store,
    dispatcher,
    vault,
    new JsonAccountDeletionOperationalAlertSink(),
  ).reconcile();
  emitAccountDeletionOperationalMetrics(operational);
  return {
    enabled: true,
    ...outbox,
    operationalInspected: operational.inspected,
  };
}

function requiredEnvironment(name: string): string {
  const value = process.env[name];
  if (!value?.trim()) throw new Error(`${name} is required.`);
  return value;
}
