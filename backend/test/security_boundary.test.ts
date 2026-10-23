/** Verifies JWT-sub ownership and isolation without real Cognito identities. */

import assert from "node:assert/strict";
import test from "node:test";

import { ApplicationError, unauthorized } from "../src/application/errors.js";
import { FolooApplication } from "../src/application/foloo_application.js";
import { createApiClientAccessGuard } from "../src/auth/api_client_access_guard.js";
import { authenticatedSubject } from "../src/auth/authenticated_identity.js";
import { webQaSubjectHash } from "../src/auth/web_qa_identity.js";
import { createRouter } from "../src/transport/router.js";
import { apiEvent, MemoryRepository } from "./helpers.js";

const issuer =
  "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_synthetic";
const fixedNow = new Date("2026-10-22T12:00:00Z");

function guardedEvent(input: {
  subject?: string;
  clientId?: string;
  tokenUse?: string;
  tokenIssuer?: string;
  expiresAt?: number;
  path?: string;
  method?: string;
}) {
  const event = apiEvent({
    subject: input.subject ?? "synthetic-subject-a",
    path: input.path,
    method: input.method,
  });
  event.requestContext.authorizer.jwt.claims = {
    sub: input.subject ?? "synthetic-subject-a",
    token_use: input.tokenUse ?? "access",
    client_id: input.clientId ?? "mobile-client",
    iss: input.tokenIssuer ?? issuer,
    exp: input.expiresAt ?? Math.floor(fixedNow.getTime() / 1000) + 60,
  };
  return event;
}

function clientGuard(
  options: {
    enabled?: boolean;
    allowedSubjects?: readonly string[];
  } = {},
) {
  return createApiClientAccessGuard(
    {
      issuer,
      mobileClientId: "mobile-client",
      webClientId: "web-client",
      webSessionsEnabled: options.enabled ?? false,
      allowedWebSubjectHashes: new Set(
        (options.allowedSubjects ?? []).map(webQaSubjectHash),
      ),
    },
    () => fixedNow,
  );
}

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

test("AUT-18 mobile access tokens keep access while Web Sessions are disabled", () => {
  assert.doesNotThrow(() =>
    clientGuard().assertAllowed(guardedEvent({ clientId: "mobile-client" })),
  );
});

test("AUT-18 web access requires enabled sessions and the QA subject allowlist", () => {
  const event = guardedEvent({
    clientId: "web-client",
    path: "/v1/profile",
  });
  assert.throws(() => clientGuard().assertAllowed(event));
  assert.throws(() =>
    clientGuard({
      enabled: true,
      allowedSubjects: ["other-subject"],
    }).assertAllowed(event),
  );
  assert.doesNotThrow(() =>
    clientGuard({
      enabled: true,
      allowedSubjects: ["synthetic-subject-a"],
    }).assertAllowed(event),
  );
});

test("AUT-18 API client guard rejects untrusted JWT claim combinations", () => {
  const guard = clientGuard({
    enabled: true,
    allowedSubjects: ["synthetic-subject-a"],
  });
  const expired = Math.floor(fixedNow.getTime() / 1000);
  for (const event of [
    guardedEvent({ tokenUse: "id" }),
    guardedEvent({ tokenIssuer: "https://issuer.invalid" }),
    guardedEvent({ expiresAt: expired }),
    guardedEvent({ subject: "" }),
    guardedEvent({ clientId: "unknown-client" }),
  ]) {
    assert.throws(() => guard.assertAllowed(event));
  }

  const missingClientId = guardedEvent({});
  delete missingClientId.requestContext.authorizer.jwt.claims.client_id;
  missingClientId.requestContext.authorizer.jwt.claims.aud = "mobile-client";
  assert.throws(() => guard.assertAllowed(missingClientId));
});

test("AUT-18 headers cannot spoof client identity or QA authorization", () => {
  const event = guardedEvent({ clientId: "web-client" });
  event.headers = {
    "x-cognito-client-id": "mobile-client",
    "x-foloo-subject": "allowed-subject",
  };
  assert.throws(() =>
    clientGuard({
      enabled: true,
      allowedSubjects: ["allowed-subject"],
    }).assertAllowed(event),
  );
});

test("AUT-18 only explicit unauthenticated API contracts bypass the client guard", () => {
  const guard = clientGuard();
  const receipt = apiEvent({
    method: "POST",
    path: "/v1/account-deletion-status",
  });
  const callback = apiEvent({
    method: "GET",
    path: "/v1/email/oauth/callback/google",
  });
  assert.doesNotThrow(() => guard.assertAllowed(receipt));
  assert.doesNotThrow(() => guard.assertAllowed(callback));
  // MON-16: Stripe signs the webhook; it never carries a Cognito JWT.
  assert.doesNotThrow(() =>
    guard.assertAllowed(
      apiEvent({ method: "POST", path: "/v1/billing/webhook" }),
    ),
  );
  assert.throws(() =>
    guard.assertAllowed(
      apiEvent({ method: "POST", path: "/v1/billing/checkout-session" }),
    ),
  );
  assert.throws(() => guard.assertAllowed(apiEvent({ path: "/v1/events" })));
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

test("REG-18 delete is authenticated, revisioned and owner scoped", async () => {
  const repository = new MemoryRepository();
  const router = createRouter(new FolooApplication(repository));
  const response = await router(
    apiEvent({
      method: "DELETE",
      path: "/v1/leads/57d8ce9a-dcc4-4b78-8fd9-552c216a62a1",
      subject: "subject-a",
      idempotencyKey: "delete-lead-key-a",
      body: { revision: 2 },
    }),
  );
  assert.equal(response.statusCode, 200);
  assert.deepEqual(repository.seenSubjects, ["subject-a"]);
  assert.match(response.body ?? "", /deletedAt/);
});

test("INF-18 an old JWT from a second device cannot sync leads, media or content", async () => {
  const repository = new MemoryRepository();
  const guarded: string[] = [];
  const router = createRouter(
    new FolooApplication(repository),
    undefined,
    undefined,
    {
      async assertActive(subject: string) {
        guarded.push(subject);
        throw new ApplicationError(
          "account_deletion_pending",
          423,
          "Account deletion is pending.",
        );
      },
    },
  );
  for (const path of [
    "/v1/leads",
    "/v1/leads/57d8ce9a-dcc4-4b78-8fd9-552c216a62a1/media",
    "/v1/content",
    "/v1/sync/pull",
  ]) {
    await assert.rejects(
      router(
        apiEvent({
          method: "POST",
          path,
          subject: "deleted-owner-device-two",
          idempotencyKey: "second-device-key",
          body: {},
        }),
      ),
      (error) =>
        (error as { code?: string }).code === "account_deletion_pending",
    );
  }
  assert.equal(guarded.length, 4);
  assert.deepEqual(repository.seenSubjects, []);
});
