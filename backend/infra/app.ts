/** AWS CDK entry point for explicitly selected Foloo environments. */

import * as cdk from "aws-cdk-lib";

import { environmentConfig } from "./config.js";
import { FolooBackendStack } from "./foloo_backend_stack.js";

const app = new cdk.App();
const environment = app.node.tryGetContext("environment");
const config = environmentConfig(
  typeof environment === "string" ? environment : "dev",
);

new FolooBackendStack(app, `FolooBackend-${config.name}`, {
  config,
  env: process.env.CDK_DEFAULT_ACCOUNT
    ? { account: process.env.CDK_DEFAULT_ACCOUNT, region: config.region }
    : { region: config.region },
  description: "FL-014 Foloo backend foundation",
});
