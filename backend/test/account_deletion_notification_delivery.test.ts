/** Durable SES delivery deduplication coverage without contacting AWS. */

import assert from "node:assert/strict";
import test from "node:test";

import type { DynamoDBClient } from "@aws-sdk/client-dynamodb";

import { DynamoAccountDeletionNotificationDelivery } from "../src/account_deletion/account_deletion_notification_delivery.js";

const requestId = "22222222-2222-4222-8222-222222222222";

function conditionalFailure(): Error {
  const error = new Error("conditional");
  error.name = "ConditionalCheckFailedException";
  return error;
}

function client() {
  let item:
    | {
        state: string;
        token?: string;
        leaseUntil: string;
      }
    | undefined;
  return {
    dynamo: {
      async send(command: unknown) {
        const value = command as {
          constructor: { name: string };
          input: Record<string, unknown>;
        };
        if (value.constructor.name === "PutItemCommand") {
          if (item) throw conditionalFailure();
          const inputItem = value.input.Item as Record<string, { S?: string }>;
          item = {
            state: "sending",
            token: inputItem.token?.S,
            leaseUntil: inputItem.lease_until?.S ?? "",
          };
          return {};
        }
        if (value.constructor.name === "GetItemCommand") {
          return {
            Item: item
              ? {
                  state: { S: item.state },
                  token: item.token ? { S: item.token } : undefined,
                  lease_until: { S: item.leaseUntil },
                }
              : undefined,
          };
        }
        if (value.constructor.name === "UpdateItemCommand") {
          const values = value.input.ExpressionAttributeValues as Record<
            string,
            { S?: string }
          >;
          if (String(value.input.UpdateExpression).includes(":sent")) {
            if (!item || item.token !== values[":token"]?.S)
              throw conditionalFailure();
            item = { ...item, state: "sent", token: undefined };
            return {};
          }
          if (!item || item.leaseUntil >= (values[":now"]?.S ?? ""))
            throw conditionalFailure();
          item = {
            state: "sending",
            token: values[":token"]?.S,
            leaseUntil: values[":lease_until"]?.S ?? "",
          };
          return {};
        }
        if (value.constructor.name === "DeleteItemCommand") {
          const values = value.input.ExpressionAttributeValues as Record<
            string,
            { S?: string }
          >;
          if (!item || item.token !== values[":token"]?.S)
            throw conditionalFailure();
          item = undefined;
          return {};
        }
        throw new Error("Unexpected DynamoDB command.");
      },
    } as unknown as DynamoDBClient,
  };
}

test("INF-19 duplicate SES events result in one durable delivery", async () => {
  const fake = client();
  const delivery = new DynamoAccountDeletionNotificationDelivery(
    fake.dynamo,
    "synthetic",
    { now: () => new Date("2035-01-01T00:00:00.000Z") },
  );
  const claim = await delivery.claim(requestId, "request_accepted");
  assert.equal(claim.state, "claimed");
  if (claim.state !== "claimed") return;
  await delivery.markSent(requestId, "request_accepted", claim.token);
  assert.deepEqual(await delivery.claim(requestId, "request_accepted"), {
    state: "already_sent",
  });
});

test("RNF-10 concurrent SES claims fail closed while a lease is active", async () => {
  const fake = client();
  const delivery = new DynamoAccountDeletionNotificationDelivery(
    fake.dynamo,
    "synthetic",
    { now: () => new Date("2035-01-01T00:00:00.000Z") },
  );
  await delivery.claim(requestId, "deletion_completed");
  await assert.rejects(
    delivery.claim(requestId, "deletion_completed"),
    /already in flight/u,
  );
});

test("INF-19 SES failure releases the claim for bounded Lambda retry", async () => {
  const fake = client();
  const delivery = new DynamoAccountDeletionNotificationDelivery(
    fake.dynamo,
    "synthetic",
  );
  const first = await delivery.claim(requestId, "request_accepted");
  assert.equal(first.state, "claimed");
  if (first.state !== "claimed") return;
  await delivery.release(requestId, "request_accepted", first.token);
  assert.equal(
    (await delivery.claim(requestId, "request_accepted")).state,
    "claimed",
  );
});
