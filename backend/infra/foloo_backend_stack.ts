/** Defines low-cost DEV API/Lambda/private-RDS infrastructure without Cognito mutation. */

import { join } from "node:path";

import * as cdk from "aws-cdk-lib";
import * as apigateway from "aws-cdk-lib/aws-apigatewayv2";
import * as authorizers from "aws-cdk-lib/aws-apigatewayv2-authorizers";
import * as integrations from "aws-cdk-lib/aws-apigatewayv2-integrations";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as lambdaNode from "aws-cdk-lib/aws-lambda-nodejs";
import * as logs from "aws-cdk-lib/aws-logs";
import * as rds from "aws-cdk-lib/aws-rds";
import * as secretsmanager from "aws-cdk-lib/aws-secretsmanager";
import type { Construct } from "constructs";

import type { EnvironmentConfig } from "./config.js";

type FolooBackendStackProps = cdk.StackProps & { config: EnvironmentConfig };

export class FolooBackendStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props: FolooBackendStackProps) {
    super(scope, id, props);
    const { config } = props;

    const vpc = new ec2.Vpc(this, "Vpc", {
      ipAddresses: ec2.IpAddresses.cidr("10.42.0.0/16"),
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
      deletionProtection: false,
      backupRetention: cdk.Duration.days(1),
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
      reservedConcurrentExecutions: 10,
      logGroup: apiLogGroup,
      vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
      securityGroups: [lambdaSg],
      environment: { ...commonEnvironment, DB_POOL_MAX: "2" },
      bundling: { minify: true, sourceMap: true },
    });
    appSecret.grantRead(apiFunction);

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
        reservedConcurrentExecutions: 1,
        logGroup: migrationLogGroup,
        vpc,
        vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_ISOLATED },
        securityGroups: [lambdaSg],
        environment: {
          ...commonEnvironment,
          DB_ADMIN_SECRET_ARN: database.secret!.secretArn,
          MIGRATIONS_DIR: "/var/task/migrations",
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

    const authorizer = new authorizers.HttpJwtAuthorizer(
      "CognitoJwt",
      `https://cognito-idp.${config.region}.amazonaws.com/${config.userPoolId}`,
      { jwtAudience: [config.appClientId] },
    );
    const api = new apigateway.HttpApi(this, "HttpApi", {
      apiName: `foloo-${config.name}`,
      createDefaultStage: true,
    });
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

    new cdk.CfnOutput(this, "ApiUrl", { value: api.apiEndpoint });
    new cdk.CfnOutput(this, "MigrationFunctionName", {
      value: migrationFunction.functionName,
    });
  }
}
