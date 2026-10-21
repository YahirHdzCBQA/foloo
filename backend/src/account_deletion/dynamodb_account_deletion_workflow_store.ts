/** Durable DynamoDB store for Account Deletion requests and receipt indexes. */

import {
  GetItemCommand,
  TransactWriteItemsCommand,
  type AttributeValue,
  type DynamoDBClient,
} from "@aws-sdk/client-dynamodb";

import type {
  AccountDeletionRecord,
  AccountDeletionWorkflowStore,
  DeletionStatus,
  SubscriptionSummary,
} from "./account_deletion_workflow.js";
import type {
  AccountDeletionBarrierReference,
  RegistrationLedgerKey,
  SubjectLedgerKey,
} from "./account_deletion_ledger.js";

type Item = Record<string, AttributeValue>;

export class DynamoAccountDeletionWorkflowStore implements AccountDeletionWorkflowStore {
  constructor(
    private readonly client: DynamoDBClient,
    private readonly tableName: string,
  ) {
    if (!tableName.trim()) throw new Error("Workflow table name is required.");
  }

  async findCurrent(ownerKey: string): Promise<AccountDeletionRecord | null> {
    const pointer = await this.get(`OWNER#${ownerKey}`);
    const requestId = pointer?.request_id?.S;
    return requestId ? this.findByRequestId(requestId) : null;
  }

  async findByRequestId(
    requestId: string,
  ): Promise<AccountDeletionRecord | null> {
    const item = await this.get(requestKey(requestId));
    return item ? decodeRecord(item) : null;
  }

  async findByReceiptHash(
    receiptHash: string,
  ): Promise<AccountDeletionRecord | null> {
    const pointer = await this.get(`RECEIPT#${receiptHash}`);
    const requestId = pointer?.request_id?.S;
    return requestId ? this.findByRequestId(requestId) : null;
  }

  async createPreflight(
    record: AccountDeletionRecord,
  ): Promise<AccountDeletionRecord> {
    const current = await this.findCurrent(record.ownerKey);
    if (current?.idempotencyKey === record.idempotencyKey) return current;
    await this.client.send(
      new TransactWriteItemsCommand({
        TransactItems: [
          put(
            this.tableName,
            recordKey(record),
            encodeRecord(record),
            "attribute_not_exists(pk)",
          ),
          put(
            this.tableName,
            `OWNER#${record.ownerKey}`,
            pointer("owner_current", record.requestId),
          ),
        ],
      }),
    );
    return record;
  }

  async update(record: AccountDeletionRecord): Promise<AccountDeletionRecord> {
    const items = [
      put(this.tableName, recordKey(record), encodeRecord(record)),
      put(
        this.tableName,
        `OWNER#${record.ownerKey}`,
        pointer("owner_current", record.requestId),
      ),
    ];
    if (record.receiptHash) {
      items.push(
        put(
          this.tableName,
          `RECEIPT#${record.receiptHash}`,
          pointer("receipt_index", record.requestId, record.receiptExpiresAt),
        ),
      );
    }
    await this.client.send(
      new TransactWriteItemsCommand({ TransactItems: items }),
    );
    return record;
  }

  private async get(pk: string): Promise<Item | undefined> {
    const result = await this.client.send(
      new GetItemCommand({
        TableName: this.tableName,
        Key: { pk: { S: pk } },
        ConsistentRead: true,
      }),
    );
    return result.Item;
  }
}

function requestKey(requestId: string) {
  if (!/^[0-9a-f-]{36}$/iu.test(requestId))
    throw new Error("Invalid request id.");
  return `WORKFLOW#${requestId}`;
}

function recordKey(record: AccountDeletionRecord) {
  return requestKey(record.requestId);
}

function put(
  tableName: string,
  pk: string,
  values: Item,
  conditionExpression?: string,
) {
  return {
    Put: {
      TableName: tableName,
      Item: { pk: { S: pk }, ...values },
      ...(conditionExpression
        ? { ConditionExpression: conditionExpression }
        : {}),
    },
  };
}

function pointer(
  type: string,
  requestId: string,
  expiresAt?: Date | null,
): Item {
  return {
    entity_type: { S: type },
    request_id: { S: requestId },
    ...(expiresAt
      ? { expires_at: { N: String(Math.ceil(expiresAt.getTime() / 1000)) } }
      : {}),
  };
}

function encodeRecord(record: AccountDeletionRecord): Item {
  return {
    entity_type: { S: "workflow_request" },
    request_id: { S: record.requestId },
    owner_key: { S: record.ownerKey },
    idempotency_key: { S: record.idempotencyKey },
    locale: { S: record.locale },
    requested_export: { BOOL: record.requestedExport },
    status: { S: record.status },
    created_at: { S: record.createdAt.toISOString() },
    expires_at_iso: { S: record.expiresAt.toISOString() },
    accepted_at: nullableDate(record.acceptedAt),
    updated_at: { S: record.updatedAt.toISOString() },
    completed_at: nullableDate(record.completedAt),
    receipt_hash: nullableString(record.receiptHash),
    receipt_expires_at: nullableDate(record.receiptExpiresAt),
    support_code: nullableString(record.supportCode),
    barrier: record.barrier
      ? {
          M: {
            deletion_id: { S: record.barrier.deletionId },
            subject_key: { S: record.barrier.subjectKey },
            registration_key: { S: record.barrier.registrationKey },
          },
        }
      : { NULL: true },
    subscription: { M: encodeSubscription(record.subscription) },
  };
}

function encodeSubscription(value: SubscriptionSummary): Item {
  return {
    status: { S: value.status },
    cancellation_required: { BOOL: value.cancellationRequired },
    plan_display_name: nullableString(value.planDisplayName),
    current_period_end: nullableDate(value.currentPeriodEnd),
  };
}

function decodeRecord(item: Item): AccountDeletionRecord {
  const subscription = requiredMap(item, "subscription");
  const barrierValue = item.barrier?.M;
  const barrier: AccountDeletionBarrierReference | null = barrierValue
    ? {
        deletionId: requiredString(barrierValue, "deletion_id"),
        subjectKey: requiredString(
          barrierValue,
          "subject_key",
        ) as SubjectLedgerKey,
        registrationKey: requiredString(
          barrierValue,
          "registration_key",
        ) as RegistrationLedgerKey,
      }
    : null;
  return {
    requestId: requiredString(item, "request_id"),
    ownerKey: requiredString(item, "owner_key"),
    idempotencyKey: requiredString(item, "idempotency_key"),
    locale: requiredString(item, "locale") === "en" ? "en" : "es",
    requestedExport: item.requested_export?.BOOL === true,
    status: requiredString(item, "status") as DeletionStatus,
    createdAt: requiredDate(item, "created_at"),
    expiresAt: requiredDate(item, "expires_at_iso"),
    acceptedAt: optionalDate(item, "accepted_at"),
    updatedAt: requiredDate(item, "updated_at"),
    completedAt: optionalDate(item, "completed_at"),
    receiptHash: optionalString(item, "receipt_hash"),
    receiptExpiresAt: optionalDate(item, "receipt_expires_at"),
    supportCode: optionalString(item, "support_code"),
    barrier,
    subscription: {
      status: requiredString(
        subscription,
        "status",
      ) as SubscriptionSummary["status"],
      cancellationRequired: subscription.cancellation_required?.BOOL === true,
      planDisplayName: optionalString(subscription, "plan_display_name"),
      currentPeriodEnd: optionalDate(subscription, "current_period_end"),
    },
  };
}

function nullableString(value: string | null): AttributeValue {
  return value === null ? { NULL: true } : { S: value };
}
function nullableDate(value: Date | null): AttributeValue {
  return value === null ? { NULL: true } : { S: value.toISOString() };
}
function requiredString(item: Item, key: string): string {
  const value = item[key]?.S;
  if (!value) throw new Error(`Workflow item is missing ${key}.`);
  return value;
}
function optionalString(item: Item, key: string): string | null {
  return item[key]?.NULL ? null : (item[key]?.S ?? null);
}
function requiredDate(item: Item, key: string): Date {
  const value = new Date(requiredString(item, key));
  if (!Number.isFinite(value.getTime())) throw new Error(`Invalid ${key}.`);
  return value;
}
function optionalDate(item: Item, key: string): Date | null {
  const value = optionalString(item, key);
  return value === null ? null : new Date(value);
}
function requiredMap(item: Item, key: string): Item {
  const value = item[key]?.M;
  if (!value) throw new Error(`Workflow item is missing ${key}.`);
  return value;
}
