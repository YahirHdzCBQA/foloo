/** Verifies retry-safe creation and conflict detection in the PostgreSQL adapter. */

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
const input = {
  id: "f225b79b-2504-4a5f-94f8-f8db264aa9e5",
  name: "Expo",
  startsAt: "2026-09-09T10:00:00Z",
  endsAt: "2026-09-10T10:00:00Z",
};

class IdempotencyClient {
  stored?: { request_hash: string; response_body: unknown };
  insertCount = 0;

  async query<Row extends Record<string, unknown> = Record<string, unknown>>(
    sql: string,
    values: unknown[] = [],
  ) {
    if (sql.includes("SELECT request_hash"))
      return {
        rows: this.stored ? [this.stored as unknown as Row] : [],
        rowCount: this.stored ? 1 : 0,
      };
    if (sql.includes("INSERT INTO events")) {
      this.insertCount += 1;
      return {
        rows: [{ ...input, revision: 1 } as unknown as Row],
        rowCount: 1,
      };
    }
    if (sql.includes("INSERT INTO idempotency_records")) {
      this.stored = {
        request_hash: String(values[3]),
        response_body: JSON.parse(String(values[4])) as unknown,
      };
    }
    return { rows: [], rowCount: 0 };
  }

  release() {}
}

function repository(client: IdempotencyClient) {
  const pool = { connect: async () => client } as unknown as pg.Pool;
  return new PostgresFolooRepository(pool);
}

test("replays a creation without inserting a duplicate", async () => {
  const client = new IdempotencyClient();
  const adapter = repository(client);
  const hash = requestHash(input);
  const first = await adapter.createEvent(principal, input, "same-key", hash);
  const second = await adapter.createEvent(principal, input, "same-key", hash);
  assert.equal(first.replayed, false);
  assert.equal(second.replayed, true);
  assert.equal(client.insertCount, 1);
});

test("takes a transaction advisory lock before checking an idempotency key", async () => {
  const calls: string[] = [];
  const client = new IdempotencyClient();
  const original = client.query.bind(client);
  client.query = async (sql: string, values: unknown[] = []) => {
    calls.push(sql);
    return original(sql, values);
  };
  await repository(client).createEvent(
    principal,
    input,
    "same-key",
    requestHash(input),
  );
  assert.ok(
    calls.findIndex((sql) => sql.includes("pg_advisory_xact_lock")) <
      calls.findIndex((sql) => sql.includes("SELECT request_hash")),
  );
});

test("rejects reuse of an idempotency key with another payload", async () => {
  const client = new IdempotencyClient();
  const adapter = repository(client);
  await adapter.createEvent(principal, input, "same-key", requestHash(input));
  await assert.rejects(
    adapter.createEvent(
      principal,
      { ...input, name: "Other" },
      "same-key",
      requestHash({ ...input, name: "Other" }),
    ),
    (error) => error instanceof ApplicationError && error.statusCode === 409,
  );
});
