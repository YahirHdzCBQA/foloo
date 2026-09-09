/** Prevents DEV Lambdas from reserving account concurrency in the CDK template. */

import assert from "node:assert/strict";
import test from "node:test";

import * as cdk from "aws-cdk-lib";
import { Template } from "aws-cdk-lib/assertions";

import { environmentConfig } from "../infra/config.js";
import { FolooBackendStack } from "../infra/foloo_backend_stack.js";

test("all FL-014 Lambdas use account unreserved concurrency", () => {
  const app = new cdk.App();
  const stack = new FolooBackendStack(app, "ConcurrencyTest", {
    config: environmentConfig("dev"),
    env: { account: "111111111111", region: "us-east-1" },
  });
  const template = JSON.stringify(Template.fromStack(stack).toJSON());
  assert.doesNotMatch(template, /ReservedConcurrentExecutions/);
});
