/** Synth-only regression coverage for the passive FOL-AUTH-02 boundary. */

import assert from "node:assert/strict";
import test from "node:test";

import * as cdk from "aws-cdk-lib";
import { Match, Template } from "aws-cdk-lib/assertions";

import { WebSessionInfrastructure } from "../infra/web_session_infrastructure.js";

test("AUT-18 web sessions use retained KMS encryption, PITR, TTL and least privilege", () => {
  const app = new cdk.App();
  const stack = new cdk.Stack(app, "WebSessionInfrastructureTest", {
    env: { account: "111111111111", region: "us-east-1" },
  });
  new WebSessionInfrastructure(stack, "Sessions", {
    environmentName: "dev",
    userPoolId: "us-east-1_synthetic",
    webClientId: "synthetic-client",
    cognitoDomain: "example.auth.us-east-1.amazoncognito.com",
    callbackUrl: "https://foloo.io/api/auth/google/callback",
    allowedOrigin: "https://foloo.io",
    publicApiBaseUrl: "https://api.example.test",
    successRedirectPath: "/dashboard",
    absoluteDurationSeconds: 43_200,
    idleDurationSeconds: 1_800,
  });
  const template = Template.fromStack(stack);

  template.hasResourceProperties("AWS::DynamoDB::Table", {
    BillingMode: "PAY_PER_REQUEST",
    DeletionProtectionEnabled: true,
    PointInTimeRecoverySpecification: { PointInTimeRecoveryEnabled: true },
    SSESpecification: {
      SSEEnabled: true,
      SSEType: "KMS",
      KMSMasterKeyId: Match.anyValue(),
    },
    TimeToLiveSpecification: { AttributeName: "expires_at", Enabled: true },
  });
  template.hasResource("AWS::DynamoDB::Table", {
    DeletionPolicy: "Retain",
    UpdateReplacePolicy: "Retain",
  });
  template.hasResource("AWS::KMS::Key", {
    DeletionPolicy: "Retain",
    UpdateReplacePolicy: "Retain",
  });
  template.resourceCountIs("AWS::CloudWatch::Alarm", 3);
  template.hasResourceProperties("AWS::Lambda::Function", {
    Environment: {
      Variables: Match.objectLike({
        FOLOO_WEB_SESSION_ENABLED: "false",
        WEB_SESSION_QA_SUBJECT_HASHES: "",
        WEB_SESSION_ABSOLUTE_SECONDS: "43200",
        WEB_SESSION_IDLE_SECONDS: "1800",
        WEB_AUTH_CALLBACK_URL: "https://foloo.io/api/auth/google/callback",
        WEB_AUTH_ALLOWED_ORIGIN: "https://foloo.io",
        WEB_COGNITO_CLIENT_ID: "synthetic-client",
        WEB_AUTH_SUCCESS_REDIRECT_PATH: "/dashboard",
      }),
    },
  });

  const policies = JSON.stringify(template.findResources("AWS::IAM::Policy"));
  assert.match(policies, /dynamodb:GetItem/u);
  assert.match(policies, /dynamodb:PutItem/u);
  assert.match(policies, /kms:Encrypt/u);
  assert.match(policies, /kms:Decrypt/u);
  assert.doesNotMatch(policies, /dynamodb:\*/u);
  assert.doesNotMatch(policies, /kms:\*/u);
});

test("AUT-18 QA activation carries only pseudonymous allowed subjects", () => {
  const app = new cdk.App();
  const stack = new cdk.Stack(app, "WebSessionQaInfrastructureTest", {
    env: { account: "111111111111", region: "us-east-1" },
  });
  const hash = "A".repeat(43);
  new WebSessionInfrastructure(stack, "Sessions", {
    environmentName: "dev",
    userPoolId: "us-east-1_synthetic",
    webClientId: "synthetic-client",
    cognitoDomain: "example.auth.us-east-1.amazoncognito.com",
    callbackUrl: "https://foloo.io/api/auth/google/callback",
    allowedOrigin: "https://foloo.io",
    publicApiBaseUrl: "https://api.example.test",
    successRedirectPath: "/dashboard",
    absoluteDurationSeconds: 43_200,
    idleDurationSeconds: 1_800,
    enabled: true,
    qaSubjectHashes: [hash],
  });

  Template.fromStack(stack).hasResourceProperties("AWS::Lambda::Function", {
    Environment: {
      Variables: Match.objectLike({
        FOLOO_WEB_SESSION_ENABLED: "true",
        WEB_SESSION_QA_SUBJECT_HASHES: hash,
        WEB_AUTH_SUCCESS_REDIRECT_PATH: "/dashboard",
      }),
    },
  });
});
