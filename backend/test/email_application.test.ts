import assert from "node:assert/strict";
import test from "node:test";

import { ApplicationError } from "../src/application/errors.js";
import type { FolooRepository } from "../src/application/ports.js";
import { EmailApplication } from "../src/email/email_application.js";
import type {
  EmailRepository,
  StoredSendIntent,
} from "../src/email/email_repository.js";
import type { EmailProviderBoundary } from "../src/email/provider_invoker.js";
import type { MediaStorage } from "../src/storage/media_storage.js";

const principal = { userId: "seller-a", workspaceId: "workspace-a" };

function intent(overrides: Partial<StoredSendIntent> = {}): StoredSendIntent {
  return {
    id: "11111111-1111-4111-8111-111111111111",
    workspaceId: principal.workspaceId,
    followUpId: "22222222-2222-4222-8222-222222222222",
    connectionId: "connection-a",
    provider: "google",
    senderAddress: "seller@example.com",
    recipientAddress: "lead@example.com",
    subject: "Follow-up",
    plainBody: "Hello",
    htmlBody: "<p>Hello</p>",
    attachedContentIds: ["33333333-3333-4333-8333-333333333333"],
    omittedContentIds: [],
    status: "pending",
    errorCode: null,
    attemptCount: 0,
    encryptedCredentials: "ciphertext",
    ...overrides,
  };
}

function harness(options: {
  remoteMissing?: boolean;
  outcome?: "accepted" | "safe_retry" | "ambiguous";
  optedOut?: boolean;
}) {
  let current = intent();
  let providerCalls = 0;
  const repository = {
    connection: async () => ({
      id: "connection-a",
      provider: "google",
      senderAddress: "seller@example.com",
      status: "connected",
      updatedAt: new Date().toISOString(),
    }),
    createIntent: async () => current,
    intent: async () => current,
    isOptedOut: async () => options.optedOut ?? false,
    intentAttachments: async () => [
      {
        id: "33333333-3333-4333-8333-333333333333",
        name: "Ficha técnica.pdf",
        byteSize: 512,
        contentType: "application/pdf" as const,
        available: true,
        storageObjectKey: "private/content.pdf",
      },
    ],
    markSending: async () => {
      current = intent({ status: "sending", attemptCount: 1 });
      return current;
    },
    finishIntent: async (_principal: unknown, _id: string, update: object) => {
      current = intent({ ...current, ...update });
      return current;
    },
  } as unknown as EmailRepository;
  const providers = {
    invoke: async () => {
      providerCalls += 1;
      return { outcome: options.outcome ?? "accepted" };
    },
  } as EmailProviderBoundary;
  const media = {
    verifyContentUpload: async () => {
      if (options.remoteMissing)
        throw new ApplicationError("upload_incomplete", 409, "Missing");
    },
    authorizeDownload: async () => ({
      url: "https://signed.invalid/content",
      expiresAt: new Date().toISOString(),
    }),
  } as unknown as MediaStorage;
  const core = {
    resolvePrincipal: async () => principal,
  } as unknown as FolooRepository;
  return {
    application: new EmailApplication(
      core,
      repository,
      providers,
      media,
      "https://api.invalid",
    ),
    providerCalls: () => providerCalls,
    intent: () => current,
  };
}

test("missing S3 attachment requires an explicit decision before provider call", async () => {
  const value = harness({ remoteMissing: true });
  const result = await value.application.confirm(
    principal.userId,
    intent().followUpId,
    { intentId: intent().id },
  );
  assert.equal(result.requiresAttachmentDecision, true);
  assert.deepEqual(result.incompatibleAttachmentIds, [
    "33333333-3333-4333-8333-333333333333",
  ]);
  assert.equal(value.providerCalls(), 0);
});

test("connection response exposes masked identity and no OAuth credentials", async () => {
  const value = harness({});
  const connection = await value.application.connection(principal.userId);
  assert.equal(connection?.provider, "google");
  assert.equal(connection?.senderAddress, "se***@example.com");
  assert.equal("encryptedCredentials" in (connection ?? {}), false);
});

test("lost provider response becomes confirmation_required and is not auto-retried", async () => {
  const value = harness({ outcome: "ambiguous" });
  const result = await value.application.confirm(
    principal.userId,
    intent().followUpId,
    { intentId: intent().id },
  );
  assert.equal(result.intent.status, "confirmation_required");
  assert.equal(value.providerCalls(), 1);
  await assert.rejects(
    () => value.application.retry(principal.userId, intent().id),
    (error: unknown) =>
      error instanceof ApplicationError && error.code === "ambiguous_send",
  );
  assert.equal(value.providerCalls(), 1);
});

test("known provider refusal remains a safe-retry error", async () => {
  const value = harness({ outcome: "safe_retry" });
  const result = await value.application.confirm(
    principal.userId,
    intent().followUpId,
    { intentId: intent().id },
  );
  assert.equal(result.intent.status, "error");
  assert.equal(value.providerCalls(), 1);
});

test("provider acceptance is persisted as sent", async () => {
  const value = harness({ outcome: "accepted" });
  const result = await value.application.confirm(
    principal.userId,
    intent().followUpId,
    { intentId: intent().id },
  );
  assert.equal(result.intent.status, "sent");
  assert.equal(value.providerCalls(), 1);
});

test("two legitimate follow-ups to one address send without an unsubscribe", async () => {
  const first = harness({ outcome: "accepted" });
  const second = harness({ outcome: "accepted" });

  assert.equal(
    (
      await first.application.confirm(principal.userId, intent().followUpId, {
        intentId: intent().id,
      })
    ).intent.status,
    "sent",
  );
  assert.equal(
    (
      await second.application.confirm(principal.userId, intent().followUpId, {
        intentId: "44444444-4444-4444-8444-444444444444",
      })
    ).intent.status,
    "sent",
  );
  assert.equal(first.providerCalls() + second.providerCalls(), 2);
});

test("recipient opt-out is persisted terminal and cannot be retried", async () => {
  const value = harness({ optedOut: true });

  await assert.rejects(
    () =>
      value.application.confirm(principal.userId, intent().followUpId, {
        intentId: intent().id,
      }),
    (error: unknown) =>
      error instanceof ApplicationError && error.code === "recipient_opted_out",
  );
  assert.equal(value.intent().status, "error");
  assert.equal(value.intent().errorCode, "recipient_opted_out");
  assert.equal(value.providerCalls(), 0);
  await assert.rejects(
    () => value.application.retry(principal.userId, intent().id),
    (error: unknown) =>
      error instanceof ApplicationError &&
      error.code === "email_retry_not_allowed",
  );
  assert.equal(value.providerCalls(), 0);
});

test("attachment cancellation persists without calling a provider", async () => {
  const value = harness({ remoteMissing: true });
  const result = await value.application.cancel(principal.userId, intent().id);
  assert.equal(result.status, "error");
  assert.equal(value.providerCalls(), 0);
});

test("prepared follow-up persists the rendered subject instead of template tokens", async () => {
  let storedSubject = "";
  const core = {
    resolvePrincipal: async () => principal,
    listEmailTemplates: async () => [],
  } as unknown as FolooRepository;
  const repository = {
    followUpContext: async () => ({
      leadId: "22222222-2222-4222-8222-222222222222",
      origin: "event" as const,
      recipientAddress: "lead@example.com",
      values: {
        nombre: "Mariana",
        apellido: "",
        empresa: "Lácteos Norte",
        puesto: "",
        evento: "Expo México",
        lugar: "",
        contenido: "",
        nombreVendedor: "Yahir",
        empresaVendedor: "Foloo",
      },
      contentFileIds: [],
      contentNames: [],
      attachments: [],
    }),
    createFollowUp: async (_principal: unknown, input: { subject: string }) => {
      storedSubject = input.subject;
      return { id: "follow-up" };
    },
  } as unknown as EmailRepository;
  const providers = {
    invoke: async () => ({ outcome: "accepted" }),
  } as EmailProviderBoundary;
  const media = {} as MediaStorage;
  const application = new EmailApplication(
    core,
    repository,
    providers,
    media,
    "https://api.invalid",
  );

  await application.prepare(
    principal.userId,
    "22222222-2222-4222-8222-222222222222",
    "es",
  );

  assert.equal(storedSubject, "Damos seguimiento, Mariana");
  assert.doesNotMatch(storedSubject, /\{nombre\}/);
});

test("historical raw subjects are rendered before returning email history", async () => {
  const core = {
    resolvePrincipal: async () => principal,
  } as unknown as FolooRepository;
  const repository = {
    listFollowUps: async () => [
      {
        id: "follow-up",
        leadId: "22222222-2222-4222-8222-222222222222",
        subject: "Un gusto conocerte, {nombre}",
      },
    ],
    followUpContext: async () => ({
      leadId: "22222222-2222-4222-8222-222222222222",
      origin: "event" as const,
      recipientAddress: "lead@example.com",
      values: { nombre: "Mariana" },
      contentFileIds: [],
      contentNames: [],
      attachments: [],
    }),
  } as unknown as EmailRepository;
  const application = new EmailApplication(
    core,
    repository,
    { invoke: async () => ({ outcome: "accepted" }) } as EmailProviderBoundary,
    {} as MediaStorage,
    "https://api.invalid",
  );

  const history = (await application.list(principal.userId)) as Array<{
    subject: string;
  }>;

  assert.equal(history[0]?.subject, "Un gusto conocerte, Mariana");
});
