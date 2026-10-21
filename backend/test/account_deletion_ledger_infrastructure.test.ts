/** Synth-only coverage for the inactive STORE-02E-02B CDK construct. */

import assert from "node:assert/strict";
import test from "node:test";

import * as cdk from "aws-cdk-lib";
import { Template } from "aws-cdk-lib/assertions";
import * as iam from "aws-cdk-lib/aws-iam";

import { AccountDeletionLedgerInfrastructure } from "../infra/account_deletion_ledger_infrastructure.js";
import { environmentConfig } from "../infra/config.js";
import { FolooBackendStack } from "../infra/foloo_backend_stack.js";

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
  template.resourceCountIs("AWS::CloudWatch::Alarm", 2);

  const policies = template.findResources("AWS::IAM::Policy");
  const serialized = JSON.stringify(policies);
  for (const action of [
    "dynamodb:GetItem",
    "dynamodb:BatchGetItem",
    "dynamodb:TransactWriteItems",
  ]) {
    assert.match(serialized, new RegExp(action, "u"));
  }
  assert.doesNotMatch(serialized, /dynamodb:(?:DeleteItem|Scan|\*)/u);
});

test("02E-02B infrastructure remains absent from the deployable Foloo stack", () => {
  const app = new cdk.App();
  const stack = new FolooBackendStack(app, "InactiveLedgerTest", {
    config: environmentConfig("dev"),
    env: { account: "111111111111", region: "us-east-1" },
  });
  const template = Template.fromStack(stack);

  template.resourceCountIs("AWS::DynamoDB::Table", 0);
  assert.doesNotMatch(
    JSON.stringify(template.toJSON()),
    /ACCOUNT_DELETION_LEDGER_TABLE/u,
  );
});
