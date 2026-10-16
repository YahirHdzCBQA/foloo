import assert from "node:assert/strict";
import test from "node:test";

import { followUpSenderDisplayName } from "../src/domain/email_follow_ups.js";
import {
  gmailMime,
  microsoftGraphBody,
  senderMailboxHeader,
} from "../src/email/provider_lambda.js";
import type { ProviderCommand } from "../src/email/provider_contract.js";

function command(
  overrides: Partial<Extract<ProviderCommand, { action: "send" }>> = {},
) {
  return {
    action: "send" as const,
    provider: "google" as const,
    encryptedCredentials: "ciphertext",
    workspaceId: "workspace-a",
    senderAddress: "seller@example.com",
    senderDisplayName: "Yahir Hernández - Foloo",
    recipientAddress: "lead@example.com",
    subject: "Follow-up",
    plainBody: "Hello",
    htmlBody: "<p>Hello</p>",
    attachments: [],
    ...overrides,
  };
}

test("SAL-11 normalizes profile identity and rejects header injection", () => {
  assert.equal(
    followUpSenderDisplayName("  Yahir   Hernández  "),
    "Yahir Hernández - Foloo",
  );
  assert.equal(followUpSenderDisplayName(""), "Foloo");
  assert.equal(followUpSenderDisplayName(null), "Foloo");
  assert.equal(
    followUpSenderDisplayName("Seller\r\nBcc: victim@example.com"),
    "Foloo",
  );
});

test("SAL-11 Gmail uses RFC 2047 and keeps the authorized address", () => {
  const message = gmailMime(command(), []);
  assert.match(message, /^From: =\?UTF-8\?B\?.+\?= <seller@example\.com>\r$/m);
  assert.doesNotMatch(message, /Bcc:/u);
});

test("SAL-11 Graph sends best-effort name with the authorized address", () => {
  const body = microsoftGraphBody(command({ provider: "microsoft" }), []);
  assert.deepEqual(body.message.from, {
    emailAddress: {
      address: "seller@example.com",
      name: "Yahir Hernández - Foloo",
    },
  });
});

test("legacy contracts use Foloo without recalculating current profile", () => {
  assert.equal(
    senderMailboxHeader(undefined, "seller@example.com"),
    '"Foloo" <seller@example.com>',
  );
});
