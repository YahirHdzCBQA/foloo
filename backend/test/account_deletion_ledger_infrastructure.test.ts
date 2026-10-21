/** Synth-only coverage for the inactive STORE-02E-02B CDK construct. */

import assert from "node:assert/strict";
import test from "node:test";

import * as cdk from "aws-cdk-lib";
import { Template } from "aws-cdk-lib/assertions";
import * as iam from "aws-cdk-lib/aws-iam";

import { AccountDeletionLedgerInfrastructure } from "../infra/account_deletion_ledger_infrastructure.js";
import { environmentConfig } from "../infra/config.js";
import { FolooBackendStack } from "../infra/foloo_backend_stack.js";

const importedKeyArns = {
  identityHmacKeyArn:
    "arn:aws:kms:us-east-1:111111111111:key/11111111-1111-4111-8111-111111111111",
  notificationRecipientKeyArn:
    "arn:aws:kms:us-east-1:111111111111:key/22222222-2222-4222-8222-222222222222",
};

test("INF-21 isolated ledger uses encryption, PITR, TTL and deletion protection", () => {
  const app = new cdk.App();
  const stack = new cdk.Stack(app, "LedgerInfrastructureTest");
  const ledger = new AccountDeletionLedgerInfrastructure(stack, "Ledger");
  const role = new iam.Role(stack, "FutureGuardRole", {
    assumedBy: new iam.ServicePrincipal("lambda.amazonaws.com"),
  });
  ledger.grantAdapterAccess(role);
  const template = Template.fromStack(stack);

  template.resourceCountIs("AWS::DynamoDB::Table", 1);
  template.hasResourceProperties("AWS::DynamoDB::Table", {
    AttributeDefinitions: [{ AttributeName: "pk", AttributeType: "S" }],
    BillingMode: "PAY_PER_REQUEST",
    DeletionProtectionEnabled: true,
    KeySchema: [{ AttributeName: "pk", KeyType: "HASH" }],
    PointInTimeRecoverySpecification: {
      PointInTimeRecoveryEnabled: true,
    },
    SSESpecification: { SSEEnabled: true },
    TimeToLiveSpecification: {
      AttributeName: "expires_at",
      Enabled: true,
    },
  });
  template.hasResource("AWS::DynamoDB::Table", {
    DeletionPolicy: "Retain",
    UpdateReplacePolicy: "Retain",
  });
  template.resourceCountIs("AWS::CloudWatch::Alarm", 3);
  template.resourceCountIs("AWS::KMS::Key", 2);
  template.resourceCountIs("AWS::SQS::Queue", 2);

  const policies = template.findResources("AWS::IAM::Policy");
  const serialized = JSON.stringify(policies);
  for (const action of [
    "dynamodb:GetItem",
    "dynamodb:BatchGetItem",
    "dynamodb:TransactWriteItems",
    "dynamodb:PutItem",
    "dynamodb:UpdateItem",
    "dynamodb:DeleteItem",
  ]) {
    assert.match(serialized, new RegExp(action, "u"));
  }
  assert.doesNotMatch(serialized, /dynamodb:(?:Scan|\*)/u);
});

test("Account Deletion KMS imports are all-or-nothing", () => {
  const app = new cdk.App();
  const stack = new cdk.Stack(app, "PartialKeyImportTest");
  assert.throws(
    () =>
      new AccountDeletionLedgerInfrastructure(stack, "Ledger", {
        existingIdentityHmacKeyArn: importedKeyArns.identityHmacKeyArn,
      }),
    /must be imported together/u,
  );
});

test("STORE-02 infrastructure is deployable but every runtime boundary stays disabled", () => {
  const app = new cdk.App();
  const stack = new FolooBackendStack(app, "InactiveLedgerTest", {
    config: environmentConfig("dev"),
    env: { account: "111111111111", region: "us-east-1" },
    unlimitedQaMode: true,
    accountDeletionKeyArns: importedKeyArns,
  });
  const template = Template.fromStack(stack);

  template.resourceCountIs("AWS::DynamoDB::Table", 1);
  template.resourceCountIs("AWS::SQS::Queue", 3);
  template.resourceCountIs("AWS::KMS::Key", 1);
  const json = JSON.stringify(template.toJSON());
  assert.match(json, /11111111-1111-4111-8111-111111111111/u);
  assert.match(json, /22222222-2222-4222-8222-222222222222/u);
  assert.doesNotMatch(json, /HMAC key for Foloo account-deletion pseudonyms/u);
  assert.match(json, /AccountDeletionWorkerFunction/u);
  assert.match(json, /AccountDeletionCognitoFinalizerFunction/u);
  assert.match(json, /AccountDeletionEmailFunction/u);
  assert.match(json, /AccountDeletionPreSignUpFunction/u);
  assert.match(json, /AccountDeletionPostAuthenticationFunction/u);
  assert.match(json, /AccountDeletionRestoreReconcilerFunction/u);
  assert.match(json, /hello@foloo\.io/u);
  assert.doesNotMatch(
    json,
    /FOLOO_ACCOUNT_DELETION_REGISTRATION_GUARD_ENABLED[^}]*true/u,
  );
  assert.doesNotMatch(json, /ACCOUNT_DELETION_SES_IDENTITY_VERIFIED[^}]*true/u);
  assert.doesNotMatch(json, /FOLOO_ACCOUNT_DELETION_ENABLED[^}]*true/u);
  assert.match(json, /FOLOO_UNLIMITED_QA_MODE[^}]*true/u);
  assert.match(json, /cognito-idp\.amazonaws\.com/u);

  const stages = Object.values(
    template.findResources("AWS::ApiGatewayV2::Stage"),
  );
  assert.equal(stages.length, 1);
  const stage = stages[0];
  assert.ok(stage);
  assert.deepEqual(stages[0]?.Properties?.RouteSettings, {
    "POST /v1/account-deletion-status": {
      ThrottlingBurstLimit: 5,
      ThrottlingRateLimit: 1,
    },
    "GET /v1/account-deletion-requests/current": {
      ThrottlingBurstLimit: 5,
      ThrottlingRateLimit: 2,
    },
    "POST /v1/account-deletion-reauthentication/verify": {
      ThrottlingBurstLimit: 3,
      ThrottlingRateLimit: 1,
    },
    "POST /v1/account-deletion-requests": {
      ThrottlingBurstLimit: 2,
      ThrottlingRateLimit: 0.2,
    },
    "POST /v1/account-deletion-requests/{requestId}/confirm": {
      ThrottlingBurstLimit: 2,
      ThrottlingRateLimit: 0.2,
    },
  });
  assert.doesNotMatch(JSON.stringify(stage), /throttling(?:Burst|Rate)Limit/u);

  const accountDeletionRouteIds = Object.entries(
    template.findResources("AWS::ApiGatewayV2::Route"),
  )
    .filter(([, route]) =>
      String(route.Properties?.RouteKey).includes("account-deletion"),
    )
    .map(([logicalId]) => logicalId);
  assert.equal(accountDeletionRouteIds.length, 5);
  assert.ok(Array.isArray(stage.DependsOn));
  for (const logicalId of accountDeletionRouteIds) {
    assert.ok(
      stage.DependsOn.includes(logicalId),
      `Default Stage must depend on ${logicalId}`,
    );
  }
});
