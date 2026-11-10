/** Private entitlement Lambda contracts reject spoofing and redact failures. */

import assert from "node:assert/strict";
import test from "node:test";

import { createAdministrativeEntitlementHandler } from "../src/entitlements/administrative_entitlement_lambda.js";
import { createAdministrativeIdentityHandler } from "../src/entitlements/administrative_entitlement_identity_lambda.js";

const operatorRole =
  "arn:aws:iam::123456789012:role/foloo-entitlement-operator";

test("status, grant, and revoke use the private service contract", async () => {
  const received: unknown[] = [];
  const handler = createAdministrativeEntitlementHandler(async (command) => {
    received.push(command);
    return {
      action:
        command.action === "status"
          ? "status"
          : command.action === "grant"
            ? "granted"
            : "revoked",
      entitlement: command.action === "revoke" ? "FREE" : "PRO",
    } as const;
  }, operatorRole);

  assert.equal(
    (await handler({ action: "status", email: "qa@example.test" })).ok,
    true,
  );
  assert.equal(
    (
      await handler({
        action: "grant",
        email: "qa@example.test",
        reason: "Approved QA access",
      })
    ).ok,
    true,
  );
  assert.equal(
    (
      await handler({
        action: "revoke",
        email: "qa@example.test",
        reason: "QA access ended",
      })
    ).ok,
    true,
  );
  assert.deepEqual(received, [
    { action: "status", email: "qa@example.test" },
    {
      action: "grant",
      email: "qa@example.test",
      reason: "Approved QA access",
      actor: operatorRole,
    },
    {
      action: "revoke",
      email: "qa@example.test",
      reason: "QA access ended",
      actor: operatorRole,
    },
  ]);
});

test("preauthorization operations remain IAM-only and operator-attributed", async () => {
  const received: unknown[] = [];
  const handler = createAdministrativeEntitlementHandler(async (command) => {
    received.push(command);
    return {
      action:
        command.action === "preauthorization-status"
          ? "preauthorization-status"
          : command.action === "preauthorize"
            ? "preauthorized"
            : "revoked",
      status:
        command.action === "revoke-preauthorization" ? "revoked" : "active",
    } as const;
  }, operatorRole);
  assert.equal(
    (
      await handler({
        action: "preauthorize",
        email: "future@example.test",
        reason: "Approved QA inventory",
      })
    ).ok,
    true,
  );
  assert.equal(
    (
      await handler({
        action: "preauthorization-status",
        email: "future@example.test",
      })
    ).ok,
    true,
  );
  assert.equal(
    (
      await handler({
        action: "revoke-preauthorization",
        email: "future@example.test",
        reason: "QA authorization ended",
      })
    ).ok,
    true,
  );
  assert.deepEqual(received, [
    {
      action: "preauthorize",
      email: "future@example.test",
      reason: "Approved QA inventory",
      actor: operatorRole,
    },
    {
      action: "preauthorization-status",
      email: "future@example.test",
    },
    {
      action: "revoke-preauthorization",
      email: "future@example.test",
      reason: "QA authorization ended",
      actor: operatorRole,
    },
  ]);
});

test("caller cannot inject an actor or unsupported fields", async () => {
  let invoked = false;
  const handler = createAdministrativeEntitlementHandler(async () => {
    invoked = true;
    return { action: "granted", entitlement: "PRO" };
  }, operatorRole);
  const result = await handler({
    action: "grant",
    email: "qa@example.test",
    reason: "Attempt",
    actor: "untrusted",
  });
  assert.deepEqual(result, {
    ok: false,
    errorCode: "entitlement_operation_failed",
  });
  assert.equal(invoked, false);
});

test("service errors are fail-closed and do not expose details", async () => {
  const handler = createAdministrativeEntitlementHandler(async () => {
    throw new Error("private subject or database detail");
  }, operatorRole);
  assert.deepEqual(
    await handler({ action: "status", email: "qa@example.test" }),
    { ok: false, errorCode: "entitlement_operation_failed" },
  );
});

test("identity resolver returns only verified ownership evidence", async () => {
  const handler = createAdministrativeIdentityHandler(async () => ({
    subject: "verified-subject",
    email: "qa@example.test",
    emailVerified: true,
  }));
  assert.deepEqual(await handler({ email: "qa@example.test" }), {
    ok: true,
    subject: "verified-subject",
    email: "qa@example.test",
    emailVerified: true,
  });
});

test("identity resolver redacts lookup failures and rejects extra fields", async () => {
  const handler = createAdministrativeIdentityHandler(async () => {
    throw new Error("ambiguous user detail");
  });
  assert.deepEqual(await handler({ email: "qa@example.test" }), {
    ok: false,
    errorCode: "identity_not_verified",
  });
  assert.deepEqual(
    await handler({ email: "qa@example.test", subject: "spoofed" }),
    { ok: false, errorCode: "identity_not_verified" },
  );
});

test("identity resolver supports exact-sub worker lookups without client email", async () => {
  const handler = createAdministrativeIdentityHandler(
    async () => {
      throw new Error("email lookup not expected");
    },
    async (subject) => ({
      subject,
      email: "verified@example.test",
      emailVerified: true,
    }),
  );
  assert.deepEqual(await handler({ subject: "verified-subject" }), {
    ok: true,
    subject: "verified-subject",
    email: "verified@example.test",
    emailVerified: true,
  });
  assert.deepEqual(
    await handler({
      subject: "verified-subject",
      email: "untrusted@example.test",
    }),
    { ok: false, errorCode: "identity_not_verified" },
  );
});
