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

test("FL-016 provisions private encrypted S3 without NAT or broad IAM", () => {
  const app = new cdk.App();
  const stack = new FolooBackendStack(app, "MediaInfrastructureTest", {
    config: environmentConfig("dev"),
    env: { account: "111111111111", region: "us-east-1" },
  });
  const template = Template.fromStack(stack);
  template.resourceCountIs("AWS::S3::Bucket", 1);
  template.hasResourceProperties("AWS::S3::Bucket", {
    PublicAccessBlockConfiguration: {
      BlockPublicAcls: true,
      BlockPublicPolicy: true,
      IgnorePublicAcls: true,
      RestrictPublicBuckets: true,
    },
    BucketEncryption: {
      ServerSideEncryptionConfiguration: [
        {
          ServerSideEncryptionByDefault: { SSEAlgorithm: "AES256" },
        },
      ],
    },
  });
  template.resourceCountIs("AWS::EC2::NatGateway", 0);
  const json = JSON.stringify(template.toJSON());
  const endpoints = template.findResources("AWS::EC2::VPCEndpoint");
  assert.equal(
    Object.values(endpoints).some((resource) => {
      const properties = resource.Properties as Record<string, unknown>;
      return (
        properties.VpcEndpointType === "Gateway" &&
        JSON.stringify(properties.ServiceName).includes("s3")
      );
    }),
    true,
  );
  assert.doesNotMatch(json, /WebsiteConfiguration|PublicRead/);
  assert.match(json, /s3:GetObject/);
  assert.match(json, /s3:PutObject/);
  const policies = template.findResources("AWS::IAM::Policy");
  const mediaPolicy = Object.values(policies).find((resource) => {
    const policy = JSON.stringify(resource);
    return policy.includes("s3:GetObject") && policy.includes("s3:PutObject");
  });
  assert.ok(mediaPolicy);
  assert.doesNotMatch(JSON.stringify(mediaPolicy), /s3:\*/);
});
