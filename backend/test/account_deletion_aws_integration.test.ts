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
import type { LambdaClient } from "@aws-sdk/client-lambda";

import { createAccountDeletionWorker } from "../src/account_deletion/account_deletion_worker.js";
import { RestoredOwnerErasureRecovery } from "../src/account_deletion/restored_owner_erasure_recovery.js";
import { parseAccountDeletionQueueMessage } from "../src/account_deletion/aws_account_deletion_adapters.js";
import { DynamoAccountDeletionWorkflowStore } from "../src/account_deletion/dynamodb_account_deletion_workflow_store.js";
import { PostgresOAuthErasure } from "../src/account_deletion/postgres_oauth_erasure.js";
import {
  accountDeletionNotifier,
  DynamoKmsDeletionRecipientVault,
} from "../src/account_deletion/account_deletion_transactional_email.js";
import type { AccountDeletionRecord } from "../src/account_deletion/account_deletion_workflow.js";

type Item = Record<string, AttributeValue>;

test("INF-19 disabled notification mode never invokes SES Lambda", async () => {
  let invocations = 0;
  const lambda = {
    async send() {
      invocations += 1;
      throw new Error("notification Lambda must not be invoked");
    },
  } as unknown as LambdaClient;
  const notifier = accountDeletionNotifier(
    "disabled",
    lambda,
    "synthetic-email-function",
  );
  await notifier.requestAccepted({
    requestId: "33333333-3333-4333-8333-333333333333",
    locale: "es",
  });
  await notifier.deletionCompleted({
    requestId: "33333333-3333-4333-8333-333333333333",
    locale: "en",
  });
  assert.equal(invocations, 0);
});

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
    confirmationIdempotencyKey: "confirmation-key-1",
    dispatchStatus: "pending",
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
    confirmationIdempotencyKey: null,
    dispatchStatus: "not_required",
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

test("RNF-10 acceptance conditionally creates one receipt index and durable outbox", async () => {
  const items = new Map<string, Item>();
  const transactions: TransactWriteItemsCommand[] = [];
  const client = {
    async send(command: unknown) {
      if (command instanceof GetItemCommand) {
        return { Item: items.get(command.input.Key?.pk?.S ?? "") };
      }
      if (command instanceof TransactWriteItemsCommand) {
        transactions.push(command);
        for (const operation of command.input.TransactItems ?? []) {
          const put = operation.Put;
          if (put?.Item?.pk?.S) items.set(put.Item.pk.S, put.Item as Item);
        }
        return {};
      }
      throw new Error("Unexpected DynamoDB command.");
    },
  } as unknown as DynamoDBClient;
  const store = new DynamoAccountDeletionWorkflowStore(client, "synthetic");
  const acceptedAt = new Date("2032-04-01T12:00:00Z");
  const requestId = "99999999-9999-4999-8999-999999999999";
  const preflight: AccountDeletionRecord = {
    requestId,
    ownerKey: "owner-conditional",
    idempotencyKey: "preflight-conditional",
    locale: "en",
    requestedExport: false,
    status: "awaiting_confirmation",
    createdAt: acceptedAt,
    expiresAt: new Date(acceptedAt.getTime() + 60_000),
    acceptedAt: null,
    updatedAt: acceptedAt,
    completedAt: null,
    receiptHash: null,
    receiptExpiresAt: null,
    supportCode: null,
    barrier: null,
    confirmationIdempotencyKey: null,
    dispatchStatus: "not_required",
    subscription: {
      status: "none",
      cancellationRequired: false,
      planDisplayName: null,
      currentPeriodEnd: null,
    },
  };
  await store.createPreflight(preflight);
  const accepted: AccountDeletionRecord = {
    ...preflight,
    status: "requested",
    acceptedAt,
    receiptHash: "b".repeat(64),
    receiptExpiresAt: new Date(acceptedAt.getTime() + 120_000),
    barrier: {
      deletionId: requestId,
      subjectKey: "SUB#policy#v1#digest" as never,
      registrationKey: "REG#policy#v1#digest" as never,
    },
    confirmationIdempotencyKey: "confirmation-conditional",
    dispatchStatus: "pending",
  };
  const result = await store.acceptConfirmation(accepted);
  assert.equal(result.replayed, false);
  const command = transactions.at(-1);
  assert.ok(command);
  const operations = command.input.TransactItems ?? [];
  assert.equal(operations.length, 3);
  assert.equal(
    operations[0]?.Put?.ConditionExpression,
    "#status = :awaiting AND #owner_key = :owner_key",
  );
  assert.equal(operations[1]?.Put?.Item?.pk?.S, `RECEIPT#${"b".repeat(64)}`);
  assert.equal(operations[2]?.Put?.Item?.pk?.S, `OUTBOX#${requestId}`);
  assert.equal(operations[2]?.Put?.Item?.entity_type?.S, "dispatch_outbox");
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

test("INF-21 restored owner messages retry independently and never enter normal workflow", async () => {
  const normal: string[] = [];
  let attempts = 0;
  const recovery = new RestoredOwnerErasureRecovery({
    async execute(input) {
      attempts += 1;
      assert.equal(input.ownerSubject, "restored-owner-a");
      if (attempts === 1) throw new Error("synthetic partial restore purge");
    },
    async verify() {
      return true;
    },
  });
  const worker = createAccountDeletionWorker(
    {
      async process(message) {
        normal.push(message.ownerSubject);
        return {} as never;
      },
    },
    recovery,
  );
  const record = {
    messageId: "restore-message",
    receiptHandle: "receipt",
    body: JSON.stringify({
      mode: "restore_recovery",
      requestId: "33333333-3333-4333-8333-333333333333",
      deletionId: "22222222-2222-4222-8222-222222222222",
      ownerSubject: "restored-owner-a",
    }),
    attributes: {} as never,
    messageAttributes: {},
    md5OfBody: "synthetic",
    eventSource: "aws:sqs",
    eventSourceARN: "arn:aws:sqs:us-east-1:111111111111:synthetic",
    awsRegion: "us-east-1",
  };
  assert.deepEqual((await worker({ Records: [record] })).batchItemFailures, [
    { itemIdentifier: "restore-message" },
  ]);
  assert.deepEqual((await worker({ Records: [record] })).batchItemFailures, []);
  assert.equal(attempts, 2);
  assert.deepEqual(normal, []);
});

test("OAuth erasure revokes encrypted credentials before owner-scoped SQL deletion", async () => {
  const calls: Array<{ sql?: string; owner?: string; action?: string }> = [];
  const transactionEvents: string[] = [];
  const client = {
    async query(sql: string, values: unknown[] = []) {
      if (["BEGIN", "COMMIT", "ROLLBACK"].includes(sql)) {
        transactionEvents.push(sql);
      }
      calls.push({ sql, owner: values[0] as string | undefined });
      return { rows: [] };
    },
    release() {},
  };
  const pool = {
    async query(sql: string, values: unknown[]) {
      calls.push({ sql, owner: values[0] as string });
      if (sql.includes("SELECT c.workspace_id")) {
        return {
          rows: [
            {
              workspace_id: "workspace-synthetic",
              provider: "google",
              status: "connected",
              encrypted_credentials: Buffer.from("ciphertext"),
            },
          ],
        };
      }
      if (sql.includes("SELECT EXISTS")) return { rows: [{ exists: false }] };
      return { rows: [] };
    },
    async connect() {
      return client;
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
  assert.match(calls[3]?.sql ?? "", /DELETE FROM email_send_intents/u);
  assert.match(calls[3]?.sql ?? "", /i\.workspace_id=w\.id/u);
  assert.match(calls[4]?.sql ?? "", /DELETE FROM email_oauth_states/u);
  assert.match(calls[5]?.sql ?? "", /DELETE FROM email_connections/u);
  assert.deepEqual(transactionEvents, ["BEGIN", "COMMIT"]);
  assert.equal(
    calls.every(
      (call) => call.owner === undefined || call.owner === "subject-synthetic",
    ),
    true,
  );
});

test("OAuth erasure rolls back all owner SQL cleanup when a parent delete fails", async () => {
  const transactionEvents: string[] = [];
  let released = false;
  const client = {
    async query(sql: string) {
      if (["BEGIN", "COMMIT", "ROLLBACK"].includes(sql)) {
        transactionEvents.push(sql);
        return { rows: [] };
      }
      if (sql.includes("DELETE FROM email_connections")) {
        throw new Error("synthetic restrictive FK failure");
      }
      return { rows: [] };
    },
    release() {
      released = true;
    },
  };
  const pool = {
    async query(sql: string) {
      if (sql.includes("SELECT c.workspace_id")) return { rows: [] };
      throw new Error("Unexpected pool query.");
    },
    async connect() {
      return client;
    },
  };
  const erasure = new PostgresOAuthErasure(
    pool as never,
    {
      async invoke() {
        throw new Error("Provider must not be called without connections.");
      },
    } as never,
  );

  await assert.rejects(
    erasure.revokeAndDestroy("subject-synthetic"),
    /synthetic restrictive FK failure/u,
  );
  assert.deepEqual(transactionEvents, ["BEGIN", "ROLLBACK"]);
  assert.equal(released, true);
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
            ownerSubject: "subject-synthetic",
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
              ownerSubject: "subject-synthetic",
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
    ownerSubject: "subject-synthetic",
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
  assert.equal(
    await vault.recoverOwnerSubject("33333333-3333-4333-8333-333333333333"),
    "subject-synthetic",
  );
  await vault.purge("33333333-3333-4333-8333-333333333333");
  assert.equal(item, undefined);
});
