/** Ordered-erasure tests use only synthetic owner identifiers and fake ports. */

import assert from "node:assert/strict";
import test from "node:test";

import {
  StagedAccountDeletionExecutor,
  type ErasureCheckpointStore,
  type ErasureStage,
} from "../src/account_deletion/staged_account_deletion_executor.js";

class Checkpoints implements ErasureCheckpointStore {
  readonly stages = new Set<ErasureStage>();
  async completed() {
    return new Set(this.stages);
  }
  async markCompleted(_requestId: string, stage: ErasureStage) {
    this.stages.add(stage);
  }
}

test("INF-17 deletes OAuth, S3, PostgreSQL and Cognito in safe order", async () => {
  const order: string[] = [];
  const checkpoints = new Checkpoints();
  const executor = new StagedAccountDeletionExecutor(
    checkpoints,
    {
      async revokeAndDestroy() {
        order.push("oauth");
      },
      async isDestroyed() {
        return true;
      },
    },
    {
      async deleteOwnerObjects() {
        order.push("s3");
      },
      async hasOwnerObjects() {
        return false;
      },
    },
    {
      async deleteOwnerData() {
        order.push("postgres");
      },
      async hasOwnerData() {
        return false;
      },
    },
    {
      async globallySignOutAndDelete() {
        order.push("cognito");
      },
      async identityExists() {
        return false;
      },
    },
  );
  const input = {
    requestId: "synthetic-request",
    ownerSubject: "synthetic-subject",
    subscription: {
      status: "none" as const,
      cancellationRequired: false,
      planDisplayName: null,
      currentPeriodEnd: null,
    },
  };
  await executor.execute(input);
  assert.deepEqual(order, ["oauth", "s3", "postgres", "cognito"]);
  assert.equal(await executor.verify(input), true);

  await executor.execute(input);
  assert.deepEqual(order, ["oauth", "s3", "postgres", "cognito"]);
});

test("RNF-09 resumes after a partial S3 failure without repeating OAuth", async () => {
  const order: string[] = [];
  const checkpoints = new Checkpoints();
  let failS3 = true;
  const executor = new StagedAccountDeletionExecutor(
    checkpoints,
    {
      async revokeAndDestroy() {
        order.push("oauth");
      },
      async isDestroyed() {
        return true;
      },
    },
    {
      async deleteOwnerObjects() {
        order.push("s3");
        if (failS3) throw new Error("synthetic S3 failure");
      },
      async hasOwnerObjects() {
        return false;
      },
    },
    {
      async deleteOwnerData() {
        order.push("postgres");
      },
      async hasOwnerData() {
        return false;
      },
    },
    {
      async globallySignOutAndDelete() {
        order.push("cognito");
      },
      async identityExists() {
        return false;
      },
    },
  );
  const input = {
    requestId: "synthetic-request",
    ownerSubject: "synthetic-subject",
    subscription: {
      status: "none" as const,
      cancellationRequired: false,
      planDisplayName: null,
      currentPeriodEnd: null,
    },
  };
  await assert.rejects(executor.execute(input), /synthetic S3 failure/);
  failS3 = false;
  await executor.execute(input);
  assert.deepEqual(order, ["oauth", "s3", "s3", "postgres", "cognito"]);
});
