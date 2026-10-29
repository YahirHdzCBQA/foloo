/** WEB-02 / AUT-10, RNF-09, E-14: synthetic inventory must never mutate or expose identity. */
import assert from "node:assert/strict";
import test from "node:test";
import { createHash } from "node:crypto";
import { SecretsManagerClient } from "@aws-sdk/client-secrets-manager";
import pg from "pg";
import {
  inventorySubject,
  inspectSyntheticInventory,
} from "../src/persistence/qa_inventory.js";
import { handler } from "../src/persistence/migration_lambda.js";
import { qaInventoryEnvironment } from "../infra/qa_inventory_config.js";
const sub = "00000000-0000-4000-8000-000000000001";
const hash = (prefix: string) =>
  createHash("sha256")
    .update(prefix + "\0" + sub)
    .digest("base64url");
const arn =
  "arn:aws:lambda:us-east-1:837153590200:function:FolooBackend-dev-MigrationFunctionSynthetic";
const env = {
  AWS_REGION: "us-east-1",
  QA_INVENTORY_ENVIRONMENT: "dev",
  QA_INVENTORY_SUBJECT: sub,
  QA_INVENTORY_SUBJECT_HASH: hash("foloo-account-deletion-qa"),
};
const counts = [
  "internalUsers",
  "personalAccounts",
  "livePersonalAccounts",
  "personalWorkspaces",
  "livePersonalWorkspaces",
  "memberships",
  "ownerMemberships",
  "seller_profiles",
  "events",
  "leads",
  "lead_media",
  "content_files",
  "idempotency_records",
  "email_templates",
  "event_email_templates",
  "email_connections",
  "email_oauth_states",
  "email_opt_outs",
  "email_owner_opt_outs",
  "email_unsubscribe_tokens",
  "email_follow_ups",
  "email_send_intents",
];
const bools = [
  "internalAccountExists",
  "activeSubscription",
  "stripeCustomerReference",
  "stripeSubscriptionReference",
  "billingEventTimestamp",
  "currentPeriodEndPresent",
];
function row() {
  return {
    ...Object.fromEntries(counts.map((k) => [k, "0"])),
    ...Object.fromEntries(bools.map((k) => [k, false])),
    subscriptionStates: [],
  };
}
function fake(data: Record<string, unknown> = row(), fail = false) {
  const calls: { sql: string; params?: unknown[] }[] = [];
  let destroyed = false;
  const pool = {
    connect: async () => ({
      query: async (sql: string, params?: unknown[]) => {
        calls.push({ sql, params });
        if (sql.startsWith("WITH") && fail)
          throw new Error("sensitive-db-error");
        return { rows: sql.startsWith("WITH") ? [data] : [] };
      },
      release: (destroy: boolean) => {
        destroyed = destroy;
      },
    }),
  };
  return {
    pool,
    calls,
    get destroyed() {
      return destroyed;
    },
  };
}
test("server binds the configured exact subject and DEV execution ARN", () => {
  assert.equal(inventorySubject(env, arn), sub);
  for (const patch of [
    { QA_INVENTORY_ENVIRONMENT: "prod" },
    { AWS_REGION: "us-west-2" },
    { QA_INVENTORY_SUBJECT: sub.replace(/1$/, "2") },
    { QA_INVENTORY_SUBJECT_HASH: "" },
    { QA_INVENTORY_SUBJECT: "person@example.invalid" },
  ])
    assert.throws(
      () => inventorySubject({ ...env, ...patch }, arn),
      /not_authorized/,
    );
  for (const bad of [
    undefined,
    arn.replace("837153590200", "000000000000"),
    arn.replace("FolooBackend-dev", "FolooBackend-prod"),
    arn.replace("MigrationFunction", "ApiFunction"),
  ])
    assert.throws(() => inventorySubject(env, bad), /not_authorized/);
});
test("CDK inventory is opt-in and requires exactly the already-authorized synthetic subject", () => {
  assert.deepEqual(qaInventoryEnvironment("dev", undefined, false, [], []), {});
  assert.equal(
    qaInventoryEnvironment(
      "dev",
      sub,
      true,
      [hash("foloo-account-deletion-qa")],
      [hash("foloo-web-session")],
    ).QA_INVENTORY_SUBJECT,
    sub,
  );
  for (const [stage, enabled, hashes, web] of [
    [
      "prod",
      true,
      [hash("foloo-account-deletion-qa")],
      [hash("foloo-web-session")],
    ],
    [
      "dev",
      false,
      [hash("foloo-account-deletion-qa")],
      [hash("foloo-web-session")],
    ],
    ["dev", true, [], []],
    ["dev", true, [hash("foloo-web-session")], [hash("foloo-web-session")]],
    [
      "dev",
      true,
      [hash("foloo-account-deletion-qa"), hash("foloo-account-deletion-qa")],
      [hash("foloo-web-session")],
    ],
    ["dev", true, [hash("foloo-account-deletion-qa")], []],
  ] as const)
    assert.throws(() =>
      qaInventoryEnvironment(stage, sub, enabled, hashes, web),
    );
});
test("snapshot uses READ ONLY, timeout, one parameterized SELECT and rollback without provisioning", async () => {
  const f = fake({
    ...row(),
    internalUsers: "1",
    internalAccountExists: true,
    subscriptionStates: ["trial"],
    leads: "2",
    sensitive: "must not escape",
  });
  const out = await inspectSyntheticInventory(f.pool as never, sub);
  assert.equal(out.leads, 2);
  assert.equal(out.internalAccountExists, true);
  assert.deepEqual(out.subscriptionStates, ["trial"]);
  assert.equal(
    f.calls[0]?.sql,
    "BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY",
  );
  assert.ok(f.calls.some((c) => c.sql.includes("statement_timeout")));
  assert.ok(f.calls.some((c) => c.sql.includes("lock_timeout")));
  const select = f.calls.find((c) => c.sql.startsWith("WITH"))!;
  assert.deepEqual(select.params, [sub]);
  assert.ok(!select.sql.includes(sub));
  assert.match(select.sql, /cognito_sub=\$1/);
  assert.match(select.sql, /a.kind='personal'/);
  for (const call of f.calls)
    assert.doesNotMatch(
      call.sql,
      /\b(INSERT|UPDATE|DELETE|ALTER|CREATE|DROP|TRUNCATE|COMMIT|ensure_personal_workspace)\b/i,
    );
  assert.equal(f.calls.at(-1)?.sql, "ROLLBACK");
  assert.ok(f.destroyed);
  assert.doesNotMatch(JSON.stringify(out), /must not escape|00000000|@/);
});
test("absent internal account produces only empty states, false and zero", async () => {
  const f = fake();
  const out = await inspectSyntheticInventory(f.pool as never, sub);
  assert.ok(
    Object.values(out).every(
      (v) => v === 0 || v === false || (Array.isArray(v) && v.length === 0),
    ),
  );
});
test("SQL failure destroys transaction connection, never commits", async () => {
  const f = fake(row(), true);
  await assert.rejects(inspectSyntheticInventory(f.pool as never, sub));
  assert.ok(f.destroyed);
  assert.ok(!f.calls.some((c) => c.sql === "COMMIT"));
});
test("unexpected subscription state or invalid counts fail closed", async () => {
  for (const patch of [
    { subscriptionStates: ["sensitive-value"] },
    { leads: "-1" },
    { leads: "9007199254740992" },
    { activeSubscription: "yes" },
  ]) {
    const f = fake({ ...row(), ...patch });
    await assert.rejects(inspectSyntheticInventory(f.pool as never, sub));
    assert.ok(f.destroyed);
  }
});
test("inventory handler reads only app secret, sanitizes errors and never enters migrations", async () => {
  const originalPool = Object.getOwnPropertyDescriptor(pg, "Pool")!;
  const originalSend = Object.getOwnPropertyDescriptor(
    SecretsManagerClient.prototype,
    "send",
  )!;
  const saved = { ...process.env };
  let secretCalls = 0;
  let connections = 0;
  let ended = 0;
  let mode = "success";
  let f = fake();
  try {
    Object.assign(process.env, env, {
      DB_SECRET_ARN: "synthetic-app-secret",
      DB_ADMIN_SECRET_ARN: "never-read",
      DB_HOST: "synthetic.invalid",
      DB_NAME: "synthetic",
    });
    Object.defineProperty(SecretsManagerClient.prototype, "send", {
      configurable: true,
      value: async (command: { input: { SecretId: string } }) => {
        secretCalls++;
        assert.equal(command.input.SecretId, "synthetic-app-secret");
        if (mode === "secret-error") throw Error("private-secret-error");
        return {
          SecretString: JSON.stringify({
            username: mode === "admin" ? "admin" : "foloo_app",
            password: "synthetic-only",
          }),
        };
      },
    });
    Object.defineProperty(pg, "Pool", {
      configurable: true,
      value: class {
        constructor(config: pg.PoolConfig) {
          assert.equal(config.user, "foloo_app");
          assert.equal(config.connectionTimeoutMillis, 5000);
          assert.match(config.options!, /default_transaction_read_only=on/);
          assert.deepEqual(config.ssl, { rejectUnauthorized: true });
        }
        async connect() {
          connections++;
          if (mode === "connection-error")
            throw Error("private-connection-error");
          return f.pool.connect();
        }
        async end() {
          ended++;
        }
      },
    });
    for (const event of [
      { action: "qa-inventory", subject: sub },
      { action: "qa-inventory", sql: "SELECT 1" },
      { action: "qa-inventory", only: "001_initial.sql" },
      { action: "qa-inventroy" },
      { sql: "SELECT 1" },
      null,
    ])
      await assert.rejects(
        handler(event as never, { invokedFunctionArn: arn }),
        /invalid_operator_action/,
      );
    assert.equal(secretCalls, 0);
    assert.equal(connections, 0);
    await assert.rejects(
      handler(
        { action: "qa-inventory" },
        { invokedFunctionArn: arn.replace("dev", "prod") },
      ),
      /not_authorized/,
    );
    assert.equal(secretCalls, 0);
    await handler({ action: "qa-inventory" }, { invokedFunctionArn: arn });
    assert.equal(secretCalls, 1);
    assert.ok(f.destroyed);
    assert.equal(ended, 1);
    for (const failure of [
      "secret-error",
      "admin",
      "connection-error",
      "query-error",
    ]) {
      mode = failure;
      f = fake(row(), failure === "query-error");
      await assert.rejects(
        handler({ action: "qa-inventory" }, { invokedFunctionArn: arn }),
        (e) => e instanceof Error && e.message === "qa_inventory_unavailable",
      );
    }
  } finally {
    Object.defineProperty(pg, "Pool", originalPool);
    if (originalSend)
      Object.defineProperty(
        SecretsManagerClient.prototype,
        "send",
        originalSend,
      );
    else Reflect.deleteProperty(SecretsManagerClient.prototype, "send");
    for (const k of Object.keys(process.env))
      if (!(k in saved)) delete process.env[k];
    Object.assign(process.env, saved);
  }
});
