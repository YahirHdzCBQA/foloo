/** AWS CDK entry point for explicitly selected Foloo environments. */

import * as cdk from "aws-cdk-lib";

import {
  environmentConfig,
  accountDeletionQaConfigForEnvironment,
  unlimitedQaModeForEnvironment,
  webSessionQaConfigForEnvironment,
} from "./config.js";
import { FolooBackendStack } from "./foloo_backend_stack.js";

const app = new cdk.App();
const environment = app.node.tryGetContext("environment");
const config = environmentConfig(
  typeof environment === "string" ? environment : "dev",
);
const unlimitedQaMode = unlimitedQaModeForEnvironment(
  config.name,
  app.node.tryGetContext("unlimitedQaMode"),
);
const webSessionQa = webSessionQaConfigForEnvironment(
  config.name,
  app.node.tryGetContext("webSessionQaEnabled"),
  app.node.tryGetContext("webSessionQaSubjectHashes"),
);
const accountDeletionQa = accountDeletionQaConfigForEnvironment(
  config.name,
  app.node.tryGetContext("accountDeletionQaEnabled"),
  app.node.tryGetContext("accountDeletionQaIntakeEnabled"),
  app.node.tryGetContext("accountDeletionQaSubjectHashes"),
  app.node.tryGetContext("accountDeletionRegistrationGuardEnabled"),
  app.node.tryGetContext("accountDeletionOutboxRecoveryEnabled"),
  app.node.tryGetContext("accountDeletionRestoreReconcilerEnabled"),
  app.node.tryGetContext("accountDeletionRecoverySchedulerEnabled"),
  app.node.tryGetContext("accountDeletionWorkerEnabled"),
  app.node.tryGetContext("accountDeletionFinalizerEnabled"),
  app.node.tryGetContext("accountDeletionWorkerEventSourceEnabled"),
  app.node.tryGetContext("accountDeletionRuntimeEnabled"),
  app.node.tryGetContext("accountDeletionNormalAccessEnabled"),
);
const requiredKeyArn = (contextName: string): string => {
  const value = app.node.tryGetContext(contextName);
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(
      `Missing required CDK context ${contextName}; refusing to create another retained Account Deletion KMS key.`,
    );
  }
  return value;
};

new FolooBackendStack(app, `FolooBackend-${config.name}`, {
  config,
  unlimitedQaMode,
  webSessionQa,
  accountDeletionQa,
  accountDeletionKeyArns: {
    identityHmacKeyArn: requiredKeyArn("accountDeletionIdentityHmacKeyArn"),
    notificationRecipientKeyArn: requiredKeyArn(
      "accountDeletionNotificationRecipientKeyArn",
    ),
  },
  env: process.env.CDK_DEFAULT_ACCOUNT
    ? { account: process.env.CDK_DEFAULT_ACCOUNT, region: config.region }
    : { region: config.region },
  description: "FL-014 Foloo backend foundation",
});
