/** FL-020 transactional entitlement enforcement at the PostgreSQL boundary. */

import assert from "node:assert/strict";
import test from "node:test";

import type pg from "pg";

import { ApplicationError } from "../src/application/errors.js";
import {
  PostgresFolooRepository,
  requestHash,
} from "../src/persistence/postgres_repository.js";

const principal = {
  subject: "subject-a",
  userId: "user-a",
  accountId: "account-a",
  workspaceId: "workspace-a",
};
const lead = {
  id: "f225b79b-2504-4a5f-94f8-f8db264aa9e5",
  capturedAt: "2026-10-06T10:00:00Z",
  origin: "direct" as const,
  place: "Expo",
  firstName: "Ana",
  company: "Foloo",
  email: "ana@example.com",
  leadType: "customer" as const,
  interest: "high" as const,
};

class EntitlementClient {
  used = 0;
  status = "trial";
  stored?: { request_hash: string; response_body: unknown };
  calls: string[] = [];

  async query<Row extends Record<string, unknown> = Record<string, unknown>>(
    sql: string,
    values: unknown[] = [],
  ) {
    this.calls.push(sql);
    if (sql.includes("SELECT request_hash")) {
      return {
        rows: this.stored ? [this.stored as unknown as Row] : [],
        rowCount: 0,
      };
    }
    if (sql.includes("SELECT subscription_status")) {
      return {
        rows: [
          {
            subscription_status: this.status,
            trial_leads_used: this.used,
          } as unknown as Row,
        ],
        rowCount: 1,
      };
    }
    if (sql.includes("INSERT INTO leads")) {
      return {
        rows: [{ id: lead.id, revision: 1 } as unknown as Row],
        rowCount: 1,
      };
    }
    if (sql.includes("UPDATE accounts SET")) {
      this.used += 1;
      if (this.used >= 5) this.status = "trial_exhausted";
    }
    if (sql.includes("INSERT INTO idempotency_records")) {
      this.stored = {
        request_hash: String(values[3]),
        response_body: JSON.parse(String(values[5])) as unknown,
      };
    }
    return { rows: [], rowCount: 0 };
  }

  release() {}
}

function repository(client: EntitlementClient) {
  return new PostgresFolooRepository({
    connect: async () => client,
  } as unknown as pg.Pool);
}

test("Lead creation locks entitlement and consumes one historical use", async () => {
  const client = new EntitlementClient();
  await repository(client).createLead(
    principal,
    lead,
    "lead-key",
    requestHash(lead),
  );
  assert.equal(client.used, 1);
  assert.ok(client.calls.some((sql) => /accounts[\s\S]*FOR UPDATE/.test(sql)));
});

test("retry with the same idempotency key never consumes twice", async () => {
  const client = new EntitlementClient();
  const adapter = repository(client);
  await adapter.createLead(principal, lead, "lead-key", requestHash(lead));
  await adapter.createLead(principal, lead, "lead-key", requestHash(lead));
  assert.equal(client.used, 1);
});

test("sixth Lead is rejected and no counter is changed", async () => {
  const client = new EntitlementClient();
  client.used = 5;
  client.status = "trial_exhausted";
  await assert.rejects(
    repository(client).createLead(
      principal,
      lead,
      "sixth-key",
      requestHash(lead),
    ),
    (error) =>
      error instanceof ApplicationError &&
      error.code === "entitlement_required" &&
      error.statusCode === 402,
  );
  assert.equal(client.used, 5);
});

test("active subscription bypasses the trial counter", async () => {
  const client = new EntitlementClient();
  client.used = 5;
  client.status = "active";
  await repository(client).createLead(
    principal,
    lead,
    "active-key",
    requestHash(lead),
  );
  assert.equal(client.used, 5);
});
