/** Covers runtime validation for the initial event, lead and media contracts. */

import assert from "node:assert/strict";
import test from "node:test";

import {
  eventSchema,
  leadSchema,
  mediaSchema,
} from "../src/transport/schemas.js";

test("accepts stable offline UUID and valid event dates", () => {
  const id = "f225b79b-2504-4a5f-94f8-f8db264aa9e5";
  assert.equal(
    eventSchema.parse({
      id,
      name: "Expo",
      startsAt: "2026-09-09T10:00:00-06:00",
      endsAt: "2026-09-10T10:00:00-06:00",
    }).id,
    id,
  );
});

test("rejects an event whose end precedes its start", () => {
  assert.equal(
    eventSchema.safeParse({
      id: "f225b79b-2504-4a5f-94f8-f8db264aa9e5",
      name: "Expo",
      startsAt: "2026-09-10T10:00:00Z",
      endsAt: "2026-09-09T10:00:00Z",
    }).success,
    false,
  );
});

test("enforces lead origin and contact invariants", () => {
  const base = {
    id: "57d8ce9a-dcc4-4b78-8fd9-552c216a62a1",
    capturedAt: "2026-09-09T10:00:00Z",
    origin: "event",
    firstName: "Ada",
    company: "Foloo",
    leadType: "customer",
    interest: "high",
  };
  assert.equal(leadSchema.safeParse(base).success, false);
  assert.equal(
    leadSchema.safeParse({
      ...base,
      eventId: "41af18b2-6357-4fa4-8104-d27768d9d563",
      email: "ada@example.com",
    }).success,
    true,
  );
});

test("media accepts metadata but exposes no binary or client storage key", () => {
  const result = mediaSchema.safeParse({
    id: "63b21d9f-8532-4ca0-b45e-cf8336bb807c",
    kind: "voice_note",
    contentType: "audio/m4a",
    byteSize: 42,
    capturedAt: "2026-09-09T10:00:00Z",
    binary: "no",
    storageObjectKey: "spoofed",
  });
  assert.equal(result.success, true);
  if (result.success) {
    assert.equal("binary" in result.data, false);
    assert.equal("storageObjectKey" in result.data, false);
  }
});
