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

test("media rejects unknown kinds, incompatible MIME types and technical oversize", () => {
  const base = {
    id: "63b21d9f-8532-4ca0-b45e-cf8336bb807c",
    kind: "business_card",
    contentType: "image/jpeg",
    byteSize: 42,
    capturedAt: "2026-09-09T10:00:00Z",
  };
  assert.equal(
    mediaSchema.safeParse({ ...base, kind: "avatar" }).success,
    false,
  );
  assert.equal(
    mediaSchema.safeParse({ ...base, contentType: "image/png" }).success,
    false,
  );
  assert.equal(
    mediaSchema.safeParse({ ...base, byteSize: 25 * 1024 * 1024 + 1 }).success,
    false,
  );
  assert.equal(
    mediaSchema.safeParse({
      ...base,
      kind: "voice_note",
      contentType: "audio/m4a",
      byteSize: 100 * 1024 * 1024 + 1,
    }).success,
    false,
  );
  assert.equal(
    mediaSchema.safeParse({ ...base, id: "not-a-uuid" }).success,
    false,
  );
});

test("accepts the exact UTC Flutter media payload and rejects the shipped naive timestamp", () => {
  const flutterPayload = {
    id: "3c395e18-8734-4532-b918-841e1b0659ce",
    kind: "business_card",
    contentType: "image/jpeg",
    byteSize: 12345,
    capturedAt: "2026-09-14T18:34:56.000Z",
    durationMs: null,
  };
  assert.equal(mediaSchema.safeParse(flutterPayload).success, true);
  assert.equal(
    mediaSchema.safeParse({
      ...flutterPayload,
      capturedAt: "2026-09-14T12:34:56.000",
    }).success,
    false,
  );
});
