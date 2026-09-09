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
