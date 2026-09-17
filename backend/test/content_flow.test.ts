/** FL-018 contract tests for PDF limits, ownership and logical deletion. */

import assert from "node:assert/strict";
import test from "node:test";

import { FolooApplication } from "../src/application/foloo_application.js";
import { createRouter } from "../src/transport/router.js";
import { apiEvent, MemoryRepository } from "./helpers.js";

const id = "54a89027-51d1-4628-92ac-7210b687fc6b";
const payload = {
  id,
  displayName: "Catálogo 漢字",
  fileName: "资料.pdf",
  byteSize: 25_000_000,
  allEvents: true,
  eventIds: [],
};

test("content is owner-scoped and delete yields a durable tombstone", async () => {
  const repository = new MemoryRepository();
  const router = createRouter(new FolooApplication(repository));
  const created = await router(
    apiEvent({
      method: "POST",
      path: "/v1/content",
      subject: "a",
      body: payload,
      idempotencyKey: "create-key",
    }),
  );
  assert.equal(created.statusCode, 201);
  const other = await router(
    apiEvent({ method: "GET", path: "/v1/content", subject: "b" }),
  );
  assert.deepEqual(JSON.parse(other.body ?? "{}").data, []);
  await assert.rejects(
    router(
      apiEvent({
        method: "DELETE",
        path: `/v1/content/${id}`,
        subject: "b",
        body: { revision: 1 },
        idempotencyKey: "foreign-delete",
      }),
    ),
  );
  const deleted = await router(
    apiEvent({
      method: "DELETE",
      path: `/v1/content/${id}`,
      subject: "a",
      body: { revision: 1 },
      idempotencyKey: "delete-key",
    }),
  );
  assert.equal(deleted.statusCode, 200);
  const own = await router(
    apiEvent({ method: "GET", path: "/v1/content", subject: "a" }),
  );
  const [record] = JSON.parse(own.body ?? "{}").data as Array<{
    deletedAt: string;
  }>;
  assert.ok(record?.deletedAt);
});

test("backend rejects PDFs exceeding the V1 per-file limit", async () => {
  const router = createRouter(new FolooApplication(new MemoryRepository()));
  await assert.rejects(
    router(
      apiEvent({
        method: "POST",
        path: "/v1/content",
        subject: "a",
        body: { ...payload, byteSize: 25_000_001 },
        idempotencyKey: "oversize-key",
      }),
    ),
  );
});
