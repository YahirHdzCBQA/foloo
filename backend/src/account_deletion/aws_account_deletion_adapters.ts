/** AWS adapters for durable checkpoints, KMS HMAC, queueing and Cognito. */

import {
  AdminDeleteUserCommand,
  AdminUserGlobalSignOutCommand,
  ListUsersCommand,
  type CognitoIdentityProviderClient,
} from "@aws-sdk/client-cognito-identity-provider";
import {
  GetItemCommand,
  UpdateItemCommand,
  type DynamoDBClient,
} from "@aws-sdk/client-dynamodb";
import { GenerateMacCommand, type KMSClient } from "@aws-sdk/client-kms";
import { SendMessageCommand, type SQSClient } from "@aws-sdk/client-sqs";

import type {
  HmacSha256Generator,
  HmacSha256KeyProvider,
} from "./pseudonymous_identity.js";
import type {
  CognitoErasurePort,
  ErasureCheckpointStore,
  ErasureStage,
} from "./staged_account_deletion_executor.js";

export type KmsHmacKey = Readonly<{ keyId: string; version: string }>;

export class ConfiguredKmsHmacKeyProvider implements HmacSha256KeyProvider<KmsHmacKey> {
  constructor(private readonly versions: Readonly<Record<string, string>>) {}

  async getKey(keyVersion: string): Promise<KmsHmacKey> {
    const keyId = this.versions[keyVersion];
    if (!keyId) throw new Error("HMAC key version is not configured.");
    return { keyId, version: keyVersion };
  }
}

export class KmsHmacSha256Generator implements HmacSha256Generator<KmsHmacKey> {
  constructor(private readonly client: KMSClient) {}

  async generate(key: KmsHmacKey, message: Uint8Array): Promise<Uint8Array> {
    const result = await this.client.send(
      new GenerateMacCommand({
        KeyId: key.keyId,
        MacAlgorithm: "HMAC_SHA_256",
        Message: message,
      }),
    );
    if (!result.Mac) throw new Error("KMS returned no MAC.");
    return new Uint8Array(result.Mac);
  }
}

export class DynamoErasureCheckpointStore implements ErasureCheckpointStore {
  constructor(
    private readonly client: DynamoDBClient,
    private readonly tableName: string,
  ) {}

  async completed(requestId: string): Promise<ReadonlySet<ErasureStage>> {
    const result = await this.client.send(
      new GetItemCommand({
        TableName: this.tableName,
        Key: { pk: { S: checkpointKey(requestId) } },
        ConsistentRead: true,
      }),
    );
    return new Set((result.Item?.completed_stages?.SS ?? []) as ErasureStage[]);
  }

  async markCompleted(requestId: string, stage: ErasureStage): Promise<void> {
    await this.client.send(
      new UpdateItemCommand({
        TableName: this.tableName,
        Key: { pk: { S: checkpointKey(requestId) } },
        UpdateExpression:
          "ADD completed_stages :stage SET entity_type = if_not_exists(entity_type, :type), updated_at = :updated",
        ExpressionAttributeValues: {
          ":stage": { SS: [stage] },
          ":type": { S: "erasure_checkpoint" },
          ":updated": { S: new Date().toISOString() },
        },
      }),
    );
  }
}

export type WorkflowDeletionQueueMessage = Readonly<{
  mode?: "workflow";
  requestId: string;
  ownerSubject: string;
}>;

export type RestoreRecoveryQueueMessage = Readonly<{
  mode: "restore_recovery";
  requestId: string;
  deletionId: string;
  ownerSubject: string;
}>;

export type AccountDeletionQueueMessage =
  WorkflowDeletionQueueMessage | RestoreRecoveryQueueMessage;

export class SqsAccountDeletionDispatcher {
  constructor(
    private readonly client: SQSClient,
    private readonly queueUrl: string,
  ) {}

  async dispatch(message: AccountDeletionQueueMessage): Promise<void> {
    validateQueueMessage(message);
    await this.client.send(
      new SendMessageCommand({
        QueueUrl: this.queueUrl,
        MessageBody: JSON.stringify(message),
        MessageGroupId: message.requestId,
        MessageDeduplicationId: message.requestId,
      }),
    );
  }
}

export class SqsRestoreErasureDispatcher {
  constructor(
    private readonly client: SQSClient,
    private readonly queueUrl: string,
  ) {}

  async dispatch(message: RestoreRecoveryQueueMessage): Promise<void> {
    validateQueueMessage(message);
    await this.client.send(
      new SendMessageCommand({
        QueueUrl: this.queueUrl,
        MessageBody: JSON.stringify(message),
        MessageGroupId: message.deletionId,
        MessageDeduplicationId: message.requestId,
      }),
    );
  }
}

export function parseAccountDeletionQueueMessage(
  body: string,
): AccountDeletionQueueMessage {
  const value = JSON.parse(body) as Partial<AccountDeletionQueueMessage>;
  validateQueueMessage(value);
  return value as AccountDeletionQueueMessage;
}

export class CognitoAdminErasure implements CognitoErasurePort {
  constructor(
    private readonly client: CognitoIdentityProviderClient,
    private readonly userPoolId: string,
  ) {}

  async globallySignOutAndDelete(ownerSubject: string): Promise<void> {
    const username = await this.username(ownerSubject);
    if (!username) return;
    await this.client.send(
      new AdminUserGlobalSignOutCommand({
        UserPoolId: this.userPoolId,
        Username: username,
      }),
    );
    await this.client.send(
      new AdminDeleteUserCommand({
        UserPoolId: this.userPoolId,
        Username: username,
      }),
    );
  }

  async identityExists(ownerSubject: string): Promise<boolean> {
    return (await this.username(ownerSubject)) !== null;
  }

  private async username(ownerSubject: string): Promise<string | null> {
    if (!/^[A-Za-z0-9-]{8,128}$/u.test(ownerSubject)) {
      throw new Error("Cognito subject is invalid.");
    }
    const result = await this.client.send(
      new ListUsersCommand({
        UserPoolId: this.userPoolId,
        Filter: `sub = "${ownerSubject}"`,
        Limit: 2,
      }),
    );
    if ((result.Users?.length ?? 0) > 1) {
      throw new Error("Cognito subject is ambiguous.");
    }
    return result.Users?.[0]?.Username ?? null;
  }
}

function checkpointKey(requestId: string): string {
  if (!/^[0-9a-f-]{36}$/iu.test(requestId))
    throw new Error("Invalid request id.");
  return `CHECKPOINT#${requestId}`;
}

function validateQueueMessage(
  value: Partial<AccountDeletionQueueMessage>,
): asserts value is AccountDeletionQueueMessage {
  if (
    typeof value.requestId !== "string" ||
    !/^[0-9a-f-]{36}$/iu.test(value.requestId) ||
    typeof value.ownerSubject !== "string" ||
    value.ownerSubject.length === 0 ||
    value.ownerSubject.length > 2048 ||
    /[\p{Cc}\p{Cf}\p{Z}]/u.test(value.ownerSubject) ||
    (value.mode !== undefined &&
      value.mode !== "workflow" &&
      value.mode !== "restore_recovery") ||
    (value.mode === "restore_recovery" &&
      (typeof value.deletionId !== "string" ||
        !/^[0-9a-f-]{36}$/iu.test(value.deletionId)))
  ) {
    throw new Error("Invalid Account Deletion queue message.");
  }
}
