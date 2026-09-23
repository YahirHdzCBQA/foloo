/** Verifies FL-019.5 no longer exposes unsubscribe as a public route. */

import assert from "node:assert/strict";
import test from "node:test";

import type { FolooRepository } from "../src/application/ports.js";
import { EmailApplication } from "../src/email/email_application.js";
import type { EmailRepository } from "../src/email/email_repository.js";
import type { EmailProviderBoundary } from "../src/email/provider_invoker.js";
import type { MediaStorage } from "../src/storage/media_storage.js";
import { createRouter } from "../src/transport/router.js";
import { FolooApplication } from "../src/application/foloo_application.js";
import { apiEvent, MemoryRepository } from "./helpers.js";

const token = "opaque-token-with-more-than-thirty-two-characters";

function unsubscribeHarness() {
  const optedOut = new Set<string>();
  let writes = 0;
  const repository = {
    isUnsubscribeTokenValid: async () => true,
    optOut: async (hash: string) => {
      if (!optedOut.has(hash)) writes += 1;
      optedOut.add(hash);
      return true;
    },
  } as unknown as EmailRepository;
  const email = new EmailApplication(
    {} as FolooRepository,
    repository,
    {} as EmailProviderBoundary,
    {} as MediaStorage,
    "https://api.invalid",
  );
  const router = createRouter(
    new FolooApplication(new MemoryRepository()),
    email,
  );
  const request = (method: "GET" | "POST") => {
    const event = apiEvent({ method, path: "/v1/email/unsubscribe" });
    event.queryStringParameters = { token };
    return router(event);
  };
  return { request, optedOut, writes: () => writes };
}

test("GET unsubscribe is no longer handled as a public endpoint", async () => {
  const value = unsubscribeHarness();
  await assert.rejects(
    () => value.request("GET"),
    /Authentication is required/,
  );
  assert.equal(value.optedOut.size, 0);
  assert.equal(value.writes(), 0);
});

test("POST unsubscribe is no longer handled as a public endpoint", async () => {
  const value = unsubscribeHarness();
  await assert.rejects(
    () => value.request("POST"),
    /Authentication is required/,
  );
  assert.equal(value.optedOut.size, 0);
  assert.equal(value.writes(), 0);
});
