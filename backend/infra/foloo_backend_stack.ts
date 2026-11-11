/** Defines environment-isolated API/Lambda/private-RDS infrastructure. */

import { join } from "node:path";

import * as cdk from "aws-cdk-lib";
import * as apigateway from "aws-cdk-lib/aws-apigatewayv2";
import * as authorizers from "aws-cdk-lib/aws-apigatewayv2-authorizers";
import * as integrations from "aws-cdk-lib/aws-apigatewayv2-integrations";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as lambdaNode from "aws-cdk-lib/aws-lambda-nodejs";
import * as lambdaEventSources from "aws-cdk-lib/aws-lambda-event-sources";
import * as logs from "aws-cdk-lib/aws-logs";
import * as rds from "aws-cdk-lib/aws-rds";
import * as s3 from "aws-cdk-lib/aws-s3";
import * as iam from "aws-cdk-lib/aws-iam";
import * as secretsmanager from "aws-cdk-lib/aws-secretsmanager";
import * as kms from "aws-cdk-lib/aws-kms";
import * as sqs from "aws-cdk-lib/aws-sqs";
import * as cloudwatch from "aws-cdk-lib/aws-cloudwatch";
import * as cloudwatchActions from "aws-cdk-lib/aws-cloudwatch-actions";
import * as cognito from "aws-cdk-lib/aws-cognito";
import * as ses from "aws-cdk-lib/aws-ses";
import * as events from "aws-cdk-lib/aws-events";
import * as eventTargets from "aws-cdk-lib/aws-events-targets";
import * as sns from "aws-cdk-lib/aws-sns";
import * as cloudtrail from "aws-cdk-lib/aws-cloudtrail";
import type { Construct } from "constructs";

import { validateBillingConfig, type EnvironmentConfig } from "./config.js";
import { AccountDeletionLedgerInfrastructure } from "./account_deletion_ledger_infrastructure.js";
import { qaInventoryEnvironment } from "./qa_inventory_config.js";
import { WebSessionInfrastructure } from "./web_session_infrastructure.js";

type FolooBackendStackProps = cdk.StackProps & {
  config: EnvironmentConfig;
  unlimitedQaMode?: boolean;
  administrativeEntitlementEnabled?: boolean;
  automaticEntitlement?: {
    enabled: boolean;
    enqueueEnabled: boolean;
    workerEnabled: boolean;
  };
  entitlementPreauthorizationPreviousHmacKeys?: readonly {
    keyArn: string;
    keyVersion: string;
  }[];
  webSessionQa?: {
    normalAccessEnabled?: boolean;
    enabled: boolean;
    subjectHashes: readonly string[];
  };
  cognitoAllowedFederatedProviders?: readonly (
    "Google" | "SignInWithApple" | "Microsoft"
  )[];
  cognitoAppleIdentityProvider?: {
    enabled: boolean;
    servicesId: string;
    teamId: string;
    keyId: string;
    privateKeySecretArn?: string;
  };
  accountDeletionQa?: {
    enabled: boolean;
    runtimeEnabled?: boolean;
    normalAccessEnabled?: boolean;
    intakeEnabled: boolean;
    registrationGuardEnabled: boolean;
    outboxRecoveryEnabled: boolean;
    restoreReconcilerEnabled: boolean;
    recoverySchedulerEnabled: boolean;
    workerEnabled: boolean;
    workerEventSourceEnabled: boolean;
    finalizerEnabled: boolean;
    subjectHashes: readonly string[];
  };
  accountDeletionSesNotificationsEnabled?: boolean;
  accountDeletionKeyArns: {
    identityHmacKeyArn: string;
    notificationRecipientKeyArn: string;
  };
};

export class FolooBackendStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: FolooBackendStackProps) {
    super(scope, id, props);
    const { config } = props;
    validateBillingConfig(config);
    const accountDeletionEnabled =
      (props.accountDeletionQa?.runtimeEnabled ??
        props.accountDeletionQa?.enabled) === true;
    const accountDeletionQaEnabled = props.accountDeletionQa?.enabled === true;
    const accountDeletionNormalAccessEnabled =
      props.accountDeletionQa?.normalAccessEnabled === true;
    const accountDeletionIntakeEnabled =
      accountDeletionEnabled && props.accountDeletionQa?.intakeEnabled === true;
    const accountDeletionRegistrationGuardEnabled =
      props.accountDeletionQa?.registrationGuardEnabled === true;
    const accountDeletionOutboxRecoveryEnabled =
      props.accountDeletionQa?.outboxRecoveryEnabled === true;
    const accountDeletionRestoreReconcilerEnabled =
      props.accountDeletionQa?.restoreReconcilerEnabled === true;
    const accountDeletionRecoverySchedulerEnabled =
      props.accountDeletionQa?.recoverySchedulerEnabled === true;
    const accountDeletionWorkerEnabled =
      props.accountDeletionQa?.workerEnabled === true;
    const accountDeletionWorkerEventSourceEnabled =
      props.accountDeletionQa?.workerEventSourceEnabled === true;
    const accountDeletionFinalizerEnabled =
      props.accountDeletionQa?.finalizerEnabled === true;
    const accountDeletionSesNotificationsEnabled =
      props.accountDeletionSesNotificationsEnabled === true;
    const automaticEntitlementEnabled =
      props.automaticEntitlement?.enabled === true;
    const entitlementInfrastructureEnabled =
      props.administrativeEntitlementEnabled === true ||
      automaticEntitlementEnabled;
    const previousEntitlementKeys =
      props.entitlementPreauthorizationPreviousHmacKeys ?? [];
    if (
      previousEntitlementKeys.some(
        ({ keyArn, keyVersion }) =>
          !keyArn.trim() ||
          !/^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/u.test(keyVersion),
      ) ||
      new Set(["v1", ...previousEntitlementKeys.map((key) => key.keyVersion)])
        .size !==
        previousEntitlementKeys.length + 1
    ) {
      throw new Error("Previous entitlement HMAC keys are invalid.");
    }
    const cognitoAllowedFederatedProviders =
      props.cognitoAllowedFederatedProviders ?? (["Google"] as const);
    if (
      new Set(cognitoAllowedFederatedProviders).size !==
      cognitoAllowedFederatedProviders.length
    ) {
      throw new Error("Cognito federated provider allowlist is invalid.");
    }

    const userPool = cognito.UserPool.fromUserPoolId(
      this,
      "ExistingUserPool",
      config.userPoolId,
    );
    if (props.cognitoAppleIdentityProvider?.enabled) {
      const applePrivateKeySecretArn =
        props.cognitoAppleIdentityProvider.privateKeySecretArn;
      if (!applePrivateKeySecretArn) {
        throw new Error("Apple IdP secret ARN is required when enabled.");
      }
      const appleSecretArn = cdk.Arn.split(
        applePrivateKeySecretArn,
        cdk.ArnFormat.COLON_RESOURCE_NAME,
      );
      if (
        appleSecretArn.region !== config.region ||
        (!cdk.Token.isUnresolved(this.account) &&
          appleSecretArn.account !== this.account)
      ) {
        throw new Error("Apple IdP secret must belong to the selected stack.");
      }
      const applePrivateKeySecret = secretsmanager.Secret.fromSecretCompleteArn(
        this,
        "ApplePrivateKeySecret",
        applePrivateKeySecretArn,
      );
      new cognito.UserPoolIdentityProviderApple(this, "AppleIdentityProvider", {
        userPool,
        clientId: props.cognitoAppleIdentityProvider.servicesId,
        teamId: props.cognitoAppleIdentityProvider.teamId,
        keyId: props.cognitoAppleIdentityProvider.keyId,
        privateKeyValue:
          applePrivateKeySecret.secretValueFromJson("privateKey"),
        scopes: ["email", "name"],
        attributeMapping: {
          email: cognito.ProviderAttribute.APPLE_EMAIL,
          emailVerified: cognito.ProviderAttribute.APPLE_EMAIL_VERIFIED,
        },
      });
    }
    const webUserPoolClient = new cognito.UserPoolClient(
      this,
      "WebUserPoolClient",
      {
        userPool,
        userPoolClientName: `foloo-web-${config.name}`,
        generateSecret: false,
        enableTokenRevocation: true,
        preventUserExistenceErrors: true,
        authFlows: {
          userSrp: true,
        },
        supportedIdentityProviders: [
          cognito.UserPoolClientIdentityProvider.COGNITO,
          ...cognitoAllowedFederatedProviders.map((provider) => {
            if (provider === "Google")
              return cognito.UserPoolClientIdentityProvider.GOOGLE;
            if (provider === "SignInWithApple")
              return cognito.UserPoolClientIdentityProvider.APPLE;
            return cognito.UserPoolClientIdentityProvider.custom("Microsoft");
          }),
        ],
        oAuth: {
          flows: {
            authorizationCodeGrant: true,
            implicitCodeGrant: false,
          },
          scopes: [
            cognito.OAuthScope.OPENID,
            cognito.OAuthScope.EMAIL,
            cognito.OAuthScope.PROFILE,
          ],
          callbackUrls: [...config.webAuth.callbackUrls],
          logoutUrls: [...config.webAuth.logoutUrls],
        },
      },
    );
    // AUT-18 / RNF-09: opt-in local evaluation; preserve the resource dependency.
    // Ref and GetAtt ClientId are documented equivalents, but AWS drift-aware
    // evaluation still needs a separately authorized Change Set.
    const explicitWebClientId = this.node.tryGetContext(
      "webClientIdExplicitAttribute",
    );
    const webClientId =
      explicitWebClientId === true || explicitWebClientId === "true"
        ? (webUserPoolClient.node.defaultChild as cognito.CfnUserPoolClient)
            .attrClientId
        : webUserPoolClient.userPoolClientId;
    new cognito.CfnManagedLoginBranding(this, "WebManagedLoginBranding", {
      userPoolId: config.userPoolId,
      clientId: webClientId,
      useCognitoProvidedValues: true,
    });

    const vpc = new ec2.Vpc(this, "Vpc", {
      ipAddresses: ec2.IpAddresses.cidr(config.vpcCidr),
      maxAzs: 2,
      natGateways: 0,
      subnetConfiguration: [
        {
          name: "isolated",
          subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
          cidrMask: 24,
        },
      ],
    });
    const lambdaSg = new ec2.SecurityGroup(this, "LambdaSecurityGroup", {
      vpc,
      allowAllOutbound: false,
    });
    const databaseSg = new ec2.SecurityGroup(this, "DatabaseSecurityGroup", {
      vpc,
      allowAllOutbound: false,
    });
    databaseSg.addIngressRule(
      lambdaSg,
      ec2.Port.tcp(5432),
      "Only Foloo Lambdas reach PostgreSQL",
    );
    lambdaSg.addEgressRule(databaseSg, ec2.Port.tcp(5432), "PostgreSQL only");

    const endpointSg = new ec2.SecurityGroup(
      this,
      "SecretsEndpointSecurityGroup",
      { vpc, allowAllOutbound: false },
    );
    endpointSg.addIngressRule(
      lambdaSg,
      ec2.Port.tcp(443),
      "Lambdas read scoped secrets",
    );
    lambdaSg.addEgressRule(
      endpointSg,
      ec2.Port.tcp(443),
      "Secrets Manager endpoint only",
    );
    vpc.addInterfaceEndpoint("SecretsManagerEndpoint", {
      service: ec2.InterfaceVpcEndpointAwsService.SECRETS_MANAGER,
      subnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [endpointSg],
      privateDnsEnabled: true,
      open: false,
    });
    for (const [id, service] of [
      ["KmsEndpoint", ec2.InterfaceVpcEndpointAwsService.KMS],
      ["SqsEndpoint", ec2.InterfaceVpcEndpointAwsService.SQS],
    ] as const) {
      vpc.addInterfaceEndpoint(id, {
        service,
        subnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
        securityGroups: [endpointSg],
        privateDnsEnabled: true,
        open: false,
      });
    }
    vpc.addGatewayEndpoint("S3Endpoint", {
      service: ec2.GatewayVpcEndpointAwsService.S3,
      subnets: [{ subnetType: ec2.SubnetType.PRIVATE_ISOLATED }],
    });
    vpc.addGatewayEndpoint("DynamoDbEndpoint", {
      service: ec2.GatewayVpcEndpointAwsService.DYNAMODB,
      subnets: [{ subnetType: ec2.SubnetType.PRIVATE_ISOLATED }],
    });
    lambdaSg.addEgressRule(
      ec2.Peer.anyIpv4(),
      ec2.Port.tcp(443),
      "HTTPS through private VPC endpoints; isolated subnets have no NAT",
    );

    const mediaBucket = new s3.Bucket(this, "MediaBucket", {
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      enforceSSL: true,
      versioned: false,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      autoDeleteObjects: false,
    });

    const emailTokenKey = new kms.Key(this, "EmailTokenKey", {
      description:
        "Encrypts Foloo email OAuth credentials at the provider boundary",
      enableKeyRotation: true,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });
    const emailProviderSecret = secretsmanager.Secret.fromSecretNameV2(
      this,
      "EmailProviderSecret",
      `foloo/${config.name}/email-providers`,
    );
    const providerLogGroup = new logs.LogGroup(this, "EmailProviderLogGroup", {
      retention: logs.RetentionDays.ONE_WEEK,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });
    const providerFunction = new lambdaNode.NodejsFunction(
      this,
      "EmailProviderFunction",
      {
        entry: join(import.meta.dirname, "../src/email/provider_lambda.ts"),
        handler: "handler",
        runtime: lambda.Runtime.NODEJS_22_X,
        architecture: lambda.Architecture.ARM_64,
        memorySize: 1024,
        timeout: cdk.Duration.seconds(45),
        logGroup: providerLogGroup,
        environment: {
          EMAIL_PROVIDER_SECRET_ARN: emailProviderSecret.secretArn,
          EMAIL_TOKEN_KEY_ARN: emailTokenKey.keyArn,
        },
        bundling: { minify: true, sourceMap: true },
      },
    );
    emailProviderSecret.grantRead(providerFunction);
    emailTokenKey.grantEncryptDecrypt(providerFunction);

    const database = new rds.DatabaseInstance(this, "Database", {
      engine: rds.DatabaseInstanceEngine.postgres({
        version: rds.PostgresEngineVersion.VER_16,
      }),
      credentials: rds.Credentials.fromGeneratedSecret("foloo_admin"),
      databaseName: config.databaseName,
      instanceType: ec2.InstanceType.of(
        ec2.InstanceClass.T4G,
        ec2.InstanceSize.MICRO,
      ),
      allocatedStorage: 20,
      maxAllocatedStorage: 50,
      storageType: rds.StorageType.GP3,
      storageEncrypted: true,
      multiAz: false,
      publiclyAccessible: false,
      deletionProtection: config.databaseDeletionProtection,
      // RC-07: environment policy is explicit; DEV retains its current
      // Free Tier-compatible day while PROD fails into the 15-day policy.
      backupRetention: cdk.Duration.days(config.databaseBackupRetentionDays),
      cloudwatchLogsExports: ["postgresql"],
      cloudwatchLogsRetention: logs.RetentionDays.ONE_WEEK,
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [databaseSg],
      removalPolicy: cdk.RemovalPolicy.SNAPSHOT,
    });
    const appSecret = new secretsmanager.Secret(
      this,
      "ApplicationDatabaseSecret",
      {
        generateSecretString: {
          secretStringTemplate: JSON.stringify({ username: "foloo_app" }),
          generateStringKey: "password",
          excludePunctuation: true,
          passwordLength: 32,
        },
      },
    );
    // MON-21: private entitlement operations use a dedicated login and never
    // receive the RDS administrator or ordinary API credentials.
    const entitlementOperatorSecret = new secretsmanager.Secret(
      this,
      "EntitlementOperatorDatabaseSecret",
      {
        generateSecretString: {
          secretStringTemplate: JSON.stringify({
            username: "foloo_entitlement_operator",
          }),
          generateStringKey: "password",
          excludePunctuation: true,
          passwordLength: 32,
        },
      },
    );

    const commonEnvironment = {
      DB_HOST: database.dbInstanceEndpointAddress,
      DB_PORT: database.dbInstanceEndpointPort,
      DB_NAME: config.databaseName,
      DB_SECRET_ARN: appSecret.secretArn,
      NODE_EXTRA_CA_CERTS: "/var/runtime/ca-cert.pem",
    };
    const apiLogGroup = new logs.LogGroup(this, "ApiLogGroup", {
      retention: logs.RetentionDays.ONE_WEEK,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });
    const apiFunction = new lambdaNode.NodejsFunction(this, "ApiFunction", {
      entry: join(import.meta.dirname, "../src/transport/lambda.ts"),
      handler: "handler",
      runtime: lambda.Runtime.NODEJS_22_X,
      architecture: lambda.Architecture.ARM_64,
      memorySize: 512,
      timeout: cdk.Duration.seconds(15),
      logGroup: apiLogGroup,
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSg],
      environment: {
        ...commonEnvironment,
        DB_POOL_MAX: "2",
        MEDIA_BUCKET_NAME: mediaBucket.bucketName,
        EMAIL_PROVIDER_FUNCTION_NAME: providerFunction.functionName,
        PUBLIC_API_BASE_URL: "https://placeholder.invalid",
        COGNITO_ISSUER: `https://cognito-idp.${config.region}.amazonaws.com/${config.userPoolId}`,
        MOBILE_COGNITO_CLIENT_ID: config.appClientId,
        WEB_COGNITO_CLIENT_ID: webClientId,
        FOLOO_WEB_SESSION_ENABLED:
          props.webSessionQa?.enabled === true ? "true" : "false",
        WEB_SESSION_NORMAL_ACCESS_ENABLED:
          props.webSessionQa?.normalAccessEnabled === true ? "true" : "false",
        WEB_SESSION_QA_SUBJECT_HASHES: (
          props.webSessionQa?.subjectHashes ?? []
        ).join(","),
        FOLOO_UNLIMITED_QA_MODE:
          props.unlimitedQaMode === true ? "true" : "false",
        // STORE-02 remains fail-closed until Security/KMS/ledger approval.
        FOLOO_ACCOUNT_DELETION_ENABLED: accountDeletionEnabled
          ? "true"
          : "false",
        FOLOO_ACCOUNT_DELETION_INTAKE_ENABLED: accountDeletionIntakeEnabled
          ? "true"
          : "false",
        FOLOO_ENVIRONMENT: config.name,
        FOLOO_ACCOUNT_DELETION_NORMAL_ACCESS_ENABLED:
          accountDeletionNormalAccessEnabled ? "true" : "false",
        FOLOO_ACCOUNT_DELETION_QA_ENABLED: accountDeletionQaEnabled
          ? "true"
          : "false",
        ACCOUNT_DELETION_QA_SUBJECT_HASHES: (
          props.accountDeletionQa?.subjectHashes ?? []
        ).join(","),
        ACCOUNT_DELETION_NOTIFICATION_MODE:
          accountDeletionSesNotificationsEnabled ? "ses" : "disabled",
      },
      bundling: { minify: true, sourceMap: true },
    });
    const verifiedEmailLogGroup = new logs.LogGroup(
      this,
      "AccountDeletionVerifiedEmailLogGroup",
      {
        retention: logs.RetentionDays.ONE_WEEK,
        removalPolicy: cdk.RemovalPolicy.DESTROY,
      },
    );
    const verifiedEmailRole = new iam.Role(
      this,
      "AccountDeletionVerifiedEmailFunctionRole",
      { assumedBy: new iam.ServicePrincipal("lambda.amazonaws.com") },
    );
    verifiedEmailLogGroup.grantWrite(verifiedEmailRole);
    const verifiedEmailFunction = new lambdaNode.NodejsFunction(
      this,
      "AccountDeletionVerifiedEmailFunction",
      {
        entry: join(
          import.meta.dirname,
          "../src/account_deletion/cognito_verified_email_lambda.ts",
        ),
        handler: "handler",
        runtime: lambda.Runtime.NODEJS_22_X,
        architecture: lambda.Architecture.ARM_64,
        memorySize: 256,
        timeout: cdk.Duration.seconds(15),
        logGroup: verifiedEmailLogGroup,
        role: verifiedEmailRole,
        environment: {
          COGNITO_USER_INFO_ENDPOINT: `https://${config.webAuth.cognitoDomain}/oauth2/userInfo`,
        },
        bundling: { minify: true, sourceMap: true },
      },
    );
    verifiedEmailFunction.grantInvoke(apiFunction);
    apiFunction.addEnvironment(
      "ACCOUNT_DELETION_VERIFIED_EMAIL_FUNCTION_NAME",
      verifiedEmailFunction.functionName,
    );

    // STORE-02 resources are provisionable but every executable boundary is
    // forced off. Enabling requires the outstanding Security/Legal ADR gates.
    const accountDeletion = new AccountDeletionLedgerInfrastructure(
      this,
      "AccountDeletion",
      {
        existingIdentityHmacKeyArn:
          props.accountDeletionKeyArns.identityHmacKeyArn,
        existingNotificationRecipientKeyArn:
          props.accountDeletionKeyArns.notificationRecipientKeyArn,
      },
    );
    const entitlementPreauthorizationKey = entitlementInfrastructureEnabled
      ? new kms.Key(this, "EntitlementPreauthorizationHmacKey", {
          description: "HMAC selectors for private FL-021 preauthorizations",
          keySpec: kms.KeySpec.HMAC_256,
          keyUsage: kms.KeyUsage.GENERATE_VERIFY_MAC,
          removalPolicy: cdk.RemovalPolicy.RETAIN,
          pendingWindow: cdk.Duration.days(30),
        })
      : undefined;
    const automaticEntitlementDlq = automaticEntitlementEnabled
      ? new sqs.Queue(this, "AutomaticEntitlementDeadLetterQueue", {
          encryption: sqs.QueueEncryption.KMS_MANAGED,
          retentionPeriod: cdk.Duration.days(14),
          enforceSSL: true,
        })
      : undefined;
    const automaticEntitlementQueue = automaticEntitlementEnabled
      ? new sqs.Queue(this, "AutomaticEntitlementQueue", {
          encryption: sqs.QueueEncryption.KMS_MANAGED,
          visibilityTimeout: cdk.Duration.minutes(2),
          retentionPeriod: cdk.Duration.days(14),
          deadLetterQueue: {
            queue: automaticEntitlementDlq!,
            maxReceiveCount: 5,
          },
          enforceSSL: true,
        })
      : undefined;
    if (automaticEntitlementDlq) {
      new cloudwatch.Alarm(this, "AutomaticEntitlementDlqAlarm", {
        metric:
          automaticEntitlementDlq.metricApproximateNumberOfMessagesVisible(),
        threshold: 1,
        evaluationPeriods: 1,
        treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
      });
    }
    const accountDeletionOperationsTopic = new sns.Topic(
      this,
      "AccountDeletionOperationsTopic",
      {
        displayName: "Foloo Account Deletion operations",
        enforceSSL: true,
      },
    );
    const accountDeletionLogGroup = (id: string) =>
      new logs.LogGroup(this, id, {
        // INF-14/RNF-09: DEV operational logs are PII-free and retained 7 days.
        retention: logs.RetentionDays.ONE_WEEK,
        removalPolicy: cdk.RemovalPolicy.DESTROY,
      });
    const accountDeletionEmailDlq = new sqs.Queue(
      this,
      "AccountDeletionEmailDeadLetterQueue",
      {
        encryption: sqs.QueueEncryption.KMS_MANAGED,
        retentionPeriod: cdk.Duration.days(14),
        enforceSSL: true,
      },
    );
    const managedAccountDeletionEmailIdentity = config.manageSesIdentity
      ? new ses.EmailIdentity(this, "AccountDeletionEmailIdentity", {
          identity: ses.Identity.domain(config.sesIdentityName),
        })
      : undefined;
    // PROD consumes the account-level verified identity without claiming its
    // lifecycle or emitting duplicate DKIM resources into FolooBackend-prod.
    const accountDeletionEmailIdentity =
      managedAccountDeletionEmailIdentity ??
      ses.EmailIdentity.fromEmailIdentityName(
        this,
        "ImportedAccountDeletionEmailIdentity",
        config.sesIdentityName,
      );
    new cloudwatch.Alarm(this, "AccountDeletionEmailDlqAlarm", {
      metric:
        accountDeletionEmailDlq.metricApproximateNumberOfMessagesVisible(),
      threshold: 1,
      evaluationPeriods: 1,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });
    const cognitoFinalizer = new lambdaNode.NodejsFunction(
      this,
      "AccountDeletionCognitoFinalizerFunction",
      {
        entry: join(
          import.meta.dirname,
          "../src/account_deletion/cognito_finalizer_lambda.ts",
        ),
        handler: "handler",
        runtime: lambda.Runtime.NODEJS_22_X,
        architecture: lambda.Architecture.ARM_64,
        timeout: cdk.Duration.seconds(30),
        logGroup: accountDeletionLogGroup(
          "AccountDeletionCognitoFinalizerLogGroup",
        ),
        environment: {
          COGNITO_USER_POOL_ID: config.userPoolId,
          FOLOO_ACCOUNT_DELETION_FINALIZER_ENABLED:
            accountDeletionFinalizerEnabled ? "true" : "false",
        },
        bundling: { minify: true, sourceMap: true },
      },
    );
    const accountDeletionEmail = new lambdaNode.NodejsFunction(
      this,
      "AccountDeletionEmailFunction",
      {
        entry: join(
          import.meta.dirname,
          "../src/account_deletion/account_deletion_email_lambda.ts",
        ),
        handler: "handler",
        runtime: lambda.Runtime.NODEJS_22_X,
        architecture: lambda.Architecture.ARM_64,
        timeout: cdk.Duration.seconds(30),
        retryAttempts: 2,
        deadLetterQueue: accountDeletionEmailDlq,
        logGroup: accountDeletionLogGroup("AccountDeletionEmailLogGroup"),
        environment: {
          ACCOUNT_DELETION_TABLE_NAME: accountDeletion.table.tableName,
          ACCOUNT_DELETION_RECIPIENT_KEY_ARN:
            accountDeletion.recipientKey.keyArn,
          ACCOUNT_DELETION_FROM_ADDRESS: "hello@foloo.io",
          ACCOUNT_DELETION_SUPPORT_ADDRESS: "hello@foloo.io",
          ACCOUNT_DELETION_SES_IDENTITY_VERIFIED:
            accountDeletionSesNotificationsEnabled ? "true" : "false",
          FOLOO_ACCOUNT_DELETION_ENABLED: accountDeletionEnabled
            ? "true"
            : "false",
        },
        bundling: { minify: true, sourceMap: true },
      },
    );
    new cloudwatch.Alarm(this, "AccountDeletionEmailErrorsAlarm", {
      metric: accountDeletionEmail.metricErrors(),
      threshold: 1,
      evaluationPeriods: 1,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });
    const accountDeletionPreSignUp = new lambdaNode.NodejsFunction(
      this,
      "AccountDeletionPreSignUpFunction",
      {
        entry: join(
          import.meta.dirname,
          "../src/account_deletion/cognito_pre_signup_lambda.ts",
        ),
        handler: "handler",
        runtime: lambda.Runtime.NODEJS_22_X,
        architecture: lambda.Architecture.ARM_64,
        timeout: cdk.Duration.seconds(10),
        logGroup: accountDeletionLogGroup("AccountDeletionPreSignUpLogGroup"),
        environment: {
          ACCOUNT_DELETION_TABLE_NAME: accountDeletion.table.tableName,
          ACCOUNT_DELETION_HMAC_KEY_ARN: accountDeletion.hmacKey.keyArn,
          ACCOUNT_DELETION_HMAC_KEY_VERSION: "v1",
          ACCOUNT_DELETION_HMAC_READ_VERSIONS: "v1",
          FOLOO_ACCOUNT_DELETION_REGISTRATION_GUARD_ENABLED:
            accountDeletionRegistrationGuardEnabled ? "true" : "false",
          COGNITO_USER_POOL_ID: config.userPoolId,
          COGNITO_ALLOWED_APP_CLIENT_IDS: [
            config.appClientId,
            webClientId,
          ].join(","),
          COGNITO_ALLOWED_FEDERATED_PROVIDERS:
            cognitoAllowedFederatedProviders.join(","),
        },
        bundling: { minify: true, sourceMap: true },
      },
    );
    accountDeletion.grantGuardReadAccess(accountDeletionPreSignUp);
    accountDeletion.grantHmac(accountDeletionPreSignUp);
    const accountDeletionPostAuthentication = new lambdaNode.NodejsFunction(
      this,
      "AccountDeletionPostAuthenticationFunction",
      {
        entry: join(
          import.meta.dirname,
          "../src/account_deletion/cognito_post_authentication_lambda.ts",
        ),
        handler: "handler",
        runtime: lambda.Runtime.NODEJS_22_X,
        architecture: lambda.Architecture.ARM_64,
        timeout: cdk.Duration.seconds(10),
        logGroup: accountDeletionLogGroup(
          "AccountDeletionPostAuthenticationLogGroup",
        ),
        environment: {
          ACCOUNT_DELETION_TABLE_NAME: accountDeletion.table.tableName,
          ACCOUNT_DELETION_HMAC_KEY_ARN: accountDeletion.hmacKey.keyArn,
          ACCOUNT_DELETION_HMAC_KEY_VERSION: "v1",
          ACCOUNT_DELETION_HMAC_READ_VERSIONS: "v1",
          FOLOO_ACCOUNT_DELETION_REGISTRATION_GUARD_ENABLED:
            accountDeletionRegistrationGuardEnabled ? "true" : "false",
          COGNITO_USER_POOL_ID: config.userPoolId,
          COGNITO_ALLOWED_APP_CLIENT_IDS: [
            config.appClientId,
            webClientId,
          ].join(","),
          COGNITO_ALLOWED_FEDERATED_PROVIDERS:
            cognitoAllowedFederatedProviders.join(","),
          FOLOO_ENTITLEMENT_AUTOMATIC_ENQUEUE_ENABLED:
            props.automaticEntitlement?.enqueueEnabled === true
              ? "true"
              : "false",
          FOLOO_ENTITLEMENT_AUTOMATIC_QUEUE_URL:
            automaticEntitlementQueue?.queueUrl ?? "disabled",
        },
        bundling: { minify: true, sourceMap: true },
      },
    );
    accountDeletion.grantGuardReadAccess(accountDeletionPostAuthentication);
    accountDeletion.grantHmac(accountDeletionPostAuthentication);
    automaticEntitlementQueue?.grantSendMessages(
      accountDeletionPostAuthentication,
    );
    // The User Pool predates and is not owned by this stack. CDK therefore
    // prepares scoped invoke permissions and outputs, but deliberately does
    // not mutate its LambdaConfig. Trigger attachment remains an activation
    // operation after the pass-through deployment has been verified.
    const userPoolArn = this.formatArn({
      service: "cognito-idp",
      resource: "userpool",
      resourceName: config.userPoolId,
    });
    for (const [id, handler] of [
      ["CognitoInvokePreSignUp", accountDeletionPreSignUp],
      ["CognitoInvokePostAuthentication", accountDeletionPostAuthentication],
    ] as const) {
      handler.addPermission(id, {
        principal: new iam.ServicePrincipal("cognito-idp.amazonaws.com"),
        sourceArn: userPoolArn,
      });
    }
    accountDeletion.grantEmailAccess(accountDeletionEmail);
    accountDeletion.grantRecipientEncryption(accountDeletionEmail);
    accountDeletionEmail.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ["ses:SendEmail"],
        resources: [accountDeletionEmailIdentity.emailIdentityArn],
      }),
    );
    cognitoFinalizer.addToRolePolicy(
      new iam.PolicyStatement({
        actions: [
          "cognito-idp:ListUsers",
          "cognito-idp:AdminUserGlobalSignOut",
          "cognito-idp:AdminDeleteUser",
        ],
        resources: [
          this.formatArn({
            service: "cognito-idp",
            resource: "userpool",
            resourceName: config.userPoolId,
          }),
        ],
      }),
    );
    const deletionWorker = new lambdaNode.NodejsFunction(
      this,
      "AccountDeletionWorkerFunction",
      {
        entry: join(
          import.meta.dirname,
          "../src/account_deletion/account_deletion_worker_lambda.ts",
        ),
        handler: "handler",
        runtime: lambda.Runtime.NODEJS_22_X,
        architecture: lambda.Architecture.ARM_64,
        memorySize: 512,
        timeout: cdk.Duration.minutes(10),
        logGroup: accountDeletionLogGroup("AccountDeletionWorkerLogGroup"),
        vpc,
        vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
        securityGroups: [lambdaSg],
        environment: {
          ...commonEnvironment,
          MEDIA_BUCKET_NAME: mediaBucket.bucketName,
          EMAIL_PROVIDER_FUNCTION_NAME: providerFunction.functionName,
          PUBLIC_API_BASE_URL: "https://placeholder.invalid",
          COGNITO_FINALIZER_FUNCTION_NAME: cognitoFinalizer.functionName,
          ACCOUNT_DELETION_TABLE_NAME: accountDeletion.table.tableName,
          ACCOUNT_DELETION_HMAC_KEY_ARN: accountDeletion.hmacKey.keyArn,
          ACCOUNT_DELETION_HMAC_KEY_VERSION: "v1",
          ACCOUNT_DELETION_RECIPIENT_KEY_ARN:
            accountDeletion.recipientKey.keyArn,
          ACCOUNT_DELETION_QUEUE_URL: accountDeletion.queue.queueUrl,
          ACCOUNT_DELETION_NOTIFICATION_FUNCTION_NAME:
            accountDeletionEmail.functionName,
          ACCOUNT_DELETION_NOTIFICATION_MODE:
            accountDeletionSesNotificationsEnabled ? "ses" : "disabled",
          FOLOO_ENVIRONMENT: config.name,
          FOLOO_ACCOUNT_DELETION_NORMAL_ACCESS_ENABLED:
            accountDeletionNormalAccessEnabled ? "true" : "false",
          FOLOO_ACCOUNT_DELETION_QA_ENABLED: accountDeletionQaEnabled
            ? "true"
            : "false",
          ACCOUNT_DELETION_QA_SUBJECT_HASHES: (
            props.accountDeletionQa?.subjectHashes ?? []
          ).join(","),
          FOLOO_ACCOUNT_DELETION_WORKER_ENABLED: accountDeletionWorkerEnabled
            ? "true"
            : "false",
        },
        bundling: { minify: true, sourceMap: true },
      },
    );
    new cloudwatch.Alarm(this, "AccountDeletionWorkerErrorsAlarm", {
      metric: deletionWorker.metricErrors(),
      threshold: 1,
      evaluationPeriods: 1,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });
    new cloudwatch.Alarm(this, "AccountDeletionQueueAgeAlarm", {
      metric: accountDeletion.queue.metricApproximateAgeOfOldestMessage(),
      threshold: cdk.Duration.minutes(20).toSeconds(),
      evaluationPeriods: 1,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });
    const deletionOutboxRecovery = new lambdaNode.NodejsFunction(
      this,
      "AccountDeletionOutboxRecoveryFunction",
      {
        entry: join(
          import.meta.dirname,
          "../src/account_deletion/account_deletion_outbox_recovery_lambda.ts",
        ),
        handler: "handler",
        runtime: lambda.Runtime.NODEJS_22_X,
        architecture: lambda.Architecture.ARM_64,
        timeout: cdk.Duration.minutes(1),
        logGroup: accountDeletionLogGroup(
          "AccountDeletionOutboxRecoveryLogGroup",
        ),
        environment: {
          ACCOUNT_DELETION_TABLE_NAME: accountDeletion.table.tableName,
          ACCOUNT_DELETION_RECIPIENT_KEY_ARN:
            accountDeletion.recipientKey.keyArn,
          ACCOUNT_DELETION_QUEUE_URL: accountDeletion.queue.queueUrl,
          FOLOO_ACCOUNT_DELETION_OUTBOX_ENABLED:
            accountDeletionOutboxRecoveryEnabled ? "true" : "false",
        },
        bundling: { minify: true, sourceMap: true },
      },
    );
    const deletionOutboxSchedule = new events.Rule(
      this,
      "AccountDeletionOutboxRecoverySchedule",
      {
        schedule: events.Schedule.rate(cdk.Duration.minutes(1)),
        enabled: accountDeletionRecoverySchedulerEnabled,
      },
    );
    deletionOutboxSchedule.addTarget(
      new eventTargets.LambdaFunction(deletionOutboxRecovery),
    );
    new cloudwatch.Alarm(this, "AccountDeletionOutboxRecoveryErrorsAlarm", {
      metric: deletionOutboxRecovery.metricErrors(),
      threshold: 1,
      evaluationPeriods: 1,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });
    const operationalAlarm = (name: string, metricName: string) => {
      const alarm = new cloudwatch.Alarm(this, name, {
        metric: new cloudwatch.Metric({
          namespace: "Foloo/AccountDeletion",
          metricName,
          statistic: "Maximum",
          period: cdk.Duration.minutes(1),
        }),
        threshold: 1,
        evaluationPeriods: 1,
        treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
      });
      alarm.addAlarmAction(
        new cloudwatchActions.SnsAction(accountDeletionOperationsTopic),
      );
    };
    operationalAlarm("AccountDeletionPendingRequestsAlarm", "PendingRequests");
    operationalAlarm("AccountDeletionBlockedRequestsAlarm", "BlockedRequests");
    operationalAlarm("AccountDeletionFailedRequestsAlarm", "FailedRequests");
    operationalAlarm("AccountDeletionOverdueRequestsAlarm", "OverdueRequests");
    operationalAlarm("AccountDeletionDay10Alarm", "Day10Alerts");
    operationalAlarm("AccountDeletionDay13Alarm", "Day13Alerts");
    operationalAlarm(
      "AccountDeletionCriticalDay15Alarm",
      "CriticalDay15Alerts",
    );
    accountDeletion.grantOutboxRecoveryAccess(deletionOutboxRecovery);
    accountDeletion.grantRecipientEncryption(deletionOutboxRecovery);
    accountDeletion.queue.grantSendMessages(deletionOutboxRecovery);
    const restoreReconciler = new lambdaNode.NodejsFunction(
      this,
      "AccountDeletionRestoreReconcilerFunction",
      {
        entry: join(
          import.meta.dirname,
          "../src/account_deletion/account_deletion_restore_reconciler_lambda.ts",
        ),
        handler: "handler",
        runtime: lambda.Runtime.NODEJS_22_X,
        architecture: lambda.Architecture.ARM_64,
        memorySize: 512,
        timeout: cdk.Duration.minutes(5),
        logGroup: accountDeletionLogGroup(
          "AccountDeletionRestoreReconcilerLogGroup",
        ),
        vpc,
        vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
        securityGroups: [lambdaSg],
        environment: {
          ...commonEnvironment,
          MEDIA_BUCKET_NAME: mediaBucket.bucketName,
          EMAIL_PROVIDER_FUNCTION_NAME: providerFunction.functionName,
          PUBLIC_API_BASE_URL: "https://placeholder.invalid",
          ACCOUNT_DELETION_TABLE_NAME: accountDeletion.table.tableName,
          ACCOUNT_DELETION_HMAC_KEY_ARN: accountDeletion.hmacKey.keyArn,
          ACCOUNT_DELETION_HMAC_KEY_VERSION: "v1",
          ACCOUNT_DELETION_QUEUE_URL: accountDeletion.queue.queueUrl,
          FOLOO_ACCOUNT_DELETION_RECONCILER_ENABLED:
            accountDeletionRestoreReconcilerEnabled ? "true" : "false",
        },
        bundling: { minify: true, sourceMap: true },
      },
    );
    new cloudwatch.Alarm(this, "AccountDeletionReconcilerErrorsAlarm", {
      metric: restoreReconciler.metricErrors(),
      threshold: 1,
      evaluationPeriods: 1,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });
    accountDeletion.grantGuardReadAccess(restoreReconciler);
    accountDeletion.grantHmac(restoreReconciler);
    accountDeletion.queue.grantSendMessages(restoreReconciler);
    appSecret.grantRead(restoreReconciler);
    deletionWorker.addEventSource(
      new lambdaEventSources.SqsEventSource(accountDeletion.queue, {
        batchSize: 1,
        enabled: accountDeletionWorkerEventSourceEnabled,
        reportBatchItemFailures: true,
      }),
    );
    accountDeletion.grantApiAccess(apiFunction);
    accountDeletion.grantWorkerAccess(deletionWorker);
    accountDeletion.grantHmac(apiFunction);
    accountDeletion.grantHmac(deletionWorker);
    accountDeletion.grantRecipientEncryption(apiFunction);
    accountDeletion.grantRecipientEncryption(deletionWorker);
    accountDeletion.queue.grantSendMessages(apiFunction);
    accountDeletion.queue.grantConsumeMessages(deletionWorker);
    appSecret.grantRead(deletionWorker);
    deletionWorker.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ["s3:GetObject", "s3:DeleteObject"],
        resources: [`${mediaBucket.bucketArn}/*`],
      }),
    );
    deletionWorker.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ["s3:ListBucket"],
        resources: [mediaBucket.bucketArn],
        conditions: {
          StringLike: {
            "s3:prefix": ["media/workspaces/*", "content/workspaces/*"],
          },
        },
      }),
    );
    providerFunction.grantInvoke(deletionWorker);
    cognitoFinalizer.grantInvoke(deletionWorker);
    accountDeletionEmail.grantInvoke(apiFunction);
    accountDeletionEmail.grantInvoke(deletionWorker);
    apiFunction.addEnvironment(
      "ACCOUNT_DELETION_TABLE_NAME",
      accountDeletion.table.tableName,
    );
    apiFunction.addEnvironment(
      "ACCOUNT_DELETION_HMAC_KEY_ARN",
      accountDeletion.hmacKey.keyArn,
    );
    apiFunction.addEnvironment("ACCOUNT_DELETION_HMAC_KEY_VERSION", "v1");
    apiFunction.addEnvironment(
      "ACCOUNT_DELETION_RECIPIENT_KEY_ARN",
      accountDeletion.recipientKey.keyArn,
    );
    apiFunction.addEnvironment(
      "ACCOUNT_DELETION_NOTIFICATION_FUNCTION_NAME",
      accountDeletionEmail.functionName,
    );
    apiFunction.addEnvironment(
      "ACCOUNT_DELETION_COGNITO_FINALIZER_FUNCTION_NAME",
      cognitoFinalizer.functionName,
    );
    apiFunction.addEnvironment(
      "ACCOUNT_DELETION_REAUTH_MAX_AGE_SECONDS",
      "300",
    );
    apiFunction.addEnvironment(
      "ACCOUNT_DELETION_QUEUE_URL",
      accountDeletion.queue.queueUrl,
    );
    providerFunction.grantInvoke(apiFunction);
    // MON-15–MON-18: Stripe has public egress; API retains its isolated VPC.
    const stripeSecret = config.stripeSecretName
      ? secretsmanager.Secret.fromSecretNameV2(
          this,
          "StripeSecret",
          config.stripeSecretName,
        )
      : undefined;
    const webhookSecret = config.stripeWebhookSecretName
      ? secretsmanager.Secret.fromSecretNameV2(
          this,
          "StripeWebhookSecret",
          config.stripeWebhookSecretName,
        )
      : undefined;
    const billingLogGroup = new logs.LogGroup(this, "BillingProviderLogGroup", {
      retention: logs.RetentionDays.ONE_WEEK,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });
    const billingFunction = new lambdaNode.NodejsFunction(
      this,
      "BillingProviderFunction",
      {
        entry: join(
          import.meta.dirname,
          "../src/billing/billing_provider_lambda.ts",
        ),
        handler: "handler",
        runtime: lambda.Runtime.NODEJS_22_X,
        architecture: lambda.Architecture.ARM_64,
        memorySize: 512,
        timeout: cdk.Duration.seconds(12),
        logGroup: billingLogGroup,
        environment:
          config.billingEnabled && stripeSecret
            ? { STRIPE_SECRET_ARN: stripeSecret.secretName }
            : {},
        bundling: { minify: true, sourceMap: true },
      },
    );
    stripeSecret?.grantRead(billingFunction);
    webhookSecret?.grantRead(apiFunction);
    billingFunction.grantInvoke(apiFunction);
    billingFunction.grantInvoke(deletionWorker);
    deletionWorker.addEnvironment(
      "BILLING_PROVIDER_FUNCTION_NAME",
      billingFunction.functionName,
    );
    const billingEnvironment = {
      BILLING_PROVIDER_FUNCTION_NAME: billingFunction.functionName,
      STRIPE_SECRET_ARN: stripeSecret?.secretName,
      STRIPE_WEBHOOK_SECRET_ARN: webhookSecret?.secretName,
      STRIPE_PRICE_ID: config.stripePriceId,
      BILLING_SUCCESS_URL: config.billingSuccessUrl,
      BILLING_CANCEL_URL: config.billingCancelUrl,
      BILLING_PORTAL_RETURN_URL: config.billingPortalReturnUrl,
    };
    for (const [key, value] of Object.entries(billingEnvironment)) {
      if (config.billingEnabled && value)
        apiFunction.addEnvironment(key, value);
    }
    const lambdaEndpointSg = new ec2.SecurityGroup(
      this,
      "LambdaEndpointSecurityGroup",
      {
        vpc,
        allowAllOutbound: false,
      },
    );
    lambdaEndpointSg.addIngressRule(
      lambdaSg,
      ec2.Port.tcp(443),
      "API invokes email provider boundary",
    );
    vpc.addInterfaceEndpoint("LambdaEndpoint", {
      service: ec2.InterfaceVpcEndpointAwsService.LAMBDA,
      subnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaEndpointSg],
      privateDnsEnabled: true,
      open: false,
    });
    appSecret.grantRead(apiFunction);
    apiFunction.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ["s3:GetObject", "s3:PutObject"],
        resources: [`${mediaBucket.bucketArn}/*`],
      }),
    );

    let identityResolver: lambdaNode.NodejsFunction | undefined;
    if (entitlementInfrastructureEnabled) {
      const identityLogGroup = new logs.LogGroup(
        this,
        "AdministrativeEntitlementIdentityLogGroup",
        {
          retention: logs.RetentionDays.ONE_WEEK,
          removalPolicy: cdk.RemovalPolicy.DESTROY,
        },
      );
      identityResolver = new lambdaNode.NodejsFunction(
        this,
        "AdministrativeEntitlementIdentityFunction",
        {
          entry: join(
            import.meta.dirname,
            "../src/entitlements/administrative_entitlement_identity_lambda.ts",
          ),
          handler: "handler",
          runtime: lambda.Runtime.NODEJS_22_X,
          architecture: lambda.Architecture.ARM_64,
          memorySize: 256,
          timeout: cdk.Duration.seconds(10),
          logGroup: identityLogGroup,
          environment: { COGNITO_USER_POOL_ID: config.userPoolId },
          bundling: { minify: true, sourceMap: true },
        },
      );
      identityResolver.addToRolePolicy(
        new iam.PolicyStatement({
          actions: ["cognito-idp:ListUsers"],
          resources: [
            cdk.Stack.of(this).formatArn({
              service: "cognito-idp",
              resource: "userpool",
              resourceName: config.userPoolId,
            }),
          ],
        }),
      );
      deletionWorker.addEnvironment(
        "ENTITLEMENT_IDENTITY_RESOLVER_FUNCTION_NAME",
        identityResolver.functionName,
      );
      deletionWorker.addEnvironment(
        "ENTITLEMENT_PREAUTHORIZATION_HMAC_KEY_ARN",
        entitlementPreauthorizationKey!.keyArn,
      );
      deletionWorker.addEnvironment(
        "ENTITLEMENT_PREAUTHORIZATION_HMAC_KEY_VERSION",
        "v1",
      );
      deletionWorker.addEnvironment(
        "ENTITLEMENT_PREAUTHORIZATION_PREVIOUS_KEYS_JSON",
        JSON.stringify(previousEntitlementKeys),
      );
      entitlementPreauthorizationKey!.grant(deletionWorker, "kms:GenerateMac");
      if (previousEntitlementKeys.length > 0) {
        deletionWorker.addToRolePolicy(
          new iam.PolicyStatement({
            actions: ["kms:GenerateMac"],
            resources: previousEntitlementKeys.map((key) => key.keyArn),
          }),
        );
      }
      deletionWorker.addToRolePolicy(
        new iam.PolicyStatement({
          actions: ["lambda:InvokeFunction"],
          resources: [identityResolver.functionArn],
        }),
      );
    }

    if (props.administrativeEntitlementEnabled === true) {
      if (!identityResolver || !entitlementPreauthorizationKey) {
        throw new Error(
          "Administrative entitlement infrastructure is incomplete.",
        );
      }
      const operatorUserName =
        config.name === "dev"
          ? "foloo-entitlement-operator"
          : `foloo-${config.name}-entitlement-operator`;
      const operatorUser = new iam.User(
        this,
        "AdministrativeEntitlementOperatorUser",
        {
          userName: operatorUserName,
        },
      );
      const operatorSessionConditions = {
        Bool: { "aws:MultiFactorAuthPresent": "true" },
        StringEquals: { "sts:SourceIdentity": operatorUserName },
        StringLike: { "sts:RoleSessionName": "fl021-*" },
      };
      const operatorPrincipal = new iam.ArnPrincipal(
        operatorUser.userArn,
      ).withConditions(operatorSessionConditions);
      const operatorSourceIdentityPrincipal = new iam.ArnPrincipal(
        operatorUser.userArn,
      ).withConditions({
        StringEquals: { "sts:SourceIdentity": operatorUserName },
      });
      const operatorRole = new iam.Role(
        this,
        "AdministrativeEntitlementOperatorRole",
        {
          roleName: `foloo-${config.name}-fl021-entitlement-operator`,
          assumedBy: operatorPrincipal,
          maxSessionDuration: cdk.Duration.hours(1),
          description:
            "MFA-protected IAM-only operator for FL-021 entitlement administration",
        },
      );
      operatorRole.assumeRolePolicy?.addStatements(
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          principals: [operatorSourceIdentityPrincipal],
          actions: ["sts:SetSourceIdentity"],
        }),
      );
      operatorUser.addToPolicy(
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: ["sts:AssumeRole", "sts:SetSourceIdentity"],
          resources: [operatorRole.roleArn],
        }),
      );
      const functionLogGroup = new logs.LogGroup(
        this,
        "AdministrativeEntitlementFunctionLogGroup",
        {
          retention: logs.RetentionDays.ONE_WEEK,
          removalPolicy: cdk.RemovalPolicy.DESTROY,
        },
      );
      const entitlementFunction = new lambdaNode.NodejsFunction(
        this,
        "AdministrativeEntitlementFunction",
        {
          entry: join(
            import.meta.dirname,
            "../src/entitlements/administrative_entitlement_lambda.ts",
          ),
          handler: "handler",
          runtime: lambda.Runtime.NODEJS_22_X,
          architecture: lambda.Architecture.ARM_64,
          memorySize: 256,
          timeout: cdk.Duration.seconds(30),
          logGroup: functionLogGroup,
          vpc,
          vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
          securityGroups: [lambdaSg],
          environment: {
            DB_HOST: database.dbInstanceEndpointAddress,
            DB_PORT: database.dbInstanceEndpointPort,
            DB_NAME: config.databaseName,
            DB_ENTITLEMENT_OPERATOR_SECRET_ARN:
              entitlementOperatorSecret.secretArn,
            COGNITO_IDENTITY_RESOLVER_FUNCTION_NAME:
              identityResolver.functionName,
            ENTITLEMENT_OPERATOR_ACTOR_ARN: operatorRole.roleArn,
            ENTITLEMENT_PREAUTHORIZATION_HMAC_KEY_ARN:
              entitlementPreauthorizationKey.keyArn,
            ENTITLEMENT_PREAUTHORIZATION_HMAC_KEY_VERSION: "v1",
            NODE_EXTRA_CA_CERTS: "/var/runtime/ca-cert.pem",
          },
          bundling: { minify: true, sourceMap: true },
        },
      );
      entitlementOperatorSecret.grantRead(entitlementFunction);
      entitlementPreauthorizationKey.grant(
        entitlementFunction,
        "kms:GenerateMac",
      );
      entitlementFunction.addToRolePolicy(
        new iam.PolicyStatement({
          actions: ["lambda:InvokeFunction"],
          resources: [identityResolver.functionArn],
        }),
      );
      entitlementFunction.grantInvoke(operatorRole);
      const entitlementAuditTrail = new cloudtrail.Trail(
        this,
        "AdministrativeEntitlementAuditTrail",
        {
          trailName: `foloo-${config.name}-fl021-entitlement-audit`,
          includeGlobalServiceEvents: true,
          isMultiRegionTrail: false,
          sendToCloudWatchLogs: true,
        },
      );
      entitlementAuditTrail.applyRemovalPolicy(cdk.RemovalPolicy.RETAIN);
      entitlementAuditTrail.addLambdaEventSelector([entitlementFunction], {
        readWriteType: cloudtrail.ReadWriteType.WRITE_ONLY,
      });
      new cdk.CfnOutput(this, "AdministrativeEntitlementFunctionName", {
        value: entitlementFunction.functionName,
        description:
          "Private IAM-only FL-021 administrative entitlement function",
      });
    }

    if (automaticEntitlementEnabled) {
      if (
        !identityResolver ||
        !entitlementPreauthorizationKey ||
        !automaticEntitlementQueue
      ) {
        throw new Error("Automatic entitlement infrastructure is incomplete.");
      }
      const automaticWorkerLogGroup = new logs.LogGroup(
        this,
        "AutomaticEntitlementWorkerLogGroup",
        {
          retention: logs.RetentionDays.ONE_WEEK,
          removalPolicy: cdk.RemovalPolicy.DESTROY,
        },
      );
      const automaticWorker = new lambdaNode.NodejsFunction(
        this,
        "AutomaticEntitlementWorkerFunction",
        {
          entry: join(
            import.meta.dirname,
            "../src/entitlements/automatic_entitlement_worker_lambda.ts",
          ),
          handler: "handler",
          runtime: lambda.Runtime.NODEJS_22_X,
          architecture: lambda.Architecture.ARM_64,
          memorySize: 256,
          timeout: cdk.Duration.seconds(60),
          logGroup: automaticWorkerLogGroup,
          vpc,
          vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
          securityGroups: [lambdaSg],
          environment: {
            DB_HOST: database.dbInstanceEndpointAddress,
            DB_PORT: database.dbInstanceEndpointPort,
            DB_NAME: config.databaseName,
            DB_ENTITLEMENT_OPERATOR_SECRET_ARN:
              entitlementOperatorSecret.secretArn,
            COGNITO_IDENTITY_RESOLVER_FUNCTION_NAME:
              identityResolver.functionName,
            ENTITLEMENT_PREAUTHORIZATION_HMAC_KEY_ARN:
              entitlementPreauthorizationKey.keyArn,
            ENTITLEMENT_PREAUTHORIZATION_HMAC_KEY_VERSION: "v1",
            NODE_EXTRA_CA_CERTS: "/var/runtime/ca-cert.pem",
          },
          bundling: { minify: true, sourceMap: true },
        },
      );
      entitlementOperatorSecret.grantRead(automaticWorker);
      entitlementPreauthorizationKey.grant(automaticWorker, "kms:GenerateMac");
      automaticWorker.addToRolePolicy(
        new iam.PolicyStatement({
          actions: ["lambda:InvokeFunction"],
          resources: [identityResolver.functionArn],
        }),
      );
      automaticWorker.addEventSource(
        new lambdaEventSources.SqsEventSource(automaticEntitlementQueue, {
          batchSize: 1,
          reportBatchItemFailures: true,
          enabled: props.automaticEntitlement?.workerEnabled === true,
          maxConcurrency: 2,
        }),
      );
    }

    const migrationLogGroup = new logs.LogGroup(this, "MigrationLogGroup", {
      retention: logs.RetentionDays.ONE_WEEK,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });
    const migrationFunction = new lambdaNode.NodejsFunction(
      this,
      "MigrationFunction",
      {
        entry: join(
          import.meta.dirname,
          "../src/persistence/migration_lambda.ts",
        ),
        handler: "handler",
        runtime: lambda.Runtime.NODEJS_22_X,
        architecture: lambda.Architecture.ARM_64,
        memorySize: 512,
        timeout: cdk.Duration.minutes(2),
        logGroup: migrationLogGroup,
        vpc,
        vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
        securityGroups: [lambdaSg],
        environment: {
          ...commonEnvironment,
          DB_ADMIN_SECRET_ARN: database.secret!.secretArn,
          DB_ENTITLEMENT_OPERATOR_SECRET_ARN:
            entitlementOperatorSecret.secretArn,
          MIGRATIONS_DIR: "/var/task/migrations",
          ...qaInventoryEnvironment(
            config.name,
            this.node.tryGetContext("qaInventorySubject"),
          ),
        },
        bundling: {
          minify: true,
          sourceMap: true,
          commandHooks: {
            beforeBundling: () => [],
            beforeInstall: () => [],
            afterBundling: (_inputDir, outputDir) => [
              `cp -R migrations ${outputDir}/migrations`,
            ],
          },
        },
      },
    );
    appSecret.grantRead(migrationFunction);
    database.secret!.grantRead(migrationFunction);
    entitlementOperatorSecret.grantRead(migrationFunction);

    const authorizer = new authorizers.HttpJwtAuthorizer(
      "CognitoJwt",
      `https://cognito-idp.${config.region}.amazonaws.com/${config.userPoolId}`,
      { jwtAudience: [config.appClientId, webClientId] },
    );
    const api = new apigateway.HttpApi(this, "HttpApi", {
      apiName: `foloo-${config.name}`,
      createDefaultStage: true,
      corsPreflight: {
        allowOrigins: [...config.webAuth.allowedOrigins],
        allowMethods: [
          apigateway.CorsHttpMethod.GET,
          apigateway.CorsHttpMethod.POST,
          apigateway.CorsHttpMethod.OPTIONS,
        ],
        allowHeaders: ["authorization", "content-type", "idempotency-key"],
        exposeHeaders: ["retry-after", "idempotency-replayed"],
        maxAge: cdk.Duration.hours(1),
      },
    });
    const webSessions = new WebSessionInfrastructure(this, "WebSessions", {
      environmentName: config.name,
      userPoolId: config.userPoolId,
      webClientId: webClientId,
      cognitoDomain: config.webAuth.cognitoDomain,
      callbackUrl: config.webAuth.bffCallbackUrl,
      allowedOrigin: config.webAuth.allowedOrigins[0]!,
      publicApiBaseUrl: api.apiEndpoint,
      successRedirectPath: config.webAuth.successRedirectPath,
      absoluteDurationSeconds:
        config.webAuth.sessionPolicy.absoluteDurationSeconds,
      idleDurationSeconds: config.webAuth.sessionPolicy.idleDurationSeconds,
      enabled: props.webSessionQa?.enabled ?? false,
      normalAccessEnabled: props.webSessionQa?.normalAccessEnabled ?? false,
      qaSubjectHashes: props.webSessionQa?.subjectHashes ?? [],
    });
    apiFunction.addEnvironment("PUBLIC_API_BASE_URL", api.apiEndpoint);
    const integration = new integrations.HttpLambdaIntegration(
      "ApiIntegration",
      apiFunction,
    );
    for (const path of ["/v1", "/v1/{proxy+}"]) {
      api.addRoutes({
        path,
        methods: [apigateway.HttpMethod.ANY],
        integration,
        authorizer,
      });
    }
    const accountDeletionRoutes: apigateway.HttpRoute[] = [];
    for (const [path, method] of [
      ["/v1/account-deletion-requests/current", apigateway.HttpMethod.GET],
      [
        "/v1/account-deletion-reauthentication/verify",
        apigateway.HttpMethod.POST,
      ],
      ["/v1/account-deletion-requests", apigateway.HttpMethod.POST],
      [
        "/v1/account-deletion-requests/{requestId}/confirm",
        apigateway.HttpMethod.POST,
      ],
    ] as const) {
      accountDeletionRoutes.push(
        ...api.addRoutes({ path, methods: [method], integration, authorizer }),
      );
    }
    // Receipt-only status route is public by contract but remains fail-closed
    // while Account Deletion is disabled. Rate limiting is an activation gate.
    accountDeletionRoutes.push(
      ...api.addRoutes({
        path: "/v1/account-deletion-status",
        methods: [apigateway.HttpMethod.POST],
        integration,
      }),
    );
    const webSessionIntegration = new integrations.HttpLambdaIntegration(
      "WebSessionIntegration",
      webSessions.function,
    );
    const webSessionRoutes: apigateway.HttpRoute[] = [];
    for (const [path, method] of [
      ["/api/auth/session/srp", apigateway.HttpMethod.POST],
      ["/api/auth/reauthentication/start", apigateway.HttpMethod.POST],
      ["/api/auth/reauthentication/srp", apigateway.HttpMethod.POST],
      ["/api/auth/google/start", apigateway.HttpMethod.GET],
      ["/api/auth/google/callback", apigateway.HttpMethod.GET],
      ["/api/auth/session", apigateway.HttpMethod.GET],
      ["/api/auth/session/refresh", apigateway.HttpMethod.POST],
      ["/api/auth/logout", apigateway.HttpMethod.POST],
      [
        "/api/foloo/v1/account-deletion-requests/current",
        apigateway.HttpMethod.GET,
      ],
      [
        "/api/foloo/v1/account-deletion-reauthentication/verify",
        apigateway.HttpMethod.POST,
      ],
      ["/api/foloo/v1/account-deletion-requests", apigateway.HttpMethod.POST],
      [
        "/api/foloo/v1/account-deletion-requests/{requestId}/confirm",
        apigateway.HttpMethod.POST,
      ],
    ] as const) {
      webSessionRoutes.push(
        ...api.addRoutes({
          path,
          methods: [method],
          integration: webSessionIntegration,
        }),
      );
    }
    const defaultStage = api.defaultStage?.node
      .defaultChild as apigateway.CfnStage;
    for (const route of [...accountDeletionRoutes, ...webSessionRoutes]) {
      defaultStage.addResourceDependency(
        route.node.defaultChild as apigateway.CfnRoute,
      );
    }
    // This is a raw L1 override: RouteSettings values must use the exact
    // CloudFormation property names rather than the camelCase CDK interface.
    defaultStage.addPropertyOverride("RouteSettings", {
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
      "POST /api/auth/session/srp": {
        ThrottlingBurstLimit: 5,
        ThrottlingRateLimit: 1,
      },
      "GET /api/auth/google/start": {
        ThrottlingBurstLimit: 5,
        ThrottlingRateLimit: 1,
      },
      "GET /api/auth/google/callback": {
        ThrottlingBurstLimit: 5,
        ThrottlingRateLimit: 1,
      },
      "GET /api/auth/session": {
        ThrottlingBurstLimit: 10,
        ThrottlingRateLimit: 5,
      },
      "POST /api/auth/session/refresh": {
        ThrottlingBurstLimit: 5,
        ThrottlingRateLimit: 2,
      },
      "POST /api/auth/logout": {
        ThrottlingBurstLimit: 5,
        ThrottlingRateLimit: 1,
      },
      "GET /api/foloo/v1/account-deletion-requests/current": {
        ThrottlingBurstLimit: 5,
        ThrottlingRateLimit: 2,
      },
      "POST /api/foloo/v1/account-deletion-reauthentication/verify": {
        ThrottlingBurstLimit: 3,
        ThrottlingRateLimit: 1,
      },
      "POST /api/foloo/v1/account-deletion-requests": {
        ThrottlingBurstLimit: 2,
        ThrottlingRateLimit: 0.2,
      },
      "POST /api/foloo/v1/account-deletion-requests/{requestId}/confirm": {
        ThrottlingBurstLimit: 2,
        ThrottlingRateLimit: 0.2,
      },
    });
    for (const path of ["/v1/email/oauth/callback/{provider}"]) {
      api.addRoutes({
        path,
        methods: [apigateway.HttpMethod.GET],
        integration,
      });
    }
    const [billingWebhookRoute] = api.addRoutes({
      path: "/v1/billing/webhook",
      methods: [apigateway.HttpMethod.POST],
      integration,
    });
    for (const path of [
      "/v1/billing/checkout-session",
      "/v1/billing/portal-session",
    ]) {
      api.addRoutes({
        path,
        methods: [apigateway.HttpMethod.POST],
        integration,
        authorizer,
      });
    }
    // The stage must wait for the route, or API Gateway rejects its settings.
    defaultStage.addResourceDependency(
      billingWebhookRoute!.node.defaultChild as apigateway.CfnRoute,
    );
    defaultStage.addPropertyOverride("RouteSettings.POST /v1/billing/webhook", {
      ThrottlingBurstLimit: 20,
      ThrottlingRateLimit: 10,
    });
    new cdk.CfnOutput(this, "BillingWebhookUrl", {
      value: `${api.apiEndpoint}/v1/billing/webhook`,
    });
    new cdk.CfnOutput(this, "ApiUrl", { value: api.apiEndpoint });
    new cdk.CfnOutput(this, "WebUserPoolClientId", {
      value: webClientId,
    });
    new cdk.CfnOutput(this, "WebSessionFunctionName", {
      value: webSessions.function.functionName,
    });
    new cdk.CfnOutput(this, "WebSessionTableName", {
      value: webSessions.table.tableName,
    });
    new cdk.CfnOutput(this, "MigrationFunctionName", {
      value: migrationFunction.functionName,
    });
    new cdk.CfnOutput(this, "AccountDeletionLedgerTableName", {
      value: accountDeletion.table.tableName,
    });
    new cdk.CfnOutput(this, "AccountDeletionOperationsTopicArn", {
      value: accountDeletionOperationsTopic.topicArn,
    });
    new cdk.CfnOutput(this, "AccountDeletionQueueUrl", {
      value: accountDeletion.queue.queueUrl,
    });
    new cdk.CfnOutput(this, "AccountDeletionDeadLetterQueueUrl", {
      value: accountDeletion.deadLetterQueue.queueUrl,
    });
    new cdk.CfnOutput(this, "AccountDeletionWorkerFunctionName", {
      value: deletionWorker.functionName,
    });
    new cdk.CfnOutput(this, "AccountDeletionEmailFunctionName", {
      value: accountDeletionEmail.functionName,
    });
    if (managedAccountDeletionEmailIdentity) {
      for (const [index, name, value] of [
        [
          1,
          managedAccountDeletionEmailIdentity.dkimDnsTokenName1,
          managedAccountDeletionEmailIdentity.dkimDnsTokenValue1,
        ],
        [
          2,
          managedAccountDeletionEmailIdentity.dkimDnsTokenName2,
          managedAccountDeletionEmailIdentity.dkimDnsTokenValue2,
        ],
        [
          3,
          managedAccountDeletionEmailIdentity.dkimDnsTokenName3,
          managedAccountDeletionEmailIdentity.dkimDnsTokenValue3,
        ],
      ] as const) {
        new cdk.CfnOutput(this, `AccountDeletionSesDkimName${index}`, {
          value: name,
        });
        new cdk.CfnOutput(this, `AccountDeletionSesDkimValue${index}`, {
          value,
        });
      }
    }
    new cdk.CfnOutput(this, "AccountDeletionRestoreReconcilerFunctionName", {
      value: restoreReconciler.functionName,
    });
    new cdk.CfnOutput(this, "AccountDeletionPreSignUpFunctionName", {
      value: accountDeletionPreSignUp.functionName,
    });
    new cdk.CfnOutput(this, "AccountDeletionPreSignUpFunctionArn", {
      value: accountDeletionPreSignUp.functionArn,
    });
    new cdk.CfnOutput(this, "AccountDeletionPostAuthenticationFunctionName", {
      value: accountDeletionPostAuthentication.functionName,
    });
    new cdk.CfnOutput(this, "AccountDeletionPostAuthenticationFunctionArn", {
      value: accountDeletionPostAuthentication.functionArn,
    });
    new cdk.CfnOutput(this, "MediaBucketName", {
      value: mediaBucket.bucketName,
    });
    new cdk.CfnOutput(this, "EmailOAuthRedirectGoogle", {
      value: `${api.apiEndpoint}/v1/email/oauth/callback/google`,
    });
    new cdk.CfnOutput(this, "EmailOAuthRedirectMicrosoft", {
      value: `${api.apiEndpoint}/v1/email/oauth/callback/microsoft`,
    });
  }
}
