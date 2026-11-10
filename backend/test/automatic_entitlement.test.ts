/** Queue and worker contracts preserve login availability and retry failures. */

import assert from "node:assert/strict";
import test from "node:test";

import {
  enqueueAutomaticEntitlementEvaluation,
  enqueueAfterVerifiedAuthentication,
  parseAutomaticEntitlementMessage,
} from "../src/entitlements/automatic_entitlement_enqueue.js";
import { createAutomaticEntitlementWorker } from "../src/entitlements/automatic_entitlement_worker_lambda.js";

test("enqueue publishes only a subject and random request ID", async () => {
  let input: Record<string, unknown> | undefined;
  await enqueueAutomaticEntitlementEvaluation(
    {
      send: async (command: { input: Record<string, unknown> }) => {
        input = command.input;
        return {};
      },
    } as never,
    "https://sqs.us-east-1.amazonaws.com/123/queue",
    "verified-subject",
  );
  assert.equal(
    input?.QueueUrl,
    "https://sqs.us-east-1.amazonaws.com/123/queue",
  );
  const body = JSON.parse(String(input?.MessageBody)) as Record<
    string,
    unknown
  >;
  assert.deepEqual(Object.keys(body).sort(), [
    "requestId",
    "subject",
    "version",
  ]);
  assert.equal(body.subject, "verified-subject");
  assert.doesNotMatch(JSON.stringify(body), /email|token|provider/iu);
});

test("parser rejects injected fields and malformed subjects", () => {
  assert.throws(() =>
    parseAutomaticEntitlementMessage(
      JSON.stringify({
        version: 1,
        requestId: "00000000-0000-4000-8000-000000000000",
        subject: "valid",
        email: "untrusted@example.test",
      }),
    ),
  );
  assert.throws(() =>
    parseAutomaticEntitlementMessage(
      JSON.stringify({
        version: 1,
        requestId: "00000000-0000-4000-8000-000000000000",
        subject: "invalid subject",
      }),
    ),
  );
});

test("login enqueue requires verified email and never propagates queue failure", async () => {
  const subjects: string[] = [];
  await enqueueAfterVerifiedAuthentication(
    { sub: "verified-subject", email_verified: "true" },
    async (subject) => {
      subjects.push(subject);
    },
  );
  await enqueueAfterVerifiedAuthentication(
    { sub: "unverified-subject", email_verified: "false" },
    async (subject) => {
      subjects.push(subject);
    },
  );
  let failures = 0;
  await enqueueAfterVerifiedAuthentication(
    { sub: "retry-subject", email_verified: "true" },
    async () => {
      throw new Error("queue unavailable");
    },
    () => {
      failures += 1;
    },
  );
  assert.deepEqual(subjects, ["verified-subject"]);
  assert.equal(failures, 1);
});

test("worker retries failed records and acknowledges successful duplicates", async () => {
  const attempts = new Map<string, number>();
  const worker = createAutomaticEntitlementWorker(async (subject) => {
    attempts.set(subject, (attempts.get(subject) ?? 0) + 1);
    if (subject === "retry-subject") throw new Error("transient");
  });
  const message = (subject: string) =>
    JSON.stringify({
      version: 1,
      requestId: crypto.randomUUID(),
      subject,
    });
  const result = await worker({
    Records: [
      { messageId: "ok", body: message("ok-subject") },
      { messageId: "retry", body: message("retry-subject") },
      { messageId: "duplicate", body: message("ok-subject") },
    ],
  } as never);
  assert.deepEqual(result, {
    batchItemFailures: [{ itemIdentifier: "retry" }],
  });
  assert.equal(attempts.get("ok-subject"), 2);
});
