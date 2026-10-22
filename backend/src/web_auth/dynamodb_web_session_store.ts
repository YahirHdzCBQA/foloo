/**
 * Persists opaque web sessions and short-lived OAuth transactions in DynamoDB.
 * Raw session IDs, refresh tokens, access tokens and PKCE verifiers never
 * appear as keys or plaintext attributes.
 */

import {
  DeleteItemCommand,
  GetItemCommand,
  PutItemCommand,
  type AttributeValue,
  type DynamoDBClient,
} from "@aws-sdk/client-dynamodb";

import type {
  OAuthTransactionRecord,
  WebSessionRecord,
  WebSessionStore,
} from "./web_session.js";

type DynamoItem = Record<string, AttributeValue>;

export class DynamoWebSessionStore implements WebSessionStore {
  constructor(
    private readonly client: DynamoDBClient,
    private readonly tableName: string,
  ) {
    if (tableName.trim().length === 0) {
      throw new Error("Web session table name is required.");
    }
  }

  async createSession(record: WebSessionRecord): Promise<void> {
    await this.put(record.key, encodeSession(record));
  }

  async readSession(key: string): Promise<WebSessionRecord | undefined> {
    const item = await this.read(key);
    if (!item) return undefined;
    return decodeSession(item);
  }

  async replaceSession(
    record: WebSessionRecord,
    expectedVersion: number,
  ): Promise<boolean> {
    try {
      await this.client.send(
        new PutItemCommand({
          TableName: this.tableName,
          Item: encodeSession(record),
          ConditionExpression: "#version = :expected_version",
          ExpressionAttributeNames: { "#version": "version" },
          ExpressionAttributeValues: {
            ":expected_version": { N: String(expectedVersion) },
          },
        }),
      );
      return true;
    } catch (error) {
      if (isConditionalFailure(error)) return false;
      throw error;
    }
  }

  async createOAuthTransaction(record: OAuthTransactionRecord): Promise<void> {
    await this.put(record.key, encodeTransaction(record));
  }

  async readOAuthTransaction(
    key: string,
  ): Promise<OAuthTransactionRecord | undefined> {
    const item = await this.read(key);
    if (!item) return undefined;
    return decodeTransaction(item);
  }

  async consumeOAuthTransaction(
    key: string,
    expectedVersion: number,
  ): Promise<boolean> {
    try {
      await this.client.send(
        new DeleteItemCommand({
          TableName: this.tableName,
          Key: { pk: { S: key } },
          ConditionExpression: "#version = :expected_version",
          ExpressionAttributeNames: { "#version": "version" },
          ExpressionAttributeValues: {
            ":expected_version": { N: String(expectedVersion) },
          },
        }),
      );
      return true;
    } catch (error) {
      if (isConditionalFailure(error)) return false;
      throw error;
    }
  }

  private async put(key: string, item: DynamoItem): Promise<void> {
    try {
      await this.client.send(
        new PutItemCommand({
          TableName: this.tableName,
          Item: item,
          ConditionExpression: "attribute_not_exists(#pk)",
          ExpressionAttributeNames: { "#pk": "pk" },
        }),
      );
    } catch (error) {
      if (isConditionalFailure(error)) {
        throw new Error(`Web session key collision for ${key.slice(0, 8)}.`, {
          cause: error,
        });
      }
      throw error;
    }
  }

  private async read(key: string): Promise<DynamoItem | undefined> {
    const response = await this.client.send(
      new GetItemCommand({
        TableName: this.tableName,
        Key: { pk: { S: key } },
        ConsistentRead: true,
      }),
    );
    return response.Item;
  }
}

function encodeSession(record: WebSessionRecord): DynamoItem {
  return {
    pk: { S: record.key },
    entity_type: { S: "web_session" },
    subject_hash: { S: record.subjectHash },
    encrypted_refresh_token: { B: record.encryptedRefreshToken },
    encrypted_access_token: { B: record.encryptedAccessToken },
    encrypted_csrf_token: { B: record.encryptedCsrfToken },
    csrf_hash: { S: record.csrfHash },
    access_expires_at_ms: { N: String(record.accessExpiresAtMs) },
    authentication_time_ms: { N: String(record.authenticationTimeMs) },
    created_at_ms: { N: String(record.createdAtMs) },
    last_seen_at_ms: { N: String(record.lastSeenAtMs) },
    absolute_expires_at_ms: { N: String(record.absoluteExpiresAtMs) },
    expires_at: { N: String(record.expiresAtEpochSeconds) },
    version: { N: String(record.version) },
    session_state: { S: record.state },
  };
}

function decodeSession(item: DynamoItem): WebSessionRecord {
  if (readString(item, "entity_type") !== "web_session") {
    throw new Error("DynamoDB item is not a web session.");
  }
  const state = readString(item, "session_state");
  if (state !== "active" && state !== "revoked" && state !== "expired") {
    throw new Error("Web session state is invalid.");
  }
  return {
    key: readString(item, "pk"),
    subjectHash: readString(item, "subject_hash"),
    encryptedRefreshToken: readBinary(item, "encrypted_refresh_token"),
    encryptedAccessToken: readBinary(item, "encrypted_access_token"),
    encryptedCsrfToken: readBinary(item, "encrypted_csrf_token"),
    csrfHash: readString(item, "csrf_hash"),
    accessExpiresAtMs: readNumber(item, "access_expires_at_ms"),
    authenticationTimeMs: readNumber(item, "authentication_time_ms"),
    createdAtMs: readNumber(item, "created_at_ms"),
    lastSeenAtMs: readNumber(item, "last_seen_at_ms"),
    absoluteExpiresAtMs: readNumber(item, "absolute_expires_at_ms"),
    expiresAtEpochSeconds: readNumber(item, "expires_at"),
    version: readNumber(item, "version"),
    state,
  };
}

function encodeTransaction(record: OAuthTransactionRecord): DynamoItem {
  return {
    pk: { S: record.key },
    entity_type: { S: "oauth_transaction" },
    state_hash: { S: record.stateHash },
    encrypted_verifier: { B: record.encryptedVerifier },
    created_at_ms: { N: String(record.createdAtMs) },
    expires_at_ms: { N: String(record.expiresAtMs) },
    expires_at: { N: String(record.expiresAtEpochSeconds) },
    version: { N: String(record.version) },
  };
}

function decodeTransaction(item: DynamoItem): OAuthTransactionRecord {
  if (readString(item, "entity_type") !== "oauth_transaction") {
    throw new Error("DynamoDB item is not an OAuth transaction.");
  }
  return {
    key: readString(item, "pk"),
    stateHash: readString(item, "state_hash"),
    encryptedVerifier: readBinary(item, "encrypted_verifier"),
    createdAtMs: readNumber(item, "created_at_ms"),
    expiresAtMs: readNumber(item, "expires_at_ms"),
    expiresAtEpochSeconds: readNumber(item, "expires_at"),
    version: readNumber(item, "version"),
  };
}

function readString(item: DynamoItem, name: string): string {
  const value = item[name]?.S;
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`DynamoDB attribute ${name} is invalid.`);
  }
  return value;
}

function readBinary(item: DynamoItem, name: string): Uint8Array {
  const value = item[name]?.B;
  if (!value || value.byteLength === 0) {
    throw new Error(`DynamoDB attribute ${name} is invalid.`);
  }
  return Uint8Array.from(value);
}

function readNumber(item: DynamoItem, name: string): number {
  const value = Number(item[name]?.N);
  if (!Number.isSafeInteger(value)) {
    throw new Error(`DynamoDB attribute ${name} is invalid.`);
  }
  return value;
}

function isConditionalFailure(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "name" in error &&
    error.name === "ConditionalCheckFailedException"
  );
}
