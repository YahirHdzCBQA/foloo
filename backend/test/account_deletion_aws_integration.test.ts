/** Synthetic integration coverage for durable STORE-02 AWS boundaries. */

import assert from "node:assert/strict";
import test from "node:test";

import {
  GetItemCommand,
  PutItemCommand,
  DeleteItemCommand,
  TransactWriteItemsCommand,
  type AttributeValue,
  type DynamoDBClient,
} from "@aws-sdk/client-dynamodb";
import {
  DecryptCommand,
  EncryptCommand,
  type KMSClient,
} from "@aws-sdk/client-kms";

import { createAccountDeletionWorker } from "../src/account_deletion/account_deletion_worker.js";
import { parseAccountDeletionQueueMessage } from "../src/account_deletion/aws_account_deletion_adapters.js";
import { DynamoAccountDeletionWorkflowStore } from "../src/account_deletion/dynamodb_account_deletion_workflow_store.js";
import { PostgresOAuthErasure } from "../src/account_deletion/postgres_oauth_erasure.js";
import { DynamoKmsDeletionRecipientVault } from "../src/account_deletion/account_deletion_transactional_email.js";
import type { AccountDeletionRecord } from "../src/account_deletion/account_deletion_workflow.js";

type Item = Record<string, AttributeValue>;

test("durable workflow store recovers current request and receipt after restart", async () => {
  const items = new Map<string, Item>();
  const client = {
    async send(command: unknown) {
      if (command instanceof GetItemCommand) {
        const input = command.input;
        const pk = input.Key?.pk?.S ?? "";
        return { Item: items.get(pk) };
      }
      if (command instanceof TransactWriteItemsCommand) {
        for (const operation of command.input.TransactItems ?? []) {
          const put = operation.Put;
          if (!put?.Item?.pk?.S) continue;
          items.set(put.Item.pk.S, put.Item as Item);
        }
        return {};
      }
      throw new Error("Unexpected DynamoDB command.");
    },
  } as unknown as DynamoDBClient;
  const first = new DynamoAccountDeletionWorkflowStore(client, "synthetic");
  const now = new Date("2026-10-20T12:00:00Z");
  const record: AccountDeletionRecord = {
    requestId: "11111111-1111-4111-8111-111111111111",
    ownerKey: "owner-key",
    idempotencyKey: "idem-key-1",
    locale: "es",
    requestedExport: true,
    status: "requested",
    createdAt: now,
    expiresAt: new Date(now.getTime() + 60_000),
    acceptedAt: now,
    updatedAt: now,
    completedAt: null,
    receiptHash: "a".repeat(64),
    receiptExpiresAt: new Date(now.getTime() + 120_000),
    supportCode: null,
    barrier: {
      deletionId: "11111111-1111-4111-8111-111111111111",
      subjectKey: "SUB#policy#v1#digest" as never,
      registrationKey: "REG#policy#v1#digest" as never,
    },
    subscription: {
      status: "trial",
      cancellationRequired: false,
      planDisplayName: null,
      currentPeriodEnd: null,
    },
  };
  await first.createPreflight({
    ...record,
    status: "awaiting_confirmation",
    receiptHash: null,
    receiptExpiresAt: null,
    barrier: null,
  });
  await first.update(record);

  const afterColdStart = new DynamoAccountDeletionWorkflowStore(
    client,
    "synthetic",
  );
  assert.deepEqual(await afterColdStart.findCurrent("owner-key"), record);
  assert.deepEqual(
    await afterColdStart.findByReceiptHash("a".repeat(64)),
    record,
  );
});

test("SQS worker retries only failed synthetic records", async () => {
  const processed: string[] = [];
  const worker = createAccountDeletionWorker({
    async process(message) {
      processed.push(message.requestId);
      if (message.ownerSubject === "subject-fail") throw new Error("synthetic");
      return {} as never;
    },
  });
  const makeRecord = (messageId: string, ownerSubject: string) => ({
    messageId,
    receiptHandle: "receipt",
    body: JSON.stringify({
      requestId: `${messageId}1111111-1111-4111-8111-111111111111`.slice(0, 36),
      ownerSubject,
    }),
    attributes: {} as never,
    messageAttributes: {},
    md5OfBody: "synthetic",
    eventSource: "aws:sqs",
    eventSourceARN: "arn:aws:sqs:us-east-1:111111111111:synthetic",
    awsRegion: "us-east-1",
  });
  const result = await worker({
    Records: [makeRecord("a", "subject-ok"), makeRecord("b", "subject-fail")],
  });
  assert.equal(processed.length, 2);
  assert.deepEqual(result.batchItemFailures, [{ itemIdentifier: "b" }]);
});

test("queue parser rejects malformed or control-character identity data", () => {
  assert.throws(() => parseAccountDeletionQueueMessage("{}"));
  assert.throws(() =>
    parseAccountDeletionQueueMessage(
      JSON.stringify({
        requestId: "11111111-1111-4111-8111-111111111111",
        ownerSubject: "subject\nleak",
      }),
    ),
  );
});

test("OAuth erasure revokes encrypted credentials before owner-scoped SQL deletion", async () => {
  const calls: Array<{ sql?: string; owner?: string; action?: string }> = [];
  const pool = {
    async query(sql: string, values: unknown[]) {
      calls.push({ sql, owner: values[0] as string });
      if (sql.includes("SELECT c.workspace_id")) {
        return {
          rows: [
            {
              workspace_id: "workspace-synthetic",
              provider: "google",
              encrypted_credentials: Buffer.from("ciphertext"),
            },
          ],
        };
      }
      if (sql.includes("SELECT EXISTS")) return { rows: [{ exists: false }] };
      return { rows: [] };
    },
  };
  const provider = {
    async invoke(command: { action: string }) {
      calls.push({ action: command.action });
      return { revoked: true } as const;
    },
  };
  const erasure = new PostgresOAuthErasure(pool as never, provider as never);
  await erasure.revokeAndDestroy("subject-synthetic");
  assert.equal(calls[1]?.action, "revoke");
  assert.match(calls[2]?.sql ?? "", /DELETE FROM email_oauth_states/u);
  assert.match(calls[3]?.sql ?? "", /DELETE FROM email_connections/u);
  assert.equal(
    calls.every(
      (call) => call.owner === undefined || call.owner === "subject-synthetic",
    ),
    true,
  );
});

test("RNF-09 stores only KMS ciphertext for the short-lived SES recipient", async () => {
  let item: Item | undefined;
  const dynamo = {
    async send(command: unknown) {
      if (command instanceof PutItemCommand) {
        item = command.input.Item as Item;
        return {};
      }
      if (command instanceof GetItemCommand) return { Item: item };
      if (command instanceof DeleteItemCommand) {
        item = undefined;
        return {};
      }
      throw new Error("Unexpected DynamoDB command.");
    },
  } as unknown as DynamoDBClient;
  const kms = {
    async send(command: unknown) {
      if (command instanceof EncryptCommand) {
        assert.deepEqual(
          JSON.parse(Buffer.from(command.input.Plaintext!).toString("utf8")),
          {
            email: "synthetic@example.test",
            receipt: "r".repeat(43),
          },
        );
        return { CiphertextBlob: Buffer.from("opaque-ciphertext") };
      }
      if (command instanceof DecryptCommand) {
        assert.deepEqual(command.input.EncryptionContext, {
          "foloo-account-deletion-request":
            "33333333-3333-4333-8333-333333333333",
        });
        return {
          Plaintext: Buffer.from(
            JSON.stringify({
              email: "synthetic@example.test",
              receipt: "r".repeat(43),
            }),
          ),
        };
      }
      throw new Error("Unexpected KMS command.");
    },
  } as unknown as KMSClient;
  const vault = new DynamoKmsDeletionRecipientVault(
    dynamo,
    kms,
    "synthetic",
    "synthetic-key",
  );
  await vault.capture({
    requestId: "33333333-3333-4333-8333-333333333333",
    verifiedEmail: "synthetic@example.test",
    receipt: "r".repeat(43),
    expiresAt: new Date(Date.now() + 60_000),
  });
  assert.doesNotMatch(JSON.stringify(item), /synthetic@example\.test/u);
  assert.equal(
    await vault.reveal("33333333-3333-4333-8333-333333333333"),
    "synthetic@example.test",
  );
  assert.equal(
    await vault.recoverReceipt("33333333-3333-4333-8333-333333333333"),
    "r".repeat(43),
  );
  await vault.purge("33333333-3333-4333-8333-333333333333");
  assert.equal(item, undefined);
});
