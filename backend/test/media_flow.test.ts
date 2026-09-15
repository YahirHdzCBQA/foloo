/** Covers the authenticated FL-016 media lifecycle without contacting AWS. */

import assert from "node:assert/strict";
import test from "node:test";

import { S3Client } from "@aws-sdk/client-s3";

import { ApplicationError, notFound } from "../src/application/errors.js";
import { FolooApplication } from "../src/application/foloo_application.js";
import type { MediaStorage } from "../src/storage/media_storage.js";
import type {
  LeadMediaInput as MediaInput,
  LeadMediaRecord as MediaRecord,
  MediaDownloadAuthorization,
  MediaUploadAuthorization,
  Principal,
} from "../src/domain/models.js";
import { S3MediaStorage } from "../src/storage/media_storage.js";
import { createRouter } from "../src/transport/router.js";
import { apiEvent, MemoryRepository } from "./helpers.js";

const leadId = "57d8ce9a-dcc4-4b78-8fd9-552c216a62a1";
const media: MediaInput = {
  id: "63b21d9f-8532-4ca0-b45e-cf8336bb807c",
  kind: "business_card",
  contentType: "image/jpeg",
  byteSize: 42,
  capturedAt: "2026-09-09T10:00:00Z",
};

class MediaRepository extends MemoryRepository {
  readonly leadOwner = new Map([[leadId, "workspace-subject-a"]]);
  readonly records = new Map<string, MediaRecord>();
  confirmCalls = 0;

  override async prepareLeadMedia(
    principal: Principal,
    targetLeadId: string,
    input: MediaInput,
    objectKey: string,
  ) {
    if (this.leadOwner.get(targetLeadId) !== principal.workspaceId) {
      throw notFound("Lead");
    }
    this.records.set(input.id, {
      ...input,
      storageObjectKey: objectKey,
      uploadStatus: "pending",
      uploadedAt: null,
      revision: 1,
    });
  }

  override async listLeadMedia(principal: Principal, targetLeadId: string) {
    if (this.leadOwner.get(targetLeadId) !== principal.workspaceId) {
      return [];
    }
    return [...this.records.values()];
  }

  override async createLeadMedia(
    principal: Principal,
    targetLeadId: string,
    input: MediaInput,
    _key: string,
    _hash: string,
    objectKey: string,
  ) {
    if (this.leadOwner.get(targetLeadId) !== principal.workspaceId) {
      throw notFound("Lead");
    }
    this.confirmCalls += 1;
    const value: MediaRecord = {
      ...input,
      storageObjectKey: objectKey,
      uploadStatus: "available",
      uploadedAt: "2026-09-11T12:00:00Z",
      revision: 1,
    };
    this.records.set(input.id, value);
    return { value, replayed: this.confirmCalls > 1 };
  }
}

class FakeMediaStorage implements MediaStorage {
  verified: string[] = [];

  objectKey(principal: Principal, targetLeadId: string, mediaId: string) {
    return `media/workspaces/${principal.workspaceId}/leads/${targetLeadId}/${mediaId}`;
  }

  async authorizeUpload(
    _principal: Principal,
    _targetLeadId: string,
    input: MediaInput,
  ): Promise<MediaUploadAuthorization> {
    return {
      mediaId: input.id,
      upload: {
        method: "PUT",
        url: "https://private.example/upload?signature=secret",
        expiresAt: "2026-09-11T12:10:00Z",
        headers: {
          "content-type": input.contentType,
          "x-amz-meta-foloo-media-id": input.id,
        },
      },
    };
  }

  async verifyUpload(objectKey: string) {
    this.verified.push(objectKey);
  }

  async authorizeDownload(): Promise<MediaDownloadAuthorization> {
    return {
      url: "https://private.example/download?signature=secret",
      expiresAt: "2026-09-11T12:05:00Z",
    };
  }
}

test("authorization derives a deterministic key and confirmation verifies it", async () => {
  const repository = new MediaRepository();
  const storage = new FakeMediaStorage();
  const application = new FolooApplication(repository, storage);

  const authorization = await application.prepareLeadMediaUpload(
    "subject-a",
    leadId,
    media,
  );
  assert.equal(authorization.mediaId, media.id);
  assert.equal(
    repository.records.get(media.id)?.storageObjectKey,
    `media/workspaces/workspace-subject-a/leads/${leadId}/${media.id}`,
  );

  await application.createLeadMedia(
    "subject-a",
    leadId,
    media,
    "stable-key",
    "stable-hash",
  );
  assert.deepEqual(storage.verified, [
    `media/workspaces/workspace-subject-a/leads/${leadId}/${media.id}`,
  ]);
  assert.equal(repository.records.get(media.id)?.uploadStatus, "available");
});

test("cross-user upload authorization cannot address another user's lead", async () => {
  const application = new FolooApplication(
    new MediaRepository(),
    new FakeMediaStorage(),
  );
  await assert.rejects(
    application.prepareLeadMediaUpload("subject-b", leadId, media),
    (error: unknown) =>
      error instanceof Error && error.message === "Lead was not found.",
  );
});

test("GET returns temporary read access but never exposes the object key", async () => {
  const repository = new MediaRepository();
  const storage = new FakeMediaStorage();
  const application = new FolooApplication(repository, storage);
  await application.prepareLeadMediaUpload("subject-a", leadId, media);
  await application.createLeadMedia(
    "subject-a",
    leadId,
    media,
    "stable-key",
    "stable-hash",
  );
  const items = await application.leadMedia("subject-a", leadId);
  assert.equal(items.length, 1);
  assert.equal("storageObjectKey" in items[0]!, false);
  assert.match(
    items[0]!.download!.url,
    /^https:\/\/private\.example\/download/,
  );
});

test("S3 key construction ignores filenames and client-provided storage keys", () => {
  const storage = new S3MediaStorage("private-bucket");
  const principal: Principal = {
    subject: "subject-a",
    userId: "user-a",
    accountId: "account-a",
    workspaceId: "workspace-a",
  };
  assert.equal(
    storage.objectKey(principal, leadId, media.id),
    `media/workspaces/workspace-a/leads/${leadId}/${media.id}`,
  );
});

test("presigned PUT binds exactly the headers Flutter must send", async () => {
  const client = new S3Client({
    region: "us-east-1",
    requestChecksumCalculation: "WHEN_REQUIRED",
    credentials: {
      accessKeyId: "FAKE_ACCESS_KEY",
      secretAccessKey: "FAKE_SECRET_KEY",
    },
  });
  const authorization = await new S3MediaStorage(
    "private-test-bucket",
    client,
  ).authorizeUpload(
    {
      subject: "subject-a",
      userId: "user-a",
      accountId: "account-a",
      workspaceId: "workspace-a",
    },
    leadId,
    media,
  );
  const url = new URL(authorization.upload.url);

  assert.equal(
    url.searchParams.get("X-Amz-SignedHeaders"),
    "content-length;content-type;host;x-amz-meta-foloo-media-id",
  );
  assert.equal(url.searchParams.has("x-amz-meta-foloo-media-id"), false);
  assert.equal(url.searchParams.has("x-amz-checksum-crc32"), false);
  assert.equal(url.searchParams.has("x-amz-sdk-checksum-algorithm"), false);
  assert.deepEqual(authorization.upload.headers, {
    "content-type": media.contentType,
    "x-amz-meta-foloo-media-id": media.id,
  });
});

test("S3 confirmation verifies metadata and the actual JPEG signature", async () => {
  const commands: string[] = [];
  let getCount = 0;
  const client = {
    send: async (command: object) => {
      commands.push(command.constructor.name);
      if (command.constructor.name === "HeadObjectCommand") {
        return {
          ContentLength: media.byteSize,
          ContentType: media.contentType,
          Metadata: { "foloo-media-id": media.id },
        };
      }
      getCount += 1;
      return {
        Body: {
          transformToByteArray: async () =>
            getCount === 1
              ? Uint8Array.from([0xff, 0xd8, 0xff, 0xe0])
              : Uint8Array.from([0xff, 0xd9]),
        },
      };
    },
  } as unknown as S3Client;
  const storage = new S3MediaStorage("private-bucket", client);

  await storage.verifyUpload("derived/key", media);

  assert.deepEqual(commands, [
    "HeadObjectCommand",
    "GetObjectCommand",
    "GetObjectCommand",
  ]);
});

test("S3 confirmation accepts a valid reference-image JPEG", async () => {
  const reference: MediaInput = { ...media, kind: "reference_image" };
  await new S3MediaStorage(
    "private-bucket",
    verificationClient({ input: reference }),
  ).verifyUpload("derived/key", reference);
});

test("S3 confirmation rejects missing or disguised objects", async () => {
  const missingClient = {
    send: async () => {
      throw Object.assign(new Error("missing"), { name: "NoSuchKey" });
    },
  } as unknown as S3Client;
  await assert.rejects(
    new S3MediaStorage("private-bucket", missingClient).verifyUpload(
      "derived/key",
      media,
    ),
    (error: unknown) =>
      error instanceof ApplicationError && error.code === "upload_incomplete",
  );

  const disguisedClient = {
    send: async (command: object) =>
      command.constructor.name === "HeadObjectCommand"
        ? {
            ContentLength: media.byteSize,
            ContentType: media.contentType,
            Metadata: { "foloo-media-id": media.id },
          }
        : {
            Body: {
              transformToByteArray: async () => Uint8Array.from([1, 2, 3, 4]),
            },
          },
  } as unknown as S3Client;
  await assert.rejects(
    new S3MediaStorage("private-bucket", disguisedClient).verifyUpload(
      "derived/key",
      media,
    ),
    (error: unknown) =>
      error instanceof ApplicationError &&
      error.code === "invalid_media_content" &&
      error.diagnosticCode === "invalid_jpeg_signature",
  );
});

test("S3 confirmation identifies PNG mislabeled as JPEG", async () => {
  const client = verificationClient({
    beginning: [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
  });
  await assert.rejects(
    new S3MediaStorage("private-bucket", client).verifyUpload(
      "derived/key",
      media,
    ),
    (error: unknown) =>
      error instanceof ApplicationError &&
      error.code === "invalid_media_content" &&
      error.diagnosticCode === "unsupported_image_format",
  );
});

test("S3 confirmation rejects a JPEG with no end marker", async () => {
  const client = verificationClient({
    beginning: [0xff, 0xd8, 0xff, 0xe0],
    ending: [0x00, 0x00],
  });
  await assert.rejects(
    new S3MediaStorage("private-bucket", client).verifyUpload(
      "derived/key",
      media,
    ),
    (error: unknown) =>
      error instanceof ApplicationError &&
      error.diagnosticCode === "invalid_jpeg_signature",
  );
});

test("S3 confirmation accepts the supported M4A container", async () => {
  const voice: MediaInput = {
    ...media,
    kind: "voice_note",
    contentType: "audio/m4a",
    byteSize: 64,
    durationMs: 1000,
  };
  const client = verificationClient({
    input: voice,
    beginning: [0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70, 0x4d, 0x34, 0x41, 0x20],
  });

  await new S3MediaStorage("private-bucket", client).verifyUpload(
    "derived/key",
    voice,
  );
});

test("S3 confirmation reports exact safe metadata and MIME mismatches", async () => {
  for (const [head, expected] of [
    [{ ContentType: "image/png" }, "content_type_mismatch"],
    [{ Metadata: { "foloo-media-id": "wrong" } }, "metadata_mismatch"],
    [{ ContentLength: media.byteSize + 1 }, "size_mismatch"],
  ] as const) {
    const client = verificationClient({ head });
    await assert.rejects(
      new S3MediaStorage("private-bucket", client).verifyUpload(
        "derived/key",
        media,
      ),
      (error: unknown) =>
        error instanceof ApplicationError &&
        error.code === "upload_mismatch" &&
        error.diagnosticCode === expected,
    );
  }
});

function verificationClient({
  input = media,
  beginning = [0xff, 0xd8, 0xff, 0xe0],
  ending = [0xff, 0xd9],
  head = {},
}: {
  input?: MediaInput;
  beginning?: number[];
  ending?: number[];
  head?: Record<string, unknown>;
}): S3Client {
  let getCount = 0;
  return {
    send: async (command: object) => {
      if (command.constructor.name === "HeadObjectCommand") {
        return {
          ContentLength: input.byteSize,
          ContentType: input.contentType,
          Metadata: { "foloo-media-id": input.id },
          ...head,
        };
      }
      getCount += 1;
      return {
        Body: {
          transformToByteArray: async () =>
            Uint8Array.from(getCount === 1 ? beginning : ending),
        },
      };
    },
  } as unknown as S3Client;
}

test("router rejects a non-UUID lead path before any media operation", async () => {
  const router = createRouter(
    new FolooApplication(new MediaRepository(), new FakeMediaStorage()),
  );
  await assert.rejects(
    router(
      apiEvent({
        method: "POST",
        path: "/v1/leads/not-a-uuid/media/uploads",
        subject: "subject-a",
        body: media,
      }),
    ),
  );
});
