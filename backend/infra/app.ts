/** AWS CDK entry point for explicitly selected Foloo environments. */

import * as cdk from "aws-cdk-lib";

import { environmentConfig, unlimitedQaModeForEnvironment } from "./config.js";
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
