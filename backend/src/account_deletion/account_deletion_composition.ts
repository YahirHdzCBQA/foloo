/** Shared AWS composition for the disabled-by-default Account Deletion runtime. */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { KMSClient } from "@aws-sdk/client-kms";
import { LambdaClient } from "@aws-sdk/client-lambda";
import { SQSClient } from "@aws-sdk/client-sqs";
import type { Pool } from "pg";

import { LambdaEmailProviderBoundary } from "../email/provider_invoker.js";
import { AccountDeletionGuard } from "./account_deletion_guard.js";
import { WorkflowAccountDeletionHttpController } from "./account_deletion_http.js";
import { AccountDeletionRuntimeGuard } from "./account_deletion_runtime_guard.js";
import {
  ConfiguredKmsHmacKeyProvider,
  DynamoErasureCheckpointStore,
  KmsHmacSha256Generator,
  SqsAccountDeletionDispatcher,
} from "./aws_account_deletion_adapters.js";
import { DynamoAccountDeletionLedger } from "./dynamodb_account_deletion_ledger.js";
import { DynamoErasureInventoryStore } from "./dynamodb_erasure_inventory_store.js";
import { DynamoAccountDeletionWorkflowStore } from "./dynamodb_account_deletion_workflow_store.js";
import {
  accountDeletionNotifier,
  DynamoKmsDeletionRecipientVault,
  type AccountDeletionNotificationMode,
} from "./account_deletion_transactional_email.js";
import { AccountDeletionWorkflow } from "./account_deletion_workflow.js";
import { LambdaCognitoErasure } from "./lambda_cognito_erasure.js";
import { LambdaCognitoVerifiedEmailResolver } from "./lambda_cognito_verified_email.js";
import { PostgresAccountDeletionRuntime } from "./postgres_account_deletion_runtime.js";
import { PostgresOAuthErasure } from "./postgres_oauth_erasure.js";
import { PostgresOwnerErasure } from "./postgres_owner_erasure.js";
import {
  PseudonymousEmailIdentifierService,
  PseudonymousSubjectIdentifierService,
} from "./pseudonymous_identity.js";
import { S3OwnerObjectErasure } from "./s3_owner_object_erasure.js";
import { StagedAccountDeletionExecutor } from "./staged_account_deletion_executor.js";
import { RestoredOwnerErasureRecovery } from "./restored_owner_erasure_recovery.js";
import { createAccountDeletionQaAccessGuard } from "./account_deletion_qa_access.js";

export type AccountDeletionAwsConfiguration = Readonly<{
  tableName: string;
  hmacKeyArn: string;
  hmacKeyVersion: string;
  recipientKeyArn: string;
  queueUrl: string;
  notificationFunctionName: string;
  notificationMode: AccountDeletionNotificationMode;
  emailProviderFunctionName: string;
  cognitoFinalizerFunctionName: string;
  mediaBucketName: string;
  maximumAuthenticationAgeMs: number;
  environment: string;
  qaAccessEnabled: boolean;
  qaAllowedSubjectHashes: ReadonlySet<string>;
  intakeEnabled: boolean;
  verifiedEmailFunctionName?: string;
}>;

export function composeAccountDeletionRuntime(
  pool: Pool,
  config: AccountDeletionAwsConfiguration,
) {
  const dynamo = new DynamoDBClient({});
  const kms = new KMSClient({});
  const lambda = new LambdaClient({});
  const keyProvider = new ConfiguredKmsHmacKeyProvider({
    [config.hmacKeyVersion]: config.hmacKeyArn,
  });
  const hmac = new KmsHmacSha256Generator(kms);
  const subjects = new PseudonymousSubjectIdentifierService(keyProvider, hmac);
  const qaAccessGuard = createAccountDeletionQaAccessGuard({
    environment: config.environment,
    enabled: config.qaAccessEnabled,
    allowedSubjectHashes: config.qaAllowedSubjectHashes,
  });
  const guard = new AccountDeletionGuard(
    new DynamoAccountDeletionLedger(dynamo, config.tableName),
    new PseudonymousEmailIdentifierService(keyProvider, hmac),
    subjects,
    {
      writeVersion: config.hmacKeyVersion,
      readVersions: [config.hmacKeyVersion],
    },
  );
  const postgresRuntime = new PostgresAccountDeletionRuntime(pool);
  const erasureInventory = new DynamoErasureInventoryStore(
    dynamo,
    config.tableName,
  );
  const postgres = new PostgresOwnerErasure(pool, erasureInventory);
  const executor = new StagedAccountDeletionExecutor(
    new DynamoErasureCheckpointStore(dynamo, config.tableName),
    new PostgresOAuthErasure(
      pool,
      new LambdaEmailProviderBoundary(config.emailProviderFunctionName),
    ),
    new S3OwnerObjectErasure(
      config.mediaBucketName,
      postgres,
      erasureInventory,
    ),
    postgres,
    new LambdaCognitoErasure(lambda, config.cognitoFinalizerFunctionName),
  );
  const recipientVault = new DynamoKmsDeletionRecipientVault(
    dynamo,
    kms,
    config.tableName,
    config.recipientKeyArn,
  );
  const workflow = new AccountDeletionWorkflow(
    new DynamoAccountDeletionWorkflowStore(dynamo, config.tableName),
    guard,
    postgresRuntime,
    postgresRuntime,
    executor,
    accountDeletionNotifier(
      config.notificationMode,
      lambda,
      config.notificationFunctionName,
    ),
    undefined,
    new SqsAccountDeletionDispatcher(new SQSClient({}), config.queueUrl),
    recipientVault,
    postgresRuntime,
  );
  const verifiedEmailResolver = config.verifiedEmailFunctionName
    ? new LambdaCognitoVerifiedEmailResolver(
        lambda,
        config.verifiedEmailFunctionName,
      )
    : {
        async resolve(): Promise<string> {
          throw new Error("Verified-email resolver is not configured.");
        },
      };
  return {
    workflow,
    controller: new WorkflowAccountDeletionHttpController(
      workflow,
      subjects,
      config.hmacKeyVersion,
      config.maximumAuthenticationAgeMs,
      qaAccessGuard,
      verifiedEmailResolver,
      config.intakeEnabled,
    ),
    accessGuard: new AccountDeletionRuntimeGuard(guard),
    executor,
  };
}

export function composeAccountDeletionWorker(
  pool: Pool,
  config: AccountDeletionAwsConfiguration,
) {
  const runtime = composeAccountDeletionRuntime(pool, config);
  return {
    workflow: runtime.workflow,
    restoreRecovery: new RestoredOwnerErasureRecovery(runtime.executor),
  };
}
