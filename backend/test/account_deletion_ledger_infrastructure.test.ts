/** Synth-only coverage for the inactive STORE-02E-02B CDK construct. */

import assert from "node:assert/strict";
import test from "node:test";

import * as cdk from "aws-cdk-lib";
import { Match, Template } from "aws-cdk-lib/assertions";

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
  new AccountDeletionLedgerInfrastructure(stack, "Ledger");
  const template = Template.fromStack(stack);

  template.resourceCountIs("AWS::DynamoDB::Table", 1);
  template.hasResourceProperties("AWS::DynamoDB::Table", {
    AttributeDefinitions: [
      { AttributeName: "pk", AttributeType: "S" },
      { AttributeName: "entity_type", AttributeType: "S" },
      { AttributeName: "created_at", AttributeType: "S" },
    ],
    BillingMode: "PAY_PER_REQUEST",
    DeletionProtectionEnabled: true,
    KeySchema: [{ AttributeName: "pk", KeyType: "HASH" }],
    GlobalSecondaryIndexes: [
      {
        IndexName: "entity_type-created_at-index",
        KeySchema: [
          { AttributeName: "entity_type", KeyType: "HASH" },
          { AttributeName: "created_at", KeyType: "RANGE" },
        ],
        Projection: { ProjectionType: "ALL" },
      },
    ],
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
  template.hasResourceProperties("AWS::SQS::Queue", {
    FifoQueue: true,
    DelaySeconds: 660,
    VisibilityTimeout: 900,
  });
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
  assert.match(json, /AccountDeletionOutboxRecoveryFunction/u);
  assert.match(json, /hello@foloo\.io/u);
  assert.match(json, /ACCOUNT_DELETION_NOTIFICATION_MODE[^}]*disabled/u);
  assert.doesNotMatch(
    json,
    /FOLOO_ACCOUNT_DELETION_REGISTRATION_GUARD_ENABLED[^}]*true/u,
  );
  assert.doesNotMatch(json, /ACCOUNT_DELETION_SES_IDENTITY_VERIFIED[^}]*true/u);
  assert.doesNotMatch(json, /FOLOO_ACCOUNT_DELETION_ENABLED[^}]*true/u);
  assert.doesNotMatch(json, /FOLOO_ACCOUNT_DELETION_OUTBOX_ENABLED[^}]*true/u);
  assert.doesNotMatch(
    json,
    /FOLOO_ACCOUNT_DELETION_RECONCILER_ENABLED[^}]*true/u,
  );
  assert.match(json, /ACCOUNT_DELETION_QUEUE_URL/u);
  assert.match(json, /FOLOO_UNLIMITED_QA_MODE[^}]*true/u);
  assert.match(json, /cognito-idp\.amazonaws\.com/u);
  assert.match(json, /s3:ListBucket/u);
  assert.match(json, /media\/workspaces\/\*/u);
  assert.match(json, /content\/workspaces\/\*/u);
  template.hasResourceProperties("AWS::Events::Rule", {
    State: "DISABLED",
    ScheduleExpression: "rate(1 minute)",
  });

  template.resourceCountIs("AWS::Cognito::UserPoolClient", 1);
  template.hasResourceProperties("AWS::Cognito::UserPoolClient", {
    UserPoolId: environmentConfig("dev").userPoolId,
    ClientName: "foloo-web-dev",
    GenerateSecret: false,
    AllowedOAuthFlowsUserPoolClient: true,
    AllowedOAuthFlows: ["code"],
    AllowedOAuthScopes: Match.arrayWith(["openid", "email", "profile"]),
    CallbackURLs: ["https://foloo.io/auth/callback"],
    LogoutURLs: ["https://foloo.io/login"],
    SupportedIdentityProviders: ["COGNITO", "Google"],
  });
  const webClients = template.findResources("AWS::Cognito::UserPoolClient");
  assert.doesNotMatch(JSON.stringify(webClients), /Microsoft/u);
  template.resourceCountIs("AWS::Cognito::ManagedLoginBranding", 1);
  template.hasResourceProperties("AWS::Cognito::ManagedLoginBranding", {
    UserPoolId: environmentConfig("dev").userPoolId,
    ClientId: {
      Ref: Object.keys(webClients)[0],
    },
    UseCognitoProvidedValues: true,
  });

  template.hasResourceProperties("AWS::ApiGatewayV2::Api", {
    CorsConfiguration: {
      AllowHeaders: ["authorization", "content-type", "idempotency-key"],
      AllowMethods: ["GET", "POST", "OPTIONS"],
      AllowOrigins: ["https://foloo.io"],
      ExposeHeaders: ["retry-after", "idempotency-replayed"],
      MaxAge: 3600,
    },
  });
  const authorizers = Object.values(
    template.findResources("AWS::ApiGatewayV2::Authorizer"),
  );
  assert.equal(authorizers.length, 1);
  const audiences = authorizers[0]?.Properties?.JwtConfiguration?.Audience;
  assert.ok(Array.isArray(audiences));
  assert.equal(audiences[0], environmentConfig("dev").appClientId);
  assert.deepEqual(audiences[1], {
    Ref: Object.keys(webClients)[0],
  });

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

test("RNF-09 Account Deletion Lambdas receive only their required ledger actions", () => {
  const app = new cdk.App();
  const stack = new FolooBackendStack(app, "LeastPrivilegeLedgerTest", {
    config: environmentConfig("dev"),
    env: { account: "111111111111", region: "us-east-1" },
    unlimitedQaMode: true,
    accountDeletionKeyArns: importedKeyArns,
  });
  const template = Template.fromStack(stack);

  assertLedgerPermissions(template, "ApiFunction", [
    "dynamodb:BatchGetItem",
    "dynamodb:GetItem",
    "dynamodb:PutItem",
    "dynamodb:TransactWriteItems",
  ]);
  assertLedgerPermissions(template, "AccountDeletionWorkerFunction", [
    "dynamodb:GetItem",
    "dynamodb:PutItem",
    "dynamodb:TransactWriteItems",
    "dynamodb:UpdateItem",
  ]);
  assertLedgerPermissions(
    template,
    "AccountDeletionOutboxRecoveryFunction",
    ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:TransactWriteItems"],
    true,
  );
  assertLedgerPermissions(template, "AccountDeletionPreSignUpFunction", [
    "dynamodb:BatchGetItem",
  ]);
  assertLedgerPermissions(
    template,
    "AccountDeletionPostAuthenticationFunction",
    ["dynamodb:BatchGetItem"],
  );
  assertLedgerPermissions(template, "AccountDeletionEmailFunction", [
    "dynamodb:DeleteItem",
    "dynamodb:GetItem",
  ]);
  assertLedgerPermissions(
    template,
    "AccountDeletionRestoreReconcilerFunction",
    ["dynamodb:BatchGetItem"],
  );
});

function assertLedgerPermissions(
  template: Template,
  functionPrefix: string,
  expectedActions: readonly string[],
  expectsIndex = false,
): void {
  const functions = template.findResources("AWS::Lambda::Function");
  const functionEntry = Object.entries(functions).find(([logicalId]) =>
    logicalId.startsWith(functionPrefix),
  );
  assert.ok(functionEntry, `${functionPrefix} Lambda was not synthesized.`);
  const roleId = functionEntry[1].Properties?.Role?.["Fn::GetAtt"]?.[0];
  assert.equal(typeof roleId, "string");

  const policies = template.findResources("AWS::IAM::Policy");
  const policy = Object.values(policies).find((resource) =>
    JSON.stringify(resource.Properties?.Roles).includes(
      JSON.stringify({ Ref: roleId }),
    ),
  );
  assert.ok(policy, `${functionPrefix} IAM policy was not synthesized.`);
  const statements = policy.Properties?.PolicyDocument?.Statement ?? [];
  const dynamoStatements = statements.filter((statement: unknown) =>
    JSON.stringify(statement).includes("dynamodb:"),
  );
  const actions = dynamoStatements
    .flatMap((statement: { Action?: string | string[] }) =>
      Array.isArray(statement.Action) ? statement.Action : [statement.Action],
    )
    .filter((action: unknown): action is string =>
      String(action).startsWith("dynamodb:"),
    )
    .sort();
  assert.deepEqual(actions, [...expectedActions].sort());
  assert.ok(actions.every((action) => action !== "dynamodb:*"));

  const resources = dynamoStatements.flatMap(
    (statement: { Resource?: unknown | unknown[] }) =>
      Array.isArray(statement.Resource)
        ? statement.Resource
        : [statement.Resource],
  );
  const serializedResources = JSON.stringify(resources);
  assert.doesNotMatch(serializedResources, /"\*"/u);
  if (expectsIndex) {
    assert.match(serializedResources, /\/index\/entity_type-created_at-index/u);
    assert.doesNotMatch(serializedResources, /\/index\/\*/u);
  } else {
    assert.doesNotMatch(serializedResources, /\/index\//u);
  }
}
