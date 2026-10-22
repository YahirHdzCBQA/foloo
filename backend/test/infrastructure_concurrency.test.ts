/** Prevents DEV Lambdas from reserving account concurrency in the CDK template. */

import assert from "node:assert/strict";
import test from "node:test";

import * as cdk from "aws-cdk-lib";
import { Template } from "aws-cdk-lib/assertions";

import { environmentConfig } from "../infra/config.js";
import { FolooBackendStack } from "../infra/foloo_backend_stack.js";

const importedKeyArns = {
  identityHmacKeyArn:
    "arn:aws:kms:us-east-1:111111111111:key/11111111-1111-4111-8111-111111111111",
  notificationRecipientKeyArn:
    "arn:aws:kms:us-east-1:111111111111:key/22222222-2222-4222-8222-222222222222",
};

test("all FL-014 Lambdas use account unreserved concurrency", () => {
  const app = new cdk.App();
  const stack = new FolooBackendStack(app, "ConcurrencyTest", {
    config: environmentConfig("dev", {
      STRIPE_PRICE_ID: "price_test",
      BILLING_SUCCESS_URL: "https://example.com/success",
      BILLING_CANCEL_URL: "https://example.com/cancel",
      BILLING_PORTAL_RETURN_URL: "https://example.com/account",
    }),
    env: { account: "111111111111", region: "us-east-1" },
    accountDeletionKeyArns: importedKeyArns,
  });
  const template = JSON.stringify(Template.fromStack(stack).toJSON());
  assert.doesNotMatch(template, /ReservedConcurrentExecutions/);
});

test("FL-016 provisions private encrypted S3 without NAT or broad IAM", () => {
  const app = new cdk.App();
  const stack = new FolooBackendStack(app, "MediaInfrastructureTest", {
    config: environmentConfig("dev", {
      STRIPE_PRICE_ID: "price_test",
      BILLING_SUCCESS_URL: "https://example.com/success",
      BILLING_CANCEL_URL: "https://example.com/cancel",
      BILLING_PORTAL_RETURN_URL: "https://example.com/account",
    }),
    env: { account: "111111111111", region: "us-east-1" },
    accountDeletionKeyArns: importedKeyArns,
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

test("public callback/status routes remain explicit and Account Deletion stays disabled", () => {
  const app = new cdk.App();
  const stack = new FolooBackendStack(app, "EmailInfrastructureTest", {
    config: environmentConfig("dev", {
      STRIPE_PRICE_ID: "price_test",
      BILLING_SUCCESS_URL: "https://example.com/success",
      BILLING_CANCEL_URL: "https://example.com/cancel",
      BILLING_PORTAL_RETURN_URL: "https://example.com/account",
    }),
    env: { account: "111111111111", region: "us-east-1" },
    accountDeletionKeyArns: importedKeyArns,
  });
  const template = Template.fromStack(stack);
  template.resourceCountIs("AWS::KMS::Key", 2);
  const functions = template.findResources("AWS::Lambda::Function");
  const provider = Object.entries(functions).find(([id]) =>
    id.includes("EmailProviderFunction"),
  )?.[1] as { Properties?: Record<string, unknown> } | undefined;
  const api = Object.entries(functions).find(([id]) =>
    id.includes("ApiFunction"),
  )?.[1] as { Properties?: Record<string, unknown> } | undefined;
  assert.ok(provider);
  assert.ok(api);
  assert.equal(provider.Properties?.VpcConfig, undefined);
  assert.ok(api.Properties?.VpcConfig);

  const routes = Object.values(
    template.findResources("AWS::ApiGatewayV2::Route"),
  ) as Array<{ Properties: Record<string, unknown> }>;
  const callback = routes.find((item) =>
    String(item.Properties.RouteKey).endsWith(
      "/v1/email/oauth/callback/{provider}",
    ),
  );
  assert.ok(callback);
  assert.equal(callback.Properties.AuthorizationType, "NONE");
  const deletionStatus = routes.find((item) =>
    String(item.Properties.RouteKey).endsWith("/v1/account-deletion-status"),
  );
  assert.ok(deletionStatus);
  assert.equal(deletionStatus.Properties.AuthorizationType, "NONE");
  assert.match(
    JSON.stringify(api.Properties?.Environment),
    /FOLOO_ACCOUNT_DELETION_ENABLED[^}]*false/u,
  );
  assert.equal(
    routes.some((item) =>
      String(item.Properties.RouteKey).includes("/v1/email/unsubscribe"),
    ),
    false,
  );
  const protectedRoute = routes.find((item) =>
    String(item.Properties.RouteKey).includes("/v1/{proxy+}"),
  );
  assert.ok(protectedRoute?.Properties.AuthorizerId);
});

test("FL-021 MON-16/MON-18 billing has public egress, scoped secrets and signed public webhook", () => {
  const app = new cdk.App();
  const stack = new FolooBackendStack(app, "BillingInfrastructureTest", {
    config: environmentConfig("dev", {
      STRIPE_PRICE_ID: "price_test",
      BILLING_SUCCESS_URL: "https://example.com/success",
      BILLING_CANCEL_URL: "https://example.com/cancel",
      BILLING_PORTAL_RETURN_URL: "https://example.com/account",
    }),
    env: { account: "111111111111", region: "us-east-1" },
    accountDeletionKeyArns: importedKeyArns,
  });
  const template = Template.fromStack(stack);
  const functions = template.findResources("AWS::Lambda::Function");
  const billing = Object.entries(functions).find(([id]) =>
    id.startsWith("BillingProviderFunction"),
  )?.[1];
  const api = Object.entries(functions).find(([id]) =>
    id.startsWith("ApiFunction"),
  )?.[1];
  assert.ok(billing);
  assert.ok(api);
  assert.equal(billing.Properties.VpcConfig, undefined);
  assert.ok(api.Properties.VpcConfig);
  assert.equal(
    billing.Properties.Environment.Variables.STRIPE_SECRET_ARN,
    "foloo/dev/stripe-api-key",
  );
  assert.equal(
    api.Properties.Environment.Variables.STRIPE_WEBHOOK_SECRET_ARN,
    "foloo/dev/stripe-webhook-signing",
  );
  template.hasResourceProperties("AWS::ApiGatewayV2::Stage", {
    RouteSettings: {
      "POST /v1/billing/webhook": {
        ThrottlingBurstLimit: 20,
        ThrottlingRateLimit: 10,
      },
    },
  });
  assert.equal(
    billing.Properties.Environment.Variables.STRIPE_WEBHOOK_SECRET_ARN,
    undefined,
  );
  const routes = Object.values(
    template.findResources("AWS::ApiGatewayV2::Route"),
  );
  for (const endpoint of ["checkout-session", "portal-session", "webhook"]) {
    const route = routes.find(
      (item) => item.Properties.RouteKey === `POST /v1/billing/${endpoint}`,
    );
    assert.ok(route);
    assert.equal(
      route.Properties.AuthorizationType,
      endpoint === "webhook" ? "NONE" : "JWT",
    );
  }
  const policies = template.findResources("AWS::IAM::Policy");
  const apiPolicy = JSON.stringify(
    Object.entries(policies).find(([id]) => id.startsWith("ApiFunction"))?.[1],
  );
  const providerPolicy = JSON.stringify(
    Object.entries(policies).find(([id]) =>
      id.startsWith("BillingProviderFunction"),
    )?.[1],
  );
  assert.match(apiPolicy, /stripe-webhook-signing/);
  assert.doesNotMatch(apiPolicy, /dev\/stripe-api-key/);
  assert.match(apiPolicy, /lambda:InvokeFunction/);
  assert.match(providerPolicy, /dev\/stripe-api-key/);
  assert.doesNotMatch(providerPolicy, /stripe-webhook-signing|rds:/);
  assert.equal(
    Object.keys(template.findResources("AWS::SecretsManager::Secret")).length,
    2,
  );
  template.resourceCountIs("AWS::EC2::NatGateway", 0);
});

test("MON-18 synth rejects incomplete enabled billing and permits explicit disable", () => {
  for (const key of [
    "STRIPE_PRICE_ID",
    "BILLING_SUCCESS_URL",
    "BILLING_CANCEL_URL",
    "BILLING_PORTAL_RETURN_URL",
  ]) {
    const env = {
      STRIPE_PRICE_ID: "price_test",
      BILLING_SUCCESS_URL: "https://example.com/success",
      BILLING_CANCEL_URL: "https://example.com/cancel",
      BILLING_PORTAL_RETURN_URL: "https://example.com/account",
      [key]: "",
    };
    assert.throws(() => environmentConfig("dev", env), new RegExp(key));
  }
  const stack = new FolooBackendStack(new cdk.App(), "DisabledBilling", {
    config: environmentConfig("dev", { BILLING_ENABLED: "false" }),
    env: { account: "111111111111", region: "us-east-1" },
    accountDeletionKeyArns: importedKeyArns,
  });
  const functions = Template.fromStack(stack).findResources(
    "AWS::Lambda::Function",
  );
  for (const [id, resource] of Object.entries(functions)) {
    if (
      id.startsWith("ApiFunction") ||
      id.startsWith("BillingProviderFunction")
    )
      assert.equal(
        resource.Properties.Environment?.Variables?.STRIPE_SECRET_ARN,
        undefined,
      );
  }
});
