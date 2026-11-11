/** Synth-only least-privilege checks for the private FL-021 operator boundary. */

import assert from "node:assert/strict";
import test from "node:test";

import * as cdk from "aws-cdk-lib";
import { Template } from "aws-cdk-lib/assertions";

import {
  administrativeEntitlementForEnvironment,
  automaticEntitlementConfigForEnvironment,
  environmentConfig,
} from "../infra/config.js";
import { FolooBackendStack } from "../infra/foloo_backend_stack.js";

const keyArns = {
  identityHmacKeyArn:
    "arn:aws:kms:us-east-1:111111111111:key/11111111-1111-4111-8111-111111111111",
  notificationRecipientKeyArn:
    "arn:aws:kms:us-east-1:111111111111:key/22222222-2222-4222-8222-222222222222",
};

test("private entitlement boundary has no public trigger and least privilege", () => {
  const app = new cdk.App();
  const template = Template.fromStack(
    new FolooBackendStack(app, "AdministrativeEntitlementTest", {
      config: environmentConfig("dev"),
      env: { account: "111111111111", region: "us-east-1" },
      accountDeletionKeyArns: keyArns,
      administrativeEntitlementEnabled: true,
    }),
  ).toJSON();
  const resources = template.Resources as Record<
    string,
    { Type: string; Properties?: Record<string, unknown> }
  >;
  const adminEntry = Object.entries(resources).find(
    ([id, resource]) =>
      id.startsWith("AdministrativeEntitlementFunction") &&
      resource.Type === "AWS::Lambda::Function",
  );
  const identityEntry = Object.entries(resources).find(
    ([id, resource]) =>
      id.startsWith("AdministrativeEntitlementIdentityFunction") &&
      resource.Type === "AWS::Lambda::Function",
  );
  assert.ok(adminEntry);
  assert.ok(identityEntry);
  assert.equal(adminEntry[1].Type, "AWS::Lambda::Function");
  assert.equal(identityEntry[1].Type, "AWS::Lambda::Function");
  assert.ok(adminEntry[1].Properties?.VpcConfig);
  assert.equal(identityEntry[1].Properties?.VpcConfig, undefined);

  const serialized = JSON.stringify(template);
  assert.doesNotMatch(serialized, /AWS::Lambda::Url/u);
  assert.doesNotMatch(serialized, /admin-entitlement.*RouteKey/iu);
  assert.match(serialized, /cognito-idp:ListUsers/u);
  assert.doesNotMatch(serialized, /cognito-idp:\*/u);
  assert.match(serialized, /secretsmanager:GetSecretValue/u);
  assert.match(serialized, /lambda:InvokeFunction/u);
  assert.doesNotMatch(
    serialized,
    /AdministrativeEntitlementIdentityFunctionA5E0E110[^}]*:\*/u,
  );

  const operatorRole = Object.values(resources).find(
    (resource) =>
      resource.Type === "AWS::IAM::Role" &&
      resource.Properties?.RoleName === "foloo-dev-fl021-entitlement-operator",
  );
  assert.ok(operatorRole);
  const operatorUserEntry = Object.entries(resources).find(
    ([id, resource]) =>
      id.startsWith("AdministrativeEntitlementOperatorUser") &&
      resource.Type === "AWS::IAM::User",
  );
  assert.ok(operatorUserEntry);
  assert.equal(
    operatorUserEntry[1].Properties?.UserName,
    "foloo-entitlement-operator",
  );
  assert.equal(operatorUserEntry[1].Properties?.LoginProfile, undefined);
  assert.equal(
    Object.values(resources).some(
      (resource) => resource.Type === "AWS::IAM::AccessKey",
    ),
    false,
  );
  const operatorTrust = operatorRole.Properties?.AssumeRolePolicyDocument as {
    Statement: Array<{
      Action: string | string[];
      Condition?: Record<string, Record<string, string>>;
      Principal?: { AWS?: { "Fn::GetAtt"?: [string, string] } };
    }>;
  };
  const trustStatementFor = (action: string) =>
    operatorTrust.Statement.find((statement) =>
      Array.isArray(statement.Action)
        ? statement.Action.includes(action)
        : statement.Action === action,
    );
  const assumeRoleTrust = trustStatementFor("sts:AssumeRole");
  const sourceIdentityTrust = trustStatementFor("sts:SetSourceIdentity");
  assert.ok(assumeRoleTrust);
  assert.ok(sourceIdentityTrust);
  const expectedOperatorPrincipal = {
    AWS: { "Fn::GetAtt": [operatorUserEntry[0], "Arn"] },
  };
  assert.deepEqual(assumeRoleTrust.Principal, expectedOperatorPrincipal);
  assert.deepEqual(sourceIdentityTrust.Principal, expectedOperatorPrincipal);
  assert.deepEqual(assumeRoleTrust.Condition, {
    Bool: { "aws:MultiFactorAuthPresent": "true" },
    StringEquals: {
      "sts:SourceIdentity": "foloo-entitlement-operator",
    },
    StringLike: { "sts:RoleSessionName": "fl021-*" },
  });
  assert.deepEqual(sourceIdentityTrust.Condition, {
    StringEquals: {
      "sts:SourceIdentity": "foloo-entitlement-operator",
    },
  });
  assert.equal(operatorRole.Properties?.MaxSessionDuration, 3600);
  const operatorUserPolicies = Object.values(resources).filter(
    (resource) =>
      resource.Type === "AWS::IAM::Policy" &&
      JSON.stringify(resource.Properties?.Users ?? []).includes(
        operatorUserEntry[0],
      ),
  );
  assert.equal(operatorUserPolicies.length, 1);
  const operatorUserPolicy = JSON.stringify(operatorUserPolicies[0]);
  assert.match(operatorUserPolicy, /sts:AssumeRole/u);
  assert.match(operatorUserPolicy, /sts:SetSourceIdentity/u);
  assert.doesNotMatch(
    operatorUserPolicy,
    /lambda:|rds:|cognito-idp:|kms:|secretsmanager:|cloudformation:/u,
  );
  assert.match(serialized, /kms:GenerateMac/u);
  assert.match(serialized, /AWS::CloudTrail::Trail/u);
  assert.match(serialized, /AWS::CloudTrail::EventDataStore|DataResources/u);
  assert.equal(
    template.Parameters?.AdministrativeEntitlementOperatorPrincipalArn,
    undefined,
  );
});

test("automatic entitlement processing is staged and has no public endpoint", () => {
  const app = new cdk.App();
  const template = Template.fromStack(
    new FolooBackendStack(app, "AutomaticEntitlementTest", {
      config: environmentConfig("dev"),
      env: { account: "111111111111", region: "us-east-1" },
      accountDeletionKeyArns: keyArns,
      automaticEntitlement: {
        enabled: true,
        enqueueEnabled: false,
        workerEnabled: false,
      },
      entitlementPreauthorizationPreviousHmacKeys: [
        {
          keyArn:
            "arn:aws:kms:us-east-1:111111111111:key/33333333-3333-4333-8333-333333333333",
          keyVersion: "v0",
        },
      ],
    }),
  ).toJSON();
  const serialized = JSON.stringify(template);
  assert.match(serialized, /AutomaticEntitlementWorkerFunction/u);
  assert.match(serialized, /AutomaticEntitlementQueue/u);
  assert.match(serialized, /AutomaticEntitlementDeadLetterQueue/u);
  assert.match(serialized, /EntitlementPreauthorizationHmacKey/u);
  assert.match(serialized, /FOLOO_ENTITLEMENT_AUTOMATIC_ENQUEUE_ENABLED/u);
  assert.match(serialized, /"false"/u);
  const postAuthentication = (
    template.Resources as Record<
      string,
      {
        Type: string;
        Properties?: {
          Environment?: { Variables?: Record<string, unknown> };
        };
      }
    >
  )["AccountDeletionPostAuthenticationFunctionD316CC49"]!;
  const preSignUp = (
    template.Resources as Record<
      string,
      {
        Type: string;
        Properties?: {
          Environment?: { Variables?: Record<string, unknown> };
        };
      }
    >
  )["AccountDeletionPreSignUpFunction5C21A596"]!;
  assert.equal(
    postAuthentication.Properties?.Environment?.Variables?.[
      "FOLOO_ENTITLEMENT_AUTOMATIC_ENQUEUE_ENABLED"
    ],
    "false",
  );
  assert.deepEqual(
    postAuthentication.Properties?.Environment?.Variables?.[
      "FOLOO_ENTITLEMENT_AUTOMATIC_QUEUE_URL"
    ],
    { Ref: "AutomaticEntitlementQueue0DE05474" },
  );
  assert.equal(
    preSignUp.Properties?.Environment?.Variables?.[
      "FOLOO_ENTITLEMENT_AUTOMATIC_ENQUEUE_ENABLED"
    ],
    undefined,
  );
  assert.equal(
    Object.entries(
      template.Resources as Record<
        string,
        { Type: string; Properties?: Record<string, unknown> }
      >,
    ).some(
      ([id, resource]) =>
        id.startsWith("AutomaticEntitlement") &&
        String(resource.Type).startsWith("AWS::ApiGateway"),
    ),
    false,
  );
  const mappings = Object.values(
    template.Resources as Record<
      string,
      { Type: string; Properties?: Record<string, unknown> }
    >,
  ).filter((resource) => resource.Type === "AWS::Lambda::EventSourceMapping");
  assert.ok(
    mappings.some((resource) => resource.Properties?.Enabled === false),
  );

  const resources = template.Resources as Record<
    string,
    {
      Type: string;
      Properties?: {
        Environment?: { Variables?: Record<string, unknown> };
        Role?: { "Fn::GetAtt"?: [string, string] };
        Roles?: unknown;
        [key: string]: unknown;
      };
    }
  >;
  const deletionWorker = Object.entries(resources).find(
    ([id, resource]) =>
      id.startsWith("AccountDeletionWorkerFunction") &&
      resource.Type === "AWS::Lambda::Function",
  );
  const identityResolver = Object.entries(resources).find(
    ([id, resource]) =>
      id.startsWith("AdministrativeEntitlementIdentityFunction") &&
      resource.Type === "AWS::Lambda::Function",
  );
  assert.ok(deletionWorker);
  assert.ok(identityResolver);
  const workerEnvironment = deletionWorker[1].Properties?.Environment
    ?.Variables as Record<string, unknown>;
  assert.deepEqual(
    workerEnvironment.ENTITLEMENT_IDENTITY_RESOLVER_FUNCTION_NAME,
    {
      Ref: identityResolver[0],
    },
  );
  assert.equal(
    workerEnvironment.ENTITLEMENT_PREAUTHORIZATION_HMAC_KEY_VERSION,
    "v1",
  );
  assert.equal(
    workerEnvironment.ENTITLEMENT_PREAUTHORIZATION_PREVIOUS_KEYS_JSON,
    JSON.stringify([
      {
        keyArn:
          "arn:aws:kms:us-east-1:111111111111:key/33333333-3333-4333-8333-333333333333",
        keyVersion: "v0",
      },
    ]),
  );
  const workerRole = deletionWorker[1].Properties?.Role?.["Fn::GetAtt"]?.[0];
  const workerPolicies = Object.values(resources).filter(
    (resource) =>
      resource.Type === "AWS::IAM::Policy" &&
      JSON.stringify(resource.Properties?.Roles).includes(
        JSON.stringify({ Ref: workerRole }),
      ),
  );
  const workerPolicyJson = JSON.stringify(workerPolicies);
  assert.match(workerPolicyJson, /kms:GenerateMac/u);
  assert.match(workerPolicyJson, /lambda:InvokeFunction/u);
  assert.match(workerPolicyJson, new RegExp(identityResolver[0], "u"));
  assert.match(workerPolicyJson, /33333333-3333-4333-8333-333333333333/u);
  assert.doesNotMatch(workerPolicyJson, /cognito-idp:ListUsers/u);
});

test("MON-21 activation enables durable enqueue and consumption while Unlimited QA is off", () => {
  const app = new cdk.App();
  const template = Template.fromStack(
    new FolooBackendStack(app, "AutomaticEntitlementActivationTest", {
      config: environmentConfig("dev"),
      env: { account: "111111111111", region: "us-east-1" },
      accountDeletionKeyArns: keyArns,
      unlimitedQaMode: false,
      automaticEntitlement: {
        enabled: true,
        enqueueEnabled: true,
        workerEnabled: true,
      },
    }),
  ).toJSON();
  const resources = template.Resources as Record<
    string,
    {
      Type: string;
      Properties?: {
        Enabled?: boolean;
        EventSourceArn?: unknown;
        Environment?: { Variables?: Record<string, unknown> };
      };
    }
  >;
  const postAuthentication =
    resources.AccountDeletionPostAuthenticationFunctionD316CC49;
  const api = resources.ApiFunctionCE271BD4;
  assert.ok(postAuthentication);
  assert.ok(api);
  assert.equal(
    postAuthentication.Properties?.Environment?.Variables?.[
      "FOLOO_ENTITLEMENT_AUTOMATIC_ENQUEUE_ENABLED"
    ],
    "true",
  );
  assert.equal(
    api.Properties?.Environment?.Variables?.FOLOO_UNLIMITED_QA_MODE,
    "false",
  );

  const automaticMapping = Object.values(resources).find(
    (resource) =>
      resource.Type === "AWS::Lambda::EventSourceMapping" &&
      JSON.stringify(resource.Properties?.EventSourceArn).includes(
        "AutomaticEntitlementQueue",
      ),
  );
  assert.ok(automaticMapping);
  assert.equal(automaticMapping.Properties?.Enabled, true);

  const serialized = JSON.stringify(template);
  assert.doesNotMatch(serialized, /AWS::Lambda::Url/u);
  assert.doesNotMatch(serialized, /admin-entitlement.*RouteKey/iu);
});

test("administrative boundary is explicit in DEV and PROD", () => {
  assert.equal(
    administrativeEntitlementForEnvironment("dev", undefined),
    false,
  );
  assert.equal(administrativeEntitlementForEnvironment("dev", "true"), true);
  assert.equal(administrativeEntitlementForEnvironment("prod", true), true);
  assert.deepEqual(
    automaticEntitlementConfigForEnvironment("dev", true, false, false),
    { enabled: true, enqueueEnabled: false, workerEnabled: false },
  );
  assert.deepEqual(
    automaticEntitlementConfigForEnvironment("dev", true, true, true),
    { enabled: true, enqueueEnabled: true, workerEnabled: true },
  );
  assert.deepEqual(
    automaticEntitlementConfigForEnvironment("prod", true, true, true),
    { enabled: true, enqueueEnabled: true, workerEnabled: true },
  );
  assert.throws(
    () => automaticEntitlementConfigForEnvironment("dev", false, true, false),
    /requires its passive boundary/u,
  );
});
