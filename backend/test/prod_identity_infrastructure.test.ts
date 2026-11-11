/** Validates the retained and environment-isolated FolooIdentity-prod template. */

import assert from "node:assert/strict";
import test from "node:test";

import * as cdk from "aws-cdk-lib";
import { Template } from "aws-cdk-lib/assertions";

import { FolooIdentityStack } from "../infra/foloo_identity_stack.js";
import { prodIdentityProviderConfig } from "../infra/prod_identity_config.js";

test("INF-04 PROD identity creates retained Cognito, keys and empty secrets", () => {
  const stack = new FolooIdentityStack(new cdk.App(), "FolooIdentity-prod", {
    providers: prodIdentityProviderConfig((name) =>
      name === "prodCognitoDomainPrefix" ? "foloo-prod-test" : undefined,
    ),
    env: { account: "111111111111", region: "us-east-1" },
    terminationProtection: true,
  });
  const template = Template.fromStack(stack);
  template.resourceCountIs("AWS::Cognito::UserPool", 1);
  template.hasResourceProperties("AWS::Cognito::UserPool", {
    UserPoolName: "foloo-users-prod",
    DeletionProtection: "ACTIVE",
    UsernameAttributes: ["email"],
    AutoVerifiedAttributes: ["email"],
  });
  template.hasResourceProperties("AWS::Cognito::UserPoolClient", {
    ClientName: "foloo-mobile-prod",
    GenerateSecret: false,
    CallbackURLs: ["foloo://callback/"],
    LogoutURLs: ["foloo://signout/"],
    SupportedIdentityProviders: ["COGNITO"],
  });
  template.resourceCountIs("AWS::SecretsManager::Secret", 3);
  const json = JSON.stringify(template.toJSON());
  assert.match(json, /foloo\/prod\/email-providers/u);
  assert.match(json, /foloo\/prod\/cognito\/google-client/u);
  assert.match(json, /foloo\/prod\/cognito\/apple-private-key/u);
  assert.doesNotMatch(json, /SecretString|GenerateSecretString/u);
  template.resourceCountIs("AWS::KMS::Key", 2);
  assert.doesNotMatch(json, /us-east-1_QVm3dWe4O|6jong3atp2crqcsde6g215ant8/u);
});

test("AUT-10 provider activation is explicit and complete", () => {
  assert.throws(
    () => prodIdentityProviderConfig(() => undefined),
    /prodCognitoDomainPrefix/u,
  );
  assert.throws(
    () =>
      prodIdentityProviderConfig((name) => {
        if (name === "prodCognitoDomainPrefix") return "foloo-prod-test";
        if (name === "prodGoogleIdentityProviderEnabled") return true;
        return undefined;
      }),
    /Google PROD configuration/u,
  );
  assert.throws(
    () =>
      prodIdentityProviderConfig((name) => {
        if (name === "prodCognitoDomainPrefix") return "foloo-prod-test";
        if (name === "prodAppleServicesId") return "com.example";
        return undefined;
      }),
    /Apple PROD configuration/u,
  );
  assert.throws(
    () =>
      prodIdentityProviderConfig((name) => {
        if (name === "prodCognitoDomainPrefix") return "foloo-prod-test";
        if (name === "prodPreSignUpFunctionArn")
          return "arn:aws:lambda:us-east-1:111111111111:function:pre";
        return undefined;
      }),
    /triggers must be configured as a pair/u,
  );
});
