/** Synthetic verification of durable, owner-scoped S3/PostgreSQL erasure. */

import assert from "node:assert/strict";
import test from "node:test";

import {
  GetItemCommand,
  PutItemCommand,
  type AttributeValue,
  type DynamoDBClient,
} from "@aws-sdk/client-dynamodb";
import {
  DeleteObjectsCommand,
  HeadObjectCommand,
  ListObjectsV2Command,
  type S3Client,
} from "@aws-sdk/client-s3";

import {
  DynamoErasureInventoryStore,
  type DurableErasureInventoryStore,
  type PostgresOwnerScope,
} from "../src/account_deletion/dynamodb_erasure_inventory_store.js";
import { PostgresOwnerErasure } from "../src/account_deletion/postgres_owner_erasure.js";
import { S3OwnerObjectErasure } from "../src/account_deletion/s3_owner_object_erasure.js";

type Item = Record<string, AttributeValue>;

class MemoryInventory implements DurableErasureInventoryStore {
  readonly objects = new Map<string, readonly string[]>();
  readonly scopes = new Map<string, PostgresOwnerScope>();

  async captureObjectKeys(requestId: string, objectKeys: readonly string[]) {
    if (!this.objects.has(requestId)) {
      this.objects.set(requestId, [...new Set(objectKeys)].sort());
    }
  }

  async objectKeys(requestId: string) {
    return this.objects.get(requestId) ?? null;
  }

  async capturePostgresScope(requestId: string, scope: PostgresOwnerScope) {
    this.scopes.set(requestId, scope);
  }

  async postgresScope(requestId: string) {
    return this.scopes.get(requestId) ?? null;
  }
}

test("INF-17 durable inventory shards and recovers more than 1,000 object keys", async () => {
  const items = new Map<string, Item>();
  const client = {
    async send(command: unknown) {
      if (command instanceof GetItemCommand) {
        return { Item: items.get(command.input.Key?.pk?.S ?? "") };
      }
      if (command instanceof PutItemCommand) {
        const key = command.input.Item?.pk?.S;
        if (!key) throw new Error("missing synthetic key");
        if (command.input.ConditionExpression && items.has(key)) {
          const error = new Error("synthetic condition");
          error.name = "ConditionalCheckFailedException";
          throw error;
        }
        items.set(key, command.input.Item as Item);
        return {};
      }
      throw new Error("Unexpected DynamoDB command.");
    },
  } as unknown as DynamoDBClient;
  const requestId = "11111111-1111-4111-8111-111111111111";
  const keys = Array.from(
    { length: 1_005 },
    (_, index) => `media/workspaces/workspace-a/leads/lead/${index}`,
  );
  await new DynamoErasureInventoryStore(client, "synthetic").captureObjectKeys(
    requestId,
    [...keys, keys[0]!],
  );
  const coldStart = new DynamoErasureInventoryStore(client, "synthetic");
  assert.deepEqual(await coldStart.objectKeys(requestId), [...keys].sort());
  assert.equal(
    [...items.keys()].filter((key) =>
      key.startsWith(`OBJECT_INVENTORY#${requestId}#`),
    ).length,
    11,
  );
});

test("INF-17 S3 inventory paginates, survives SQL loss and retries partial deletion", async () => {
  const inventory = new MemoryInventory();
  const requestId = "22222222-2222-4222-8222-222222222222";
  const workspaceId = "workspace-a";
  const keys = Array.from(
    { length: 1_005 },
    (_, index) => `media/workspaces/${workspaceId}/leads/lead/${index}`,
  );
  const existing = new Set(keys);
  let firstDelete = true;
  const deleteSizes: number[] = [];
  const client = {
    async send(command: unknown) {
      if (command instanceof ListObjectsV2Command) {
        const prefix = command.input.Prefix!;
        if (prefix.startsWith("content/")) return { Contents: [] };
        if (!command.input.ContinuationToken) {
          return {
            Contents: keys.slice(0, 1000).map((Key) => ({ Key })),
            IsTruncated: true,
            NextContinuationToken: "page-2",
          };
        }
        return {
          Contents: keys.slice(1000).map((Key) => ({ Key })),
          IsTruncated: false,
        };
      }
      if (command instanceof DeleteObjectsCommand) {
        const batch = (command.input.Delete?.Objects ?? []).flatMap(
          (value) => value.Key ?? [],
        );
        deleteSizes.push(batch.length);
        if (firstDelete) {
          firstDelete = false;
          for (const key of batch.slice(1)) existing.delete(key);
          return { Errors: [{ Key: batch[0], Code: "InternalError" }] };
        }
        for (const key of batch) existing.delete(key);
        return { Errors: [] };
      }
      if (command instanceof HeadObjectCommand) {
        if (existing.has(command.input.Key!)) return {};
        const error = new Error("not found") as Error & {
          $metadata: { httpStatusCode: number };
        };
        error.name = "NotFound";
        error.$metadata = { httpStatusCode: 404 };
        throw error;
      }
      throw new Error("Unexpected S3 command.");
    },
  } as unknown as S3Client;
  let sqlAvailable = true;
  const source = {
    async ownerScope() {
      return sqlAvailable
        ? { userId: "user-a", accountId: "account-a", workspaceId }
        : null;
    },
    async objectKeys() {
      return sqlAvailable ? [keys[0]!] : [];
    },
  };
  const erasure = new S3OwnerObjectErasure(
    "synthetic-bucket",
    source,
    inventory,
    client,
  );
  await erasure.freezeInventory(requestId, "owner-a");
  sqlAvailable = false;
  await assert.rejects(
    erasure.deleteOwnerObjects(requestId),
    /deletion was incomplete/u,
  );
  await erasure.deleteOwnerObjects(requestId);
  assert.equal(await erasure.hasOwnerObjects(requestId), false);
  assert.deepEqual(deleteSizes, [1000, 1000, 5]);
  assert.equal((await inventory.objectKeys(requestId))?.length, 1_005);
});

test("INF-17 S3 deletion remains isolated between two owners", async () => {
  const inventory = new MemoryInventory();
  const requestA = "33333333-3333-4333-8333-333333333333";
  const requestB = "44444444-4444-4444-8444-444444444444";
  const keyA = "media/workspaces/workspace-a/leads/a/file";
  const keyB = "media/workspaces/workspace-b/leads/b/file";
  const existing = new Set([keyA, keyB]);
  const client = {
    async send(command: unknown) {
      if (command instanceof ListObjectsV2Command) {
        const prefix = command.input.Prefix!;
        return {
          Contents: [...existing]
            .filter((key) => key.startsWith(prefix))
            .map((Key) => ({ Key })),
        };
      }
      if (command instanceof DeleteObjectsCommand) {
        for (const object of command.input.Delete?.Objects ?? []) {
          if (object.Key) existing.delete(object.Key);
        }
        return {};
      }
      if (command instanceof HeadObjectCommand) {
        if (existing.has(command.input.Key!)) return {};
        const error = new Error("not found");
        error.name = "NotFound";
        throw error;
      }
      throw new Error("Unexpected S3 command.");
    },
  } as unknown as S3Client;
  const source = {
    async ownerScope(subject: string) {
      const suffix = subject === "owner-a" ? "a" : "b";
      return {
        userId: `user-${suffix}`,
        accountId: `account-${suffix}`,
        workspaceId: `workspace-${suffix}`,
      };
    },
    async objectKeys(subject: string) {
      return [subject === "owner-a" ? keyA : keyB];
    },
  };
  const erasure = new S3OwnerObjectErasure(
    "synthetic-bucket",
    source,
    inventory,
    client,
  );
  await erasure.freezeInventory(requestA, "owner-a");
  await erasure.freezeInventory(requestB, "owner-b");
  await erasure.deleteOwnerObjects(requestA);
  assert.equal(existing.has(keyA), false);
  assert.equal(existing.has(keyB), true);
  assert.equal(await erasure.hasOwnerObjects(requestB), true);
});

test("INF-19 PostgreSQL verification covers the full frozen owner graph", async () => {
  const inventory = new MemoryInventory();
  const requestA = "55555555-5555-4555-8555-555555555555";
  const scopeA = {
    userId: "user-a",
    accountId: "account-a",
    workspaceId: "workspace-a",
  };
  const scopeB = {
    userId: "user-b",
    accountId: "account-b",
    workspaceId: "workspace-b",
  };
  const owners = new Map([
    ["owner-a", scopeA],
    ["owner-b", scopeB],
  ]);
  const deletedWorkspaceIds: string[] = [];
  const deletionParameters: unknown[][] = [];
  let verificationSql = "";
  const pool = {
    async query(sql: string, values: unknown[]) {
      if (sql.includes('AS "userId"')) {
        const scope = owners.get(values[0] as string);
        return { rows: scope ? [scope] : [], rowCount: scope ? 1 : 0 };
      }
      if (sql.includes("SELECT EXISTS")) {
        verificationSql = sql;
        return { rows: [{ exists: false }], rowCount: 1 };
      }
      if (sql.includes("storage_object_key")) return { rows: [], rowCount: 0 };
      throw new Error(`Unexpected pool query: ${sql}`);
    },
    async connect() {
      return {
        async query(sql: string, values: unknown[] = []) {
          if (sql.includes("SELECT u.id AS user_id")) {
            return {
              rows:
                values[0] === "owner-a" && values[3] === scopeA.workspaceId
                  ? [
                      {
                        user_id: scopeA.userId,
                        account_id: scopeA.accountId,
                        workspace_id: scopeA.workspaceId,
                      },
                    ]
                  : [],
              rowCount: 1,
            };
          }
          if (
            sql.startsWith("DELETE FROM") &&
            values[0] === scopeA.workspaceId
          ) {
            deletedWorkspaceIds.push(values[0] as string);
          }
          if (sql.startsWith("DELETE FROM")) deletionParameters.push(values);
          return { rows: [], rowCount: 1 };
        },
        release() {},
      };
    },
  };
  const erasure = new PostgresOwnerErasure(pool as never, inventory);
  await erasure.freezeScope(requestA, "owner-a");
  await erasure.deleteOwnerData(requestA, "owner-a");
  assert.equal(await erasure.hasOwnerData(requestA, "owner-a"), false);
  assert.equal(
    deletedWorkspaceIds.every((id) => id === scopeA.workspaceId),
    true,
  );
  assert.equal(deletedWorkspaceIds.includes(scopeB.workspaceId), false);
  assert.equal(
    deletionParameters.flat().some((value) => String(value).endsWith("-b")),
    false,
  );
  assert.deepEqual(await erasure.ownerScope("owner-b"), scopeB);
  for (const table of [
    "app_users",
    "accounts",
    "workspaces",
    "workspace_members",
    "seller_profiles",
    "events",
    "leads",
    "lead_media",
    "content_files",
    "idempotency_records",
    "email_templates",
    "event_email_templates",
    "email_connections",
    "email_oauth_states",
    "email_opt_outs",
    "email_owner_opt_outs",
    "email_unsubscribe_tokens",
    "email_follow_ups",
    "email_send_intents",
  ]) {
    assert.match(verificationSql, new RegExp(`FROM ${table}\\b`, "u"));
  }
});

test("RNF-09 PostgreSQL partial failure rolls back and retries the frozen scope", async () => {
  const inventory = new MemoryInventory();
  const requestId = "66666666-6666-4666-8666-666666666666";
  const scope = {
    userId: "user-retry",
    accountId: "account-retry",
    workspaceId: "workspace-retry",
  };
  let failOnce = true;
  const transactionEvents: string[] = [];
  const pool = {
    async query(sql: string) {
      if (sql.includes('AS "userId"')) {
        return { rows: [scope], rowCount: 1 };
      }
      if (sql.includes("SELECT EXISTS")) {
        return { rows: [{ exists: false }], rowCount: 1 };
      }
      throw new Error("Unexpected pool query.");
    },
    async connect() {
      return {
        async query(sql: string) {
          if (["BEGIN", "COMMIT", "ROLLBACK"].includes(sql)) {
            transactionEvents.push(sql);
            return { rows: [], rowCount: 0 };
          }
          if (sql.includes("SELECT u.id AS user_id")) {
            return {
              rows: [
                {
                  user_id: scope.userId,
                  account_id: scope.accountId,
                  workspace_id: scope.workspaceId,
                },
              ],
              rowCount: 1,
            };
          }
          if (failOnce && sql.startsWith("DELETE FROM leads")) {
            failOnce = false;
            throw new Error("synthetic PostgreSQL interruption");
          }
          return { rows: [], rowCount: 1 };
        },
        release() {},
      };
    },
  };
  const erasure = new PostgresOwnerErasure(pool as never, inventory);
  await erasure.freezeScope(requestId, "owner-retry");
  await assert.rejects(
    erasure.deleteOwnerData(requestId, "owner-retry"),
    /synthetic PostgreSQL interruption/u,
  );
  await erasure.deleteOwnerData(requestId, "owner-retry");
  assert.deepEqual(transactionEvents, ["BEGIN", "ROLLBACK", "BEGIN", "COMMIT"]);
  assert.equal(await erasure.hasOwnerData(requestId, "owner-retry"), false);
});
