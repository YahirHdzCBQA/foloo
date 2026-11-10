/** FL-021 HMAC selectors are canonical, domain-separated, and PII-free. */

import assert from "node:assert/strict";
import test from "node:test";

import { KmsVerifiedEmailSelector } from "../src/entitlements/preauthorization_selector.js";

test("verified emails use one canonical domain-separated KMS message", async () => {
  const messages: Uint8Array[] = [];
  const selector = new KmsVerifiedEmailSelector(
    {
      send: async (command: { input: { Message?: Uint8Array } }) => {
        messages.push(command.input.Message!);
        return { Mac: new Uint8Array(32).fill(7) };
      },
    } as never,
    "arn:aws:kms:us-east-1:123456789012:key/synthetic",
  );
  const upper = await selector.select("Person@EXAMPLE.test");
  const lower = await selector.select("person@example.test");
  assert.deepEqual(upper, lower);
  const message = new TextDecoder().decode(messages[0]);
  assert.match(message, /^foloo\0fl021\0entitlement-preauthorization\0/u);
  assert.match(message, /person@example\.test$/u);
  assert.equal(upper.digest.length, 43);
});

test("Apple Private Relay never matches a different approved real email", async () => {
  const selector = new KmsVerifiedEmailSelector(
    {
      send: async (command: { input: { Message?: Uint8Array } }) => ({
        Mac: new Uint8Array(
          await crypto.subtle.digest("SHA-256", command.input.Message!),
        ),
      }),
    } as never,
    "arn:aws:kms:us-east-1:123456789012:key/synthetic",
  );
  const real = await selector.select("approved@example.test");
  const relay = await selector.select("relay@privaterelay.appleid.com");
  assert.notEqual(real.digest, relay.digest);
});
