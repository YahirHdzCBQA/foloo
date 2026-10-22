/**
 * Durable deletion inventories stored in the existing Account Deletion table.
 * Sharded S3 manifests and owner scope survive PostgreSQL erasure so retries
 * and final verification never reconstruct evidence from deleted rows.
 */

import { createHash } from "node:crypto";

import {
  GetItemCommand,
  PutItemCommand,
  type AttributeValue,
  type DynamoDBClient,
} from "@aws-sdk/client-dynamodb";

export type PostgresOwnerScope = Readonly<{
  userId: string;
  accountId: string;
  workspaceId: string;
}>;

export interface DurableErasureInventoryStore {
  captureObjectKeys(
    requestId: string,
    objectKeys: readonly string[],
  ): Promise<void>;
  objectKeys(requestId: string): Promise<readonly string[] | null>;
  capturePostgresScope(
    requestId: string,
    scope: PostgresOwnerScope,
  ): Promise<void>;
  postgresScope(requestId: string): Promise<PostgresOwnerScope | null>;
}

const objectKeysPerShard = 100;
const retentionSeconds = 31 * 24 * 60 * 60;

export class DynamoErasureInventoryStore implements DurableErasureInventoryStore {
  constructor(
    private readonly client: DynamoDBClient,
    private readonly tableName: string,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async captureObjectKeys(
    requestId: string,
    objectKeys: readonly string[],
  ): Promise<void> {
    assertRequestId(requestId);
    const keys = normalizedObjectKeys(objectKeys);
    const manifestHash = digest(keys);
    const current = await this.objectManifest(requestId);
    if (current) {
      if (current.manifestHash !== manifestHash) {
        throw new Error("Deletion object inventory is immutable.");
      }
      return;
    }
    const expiresAt = Math.ceil(this.now().getTime() / 1000) + retentionSeconds;
    const shards = chunk(keys, objectKeysPerShard);
    for (const [index, values] of shards.entries()) {
      await this.client.send(
        new PutItemCommand({
          TableName: this.tableName,
          Item: {
            pk: { S: objectShardKey(requestId, index) },
            entity_type: { S: "erasure_object_inventory_shard" },
            object_keys: { L: values.map((value) => ({ S: value })) },
            expires_at: { N: String(expiresAt) },
          },
        }),
      );
    }
    try {
      await this.client.send(
        new PutItemCommand({
          TableName: this.tableName,
          Item: {
            pk: { S: objectManifestKey(requestId) },
            entity_type: { S: "erasure_object_inventory" },
            object_count: { N: String(keys.length) },
            shard_count: { N: String(shards.length) },
            manifest_hash: { S: manifestHash },
            expires_at: { N: String(expiresAt) },
          },
          ConditionExpression: "attribute_not_exists(pk)",
        }),
      );
    } catch (error) {
      const replay = await this.objectManifest(requestId);
      if (
        isConditionalWriteFailure(error) &&
        replay?.manifestHash === manifestHash
      ) {
        return;
      }
      throw error;
    }
  }

  async objectKeys(requestId: string): Promise<readonly string[] | null> {
    const manifest = await this.objectManifest(requestId);
    if (!manifest) return null;
    const keys: string[] = [];
    for (let index = 0; index < manifest.shardCount; index += 1) {
      const item = await this.get(objectShardKey(requestId, index));
      if (!item) throw new Error("Deletion object inventory shard is missing.");
      for (const value of item.object_keys?.L ?? []) {
        if (!value.S) throw new Error("Deletion object inventory is invalid.");
        keys.push(value.S);
      }
    }
    const normalized = normalizedObjectKeys(keys);
    if (
      normalized.length !== manifest.objectCount ||
      digest(normalized) !== manifest.manifestHash
    ) {
      throw new Error("Deletion object inventory integrity check failed.");
    }
    return normalized;
  }

  async capturePostgresScope(
    requestId: string,
    scope: PostgresOwnerScope,
  ): Promise<void> {
    assertRequestId(requestId);
    const current = await this.postgresScope(requestId);
    if (current) {
      if (JSON.stringify(current) !== JSON.stringify(scope)) {
        throw new Error("Deletion PostgreSQL scope is immutable.");
      }
      return;
    }
    try {
      await this.client.send(
        new PutItemCommand({
          TableName: this.tableName,
          Item: {
            pk: { S: postgresScopeKey(requestId) },
            entity_type: { S: "erasure_postgres_scope" },
            user_id: { S: scope.userId },
            account_id: { S: scope.accountId },
            workspace_id: { S: scope.workspaceId },
            expires_at: {
              N: String(
                Math.ceil(this.now().getTime() / 1000) + retentionSeconds,
              ),
            },
          },
          ConditionExpression: "attribute_not_exists(pk)",
        }),
      );
    } catch (error) {
      const replay = await this.postgresScope(requestId);
      if (isConditionalWriteFailure(error) && sameScope(replay, scope)) return;
      throw error;
    }
  }

  async postgresScope(requestId: string): Promise<PostgresOwnerScope | null> {
    assertRequestId(requestId);
    const item = await this.get(postgresScopeKey(requestId));
    if (!item) return null;
    return {
      userId: requiredString(item, "user_id"),
      accountId: requiredString(item, "account_id"),
      workspaceId: requiredString(item, "workspace_id"),
    };
  }

  private async objectManifest(requestId: string): Promise<{
    objectCount: number;
    shardCount: number;
    manifestHash: string;
  } | null> {
    assertRequestId(requestId);
    const item = await this.get(objectManifestKey(requestId));
    if (!item) return null;
    return {
      objectCount: requiredNonNegativeInteger(item, "object_count"),
      shardCount: requiredNonNegativeInteger(item, "shard_count"),
      manifestHash: requiredString(item, "manifest_hash"),
    };
  }

  private async get(
    pk: string,
  ): Promise<Record<string, AttributeValue> | null> {
    const result = await this.client.send(
      new GetItemCommand({
        TableName: this.tableName,
        Key: { pk: { S: pk } },
        ConsistentRead: true,
      }),
    );
    return result.Item ?? null;
  }
}

function normalizedObjectKeys(values: readonly string[]): string[] {
  const keys = [...new Set(values)].sort();
  for (const key of keys) {
    if (!key || key.length > 1024 || /[\p{Cc}\p{Cf}]/u.test(key)) {
      throw new Error("Deletion object key is invalid.");
    }
  }
  return keys;
}

function digest(keys: readonly string[]): string {
  return createHash("sha256")
    .update(JSON.stringify(keys), "utf8")
    .digest("hex");
}

function chunk<T>(values: readonly T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let offset = 0; offset < values.length; offset += size) {
    chunks.push(values.slice(offset, offset + size));
  }
  return chunks;
}

function objectManifestKey(requestId: string): string {
  return `OBJECT_INVENTORY#${requestId}`;
}

function objectShardKey(requestId: string, index: number): string {
  return `OBJECT_INVENTORY#${requestId}#${index.toString().padStart(6, "0")}`;
}

function postgresScopeKey(requestId: string): string {
  return `POSTGRES_SCOPE#${requestId}`;
}

function requiredString(
  item: Record<string, AttributeValue>,
  key: string,
): string {
  const value = item[key]?.S;
  if (!value) throw new Error(`Deletion inventory is missing ${key}.`);
  return value;
}

function requiredNonNegativeInteger(
  item: Record<string, AttributeValue>,
  key: string,
): number {
  const value = Number(item[key]?.N);
  if (!Number.isInteger(value) || value < 0) {
    throw new Error(`Deletion inventory has invalid ${key}.`);
  }
  return value;
}

function assertRequestId(requestId: string): void {
  if (!/^[0-9a-f-]{36}$/iu.test(requestId)) {
    throw new Error("Invalid request id.");
  }
}

function isConditionalWriteFailure(error: unknown): boolean {
  return (
    error instanceof Error && error.name === "ConditionalCheckFailedException"
  );
}

function sameScope(
  left: PostgresOwnerScope | null,
  right: PostgresOwnerScope,
): boolean {
  return (
    left?.userId === right.userId &&
    left.accountId === right.accountId &&
    left.workspaceId === right.workspaceId
  );
}
