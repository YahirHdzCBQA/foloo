/** AUT-18/RNF-09: the intent binding survives Dynamo serialization. No AWS calls. */
import test from "node:test";
import assert from "node:assert/strict";
import type { DynamoDBClient, AttributeValue } from "@aws-sdk/client-dynamodb";
import { DynamoWebSessionStore } from "../src/web_auth/dynamodb_web_session_store.js";
test("AUT-18 Dynamo preserves reauth binding and rejects partial records", async () => {
  let item: Record<string, AttributeValue> = {};
  const client = {
    send: async (command: {
      constructor: { name: string };
      input: { Item?: Record<string, AttributeValue> };
    }) => {
      if (command.constructor.name === "PutItemCommand") {
        item = command.input.Item!;
        return {};
      }
      return { Item: item };
    },
  } as unknown as DynamoDBClient;
  const store = new DynamoWebSessionStore(client, "synthetic-table");
  const record = {
    key: "OAUTH#synthetic-hash",
    stateHash: "synthetic-state-hash",
    encryptedVerifier: Uint8Array.from([1, 2, 3]),
    createdAtMs: 1000,
    expiresAtMs: 5000,
    expiresAtEpochSeconds: 5,
    version: 1,
    reauthSessionKey: "SESSION#synthetic-hash",
    reauthSubjectHash: "synthetic-subject-hash",
    reauthProvider: "srp" as const,
  };
  await store.createOAuthTransaction(record);
  assert.deepEqual(await store.readOAuthTransaction(record.key), record);
  delete item.reauth_session_key;
  await assert.rejects(store.readOAuthTransaction(record.key));
});
