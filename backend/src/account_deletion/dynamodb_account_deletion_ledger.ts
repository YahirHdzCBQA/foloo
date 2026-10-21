/**
 * DynamoDB adapter for the isolated Account Deletion ledger contract.
 * The table stores only versioned pseudonyms and durable workflow metadata;
 * deployment and runtime wiring are intentionally outside this module.
 */

import {
  BatchGetItemCommand,
  GetItemCommand,
  TransactWriteItemsCommand,
  TransactionCanceledException,
  type AttributeValue,
  type DynamoDBClient,
} from "@aws-sdk/client-dynamodb";

import {
  AccountDeletionLedgerConflictError,
  type AcceptAccountDeletionBarrier,
  type AccountDeletionBarrierReference,
  type AccountDeletionLedger,
  type RegistrationBlocker,
  type RegistrationLedgerKey,
  type SubjectLedgerKey,
  type SubjectTombstone,
} from "./account_deletion_ledger.js";

const partitionKey = "pk";

type DynamoItem = Record<string, AttributeValue>;

export class DynamoAccountDeletionLedger implements AccountDeletionLedger {
  constructor(
    private readonly client: DynamoDBClient,
    private readonly tableName: string,
  ) {
    if (tableName.trim().length === 0) {
      throw new Error("Account deletion ledger table name is required.");
    }
  }

  async findSubjectTombstones(
    keys: readonly SubjectLedgerKey[],
  ): Promise<readonly SubjectTombstone[]> {
    const items = await this.batchGet(keys);
    return items.map(decodeSubjectTombstone);
  }

  async findRegistrationBlockers(
    keys: readonly RegistrationLedgerKey[],
  ): Promise<readonly RegistrationBlocker[]> {
    const items = await this.batchGet(keys);
    return items.map(decodeRegistrationBlocker);
  }

  async acceptBarrier(
    input: AcceptAccountDeletionBarrier,
  ): Promise<AccountDeletionBarrierReference> {
    validateBarrierInput(input);
    const requestKey = deletionRequestKey(input.reference.deletionId);
    const existing = await this.getRequest(requestKey);
    if (existing) return assertIdempotent(existing, input.reference);

    const acceptedAt = input.acceptedAt.toISOString();
    const blockedUntil = input.blockedUntil.getTime();
    try {
      await this.client.send(
        new TransactWriteItemsCommand({
          TransactItems: [
            {
              Put: {
                TableName: this.tableName,
                Item: {
                  pk: { S: requestKey },
                  entity_type: { S: "deletion_request" },
                  deletion_id: { S: input.reference.deletionId },
                  deletion_state: { S: "pending" },
                  subject_key: { S: input.reference.subjectKey },
                  registration_key: { S: input.reference.registrationKey },
                  created_at: { S: acceptedAt },
                  updated_at: { S: acceptedAt },
                },
                ConditionExpression: "attribute_not_exists(#pk)",
                ExpressionAttributeNames: { "#pk": partitionKey },
              },
            },
            {
              Put: {
                TableName: this.tableName,
                Item: {
                  pk: { S: input.reference.subjectKey },
                  entity_type: { S: "subject_tombstone" },
                  deletion_id: { S: input.reference.deletionId },
                  deletion_state: { S: "pending" },
                  created_at: { S: acceptedAt },
                  updated_at: { S: acceptedAt },
                },
                ConditionExpression: "attribute_not_exists(#pk)",
                ExpressionAttributeNames: { "#pk": partitionKey },
              },
            },
            {
              Put: {
                TableName: this.tableName,
                Item: {
                  pk: { S: input.reference.registrationKey },
                  entity_type: { S: "registration_blocker" },
                  deletion_id: { S: input.reference.deletionId },
                  blocked_until: { N: String(blockedUntil) },
                  expires_at: {
                    N: String(Math.ceil(input.blockedUntil.getTime() / 1000)),
                  },
                  created_at: { S: acceptedAt },
                },
                ConditionExpression:
                  "attribute_not_exists(#pk) OR #blocked_until <= :accepted_at",
                ExpressionAttributeNames: {
                  "#pk": partitionKey,
                  "#blocked_until": "blocked_until",
                },
                ExpressionAttributeValues: {
                  ":accepted_at": {
                    N: String(input.acceptedAt.getTime()),
                  },
                },
              },
            },
          ],
        }),
      );
      return input.reference;
    } catch (error) {
      if (!hasConditionalFailure(error)) throw error;
      const winner = await this.getRequest(requestKey);
      if (winner) return assertIdempotent(winner, input.reference);
      throw new AccountDeletionLedgerConflictError();
    }
  }

  async markDeleted(
    reference: AccountDeletionBarrierReference,
    completedAt: Date,
  ): Promise<void> {
    assertValidDate(completedAt);
    const updatedAt = completedAt.toISOString();
    const values = {
      ":deletion_id": { S: reference.deletionId },
      ":pending": { S: "pending" },
      ":deleted": { S: "deleted" },
      ":updated_at": { S: updatedAt },
    } satisfies Record<string, AttributeValue>;
    try {
      await this.client.send(
        new TransactWriteItemsCommand({
          TransactItems: [
            {
              Update: {
                TableName: this.tableName,
                Key: { pk: { S: deletionRequestKey(reference.deletionId) } },
                UpdateExpression:
                  "SET #state = :deleted, #updated_at = :updated_at",
                ConditionExpression:
                  "#deletion_id = :deletion_id AND #subject_key = :subject_key AND #registration_key = :registration_key AND (#state = :pending OR #state = :deleted)",
                ExpressionAttributeNames: {
                  "#deletion_id": "deletion_id",
                  "#registration_key": "registration_key",
                  "#state": "deletion_state",
                  "#subject_key": "subject_key",
                  "#updated_at": "updated_at",
                },
                ExpressionAttributeValues: {
                  ...values,
                  ":registration_key": { S: reference.registrationKey },
                  ":subject_key": { S: reference.subjectKey },
                },
              },
            },
            {
              Update: {
                TableName: this.tableName,
                Key: { pk: { S: reference.subjectKey } },
                UpdateExpression:
                  "SET #state = :deleted, #updated_at = :updated_at",
                ConditionExpression:
                  "#deletion_id = :deletion_id AND (#state = :pending OR #state = :deleted)",
                ExpressionAttributeNames: {
                  "#deletion_id": "deletion_id",
                  "#state": "deletion_state",
                  "#updated_at": "updated_at",
                },
                ExpressionAttributeValues: values,
              },
            },
          ],
        }),
      );
    } catch (error) {
      if (hasConditionalFailure(error)) {
        throw new AccountDeletionLedgerConflictError();
      }
      throw error;
    }
  }

  private async getRequest(key: string): Promise<DynamoItem | undefined> {
    const response = await this.client.send(
      new GetItemCommand({
        TableName: this.tableName,
        Key: { pk: { S: key } },
        ConsistentRead: true,
      }),
    );
    return response.Item;
  }

  private async batchGet(keys: readonly string[]): Promise<DynamoItem[]> {
    const unique = [...new Set(keys)];
    if (unique.length === 0) return [];
    const items: DynamoItem[] = [];
    for (let offset = 0; offset < unique.length; offset += 100) {
      const chunk = unique.slice(offset, offset + 100);
      const response = await this.client.send(
        new BatchGetItemCommand({
          RequestItems: {
            [this.tableName]: {
              ConsistentRead: true,
              Keys: chunk.map((key) => ({ pk: { S: key } })),
            },
          },
        }),
      );
      const unprocessed = response.UnprocessedKeys?.[this.tableName]?.Keys;
      if (unprocessed && unprocessed.length > 0) {
        throw new Error("Account deletion ledger read was incomplete.");
      }
      items.push(...(response.Responses?.[this.tableName] ?? []));
    }
    return items;
  }
}

function deletionRequestKey(deletionId: string): string {
  if (!/^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$/u.test(deletionId)) {
    throw new Error("Account deletion request identifier is invalid.");
  }
  return `REQ#${deletionId}`;
}

function validateBarrierInput(input: AcceptAccountDeletionBarrier): void {
  deletionRequestKey(input.reference.deletionId);
  assertValidDate(input.acceptedAt);
  assertValidDate(input.blockedUntil);
  if (input.blockedUntil.getTime() <= input.acceptedAt.getTime()) {
    throw new Error("Registration block must end after acceptance.");
  }
}

function assertValidDate(value: Date): void {
  if (!Number.isFinite(value.getTime()))
    throw new Error("Ledger date is invalid.");
}

function assertIdempotent(
  item: DynamoItem,
  expected: AccountDeletionBarrierReference,
): AccountDeletionBarrierReference {
  if (
    readString(item, "entity_type") !== "deletion_request" ||
    readString(item, "deletion_id") !== expected.deletionId ||
    readString(item, "subject_key") !== expected.subjectKey ||
    readString(item, "registration_key") !== expected.registrationKey
  ) {
    throw new AccountDeletionLedgerConflictError();
  }
  return expected;
}

function decodeSubjectTombstone(item: DynamoItem): SubjectTombstone {
  const state = readString(item, "deletion_state");
  if (readString(item, "entity_type") !== "subject_tombstone") {
    throw new Error("Ledger subject item has an invalid entity type.");
  }
  if (state !== "pending" && state !== "deleted") {
    throw new Error("Ledger subject item has an invalid state.");
  }
  return {
    key: readString(item, "pk") as SubjectLedgerKey,
    deletionId: readString(item, "deletion_id"),
    state,
    createdAt: readDate(item, "created_at"),
    updatedAt: readDate(item, "updated_at"),
  };
}

function decodeRegistrationBlocker(item: DynamoItem): RegistrationBlocker {
  if (readString(item, "entity_type") !== "registration_blocker") {
    throw new Error("Ledger registration item has an invalid entity type.");
  }
  return {
    key: readString(item, "pk") as RegistrationLedgerKey,
    deletionId: readString(item, "deletion_id"),
    blockedUntil: new Date(readNumber(item, "blocked_until")),
    createdAt: readDate(item, "created_at"),
  };
}

function readString(item: DynamoItem, name: string): string {
  const value = item[name]?.S;
  if (!value) throw new Error(`Ledger item is missing ${name}.`);
  return value;
}

function readNumber(item: DynamoItem, name: string): number {
  const value = Number(item[name]?.N);
  if (!Number.isFinite(value))
    throw new Error(`Ledger item has invalid ${name}.`);
  return value;
}

function readDate(item: DynamoItem, name: string): Date {
  const value = new Date(readString(item, name));
  assertValidDate(value);
  return value;
}

function hasConditionalFailure(error: unknown): boolean {
  return (
    error instanceof TransactionCanceledException &&
    (error.CancellationReasons ?? []).some(
      (reason) => reason.Code === "ConditionalCheckFailed",
    )
  );
}
