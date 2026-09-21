import assert from "node:assert/strict";
import test from "node:test";

import { acceptedProviderPayload } from "../src/email/provider_lambda.js";

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
