/** FL-021 / AUT-10 / MON-07, MON-15–MON-19: signed HTTP flow with no network. */
import assert from "node:assert/strict";
import test, { mock } from "node:test";
import { LambdaClient } from "@aws-sdk/client-lambda";
import { LambdaBillingProvider } from "../src/billing/billing_provider_invoker.js";
import { createServer } from "node:http";
import { once } from "node:events";
import type pg from "pg";
import Stripe from "stripe";
import { BillingApplication } from "../src/billing/billing_application.js";
import {
  PostgresBillingRepository,
  type BillingEvent,
} from "../src/billing/postgres_billing_repository.js";
import type { BillingCommand } from "../src/billing/billing_provider_contract.js";
import { executeBillingCommand } from "../src/billing/billing_provider_lambda.js";
import { FolooApplication } from "../src/application/foloo_application.js";
import { createRouter } from "../src/transport/router.js";
import { errorResponse } from "../src/transport/error_response.js";
import { apiEvent, MemoryRepository } from "./helpers.js";

const accountId = "d7ca7b4c-5f14-4160-9f07-0cf05b1fd661";
const otherId = "45aab8cf-045f-4f27-b348-aa32375ac7f0";
const webhookSecret = "whsec_unit_test_only";
const config = {
  STRIPE_PRICE_ID: "price_configured",
  STRIPE_SECRET_ARN: "secret-reference",
  STRIPE_WEBHOOK_SECRET_ARN: "webhook-reference",
  BILLING_PROVIDER_FUNCTION_NAME: "billing",
  BILLING_SUCCESS_URL: "https://example.com/success",
  BILLING_CANCEL_URL: "https://example.com/cancel",
  BILLING_PORTAL_RETURN_URL: "https://example.com/account",
};
const completed = (id = "evt_checkout"): BillingEvent => ({
  id,
  created: 100,
  type: "checkout.session.completed",
  data: {
    object: {
      mode: "subscription",
      payment_status: "paid",
      metadata: { sub: "alice", origin: "foloo-app" },
      client_reference_id: accountId,
      customer: "cus_a",
      subscription: "sub_a",
    },
  },
});

/** Serial transaction fake: exercises the real adapter and rolls back its staged writes.
 * It models unique-index contention, not a replacement for a PostgreSQL integration test.
 */
class BillingDatabase {
  accounts = new Map(
    [accountId, otherId].map((id) => [
      id,
      {
        id,
        subscriptionStatus: "trial_exhausted",
        customerId: null as string | null,
        subscriptionId: null as string | null,
        periodEnd: null as number | null,
        billingEventAt: null as number | null,
      },
    ]),
  );
  events = new Set<string>();
  leads = [{ id: "lead-preserved", accountId }];
  calls: { sql: string; values: unknown[] }[] = [];
  writes = 0;
  failUpdate = false;
  private tail = Promise.resolve();
  async query(sql: string, values: unknown[] = []) {
    assert.match(sql, /WHERE id=\$1 AND deleted_at IS NULL/);
    const account = this.accounts.get(String(values[0]));
    if (sql.startsWith("UPDATE accounts") && account && !account.customerId)
      account.customerId = String(values[1]);
    return { rows: [account].filter(Boolean) };
  }
  async connect() {
    let unlock!: () => void;
    const prior = this.tail;
    this.tail = new Promise<void>((resolve) => {
      unlock = resolve;
    });
    await prior;
    const accounts = structuredClone(this.accounts);
    const events = new Set(this.events);
    let writes = 0;
    return {
      query: async (sql: string, values: unknown[] = []) => {
        this.calls.push({ sql, values });
        if (sql === "COMMIT") {
          this.accounts = accounts;
          this.events = events;
          this.writes += writes;
        }
        if (sql.startsWith("INSERT INTO billing_events")) {
          assert.match(sql, /ON CONFLICT DO NOTHING RETURNING event_id/);
          const id = String(values[0]);
          if (events.has(id)) return { rows: [], rowCount: 0 };
          events.add(id);
          return { rows: [{ event_id: id }], rowCount: 1 };
        }
        if (sql.startsWith("SELECT a.id")) {
          const account = accounts.get(String(values[0]));
          const matches =
            account &&
            values[1] === (account.id === accountId ? "alice" : "bob");
          assert.match(sql, /u.cognito_sub=\$2/);
          return { rows: matches ? [account] : [], rowCount: matches ? 1 : 0 };
        }
        if (sql.startsWith("SELECT stripe_customer_id")) {
          const matches = [...accounts.values()].filter(
            (a) => a.customerId === values[0] || a.id === values[1],
          );
          return { rows: matches, rowCount: matches.length };
        }
        if (sql.startsWith("UPDATE accounts")) {
          if (this.failUpdate) throw new Error("simulated database failure");
          assert.match(sql, /entitlement_updated_at=now\(\)/);
          assert.match(
            sql,
            /billing_event_at IS NULL OR billing_event_at <= to_timestamp\(\$5\)/,
          );
          assert.doesNotMatch(sql, /trial_leads_used/);
          const checkout = sql.includes("stripe_customer_id=$2,");
          const candidates = checkout
            ? [accounts.get(String(values[0]))].filter((a) => a !== undefined)
            : [...accounts.values()].filter(
                (a) =>
                  a.subscriptionId === values[0] && a.customerId === values[1],
              );
          let matched = 0;
          for (const account of candidates) {
            const created = Number(values[4]);
            const status = (checkout ? values[3] : values[2]) as string | null;
            if (
              account.billingEventAt !== null &&
              account.billingEventAt > created
            )
              continue;
            if (
              account.subscriptionStatus === "expired" &&
              status === "active" &&
              (!checkout || account.subscriptionId === values[2]) &&
              account.billingEventAt !== null &&
              account.billingEventAt >= created
            )
              continue;
            if (checkout) {
              if (account.customerId && account.customerId !== values[1])
                continue;
              if (
                account.subscriptionId &&
                account.subscriptionId !== values[2] &&
                account.subscriptionStatus !== "expired"
              )
                continue;
              account.customerId = String(values[1]);
              account.subscriptionId = String(values[2]);
            } else if (values[3] !== null)
              account.periodEnd = Number(values[3]);
            account.subscriptionStatus = status ?? account.subscriptionStatus;
            account.billingEventAt = created;
            writes++;
            matched++;
          }
          return { rows: [], rowCount: matched };
        }
        assert.ok(
          ["BEGIN", "COMMIT", "ROLLBACK"].includes(sql),
          `Unexpected SQL: ${sql}`,
        );
        return { rows: [], rowCount: 0 };
      },
      release: unlock,
    };
  }
}
function fixture(environment = config) {
  const db = new BillingDatabase();
  const repo = new PostgresBillingRepository(db as unknown as pg.Pool);
  const identities = new MemoryRepository();
  identities.resolvePrincipal = async (subject) => {
    identities.seenSubjects.push(subject);
    return {
      subject,
      userId: "user",
      accountId: subject === "alice" ? accountId : otherId,
      workspaceId: "workspace",
    };
  };
  const commands: BillingCommand[] = [];
  const billing = new BillingApplication(
    identities,
    repo,
    {
      invoke: async (command) => {
        commands.push(command);
        if (command.action === "createCustomer") return { customerId: "cus_a" };
        return { url: "https://checkout.stripe.com/session" };
      },
    },
    environment,
    async () => webhookSecret,
  );
  const route = createRouter(
    new FolooApplication(identities),
    undefined,
    undefined,
    undefined,
    undefined,
    billing,
  );
  const http = async (event: ReturnType<typeof apiEvent>) => {
    try {
      return await route(event);
    } catch (error) {
      return errorResponse(error, "test", event.rawPath);
    }
  };
  const webhook = (event: BillingEvent, base64 = false) => {
    const payload = JSON.stringify(event);
    const request = apiEvent({ method: "POST", path: "/v1/billing/webhook" });
    request.body = base64 ? Buffer.from(payload).toString("base64") : payload;
    request.isBase64Encoded = base64;
    request.headers["Stripe-Signature"] =
      Stripe.webhooks.generateTestHeaderString({
        payload,
        secret: webhookSecret,
      });
    return request;
  };
  return { db, repo, identities, commands, http, webhook };
}

test("MON-15/AUT-10 checkout ignores body identity/price/URLs and derives account from JWT", async () => {
  const f = fixture();
  const response = await f.http(
    apiEvent({
      method: "POST",
      path: "/v1/billing/checkout-session",
      subject: "alice",
      body: {
        accountId: otherId,
        sub: "bob",
        priceId: "attacker",
        successUrl: "https://attacker.invalid",
      },
    }),
  );
  assert.equal(response.statusCode, 200);
  assert.deepEqual(f.commands, [
    { action: "createCustomer", accountId, sub: "alice" },
    {
      action: "createCheckoutSession",
      accountId,
      sub: "alice",
      customerId: "cus_a",
      priceId: config.STRIPE_PRICE_ID,
      successUrl: config.BILLING_SUCCESS_URL,
      cancelUrl: config.BILLING_CANCEL_URL,
    },
  ]);
  assert.deepEqual(f.identities.seenSubjects, ["alice"]);
  assert.deepEqual(JSON.parse(response.body!), {
    url: "https://checkout.stripe.com/session",
  });
});
test("MON-19 active account gets 409 directing it to Portal", async () => {
  const f = fixture();
  f.db.accounts.get(accountId)!.subscriptionStatus = "active";
  const result = await f.http(
    apiEvent({
      method: "POST",
      path: "/v1/billing/checkout-session",
      subject: "alice",
    }),
  );
  assert.equal(result.statusCode, 409);
  assert.match(result.body!, /portal/);
  assert.equal(f.commands.length, 0);
});
test("MON-18 missing price produces safe billing_not_configured 503", async () => {
  const f = fixture({ ...config, STRIPE_PRICE_ID: "" });
  const result = await f.http(
    apiEvent({
      method: "POST",
      path: "/v1/billing/checkout-session",
      subject: "alice",
    }),
  );
  assert.equal(result.statusCode, 503);
  assert.match(result.body!, /billing_not_configured/);
  assert.equal(f.commands.length, 0);
});
test("MON-17 portal returns 404 without customer and uses only authenticated customer's ID", async () => {
  const f = fixture();
  const event = apiEvent({
    method: "POST",
    path: "/v1/billing/portal-session",
    subject: "alice",
    body: { customerId: "cus_other" },
  });
  assert.equal((await f.http(event)).statusCode, 404);
  f.db.accounts.get(accountId)!.customerId = "cus_a";
  assert.equal((await f.http(event)).statusCode, 200);
  assert.deepEqual(f.commands, [
    {
      action: "createPortalSession",
      customerId: "cus_a",
      returnUrl: config.BILLING_PORTAL_RETURN_URL,
    },
  ]);
});
test("AUT-10 billing session routes reject missing JWT", async () => {
  const f = fixture();
  for (const endpoint of ["checkout-session", "portal-session"])
    assert.equal(
      (
        await f.http(
          apiEvent({ method: "POST", path: `/v1/billing/${endpoint}` }),
        )
      ).statusCode,
      401,
    );
  assert.equal(f.commands.length, 0);
});
for (const base64 of [false, true])
  test(`MON-16 valid raw webhook (base64=${base64}) activates exactly client_reference_id without JWT`, async () => {
    const f = fixture();
    assert.equal(
      (await f.http(f.webhook(completed(), base64))).statusCode,
      200,
    );
    assert.equal(f.db.accounts.get(accountId)!.subscriptionStatus, "active");
    assert.equal(
      f.db.accounts.get(otherId)!.subscriptionStatus,
      "trial_exhausted",
    );
    assert.equal(f.db.accounts.get(accountId)!.subscriptionId, "sub_a");
  });
test("MON-16 invalid/tampered/stale/missing signatures return safe 400 without writes", async () => {
  const f = fixture();
  for (const variant of ["tampered", "stale", "missing", "invalid"]) {
    const event = f.webhook(completed());
    if (variant === "tampered") event.body += " ";
    if (variant === "missing") event.headers = {};
    if (variant === "invalid")
      event.headers["Stripe-Signature"] = "secret-should-not-leak";
    if (variant === "stale")
      event.headers["Stripe-Signature"] =
        Stripe.webhooks.generateTestHeaderString({
          payload: event.body!,
          secret: webhookSecret,
          timestamp: 1,
        });
    const result = await f.http(event);
    assert.equal(result.statusCode, 400);
    assert.match(result.body!, /invalid_webhook/);
    assert.doesNotMatch(result.body!, /whsec|secret-should|client_reference/);
  }
  assert.equal(f.db.events.size, 0);
  assert.equal(f.db.calls.length, 0);
});
test("MON-16 repeated and concurrent deliveries commit exactly once", async () => {
  const f = fixture();
  const results = await Promise.all(
    Array.from({ length: 12 }, () => f.http(f.webhook(completed()))),
  );
  assert.ok(results.every((result) => result.statusCode === 200));
  assert.equal((await f.http(f.webhook(completed()))).statusCode, 200);
  assert.equal(f.db.events.size, 1);
  assert.equal(f.db.writes, 1);
});
test("MON-16 failed transaction rolls back event receipt so a retry applies", async () => {
  const f = fixture();
  f.db.failUpdate = true;
  assert.equal((await f.http(f.webhook(completed()))).statusCode, 500);
  assert.equal(f.db.events.size, 0);
  assert.equal(
    f.db.accounts.get(accountId)!.subscriptionStatus,
    "trial_exhausted",
  );
  assert.ok(f.db.calls.some((call) => call.sql === "ROLLBACK"));
  f.db.failUpdate = false;
  assert.equal((await f.http(f.webhook(completed()))).statusCode, 200);
  assert.equal(f.db.writes, 1);
});
test("MON-07/MON-16 deleted expires only the matching subscription and preserves leads", async () => {
  const f = fixture();
  await f.repo.apply(completed());
  const leads = structuredClone(f.db.leads);
  await f.repo.apply({
    id: "evt_deleted",
    created: 200,
    type: "customer.subscription.deleted",
    data: {
      object: {
        id: "sub_a",
        customer: "cus_a",
        status: "canceled",
        current_period_end: 1800000000,
      },
    },
  });
  assert.equal(f.db.accounts.get(accountId)!.subscriptionStatus, "expired");
  assert.equal(f.db.accounts.get(accountId)!.periodEnd, 1800000000);
  assert.equal(
    f.db.accounts.get(otherId)!.subscriptionStatus,
    "trial_exhausted",
  );
  assert.deepEqual(f.db.leads, leads);
  assert.ok(
    f.db.calls.every(
      (call) => !/\b(leads|workspaces|DELETE)\b/i.test(call.sql),
    ),
  );
});
test("MON-16 subscription snapshots map trialing/active/unpaid and preserve past_due", async () => {
  const f = fixture();
  await f.repo.apply(completed());
  for (const [status, expected] of [
    ["past_due", "active"],
    ["unpaid", "expired"],
    ["trialing", "active"],
    ["active", "active"],
  ]) {
    await f.repo.apply({
      id: `evt_${status}`,
      created:
        200 + ["past_due", "unpaid", "trialing", "active"].indexOf(status!),
      type: "customer.subscription.updated",
      data: {
        object: {
          id: "sub_a",
          customer: "cus_a",
          status,
          items: { data: [{ current_period_end: 1800000000 }] },
        },
      },
    });
    assert.equal(f.db.accounts.get(accountId)!.subscriptionStatus, expected);
    assert.equal(f.db.accounts.get(accountId)!.periodEnd, 1800000000);
  }
});
test("MON-16 unknown types and payment failures acknowledge without inventing expiry", async () => {
  const f = fixture();
  await f.repo.apply(completed());
  for (const type of ["invoice.payment_failed", "unhandled.event"]) {
    assert.equal(
      (
        await f.http(
          f.webhook({
            id: `evt_${type}`,
            created: 200,
            type,
            data: { object: { next_payment_attempt: null } },
          }),
        )
      ).statusCode,
      200,
    );
  }
  assert.equal(f.db.writes, 1);
  assert.equal(f.db.events.size, 3);
});
test("MON-15/MON-17 official SDK receives server-owned subscription metadata and Portal URLs", async () => {
  const calls: unknown[] = [];
  const create = async (input: unknown) => {
    calls.push(input);
    return { url: "https://stripe.example/session" };
  };
  const stripe = {
    subscriptions: { list: async function* () {} },
    checkout: { sessions: { create } },
    billingPortal: { sessions: { create } },
  } as unknown as Stripe;
  await executeBillingCommand(stripe, {
    action: "createCheckoutSession",
    accountId,
    sub: "alice",
    customerId: "cus_a",
    priceId: "price_a",
    successUrl: config.BILLING_SUCCESS_URL,
    cancelUrl: config.BILLING_CANCEL_URL,
  });
  assert.deepEqual(calls[0], {
    mode: "subscription",
    client_reference_id: accountId,
    metadata: { sub: "alice", origin: "foloo-app" },
    subscription_data: { metadata: { accountId } },
    customer: "cus_a",
    line_items: [{ price: "price_a", quantity: 1 }],
    success_url: config.BILLING_SUCCESS_URL,
    cancel_url: config.BILLING_CANCEL_URL,
  });
  await executeBillingCommand(stripe, {
    action: "createPortalSession",
    customerId: "cus_a",
    returnUrl: config.BILLING_PORTAL_RETURN_URL,
  });
  assert.deepEqual(calls[1], {
    customer: "cus_a",
    return_url: config.BILLING_PORTAL_RETURN_URL,
  });
});

test("MON-16 webhook HTTP smoke test preserves raw bytes through actual local HTTP", async () => {
  const f = fixture();
  const server = createServer(async (request, response) => {
    const chunks: Buffer[] = [];
    for await (const chunk of request) chunks.push(Buffer.from(chunk));
    const event = apiEvent({ method: request.method, path: request.url });
    event.body = Buffer.concat(chunks).toString("utf8");
    event.headers = {
      "stripe-signature": String(request.headers["stripe-signature"] ?? ""),
    };
    const result = await f.http(event);
    response.writeHead(result.statusCode ?? 500, {
      "content-type": "application/json",
    });
    response.end(result.body);
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  try {
    const address = server.address();
    assert.ok(address && typeof address === "object");
    const event = f.webhook(completed());
    const response = await fetch(
      `http://127.0.0.1:${address.port}/v1/billing/webhook`,
      {
        method: "POST",
        headers: { "stripe-signature": event.headers["Stripe-Signature"]! },
        body: event.body,
      },
    );
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { received: true });
    assert.equal(f.db.accounts.get(accountId)!.subscriptionStatus, "active");
  } finally {
    server.closeAllConnections();
    await new Promise<void>((resolve, reject) =>
      server.close((error) => (error ? reject(error) : resolve())),
    );
  }
});

test("MON-16 subscription delivered before Checkout rolls back and succeeds on retry", async () => {
  const f = fixture();
  f.db.accounts.get(accountId)!.customerId = "cus_a";
  const event: BillingEvent = {
    id: "evt_early",
    created: 200,
    type: "customer.subscription.updated",
    data: {
      object: {
        id: "sub_a",
        customer: "cus_a",
        status: "active",
        current_period_end: 1800000000,
      },
    },
  };
  assert.equal((await f.http(f.webhook(event))).statusCode, 503);
  assert.equal(f.db.events.size, 0);
  await f.repo.apply(completed());
  assert.equal((await f.http(f.webhook(event))).statusCode, 200);
  assert.equal(f.db.accounts.get(accountId)!.periodEnd, 1800000000);
});

const snapshot = (
  id: string,
  created: number,
  status = "active",
  subscription = "sub_a",
): BillingEvent => ({
  id,
  created,
  type:
    status === "canceled"
      ? "customer.subscription.deleted"
      : "customer.subscription.updated",
  data: {
    object: {
      id: subscription,
      customer: "cus_a",
      status,
      current_period_end: 1800000000,
    },
  },
});

test("MON-16 deleted then delayed active/Checkout and reordered retries preserve expiry", async () => {
  const f = fixture();
  await f.repo.apply(completed());
  const deleted = snapshot("evt_end", 300, "canceled");
  const older = snapshot("evt_old", 200);
  await f.repo.apply(deleted);
  for (const event of [
    older,
    deleted,
    { ...completed("evt_delayed_checkout"), created: 250 },
    snapshot("evt_tie", 300),
    older,
  ]) {
    assert.equal((await f.http(f.webhook(event))).statusCode, 200);
    assert.equal(f.db.accounts.get(accountId)!.subscriptionStatus, "expired");
    assert.equal(f.db.accounts.get(accountId)!.billingEventAt, 300);
  }
  assert.equal(f.db.events.size, 5);
  assert.equal(f.db.writes, 2);
});

for (const paymentStatus of ["paid", "no_payment_required", "unpaid"])
  test(`MON-16 Checkout ${paymentStatus} binds IDs and grants only confirmed payment`, async () => {
    const f = fixture();
    const event = completed();
    event.data.object.payment_status = paymentStatus;
    await f.repo.apply(event);
    const account = f.db.accounts.get(accountId)!;
    assert.equal(account.customerId, "cus_a");
    assert.equal(account.subscriptionId, "sub_a");
    assert.equal(
      account.subscriptionStatus,
      paymentStatus === "unpaid" ? "trial_exhausted" : "active",
    );
    await f.repo.apply(snapshot("evt_paid_later", 200));
    assert.equal(f.db.accounts.get(accountId)!.subscriptionStatus, "active");
  });

for (const variant of [
  "wrong-owner",
  "wrong-price",
  "no-origin",
  "payment",
  "foreign-customer",
])
  test(`AUT-10/MON-16 unrelated Checkout ${variant} is recorded with 200 and no activation`, async () => {
    const f = fixture();
    const event = completed();
    if (variant === "wrong-owner")
      event.data.object.metadata = { sub: "bob", origin: "foloo-app" };
    if (variant === "wrong-price" || variant === "no-origin") {
      event.data.object.metadata = { sub: "alice" };
      if (variant === "wrong-price")
        event.data.object.line_items = {
          data: [{ price: { id: "price_foreign" } }],
        };
    }
    if (variant === "payment") event.data.object.mode = "payment";
    if (variant === "foreign-customer")
      f.db.accounts.get(accountId)!.customerId = "cus_other";
    assert.equal((await f.http(f.webhook(event))).statusCode, 200);
    assert.equal(
      f.db.accounts.get(accountId)!.subscriptionStatus,
      "trial_exhausted",
    );
    assert.equal(f.db.events.size, 1);
    assert.equal(f.db.writes, 0);
  });

test("MON-16 matching configured price can verify a session without origin", async () => {
  const f = fixture();
  const event = completed();
  event.data.object.metadata = { sub: "alice" };
  event.data.object.line_items = {
    data: [{ price: { id: config.STRIPE_PRICE_ID } }],
  };
  assert.equal((await f.http(f.webhook(event))).statusCode, 200);
  assert.equal(f.db.accounts.get(accountId)!.subscriptionStatus, "active");
});

test("MON-16 foreign and replaced subscriptions acknowledge; known pending binding retries", async () => {
  const f = fixture();
  assert.equal(
    (await f.http(f.webhook(snapshot("evt_foreign", 200)))).statusCode,
    200,
  );
  f.db.accounts.get(accountId)!.customerId = "cus_a";
  assert.equal(
    (await f.http(f.webhook(snapshot("evt_pending", 200)))).statusCode,
    503,
  );
  assert.equal(f.db.events.has("evt_pending"), false);
  await f.repo.apply(completed());
  assert.equal(
    (
      await f.http(
        f.webhook(snapshot("evt_replaced", 200, "canceled", "sub_old")),
      )
    ).statusCode,
    200,
  );
  assert.equal(
    (await f.http(f.webhook(snapshot("evt_pending", 200)))).statusCode,
    200,
  );
  assert.equal(f.db.accounts.get(accountId)!.subscriptionStatus, "active");
});

test("MON-16 subscription metadata identifies pending customer persistence for retry", async () => {
  const f = fixture();
  const event = snapshot("evt_before_customer_persisted", 200);
  event.data.object.metadata = { accountId };
  assert.equal((await f.http(f.webhook(event))).statusCode, 503);
  assert.equal(f.db.events.size, 0);
  await f.repo.apply(completed());
  assert.equal((await f.http(f.webhook(event))).statusCode, 200);
});

test("MON-15 customer creation is idempotent and persisted before concurrent Checkout attempts", async () => {
  const f = fixture();
  const order: string[] = [];
  const stripe = {
    customers: {
      create: async (input: unknown, options: unknown) => {
        assert.deepEqual(input, { metadata: { accountId, sub: "alice" } });
        assert.deepEqual(options, { idempotencyKey: accountId });
        order.push("customer");
        return { id: "cus_a" };
      },
    },
    subscriptions: {
      list: async function* (input: unknown) {
        assert.equal(f.db.accounts.get(accountId)!.customerId, "cus_a");
        assert.deepEqual(input, {
          customer: "cus_a",
          status: "all",
          limit: 100,
        });
        yield { status: "canceled" };
      },
    },
    checkout: {
      sessions: {
        create: async () => {
          assert.equal(f.db.accounts.get(accountId)!.customerId, "cus_a");
          order.push("checkout");
          return { url: "https://example.com/checkout" };
        },
      },
    },
  } as unknown as Stripe;
  const app = new BillingApplication(
    f.identities,
    f.repo,
    { invoke: (command) => executeBillingCommand(stripe, command) },
    config,
  );
  await Promise.all([app.checkout("alice"), app.checkout("alice")]);
  assert.equal(f.db.accounts.get(accountId)!.customerId, "cus_a");
  assert.ok(order.indexOf("customer") < order.indexOf("checkout"));
  // A competing write cannot overwrite a previously bound customer.
  assert.equal(await f.repo.linkCustomer(accountId, "cus_other"), "cus_a");
});

for (const status of ["active", "trialing", "past_due"])
  test(`MON-19 Stripe ${status} subscription prevents Checkout with 409 portal`, async () => {
    const f = fixture();
    f.db.accounts.get(accountId)!.customerId = "cus_a";
    const stripe = {
      subscriptions: {
        list: async function* () {
          yield { status: "canceled" };
          yield { status };
        },
      },
    } as unknown as Stripe;
    const billing = new BillingApplication(
      f.identities,
      f.repo,
      { invoke: (command) => executeBillingCommand(stripe, command) },
      config,
    );
    await assert.rejects(
      () => billing.checkout("alice"),
      (error: unknown) => {
        const response = errorResponse(
          error,
          "test",
          "/v1/billing/checkout-session",
        );
        assert.equal(response.statusCode, 409);
        assert.match(response.body!, /portal/);
        return true;
      },
    );
  });

test("MON-18 missing signature rejects before reading secrets", async () => {
  const f = fixture();
  let reads = 0;
  const app = new BillingApplication(
    f.identities,
    f.repo,
    { invoke: async () => ({ url: "https://example.com" }) },
    config,
    async () => {
      reads++;
      return webhookSecret;
    },
  );
  for (const signature of [undefined, "", " "])
    await assert.rejects(
      () => app.webhook(Buffer.from("{}"), signature),
      /Invalid webhook/,
    );
  assert.equal(reads, 0);
});

test("MON-19 provider Lambda conflict survives invocation as HTTP 409", async () => {
  const send = mock.method(LambdaClient.prototype, "send", async () => ({
    Payload: Buffer.from(
      JSON.stringify({ ok: false, errorCode: "billing_use_portal" }),
    ),
  }));
  try {
    await assert.rejects(
      () =>
        new LambdaBillingProvider("billing").invoke({
          action: "createPortalSession",
          customerId: "cus_a",
          returnUrl: "https://example.com",
        }),
      (error: unknown) => {
        const response = errorResponse(
          error,
          "test",
          "/v1/billing/checkout-session",
        );
        assert.equal(response.statusCode, 409);
        assert.match(response.body!, /portal/);
        return true;
      },
    );
  } finally {
    send.mock.restore();
  }
});

test("MON-15 failed customer persistence prevents Checkout and retries safely", async () => {
  const f = fixture();
  const actions: string[] = [];
  const app = new BillingApplication(
    f.identities,
    {
      account: (id) => f.repo.account(id),
      apply: (event) => f.repo.apply(event),
      linkCustomer: async () => {
        throw Error("database unavailable");
      },
    },
    {
      invoke: async (command) => {
        actions.push(command.action);
        return { customerId: "cus_a" };
      },
    },
    config,
  );
  await assert.rejects(() => app.checkout("alice"), /database unavailable/);
  assert.deepEqual(actions, ["createCustomer"]);
  assert.equal(f.db.accounts.get(accountId)!.customerId, null);
});
