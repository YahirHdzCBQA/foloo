/**
 * Ordered, resumable erasure executor for STORE-02.
 * Cognito is deliberately last; completion requires independent verification
 * of OAuth, S3, PostgreSQL and identity removal (INF-17, INF-19, RNF-09).
 */

import type {
  AccountDeletionExecutor,
  SubscriptionSummary,
} from "./account_deletion_workflow.js";

export type ErasureStage =
  "oauth_revoked" | "objects_deleted" | "postgres_deleted" | "identity_deleted";

export interface ErasureCheckpointStore {
  completed(requestId: string): Promise<ReadonlySet<ErasureStage>>;
  markCompleted(requestId: string, stage: ErasureStage): Promise<void>;
}

export interface OAuthErasurePort {
  revokeAndDestroy(ownerSubject: string): Promise<void>;
  isDestroyed(ownerSubject: string): Promise<boolean>;
}

export interface ObjectErasurePort {
  deleteOwnerObjects(ownerSubject: string): Promise<void>;
  hasOwnerObjects(ownerSubject: string): Promise<boolean>;
}

export interface PostgresErasurePort {
  deleteOwnerData(ownerSubject: string): Promise<void>;
  hasOwnerData(ownerSubject: string): Promise<boolean>;
}

export interface CognitoErasurePort {
  globallySignOutAndDelete(ownerSubject: string): Promise<void>;
  identityExists(ownerSubject: string): Promise<boolean>;
}

export class StagedAccountDeletionExecutor implements AccountDeletionExecutor {
  constructor(
    private readonly checkpoints: ErasureCheckpointStore,
    private readonly oauth: OAuthErasurePort,
    private readonly objects: ObjectErasurePort,
    private readonly postgres: PostgresErasurePort,
    private readonly cognito: CognitoErasurePort,
  ) {}

  async execute(input: {
    requestId: string;
    ownerSubject: string;
    subscription: SubscriptionSummary;
  }): Promise<void> {
    if (input.subscription.cancellationRequired) {
      throw new Error("Subscription renewal cancellation is not confirmed.");
    }
    const completed = await this.checkpoints.completed(input.requestId);
    await this.run(input.requestId, "oauth_revoked", completed, () =>
      this.oauth.revokeAndDestroy(input.ownerSubject),
    );
    await this.run(input.requestId, "objects_deleted", completed, () =>
      this.objects.deleteOwnerObjects(input.ownerSubject),
    );
    await this.run(input.requestId, "postgres_deleted", completed, () =>
      this.postgres.deleteOwnerData(input.ownerSubject),
    );
    await this.run(input.requestId, "identity_deleted", completed, () =>
      this.cognito.globallySignOutAndDelete(input.ownerSubject),
    );
  }

  async verify(input: {
    requestId: string;
    ownerSubject: string;
  }): Promise<boolean> {
    const completed = await this.checkpoints.completed(input.requestId);
    if (
      ![
        "oauth_revoked",
        "objects_deleted",
        "postgres_deleted",
        "identity_deleted",
      ].every((stage) => completed.has(stage as ErasureStage))
    ) {
      return false;
    }
    const [oauthExists, objectExists, postgresExists, identityExists] =
      await Promise.all([
        this.oauth.isDestroyed(input.ownerSubject).then((value) => !value),
        this.objects.hasOwnerObjects(input.ownerSubject),
        this.postgres.hasOwnerData(input.ownerSubject),
        this.cognito.identityExists(input.ownerSubject),
      ]);
    return !oauthExists && !objectExists && !postgresExists && !identityExists;
  }

  private async run(
    requestId: string,
    stage: ErasureStage,
    completed: ReadonlySet<ErasureStage>,
    action: () => Promise<void>,
  ): Promise<void> {
    if (completed.has(stage)) return;
    await action();
    await this.checkpoints.markCompleted(requestId, stage);
  }
}
