/** MON-18: successful secret reads are cached, using unambiguous identifiers. */
import assert from "node:assert/strict";
import test from "node:test";
import { createBillingSecretReader } from "../src/billing/secrets.js";

test("MON-18 names and complete ARNs pass through; five-minute cache expires per secret", async () => {
  let now = 0;
  const calls: string[] = [];
  const read = createBillingSecretReader(
    async (id) => {
      calls.push(id);
      return `value-${calls.length}`;
    },
    () => now,
  );
  const name = "foloo/dev/stripe-api-key";
  const arn =
    "arn:aws:secretsmanager:us-east-1:111111111111:secret:foloo/dev/stripe-webhook-signing-AbCd12";
  assert.equal(await read(name), "value-1");
  assert.equal(await read(arn), "value-2");
  now = 299999;
  assert.equal(await read(name), "value-1");
  now = 300000;
  assert.equal(await read(name), "value-3");
  assert.deepEqual(calls, [name, arn, name]);
});

test("MON-18 failed or empty reads never poison secret cache", async () => {
  let calls = 0;
  const read = createBillingSecretReader(async () => {
    calls++;
    if (calls === 1) throw Error("private");
    return calls === 2 ? undefined : "valid";
  });
  await assert.rejects(() => read(undefined), /Billing is not configured/);
  await assert.rejects(() => read("name"), /Billing is not configured/);
  await assert.rejects(() => read("name"), /Billing is not configured/);
  assert.equal(await read("name"), "valid");
  assert.equal(await read("name"), "valid");
  assert.equal(calls, 3);
});
