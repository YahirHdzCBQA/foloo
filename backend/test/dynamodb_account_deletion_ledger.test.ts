/** Contract tests for the non-deployed DynamoDB Account Deletion adapter. */

import assert from "node:assert/strict";
import test from "node:test";

import {
  BatchGetItemCommand,
  GetItemCommand,
  TransactWriteItemsCommand,
  TransactionCanceledException,
  type DynamoDBClient,
} from "@aws-sdk/client-dynamodb";

import {
  AccountDeletionLedgerConflictError,
  type AcceptAccountDeletionBarrier,
  type RegistrationLedgerKey,
  type SubjectLedgerKey,
} from "../src/account_deletion/account_deletion_ledger.js";
import { DynamoAccountDeletionLedger } from "../src/account_deletion/dynamodb_account_deletion_ledger.js";

class FakeDynamoClient {
  readonly commands: unknown[] = [];
  readonly responses: unknown[] = [];

  async send(command: unknown): Promise<unknown> {
    this.commands.push(command);
    const response = this.responses.shift();
    if (response instanceof Error) throw response;
    return response ?? {};
  }
}

const barrier: AcceptAccountDeletionBarrier = {
  reference: {
    deletionId: "deletion-adapter-0001",
    subjectKey: "SUB#policy#v1#synthetic" as SubjectLedgerKey,
    registrationKey: "REG#policy#v1#synthetic" as RegistrationLedgerKey,
  },
  acceptedAt: new Date("2030-01-01T00:00:00.000Z"),
  blockedUntil: new Date("2030-01-31T00:00:00.000Z"),
};

function adapter(client: FakeDynamoClient): DynamoAccountDeletionLedger {
  return new DynamoAccountDeletionLedger(
    client as unknown as DynamoDBClient,
    "synthetic-ledger-table",
  );
}

test("INF-20 atomically writes request, tombstone and logical registration expiry", async () => {
  const client = new FakeDynamoClient();
  client.responses.push({}, {});

  await adapter(client).acceptBarrier(barrier);

  assert.ok(client.commands[0] instanceof GetItemCommand);
  const transaction = client.commands[1];
  assert.ok(transaction instanceof TransactWriteItemsCommand);
  assert.equal(transaction.input.TransactItems?.length, 3);
  const serialized = JSON.stringify(transaction.input);
  assert.match(serialized, /attribute_not_exists/);
  assert.match(serialized, /blocked_until/);
  assert.match(serialized, /expires_at/);
  assert.match(serialized, /1896048000000/);
  assert.doesNotMatch(serialized, /@|fixture|example/iu);
});

test("INF-20 repeated request is idempotent without rewriting the blocker", async () => {
  const client = new FakeDynamoClient();
  client.responses.push({
    Item: {
      pk: { S: "REQ#deletion-adapter-0001" },
      entity_type: { S: "deletion_request" },
      deletion_id: { S: barrier.reference.deletionId },
      subject_key: { S: barrier.reference.subjectKey },
      registration_key: { S: barrier.reference.registrationKey },
    },
  });

  assert.deepEqual(
    await adapter(client).acceptBarrier(barrier),
    barrier.reference,
  );
  assert.equal(client.commands.length, 1);
});

test("INF-20 conflicting reuse of a deletion id is rejected", async () => {
  const client = new FakeDynamoClient();
  client.responses.push({
    Item: {
      pk: { S: "REQ#deletion-adapter-0001" },
      entity_type: { S: "deletion_request" },
      deletion_id: { S: barrier.reference.deletionId },
      subject_key: { S: "SUB#other" },
      registration_key: { S: barrier.reference.registrationKey },
    },
  });

  await assert.rejects(
    adapter(client).acceptBarrier(barrier),
    AccountDeletionLedgerConflictError,
  );
});

test("INF-20 resolves a concurrent identical transaction as idempotent", async () => {
  const client = new FakeDynamoClient();
  client.responses.push(
    {},
    new TransactionCanceledException({
      $metadata: {},
      message: "Synthetic conditional race.",
      CancellationReasons: [{ Code: "ConditionalCheckFailed" }],
    }),
    {
      Item: {
        pk: { S: "REQ#deletion-adapter-0001" },
        entity_type: { S: "deletion_request" },
        deletion_id: { S: barrier.reference.deletionId },
        subject_key: { S: barrier.reference.subjectKey },
        registration_key: { S: barrier.reference.registrationKey },
      },
    },
  );

  assert.deepEqual(
    await adapter(client).acceptBarrier(barrier),
    barrier.reference,
  );
  assert.equal(client.commands.length, 3);
});

test("INF-18 reads both durable states and temporary blockers consistently", async () => {
  const client = new FakeDynamoClient();
  client.responses.push(
    {
      Responses: {
        "synthetic-ledger-table": [
          {
            pk: { S: barrier.reference.subjectKey },
            entity_type: { S: "subject_tombstone" },
            deletion_id: { S: barrier.reference.deletionId },
            deletion_state: { S: "deleted" },
            created_at: { S: "2030-01-01T00:00:00.000Z" },
            updated_at: { S: "2030-01-02T00:00:00.000Z" },
          },
        ],
      },
    },
    {
      Responses: {
        "synthetic-ledger-table": [
          {
            pk: { S: barrier.reference.registrationKey },
            entity_type: { S: "registration_blocker" },
            deletion_id: { S: barrier.reference.deletionId },
            blocked_until: { N: "1896048000000" },
            created_at: { S: "2030-01-01T00:00:00.000Z" },
          },
        ],
      },
    },
  );
  const ledger = adapter(client);

  const subjects = await ledger.findSubjectTombstones([
    barrier.reference.subjectKey,
  ]);
  const blockers = await ledger.findRegistrationBlockers([
    barrier.reference.registrationKey,
  ]);
  assert.equal(subjects[0]?.state, "deleted");
  assert.equal(
    blockers[0]?.blockedUntil.toISOString(),
    "2030-01-31T00:00:00.000Z",
  );
  assert.ok(
    client.commands.every((command) => command instanceof BatchGetItemCommand),
  );
});

test("INF-21 markDeleted is an atomic, idempotent state transition", async () => {
  const client = new FakeDynamoClient();
  client.responses.push({});

  await adapter(client).markDeleted(
    barrier.reference,
    new Date("2030-01-02T00:00:00.000Z"),
  );

  const transaction = client.commands[0];
  assert.ok(transaction instanceof TransactWriteItemsCommand);
  assert.equal(transaction.input.TransactItems?.length, 2);
  assert.match(JSON.stringify(transaction.input), /deletion_state/);
  assert.match(JSON.stringify(transaction.input), /deleted/);
});
