import assert from "node:assert/strict";
import test from "node:test";

import {
  acceptedProviderPayload,
  authorizationPrompt,
} from "../src/email/provider_lambda.js";

test("OAuth connect/change-account explicitly shows the provider account chooser", () => {
  assert.equal(authorizationPrompt("microsoft"), "select_account");
  assert.equal(authorizationPrompt("google"), "select_account consent");
});

test("Microsoft Graph 202 with an empty body is accepted without JSON parsing", async () => {
  const payload = await acceptedProviderPayload({
    status: 202,
    text: async () => "",
  });
  assert.deepEqual(payload, {});
});

test("Gmail success keeps the provider message id", async () => {
  const payload = await acceptedProviderPayload({
    status: 200,
    text: async () => JSON.stringify({ id: "gmail-message" }),
  });
  assert.equal(payload.id, "gmail-message");
});
