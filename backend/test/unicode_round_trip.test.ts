/** Proves Unicode survives API parsing, validation, storage and response JSON. */

import assert from "node:assert/strict";
import test from "node:test";

import { FolooApplication } from "../src/application/foloo_application.js";
import { createRouter } from "../src/transport/router.js";
import { apiEvent, MemoryRepository } from "./helpers.js";

const unicodeText =
  "MÉXICO · José Álvarez · León, Guanajuato · Niñez y pingüino · " +
  "¿Información? · ¡Hola! · España · São Paulo";
const eventPayload = {
  id: "b9174606-f614-4f11-975b-d5a777427605",
  name: unicodeText,
  startsAt: "2026-09-15T10:00:00Z",
  endsAt: "2026-09-16T10:00:00Z",
};

test("RNF-06 request, validation, repository and response preserve Unicode", async () => {
  const repository = new MemoryRepository();
  const router = createRouter(new FolooApplication(repository));

  const createResponse = await router(
    apiEvent({
      method: "POST",
      path: "/v1/events",
      subject: "unicode-owner",
      idempotencyKey: "unicode-event-request",
      body: eventPayload,
    }),
  );

  assert.equal(createResponse.statusCode, 201);
  assert.equal(
    (JSON.parse(createResponse.body ?? "{}") as { data: { name: string } }).data
      .name,
    unicodeText,
  );
  assert.equal(
    (
      repository.eventsByWorkspace.get("workspace-unicode-owner")?.[0] as {
        name: string;
      }
    ).name,
    unicodeText,
  );

  const listResponse = await router(
    apiEvent({ path: "/v1/events", subject: "unicode-owner" }),
  );
  assert.equal(
    (
      JSON.parse(listResponse.body ?? "{}") as {
        data: Array<{ name: string }>;
      }
    ).data[0]?.name,
    unicodeText,
  );
  assert.equal(
    listResponse.headers?.["content-type"],
    "application/json; charset=utf-8",
  );
});

test("RNF-06 base64 API Gateway bodies decode explicitly as UTF-8", async () => {
  const repository = new MemoryRepository();
  const router = createRouter(new FolooApplication(repository));
  const event = apiEvent({
    method: "POST",
    path: "/v1/events",
    subject: "unicode-owner",
    idempotencyKey: "unicode-base64-request",
  });
  event.body = Buffer.from(JSON.stringify(eventPayload), "utf8").toString(
    "base64",
  );
  event.isBase64Encoded = true;

  const response = await router(event);

  assert.equal(response.statusCode, 201);
  assert.equal(
    (JSON.parse(response.body ?? "{}") as { data: { name: string } }).data.name,
    unicodeText,
  );
});
