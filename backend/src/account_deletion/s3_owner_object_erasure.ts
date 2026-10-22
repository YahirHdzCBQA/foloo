/** S3 deletion adapter scoped to the exact inventory frozen in the ledger. */

import {
  DeleteObjectsCommand,
  HeadObjectCommand,
  ListObjectsV2Command,
  S3Client,
} from "@aws-sdk/client-s3";

import type { DurableErasureInventoryStore } from "./dynamodb_erasure_inventory_store.js";
import type { ObjectErasurePort } from "./staged_account_deletion_executor.js";
import type { PostgresOwnerErasure } from "./postgres_owner_erasure.js";

export class S3OwnerObjectErasure implements ObjectErasurePort {
  constructor(
    private readonly bucketName: string,
    private readonly source: Pick<
      PostgresOwnerErasure,
      "objectKeys" | "ownerScope"
    >,
    private readonly inventory: DurableErasureInventoryStore,
    private readonly client: S3Client = new S3Client({}),
  ) {}

  async freezeInventory(
    requestId: string,
    ownerSubject: string,
  ): Promise<void> {
    if ((await this.inventory.objectKeys(requestId)) !== null) return;
    const scope = await this.source.ownerScope(ownerSubject);
    const databaseKeys = await this.source.objectKeys(ownerSubject);
    const prefixes = scope
      ? [
          `media/workspaces/${scope.workspaceId}/`,
          `content/workspaces/${scope.workspaceId}/`,
        ]
      : [];
    for (const key of databaseKeys) {
      if (!prefixes.some((prefix) => key.startsWith(prefix))) {
        throw new Error("Owner object inventory contains an unsafe key.");
      }
    }
    const listedKeys: string[] = [];
    for (const prefix of prefixes) {
      listedKeys.push(...(await this.listPrefix(prefix)));
    }
    await this.inventory.captureObjectKeys(requestId, [
      ...databaseKeys,
      ...listedKeys,
    ]);
  }

  async deleteOwnerObjects(requestId: string): Promise<void> {
    const keys = await this.requiredInventory(requestId);
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

  async hasOwnerObjects(requestId: string): Promise<boolean> {
    const keys = await this.requiredInventory(requestId);
    for (const key of keys) {
      if (await this.objectExists(key)) return true;
    }
    return false;
  }

  private async requiredInventory(
    requestId: string,
  ): Promise<readonly string[]> {
    const keys = await this.inventory.objectKeys(requestId);
    if (keys === null)
      throw new Error("Owner object inventory was not frozen.");
    return keys;
  }

  private async listPrefix(prefix: string): Promise<string[]> {
    const keys: string[] = [];
    const seenTokens = new Set<string>();
    let continuationToken: string | undefined;
    do {
      const result = await this.client.send(
        new ListObjectsV2Command({
          Bucket: this.bucketName,
          Prefix: prefix,
          ContinuationToken: continuationToken,
          MaxKeys: 1000,
        }),
      );
      for (const object of result.Contents ?? []) {
        if (!object.Key?.startsWith(prefix)) {
          throw new Error("S3 returned an object outside the owner prefix.");
        }
        keys.push(object.Key);
      }
      if (result.IsTruncated && !result.NextContinuationToken) {
        throw new Error("S3 inventory pagination token is missing.");
      }
      const nextToken = result.IsTruncated
        ? result.NextContinuationToken
        : undefined;
      if (nextToken && seenTokens.has(nextToken)) {
        throw new Error("S3 inventory pagination token was repeated.");
      }
      if (nextToken) seenTokens.add(nextToken);
      continuationToken = nextToken;
    } while (continuationToken);
    return keys;
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
