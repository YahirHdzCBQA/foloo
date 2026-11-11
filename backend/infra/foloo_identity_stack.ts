/** Owns the retained PROD identity, key and empty-secret boundary for Foloo. */

import * as cdk from "aws-cdk-lib";
import * as cognito from "aws-cdk-lib/aws-cognito";
import * as kms from "aws-cdk-lib/aws-kms";
import * as secretsmanager from "aws-cdk-lib/aws-secretsmanager";
import type { Construct } from "constructs";

import type { ProdIdentityProviderConfig } from "./prod_identity_config.js";

export type FolooIdentityStackProps = cdk.StackProps & {
  providers: ProdIdentityProviderConfig;
};

export class FolooIdentityStack extends cdk.Stack {
  readonly userPool: cognito.UserPool;
  readonly mobileClient: cognito.UserPoolClient;
  readonly cognitoDomain: string;
  readonly identityHmacKey: kms.Key;
  readonly notificationRecipientKey: kms.Key;

  constructor(scope: Construct, id: string, props: FolooIdentityStackProps) {
    super(scope, id, props);

    this.userPool = new cognito.UserPool(this, "UserPool", {
      userPoolName: "foloo-users-prod",
      featurePlan: cognito.FeaturePlan.ESSENTIALS,
      selfSignUpEnabled: true,
      signInAliases: { email: true },
      autoVerify: { email: true },
      signInCaseSensitive: false,
      accountRecovery: cognito.AccountRecovery.EMAIL_ONLY,
      mfa: cognito.Mfa.OFF,
      passwordPolicy: {
        minLength: 8,
        requireDigits: true,
        requireLowercase: true,
        requireSymbols: true,
        requireUppercase: true,
      },
      deletionProtection: true,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });
    if (
      props.providers.triggers.preSignUpFunctionArn &&
      props.providers.triggers.postAuthenticationFunctionArn
    ) {
      for (const arn of [
        props.providers.triggers.preSignUpFunctionArn,
        props.providers.triggers.postAuthenticationFunctionArn,
      ]) {
        const parsed = cdk.Arn.split(arn, cdk.ArnFormat.COLON_RESOURCE_NAME);
        if (
          parsed.service !== "lambda" ||
          parsed.region !== this.region ||
          (!cdk.Token.isUnresolved(this.account) &&
            parsed.account !== this.account)
        )
          throw new Error(
            "PROD Cognito trigger ARN must belong to this environment.",
          );
      }
      const cfnUserPool = this.userPool.node
        .defaultChild as cognito.CfnUserPool;
      cfnUserPool.lambdaConfig = {
        preSignUp: props.providers.triggers.preSignUpFunctionArn,
        postAuthentication:
          props.providers.triggers.postAuthenticationFunctionArn,
      };
    }
    const domain = this.userPool.addDomain("Domain", {
      cognitoDomain: { domainPrefix: props.providers.domainPrefix },
    });
    this.cognitoDomain = `${props.providers.domainPrefix}.auth.${this.region}.amazoncognito.com`;

    const googleSecret = this.emptySecret(
      "GoogleClientSecret",
      "foloo/prod/cognito/google-client",
      "Google OAuth client secret; populate manually before enabling the IdP.",
    );
    const appleSecret = this.emptySecret(
      "ApplePrivateKeySecret",
      "foloo/prod/cognito/apple-private-key",
      "Apple private key; populate manually before enabling the IdP.",
    );
    const emailProvidersSecret = this.emptySecret(
      "EmailProvidersSecret",
      "foloo/prod/email-providers",
      "Gmail and Outlook sender OAuth configuration for PROD.",
    );

    const supportedProviders = [cognito.UserPoolClientIdentityProvider.COGNITO];
    const dependencies: cdk.CfnResource[] = [];
    if (props.providers.google.enabled) {
      const provider = new cognito.UserPoolIdentityProviderGoogle(
        this,
        "GoogleIdentityProvider",
        {
          userPool: this.userPool,
          clientId: props.providers.google.clientId!,
          clientSecretValue: cdk.SecretValue.secretsManager(googleSecret.ref, {
            jsonField: "clientSecret",
          }),
          scopes: ["openid", "email", "profile"],
          attributeMapping: {
            email: cognito.ProviderAttribute.GOOGLE_EMAIL,
            emailVerified: cognito.ProviderAttribute.GOOGLE_EMAIL_VERIFIED,
          },
        },
      );
      provider.node.addDependency(googleSecret);
      dependencies.push(provider.node.defaultChild as cdk.CfnResource);
      supportedProviders.push(cognito.UserPoolClientIdentityProvider.GOOGLE);
    }
    if (props.providers.apple.enabled) {
      const provider = new cognito.UserPoolIdentityProviderApple(
        this,
        "AppleIdentityProvider",
        {
          userPool: this.userPool,
          clientId: props.providers.apple.servicesId!,
          teamId: props.providers.apple.teamId!,
          keyId: props.providers.apple.keyId!,
          privateKeyValue: cdk.SecretValue.secretsManager(appleSecret.ref, {
            jsonField: "privateKey",
          }),
          scopes: ["email", "name"],
          attributeMapping: {
            email: cognito.ProviderAttribute.APPLE_EMAIL,
            emailVerified: cognito.ProviderAttribute.APPLE_EMAIL_VERIFIED,
          },
        },
      );
      provider.node.addDependency(appleSecret);
      dependencies.push(provider.node.defaultChild as cdk.CfnResource);
      supportedProviders.push(cognito.UserPoolClientIdentityProvider.APPLE);
    }

    this.mobileClient = this.userPool.addClient("MobileClient", {
      userPoolClientName: "foloo-mobile-prod",
      generateSecret: false,
      enableTokenRevocation: true,
      preventUserExistenceErrors: true,
      authFlows: { userSrp: true },
      supportedIdentityProviders: supportedProviders,
      accessTokenValidity: cdk.Duration.minutes(60),
      idTokenValidity: cdk.Duration.minutes(60),
      refreshTokenValidity: cdk.Duration.days(5),
      oAuth: {
        flows: { authorizationCodeGrant: true, implicitCodeGrant: false },
        scopes: [
          cognito.OAuthScope.OPENID,
          cognito.OAuthScope.EMAIL,
          cognito.OAuthScope.PROFILE,
        ],
        callbackUrls: ["foloo://callback/"],
        logoutUrls: ["foloo://signout/"],
      },
    });
    for (const dependency of dependencies)
      this.mobileClient.node.addDependency(dependency);

    this.identityHmacKey = new kms.Key(this, "AccountDeletionIdentityHmacKey", {
      description: "HMAC selectors for PROD registration and deletion guards",
      keySpec: kms.KeySpec.HMAC_256,
      keyUsage: kms.KeyUsage.GENERATE_VERIFY_MAC,
      pendingWindow: cdk.Duration.days(30),
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });
    this.identityHmacKey.addAlias("alias/foloo-prod-account-deletion-identity");
    this.notificationRecipientKey = new kms.Key(
      this,
      "AccountDeletionNotificationRecipientKey",
      {
        description: "Encrypts PROD account-deletion notification recipients",
        enableKeyRotation: true,
        pendingWindow: cdk.Duration.days(30),
        removalPolicy: cdk.RemovalPolicy.RETAIN,
      },
    );
    this.notificationRecipientKey.addAlias(
      "alias/foloo-prod-account-deletion-recipient",
    );

    for (const [outputId, value] of [
      ["UserPoolId", this.userPool.userPoolId],
      ["MobileAppClientId", this.mobileClient.userPoolClientId],
      ["CognitoDomain", this.cognitoDomain],
      ["AccountDeletionIdentityHmacKeyArn", this.identityHmacKey.keyArn],
      [
        "AccountDeletionNotificationRecipientKeyArn",
        this.notificationRecipientKey.keyArn,
      ],
      ["GoogleClientSecretArn", googleSecret.ref],
      ["ApplePrivateKeySecretArn", appleSecret.ref],
      ["EmailProvidersSecretArn", emailProvidersSecret.ref],
    ] as const) {
      new cdk.CfnOutput(this, outputId, { value });
    }
    new cdk.CfnOutput(this, "CognitoHostedUiBaseUrl", {
      value: domain.baseUrl(),
    });
  }

  private emptySecret(
    id: string,
    name: string,
    description: string,
  ): secretsmanager.CfnSecret {
    const secret = new secretsmanager.CfnSecret(this, id, {
      name,
      description,
      tags: [{ key: "Environment", value: "prod" }],
    });
    secret.applyRemovalPolicy(cdk.RemovalPolicy.RETAIN);
    return secret;
  }
}
