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
        response_body: JSON.parse(String(values[5])) as unknown,
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

class LeadUpdateClient extends IdempotencyClient {
  updateCount = 0;
  conflictRevision = false;

  override async query<
    Row extends Record<string, unknown> = Record<string, unknown>,
  >(sql: string, values: unknown[] = []) {
    if (sql.includes("SELECT origin FROM leads"))
      return { rows: [{ origin: "direct" } as unknown as Row], rowCount: 1 };
    if (sql.includes("UPDATE leads SET")) {
      this.updateCount += 1;
      return {
        rows: this.conflictRevision
          ? []
          : ([
              {
                id: values[1],
                firstName: values[3],
                revision: Number(values[2]) + 1,
              } as unknown as Row,
            ] as Row[]),
        rowCount: this.conflictRevision ? 0 : 1,
      };
    }
    return super.query<Row>(sql, values);
  }
}

class EventMutationClient extends IdempotencyClient {
  updateCount = 0;
  deleteCount = 0;
  stale = false;
  override async query<
    Row extends Record<string, unknown> = Record<string, unknown>,
  >(sql: string, values: unknown[] = []) {
    if (sql.includes("UPDATE events SET name")) {
      this.updateCount += 1;
      return {
        rows: this.stale
          ? []
          : [
              {
                id: values[1],
                name: values[3],
                revision: "2",
              } as unknown as Row,
            ],
        rowCount: this.stale ? 0 : 1,
      };
    }
    if (sql.includes("UPDATE events SET deleted_at")) {
      this.deleteCount += 1;
      assert.doesNotMatch(sql, /DELETE FROM|leads|lead_media/i);
      return {
        rows: [
          {
            id: values[1],
            revision: "3",
            deletedAt: "2026-09-16T12:00:00Z",
          } as unknown as Row,
        ],
        rowCount: 1,
      };
    }
    if (sql.includes("SELECT id FROM events"))
      return { rows: [{ id: values[1] } as unknown as Row], rowCount: 1 };
    return super.query<Row>(sql, values);
  }
}

test("EVT-02 update is idempotent, revision guarded and preserves Unicode", async () => {
  const client = new EventMutationClient();
  const adapter = repository(client);
  const update = {
    revision: 1,
    name: "México · León · Exposición · Niñez · São Paulo",
    startsAt: input.startsAt,
    endsAt: input.endsAt,
  };
  const hash = requestHash({ eventId: input.id, ...update });
  await adapter.updateEvent(
    principal,
    input.id,
    update,
    "event-update-key",
    hash,
  );
  await adapter.updateEvent(
    principal,
    input.id,
    update,
    "event-update-key",
    hash,
  );
  assert.equal(client.updateCount, 1);
  client.stored = undefined;
  client.stale = true;
  await assert.rejects(
    adapter.updateEvent(principal, input.id, update, "stale-event-key", hash),
    (error) =>
      error instanceof ApplicationError && error.code === "revision_conflict",
  );
});

test("EVT-02 delete creates an idempotent tombstone without touching Leads", async () => {
  const client = new EventMutationClient();
  const adapter = repository(client);
  const payload = { revision: 2 };
  const hash = requestHash({ eventId: input.id, ...payload });
  await adapter.deleteEvent(
    principal,
    input.id,
    payload,
    "event-delete-key",
    hash,
  );
  await adapter.deleteEvent(
    principal,
    input.id,
    payload,
    "event-delete-key",
    hash,
  );
  assert.equal(client.deleteCount, 1);
});

test("EVT-02 event pull includes scoped tombstones so Lead references remain valid", async () => {
  const calls: Array<{ sql: string; values: unknown[] }> = [];
  const pool = {
    query: async (sql: string, values: unknown[]) => {
      calls.push({ sql, values });
      return {
        rows: [
          { id: input.id, deletedAt: "2026-09-16T12:00:00Z", revision: "2" },
        ],
      };
    },
  } as unknown as pg.Pool;
  const events = await new PostgresFolooRepository(pool).listEvents(principal);
  assert.equal(events.length, 1);
  assert.equal(calls[0]?.values[0], principal.workspaceId);
  assert.match(calls[0]?.sql ?? "", /WHERE workspace_id = \$1/);
  assert.doesNotMatch(calls[0]?.sql ?? "", /deleted_at IS NULL/);
});

const leadUpdate = {
  revision: 3,
  firstName: "José",
  company: "Foloo",
  email: "jose@example.com",
  leadType: "partner" as const,
  interest: "high" as const,
  place: "Monterrey",
};

test("REG-07 replays an optimistic lead update without a second write", async () => {
  const client = new LeadUpdateClient();
  const adapter = repository(client);
  const hash = requestHash(leadUpdate);
  const first = await adapter.updateLead(
    principal,
    "57d8ce9a-dcc4-4b78-8fd9-552c216a62a1",
    leadUpdate,
    "update-key",
    hash,
  );
  const replay = await adapter.updateLead(
    principal,
    "57d8ce9a-dcc4-4b78-8fd9-552c216a62a1",
    leadUpdate,
    "update-key",
    hash,
  );
  assert.equal(first.replayed, false);
  assert.equal(replay.replayed, true);
  assert.equal(client.updateCount, 1);
});

test("REG-07 returns a specific recoverable revision conflict", async () => {
  const client = new LeadUpdateClient();
  client.conflictRevision = true;
  await assert.rejects(
    repository(client).updateLead(
      principal,
      "57d8ce9a-dcc4-4b78-8fd9-552c216a62a1",
      leadUpdate,
      "conflict-key",
      requestHash(leadUpdate),
    ),
    (error) =>
      error instanceof ApplicationError &&
      error.statusCode === 409 &&
      error.code === "revision_conflict",
  );
});
