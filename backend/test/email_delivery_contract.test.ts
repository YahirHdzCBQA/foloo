import assert from "node:assert/strict";
import test from "node:test";

import {
  GMAIL_MESSAGE_LIMIT,
  GOOGLE_SCOPES,
  MICROSOFT_SCOPES,
  classifyProviderHttpStatus,
  incompatibleAttachments,
  maskedAddress,
} from "../src/domain/email_follow_ups.js";

const attachment = (id: string, byteSize: number, available = true) => ({
  id,
  name: `${id}.pdf`,
  byteSize,
  contentType: "application/pdf" as const,
  available,
  storageObjectKey: available ? `private/${id}` : null,
});

test("Microsoft uses Mail.Send least privilege and rejects large simple attachments", () => {
  assert.ok(MICROSOFT_SCOPES.includes("Mail.Send"));
  assert.ok(MICROSOFT_SCOPES.includes("offline_access"));
  assert.equal(
    MICROSOFT_SCOPES.some((scope) => /Mail\.Read/i.test(scope)),
    false,
  );
  assert.deepEqual(
    incompatibleAttachments("microsoft", [attachment("large", 3_000_000)]),
    [{ unavailableIds: ["large"], reason: "provider_limit" }],
  );
});

test("Google requests gmail.send only and accounts for MIME base64 overhead", () => {
  assert.ok(
    GOOGLE_SCOPES.includes("https://www.googleapis.com/auth/gmail.send"),
  );
  assert.equal(
    GOOGLE_SCOPES.some((scope) => /gmail\.read/i.test(scope)),
    false,
  );
  const raw = Math.ceil(GMAIL_MESSAGE_LIMIT * 0.76);
  assert.equal(
    incompatibleAttachments("google", [attachment("oversized", raw)])[0]
      ?.reason,
    "provider_limit",
  );
});

test("missing historical content is never silently omitted", () => {
  assert.deepEqual(
    incompatibleAttachments("google", [attachment("gone", 10, false)]),
    [{ unavailableIds: ["gone"], reason: "missing" }],
  );
});

test("safe connection metadata masks addresses", () => {
  assert.equal(maskedAddress("seller@example.com"), "se***@example.com");
});

test("provider responses separate accepted, revoked and safe retry outcomes", () => {
  assert.equal(classifyProviderHttpStatus(202), "accepted");
  assert.equal(classifyProviderHttpStatus(401), "reconnect_required");
  assert.equal(classifyProviderHttpStatus(403), "reconnect_required");
  assert.equal(classifyProviderHttpStatus(429), "safe_retry");
  assert.equal(classifyProviderHttpStatus(503), "safe_retry");
  assert.equal(classifyProviderHttpStatus(400), "rejected");
});
