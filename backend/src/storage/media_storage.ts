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

export interface MediaStorage {
  objectKey(principal: Principal, leadId: string, mediaId: string): string;
  authorizeUpload(
    principal: Principal,
    leadId: string,
    input: LeadMediaInput,
  ): Promise<MediaUploadAuthorization>;
  verifyUpload(objectKey: string, input: LeadMediaInput): Promise<void>;
  authorizeDownload(objectKey: string): Promise<MediaDownloadAuthorization>;
}

export class S3MediaStorage implements MediaStorage {
  constructor(
    private readonly bucketName: string,
    private readonly client: S3Client = new S3Client({}),
    private readonly now: () => Date = () => new Date(),
  ) {}

  objectKey(principal: Principal, leadId: string, mediaId: string): string {
    return `media/workspaces/${principal.workspaceId}/leads/${leadId}/${mediaId}`;
  }

  async authorizeUpload(
    principal: Principal,
    leadId: string,
    input: LeadMediaInput,
  ): Promise<MediaUploadAuthorization> {
    const key = this.objectKey(principal, leadId, input.id);
    const headers = {
      "content-type": input.contentType,
      "x-amz-meta-foloo-media-id": input.id,
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
      { expiresIn: uploadLifetimeSeconds },
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
      if (
        head.ContentLength !== input.byteSize ||
        head.ContentType !== input.contentType ||
        head.Metadata?.["foloo-media-id"] !== input.id
      ) {
        throw new ApplicationError(
          "upload_mismatch",
          409,
          "Uploaded media does not match its authorization.",
        );
      }
      const sample = await this.client.send(
        new GetObjectCommand({
          Bucket: this.bucketName,
          Key: objectKey,
          Range: "bytes=0-31",
        }),
      );
      const bytes = await sample.Body?.transformToByteArray();
      if (!bytes || !matchesContent(input.contentType, bytes)) {
        throw new ApplicationError(
          "invalid_media_content",
          400,
          "Uploaded media content is not an allowed format.",
        );
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

function matchesContent(contentType: string, bytes: Uint8Array): boolean {
  if (contentType === "image/jpeg") {
    return (
      bytes.length >= 3 &&
      bytes[0] === 0xff &&
      bytes[1] === 0xd8 &&
      bytes[2] === 0xff
    );
  }
  if (contentType === "audio/m4a") {
    return (
      bytes.length >= 12 && String.fromCharCode(...bytes.slice(4, 8)) === "ftyp"
    );
  }
  return false;
}
