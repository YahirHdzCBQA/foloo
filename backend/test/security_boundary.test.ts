/** Verifies JWT-sub ownership and isolation without real Cognito identities. */

import assert from "node:assert/strict";
import test from "node:test";

import { unauthorized } from "../src/application/errors.js";
import { FolooApplication } from "../src/application/foloo_application.js";
import { authenticatedSubject } from "../src/auth/authenticated_identity.js";
import { createRouter } from "../src/transport/router.js";
import { apiEvent, MemoryRepository } from "./helpers.js";

test("rejects an event without verified JWT sub", () => {
  assert.throws(
    () => authenticatedSubject(apiEvent()),
    (error) =>
      error instanceof Error && error.message === unauthorized().message,
  );
});

test("rejects an ID token even when it contains a subject", () => {
  const event = apiEvent({ subject: "subject-a" });
  event.requestContext.authorizer.jwt.claims.token_use = "id";
  assert.throws(() => authenticatedSubject(event));
});

test("ignores spoofed owner fields and derives ownership from JWT sub", async () => {
  const repository = new MemoryRepository();
  const router = createRouter(new FolooApplication(repository));
  const response = await router(
    apiEvent({
      method: "POST",
      path: "/v1/events",
      subject: "subject-a",
      idempotencyKey: "request-key-a",
      body: {
        id: "f225b79b-2504-4a5f-94f8-f8db264aa9e5",
        name: "Expo",
        startsAt: "2026-09-09T10:00:00Z",
        endsAt: "2026-09-10T10:00:00Z",
        ownerId: "subject-b",
        workspaceId: "workspace-subject-b",
      },
    }),
  );
  assert.equal(response.statusCode, 201);
  assert.deepEqual(repository.seenSubjects, ["subject-a"]);
  assert.equal(repository.eventsByWorkspace.has("workspace-subject-a"), true);
  assert.equal(repository.eventsByWorkspace.has("workspace-subject-b"), false);
});

test("keeps user A and user B event lists isolated", async () => {
  const repository = new MemoryRepository();
  repository.eventsByWorkspace.set("workspace-subject-a", [{ id: "event-a" }]);
  repository.eventsByWorkspace.set("workspace-subject-b", [{ id: "event-b" }]);
  const router = createRouter(new FolooApplication(repository));
  const a = await router(
    apiEvent({ path: "/v1/events", subject: "subject-a" }),
  );
  const b = await router(
    apiEvent({ path: "/v1/events", subject: "subject-b" }),
  );
  assert.match(a.body ?? "", /event-a/);
  assert.doesNotMatch(a.body ?? "", /event-b/);
  assert.match(b.body ?? "", /event-b/);
});

test("EVT-02 update/delete remain scoped to JWT owner and expose numeric revisions", async () => {
  const repository = new MemoryRepository();
  const id = "f225b79b-2504-4a5f-94f8-f8db264aa9e5";
  repository.eventsByWorkspace.set("workspace-subject-a", [
    { id, name: "M�xico", revision: "1" },
  ]);
  const router = createRouter(new FolooApplication(repository));
  const listed = await router(
    apiEvent({ path: "/v1/events", subject: "subject-a" }),
  );
  assert.equal(
    (JSON.parse(listed.body ?? "{}") as { data: Array<{ revision: number }> })
      .data[0]?.revision,
    1,
  );
  const update = await router(
    apiEvent({
      method: "PUT",
      path: `/v1/events/${id}`,
      subject: "subject-a",
      idempotencyKey: "event-update-key",
      body: {
        revision: 1,
        name: "México",
        startsAt: "2026-09-16T10:00:00Z",
        endsAt: "2026-09-17T10:00:00Z",
        ownerId: "subject-b",
      },
    }),
  );
  assert.equal(update.statusCode, 200);
  assert.match(update.body ?? "", /México/);
  assert.doesNotMatch(update.body ?? "", /subject-b/);
  const deleted = await router(
    apiEvent({
      method: "DELETE",
      path: `/v1/events/${id}`,
      subject: "subject-a",
      idempotencyKey: "event-delete-key",
      body: { revision: 2 },
    }),
  );
  assert.equal(deleted.statusCode, 200);
  assert.equal(
    repository.eventsByWorkspace.get("workspace-subject-a")?.length,
    0,
  );
  assert.equal(repository.eventsByWorkspace.has("workspace-subject-b"), false);
});

test("REG-07 update derives ownership from JWT and keeps immutable fields out", async () => {
  const repository = new MemoryRepository();
  const router = createRouter(new FolooApplication(repository));
  const response = await router(
    apiEvent({
      method: "PUT",
      path: "/v1/leads/57d8ce9a-dcc4-4b78-8fd9-552c216a62a1",
      subject: "subject-a",
      idempotencyKey: "update-key-a",
      body: {
        revision: 1,
        firstName: "Ada",
        company: "Foloo",
        email: "ada@example.com",
        leadType: "customer",
        interest: "high",
        ownerId: "subject-b",
        capturedAt: "2000-01-01T00:00:00Z",
      },
    }),
  );
  assert.equal(response.statusCode, 200);
  assert.deepEqual(repository.seenSubjects, ["subject-a"]);
  assert.doesNotMatch(response.body ?? "", /subject-b|capturedAt/);
});
