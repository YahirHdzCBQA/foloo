/**
 * Durable, lease-based deduplication for Account Deletion transactional mail.
 * The receipt/status remains authoritative; this state only prevents duplicate
 * processing of repeated Lambda events (INF-19, RNF-09, RNF-10).
 */

import { randomUUID } from "node:crypto";

import {
  DeleteItemCommand,
  GetItemCommand,
  PutItemCommand,
  UpdateItemCommand,
  type DynamoDBClient,
} from "@aws-sdk/client-dynamodb";

export type AccountDeletionNotificationAction =
  "request_accepted" | "deletion_completed";

export type NotificationDeliveryClaim =
  | Readonly<{ state: "already_sent" }>
  | Readonly<{ state: "claimed"; token: string }>;

const leaseMs = 5 * 60 * 1000;

export class DynamoAccountDeletionNotificationDelivery {
  constructor(
    private readonly dynamo: DynamoDBClient,
    private readonly tableName: string,
    private readonly clock: { now(): Date } = { now: () => new Date() },
  ) {}

  async claim(
    requestId: string,
    action: AccountDeletionNotificationAction,
  ): Promise<NotificationDeliveryClaim> {
    const token = randomUUID();
    const now = this.clock.now();
    const leaseUntil = new Date(now.getTime() + leaseMs);
    const key = deliveryKey(requestId, action);
    try {
      await this.dynamo.send(
        new PutItemCommand({
          TableName: this.tableName,
          Item: {
            pk: { S: key },
            entity_type: { S: "notification_delivery" },
            request_id: { S: requestId },
            action: { S: action },
            state: { S: "sending" },
            token: { S: token },
            lease_until: { S: leaseUntil.toISOString() },
            created_at: { S: now.toISOString() },
          },
          ConditionExpression: "attribute_not_exists(pk)",
        }),
      );
      return { state: "claimed", token };
    } catch (error) {
      if (!conditionalFailure(error)) throw error;
    }

    const existing = await this.dynamo.send(
      new GetItemCommand({
        TableName: this.tableName,
        Key: { pk: { S: key } },
        ConsistentRead: true,
      }),
    );
    if (existing.Item?.state?.S === "sent") return { state: "already_sent" };
    try {
      await this.dynamo.send(
        new UpdateItemCommand({
          TableName: this.tableName,
          Key: { pk: { S: key } },
          UpdateExpression:
            "SET #token = :token, #lease_until = :lease_until, #updated_at = :now",
          ConditionExpression: "#state = :sending AND #lease_until < :now",
          ExpressionAttributeNames: {
            "#state": "state",
            "#token": "token",
            "#lease_until": "lease_until",
            "#updated_at": "updated_at",
          },
          ExpressionAttributeValues: {
            ":sending": { S: "sending" },
            ":token": { S: token },
            ":lease_until": { S: leaseUntil.toISOString() },
            ":now": { S: now.toISOString() },
          },
        }),
      );
      return { state: "claimed", token };
    } catch (error) {
      if (conditionalFailure(error)) {
        throw new Error("Account deletion notification is already in flight.", {
          cause: error,
        });
      }
      throw error;
    }
  }

  async markSent(
    requestId: string,
    action: AccountDeletionNotificationAction,
    token: string,
  ): Promise<void> {
    await this.dynamo.send(
      new UpdateItemCommand({
        TableName: this.tableName,
        Key: { pk: { S: deliveryKey(requestId, action) } },
        UpdateExpression: "SET #state = :sent, #sent_at = :now REMOVE #token",
        ConditionExpression: "#state = :sending AND #token = :token",
        ExpressionAttributeNames: {
          "#state": "state",
          "#sent_at": "sent_at",
          "#token": "token",
        },
        ExpressionAttributeValues: {
          ":sending": { S: "sending" },
          ":sent": { S: "sent" },
          ":token": { S: token },
          ":now": { S: this.clock.now().toISOString() },
        },
      }),
    );
  }

  async release(
    requestId: string,
    action: AccountDeletionNotificationAction,
    token: string,
  ): Promise<void> {
    try {
      await this.dynamo.send(
        new DeleteItemCommand({
          TableName: this.tableName,
          Key: { pk: { S: deliveryKey(requestId, action) } },
          ConditionExpression: "#state = :sending AND #token = :token",
          ExpressionAttributeNames: { "#state": "state", "#token": "token" },
          ExpressionAttributeValues: {
            ":sending": { S: "sending" },
            ":token": { S: token },
          },
        }),
      );
    } catch (error) {
      if (!conditionalFailure(error)) throw error;
    }
  }
}

function deliveryKey(
  requestId: string,
  action: AccountDeletionNotificationAction,
): string {
  if (!/^[0-9a-f-]{36}$/iu.test(requestId)) {
    throw new Error("Invalid request id.");
  }
  return `NOTIFICATION#${requestId}#${action}`;
}

function conditionalFailure(error: unknown): boolean {
  return (
    error instanceof Error && error.name === "ConditionalCheckFailedException"
  );
}
