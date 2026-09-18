import assert from "node:assert/strict";
import test from "node:test";

import { FolooApplication } from "../src/application/foloo_application.js";
import { defaultEmailTemplate } from "../src/domain/email_templates.js";
import { createRouter } from "../src/transport/router.js";
import { apiEvent, MemoryRepository } from "./helpers.js";

test("email templates are JWT workspace scoped", async () => {
  const router = createRouter(new FolooApplication(new MemoryRepository()));
  const template = defaultEmailTemplate("event", "es");
  const saved = await router(
    apiEvent({
      method: "PUT",
      path: "/v1/email/templates",
      subject: "seller-a",
      body: template,
      idempotencyKey: "template-a-1",
    }),
  );
  assert.equal(saved.statusCode, 200);
  const a = await router(
    apiEvent({ path: "/v1/email/templates", subject: "seller-a" }),
  );
  const b = await router(
    apiEvent({ path: "/v1/email/templates", subject: "seller-b" }),
  );
  assert.equal((JSON.parse(a.body!) as { data: unknown[] }).data.length, 1);
  assert.deepEqual((JSON.parse(b.body!) as { data: unknown[] }).data, []);
});

test("email route rejects unapproved template variables", async () => {
  const router = createRouter(new FolooApplication(new MemoryRepository()));
  await assert.rejects(
    () =>
      router(
        apiEvent({
          method: "PUT",
          path: "/v1/email/templates",
          subject: "seller-a",
          body: { ...defaultEmailTemplate("direct", "en"), body: "{script}" },
          idempotencyKey: "template-a-2",
        }),
      ),
    /unsupported_email_variable/,
  );
});
