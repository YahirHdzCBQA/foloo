/** Private S3 boundary for direct media transfer authorizations and verification.
 *
 * The backend derives every object key from the authenticated workspace and
 * verifies the uploaded bytes before PostgreSQL can mark media available.
 */

import {
  GetObjectCommand,
  HeadObjectCommand,
  PutObjectCommand,
  S3Client,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

import { ApplicationError } from "../application/errors.js";
import type {
  LeadMediaInput,
  MediaDownloadAuthorization,
  MediaUploadAuthorization,
  Principal,
} from "../domain/models.js";

const uploadLifetimeSeconds = 600;
const downloadLifetimeSeconds = 300;
const mediaIdHeader = "x-amz-meta-foloo-media-id";

export interface MediaStorage {
  objectKey(principal: Principal, leadId: string, mediaId: string): string;
  authorizeUpload(
    principal: Principal,
    leadId: string,
    input: LeadMediaInput,
  ): Promise<MediaUploadAuthorization>;
  verifyUpload(objectKey: string, input: LeadMediaInput): Promise<void>;
  authorizeDownload(objectKey: string): Promise<MediaDownloadAuthorization>;
  contentObjectKey(principal: Principal, contentId: string): string;
  authorizeContentUpload(
    principal: Principal,
    contentId: string,
    byteSize: number,
  ): Promise<{ upload: MediaUploadAuthorization["upload"] }>;
  verifyContentUpload(
    objectKey: string,
    contentId: string,
    byteSize: number,
  ): Promise<void>;
}

export class S3MediaStorage implements MediaStorage {
  constructor(
    private readonly bucketName: string,
    private readonly client: S3Client = new S3Client({
      // A presign operation does not have the binary body. Do not bind the URL
      // to the SDK checksum of an empty body; S3 validates the actual media.
      requestChecksumCalculation: "WHEN_REQUIRED",
    }),
    private readonly now: () => Date = () => new Date(),
  ) {}

  objectKey(principal: Principal, leadId: string, mediaId: string): string {
    return `media/workspaces/${principal.workspaceId}/leads/${leadId}/${mediaId}`;
  }

  contentObjectKey(principal: Principal, contentId: string): string {
    return `content/workspaces/${principal.workspaceId}/files/${contentId}`;
  }

  async authorizeContentUpload(
    principal: Principal,
    contentId: string,
    byteSize: number,
  ): Promise<{ upload: MediaUploadAuthorization["upload"] }> {
    if (byteSize < 1 || byteSize > 25_000_000)
      throw invalidMedia("pdf_size_limit");
    const headers = {
      "content-type": "application/pdf",
      "x-amz-meta-foloo-content-id": contentId,
    };
    const url = await getSignedUrl(
      this.client,
      new PutObjectCommand({
        Bucket: this.bucketName,
        Key: this.contentObjectKey(principal, contentId),
        ContentType: "application/pdf",
        ContentLength: byteSize,
        Metadata: { "foloo-content-id": contentId },
      }),
      {
        expiresIn: uploadLifetimeSeconds,
        signableHeaders: new Set(["content-type"]),
        unhoistableHeaders: new Set(["x-amz-meta-foloo-content-id"]),
      },
    );
    return {
      upload: {
        method: "PUT",
        url,
        expiresAt: new Date(
          this.now().getTime() + uploadLifetimeSeconds * 1000,
        ).toISOString(),
        headers,
      },
    };
  }

  async verifyContentUpload(
    objectKey: string,
    contentId: string,
    byteSize: number,
  ): Promise<void> {
    try {
      const head = await this.client.send(
        new HeadObjectCommand({ Bucket: this.bucketName, Key: objectKey }),
      );
      if (
        head.ContentLength !== byteSize ||
        head.ContentType !== "application/pdf" ||
        head.Metadata?.["foloo-content-id"] !== contentId
      ) {
        throw uploadMismatch("pdf_metadata_mismatch");
      }
      const first = await this.client.send(
        new GetObjectCommand({
          Bucket: this.bucketName,
          Key: objectKey,
          Range: "bytes=0-4",
        }),
      );
      const bytes = await first.Body?.transformToByteArray();
      if (!bytes || Buffer.from(bytes).toString("ascii") !== "%PDF-") {
        throw invalidMedia("invalid_pdf_signature");
      }
    } catch (error) {
      if (error instanceof ApplicationError) throw error;
      const name = (error as { name?: unknown } | null)?.name;
      if (name === "NotFound" || name === "NoSuchKey") {
        throw new ApplicationError(
          "upload_incomplete",
          409,
          "The PDF upload has not completed.",
        );
      }
      throw error;
    }
  }

  async authorizeUpload(
    principal: Principal,
    leadId: string,
    input: LeadMediaInput,
  ): Promise<MediaUploadAuthorization> {
    const key = this.objectKey(principal, leadId, input.id);
    const headers = {
      "content-type": input.contentType,
      [mediaIdHeader]: input.id,
    };
    const url = await getSignedUrl(
      this.client,
      new PutObjectCommand({
        Bucket: this.bucketName,
        Key: key,
        ContentType: input.contentType,
        ContentLength: input.byteSize,
        Metadata: { "foloo-media-id": input.id },
      }),
      {
        expiresIn: uploadLifetimeSeconds,
        signableHeaders: new Set(["content-type"]),
        unhoistableHeaders: new Set([mediaIdHeader]),
      },
    );
    return {
      mediaId: input.id,
      upload: {
        method: "PUT",
        url,
        expiresAt: new Date(
          this.now().getTime() + uploadLifetimeSeconds * 1000,
        ).toISOString(),
        headers,
      },
    };
  }

  async verifyUpload(objectKey: string, input: LeadMediaInput): Promise<void> {
    try {
      const head = await this.client.send(
        new HeadObjectCommand({ Bucket: this.bucketName, Key: objectKey }),
      );
      if (head.ContentLength !== input.byteSize) {
        throw uploadMismatch("size_mismatch");
      }
      if (head.ContentType !== input.contentType) {
        throw uploadMismatch("content_type_mismatch");
      }
      if (head.Metadata?.["foloo-media-id"] !== input.id) {
        throw uploadMismatch("metadata_mismatch");
      }
      const sample = await this.client.send(
        new GetObjectCommand({
          Bucket: this.bucketName,
          Key: objectKey,
          Range: "bytes=0-31",
        }),
      );
      const bytes = await sample.Body?.transformToByteArray();
      if (!bytes) throw invalidMedia("empty_content_sample");
      if (input.contentType === "image/jpeg") {
        if (isPng(bytes)) throw invalidMedia("unsupported_image_format");
        if (!isJpegStart(bytes)) throw invalidMedia("invalid_jpeg_signature");
        const ending = await this.client.send(
          new GetObjectCommand({
            Bucket: this.bucketName,
            Key: objectKey,
            Range: `bytes=${input.byteSize - 2}-${input.byteSize - 1}`,
          }),
        );
        const endingBytes = await ending.Body?.transformToByteArray();
        if (!endingBytes || !isJpegEnd(endingBytes)) {
          throw invalidMedia("invalid_jpeg_signature");
        }
      } else if (!isM4a(bytes)) {
        throw invalidMedia("invalid_m4a_container");
      }
    } catch (error) {
      if (error instanceof ApplicationError) throw error;
      const name = (error as { name?: unknown } | null)?.name;
      if (name === "NotFound" || name === "NoSuchKey") {
        throw new ApplicationError(
          "upload_incomplete",
          409,
          "The media upload has not completed.",
        );
      }
      throw error;
    }
  }

  async authorizeDownload(
    objectKey: string,
  ): Promise<MediaDownloadAuthorization> {
    const url = await getSignedUrl(
      this.client,
      new GetObjectCommand({ Bucket: this.bucketName, Key: objectKey }),
      { expiresIn: downloadLifetimeSeconds },
    );
    return {
      url,
      expiresAt: new Date(
        this.now().getTime() + downloadLifetimeSeconds * 1000,
      ).toISOString(),
    };
  }
}

function uploadMismatch(diagnosticCode: string): ApplicationError {
  return new ApplicationError(
    "upload_mismatch",
    409,
    "Uploaded media does not match its authorization.",
    diagnosticCode,
  );
}

function invalidMedia(diagnosticCode: string): ApplicationError {
  return new ApplicationError(
    "invalid_media_content",
    400,
    "Uploaded media content is not an allowed format.",
    diagnosticCode,
  );
}

function isJpegStart(bytes: Uint8Array): boolean {
  return (
    bytes.length >= 4 &&
    bytes[0] === 0xff &&
    bytes[1] === 0xd8 &&
    bytes[2] === 0xff &&
    bytes[3] !== 0x00 &&
    bytes[3] !== 0xff
  );
}

function isJpegEnd(bytes: Uint8Array): boolean {
  return (
    bytes.length >= 2 &&
    bytes[bytes.length - 2] === 0xff &&
    bytes[bytes.length - 1] === 0xd9
  );
}

function isPng(bytes: Uint8Array): boolean {
  const signature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  return signature.every((value, index) => bytes[index] === value);
}

function isM4a(bytes: Uint8Array): boolean {
  if (
    bytes.length < 12 ||
    String.fromCharCode(...bytes.slice(4, 8)) !== "ftyp"
  ) {
    return false;
  }
  const boxSize = new DataView(
    bytes.buffer,
    bytes.byteOffset,
    bytes.byteLength,
  ).getUint32(0);
  const majorBrand = String.fromCharCode(...bytes.slice(8, 12));
  return (
    boxSize >= 12 &&
    ["M4A ", "M4B ", "mp41", "mp42", "isom"].includes(majorBrand)
  );
}
