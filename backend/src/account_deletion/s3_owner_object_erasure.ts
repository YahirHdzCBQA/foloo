/** S3 deletion adapter scoped to the exact object inventory frozen in SQL. */

import {
  DeleteObjectsCommand,
  HeadObjectCommand,
  S3Client,
} from "@aws-sdk/client-s3";

import type { ObjectErasurePort } from "./staged_account_deletion_executor.js";
import type { PostgresOwnerErasure } from "./postgres_owner_erasure.js";

export class S3OwnerObjectErasure implements ObjectErasurePort {
  constructor(
    private readonly bucketName: string,
    private readonly inventory: Pick<PostgresOwnerErasure, "objectKeys">,
    private readonly client: S3Client = new S3Client({}),
  ) {}

  async deleteOwnerObjects(ownerSubject: string): Promise<void> {
    const keys = [...new Set(await this.inventory.objectKeys(ownerSubject))];
    for (let offset = 0; offset < keys.length; offset += 1000) {
      const chunk = keys.slice(offset, offset + 1000);
      const result = await this.client.send(
        new DeleteObjectsCommand({
          Bucket: this.bucketName,
          Delete: { Objects: chunk.map((Key) => ({ Key })), Quiet: true },
        }),
      );
      if ((result.Errors?.length ?? 0) > 0) {
        throw new Error("Owner object deletion was incomplete.");
      }
      for (const key of chunk) {
        if (await this.objectExists(key)) {
          throw new Error("Owner object deletion could not be verified.");
        }
      }
    }
  }

  async hasOwnerObjects(ownerSubject: string): Promise<boolean> {
    const keys = await this.inventory.objectKeys(ownerSubject);
    for (const key of keys) {
      if (await this.objectExists(key)) return true;
    }
    return false;
  }

  private async objectExists(key: string): Promise<boolean> {
    try {
      await this.client.send(
        new HeadObjectCommand({ Bucket: this.bucketName, Key: key }),
      );
      return true;
    } catch (error) {
      const status = (error as { $metadata?: { httpStatusCode?: number } })
        .$metadata?.httpStatusCode;
      const name = (error as { name?: string }).name;
      if (status === 404 || name === "NotFound" || name === "NoSuchKey") {
        return false;
      }
      throw error;
    }
  }
}
