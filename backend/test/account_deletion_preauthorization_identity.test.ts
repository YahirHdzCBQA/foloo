/** Regression coverage for verified, versioned deletion selector derivation. */

import assert from "node:assert/strict";
import test from "node:test";

import { GenerateMacCommand } from "@aws-sdk/client-kms";
import { InvokeCommand } from "@aws-sdk/client-lambda";

import {
  entitlementHmacKeysFromEnvironment,
  LambdaKmsDeletionPreauthorizationIdentity,
} from "../src/account_deletion/preauthorization_erasure_identity.js";

const subject = "subject-owner";
const email = "owner@example.test";

function lambdaResponse(overrides: Record<string, unknown> = {}) {
  return {
    async send(command: unknown) {
      assert.ok(command instanceof InvokeCommand);
      assert.deepEqual(
        JSON.parse(
          Buffer.from(command.input.Payload! as Uint8Array).toString("utf8"),
        ),
        { subject },
      );
      return {
        Payload: Buffer.from(
          JSON.stringify({
            ok: true,
            subject,
            email,
            emailVerified: true,
            ...overrides,
          }),
        ),
      };
    },
  };
}

test("MON-21 derives current and retained HMAC selectors for one verified subject", async () => {
  const keyIds: string[] = [];
  const kms = {
    async send(command: unknown) {
      assert.ok(command instanceof GenerateMacCommand);
      keyIds.push(command.input.KeyId!);
      return {
        Mac: new Uint8Array(32).fill(keyIds.length),
      };
    },
  };
  const resolver = new LambdaKmsDeletionPreauthorizationIdentity(
    lambdaResponse(),
    "private-resolver",
    kms,
    [
      { keyArn: "arn:current", keyVersion: "v2" },
      { keyArn: "arn:previous", keyVersion: "v1" },
    ],
  );
  const selectors = await resolver.selectorsForOwner(subject);
  assert.deepEqual(
    selectors.map(({ keyVersion }) => keyVersion),
    ["v2", "v1"],
  );
  assert.deepEqual(keyIds, ["arn:current", "arn:previous"]);
  assert.equal(
    selectors.every(({ digest }) => digest.length === 43),
    true,
  );
});

test("MON-21 rejects divergent, unverified, or unavailable Cognito identities", async () => {
  const kms = {
    async send() {
      return { Mac: new Uint8Array(32) };
    },
  };
  for (const response of [
    { subject: "other-subject" },
    { emailVerified: false },
    { ok: false },
  ]) {
    const resolver = new LambdaKmsDeletionPreauthorizationIdentity(
      lambdaResponse(response),
      "private-resolver",
      kms,
      [{ keyArn: "arn:key", keyVersion: "v1" }],
    );
    await assert.rejects(
      resolver.selectorsForOwner(subject),
      /identity verification failed/u,
    );
  }
  const unavailable = new LambdaKmsDeletionPreauthorizationIdentity(
    {
      async send() {
        throw new Error(`sensitive:${email}`);
      },
    },
    "private-resolver",
    kms,
    [{ keyArn: "arn:key", keyVersion: "v1" }],
  );
  await assert.rejects(unavailable.selectorsForOwner(subject), (error) => {
    assert.equal((error as Error).message.includes(email), false);
    return true;
  });
});

test("MON-21 fails closed when KMS cannot derive a selector", async () => {
  const resolver = new LambdaKmsDeletionPreauthorizationIdentity(
    lambdaResponse(),
    "private-resolver",
    {
      async send() {
        throw new Error("synthetic KMS failure");
      },
    },
    [{ keyArn: "arn:key", keyVersion: "v1" }],
  );
  await assert.rejects(
    resolver.selectorsForOwner(subject),
    /identity verification failed/u,
  );
});

test("MON-21 key rotation configuration is bounded and version-unique", () => {
  assert.deepEqual(
    entitlementHmacKeysFromEnvironment(
      "arn:current",
      "v2",
      JSON.stringify([{ keyArn: "arn:previous", keyVersion: "v1" }]),
    ),
    [
      { keyArn: "arn:current", keyVersion: "v2" },
      { keyArn: "arn:previous", keyVersion: "v1" },
    ],
  );
  assert.throws(
    () =>
      new LambdaKmsDeletionPreauthorizationIdentity(
        lambdaResponse(),
        "private-resolver",
        {
          async send() {
            return { Mac: new Uint8Array(32) };
          },
        },
        [
          { keyArn: "arn:a", keyVersion: "v1" },
          { keyArn: "arn:b", keyVersion: "v1" },
        ],
      ),
    /must be unique/u,
  );
});
