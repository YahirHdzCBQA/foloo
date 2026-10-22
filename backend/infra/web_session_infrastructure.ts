/**
 * Declares the disabled-by-default server-side web-session boundary.
 * Sessions are opaque to browsers; Cognito tokens remain encrypted at rest
 * with a dedicated KMS key and expire logically as well as through DynamoDB TTL.
 */

import { join } from "node:path";

import * as cdk from "aws-cdk-lib";
import * as cloudwatch from "aws-cdk-lib/aws-cloudwatch";
import * as dynamodb from "aws-cdk-lib/aws-dynamodb";
import * as iam from "aws-cdk-lib/aws-iam";
import * as kms from "aws-cdk-lib/aws-kms";
import * as lambda from "aws-cdk-lib/aws-lambda";
import * as lambdaNode from "aws-cdk-lib/aws-lambda-nodejs";
import * as logs from "aws-cdk-lib/aws-logs";
import { Construct } from "constructs";

export type WebSessionInfrastructureProps = Readonly<{
  environmentName: string;
  userPoolId: string;
  webClientId: string;
  cognitoDomain: string;
  callbackUrl: string;
  allowedOrigin: string;
  publicApiBaseUrl: string;
  successRedirectPath: string;
  absoluteDurationSeconds: number;
  idleDurationSeconds: number;
  enabled?: boolean;
  qaSubjectHashes?: readonly string[];
}>;

/** Provisions isolated storage, encryption, execution and observability. */
export class WebSessionInfrastructure extends Construct {
  readonly table: dynamodb.Table;
  readonly encryptionKey: kms.Key;
  readonly function: lambdaNode.NodejsFunction;

  constructor(
    scope: Construct,
    id: string,
    props: WebSessionInfrastructureProps,
  ) {
    super(scope, id);

    this.encryptionKey = new kms.Key(this, "EncryptionKey", {
      alias: `alias/foloo-${props.environmentName}-web-sessions`,
      description: "Encrypts Cognito credentials held by Foloo web sessions",
      enableKeyRotation: true,
      pendingWindow: cdk.Duration.days(30),
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    this.table = new dynamodb.Table(this, "Table", {
      partitionKey: { name: "pk", type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      encryption: dynamodb.TableEncryption.CUSTOMER_MANAGED,
      encryptionKey: this.encryptionKey,
      pointInTimeRecoverySpecification: {
        pointInTimeRecoveryEnabled: true,
      },
      timeToLiveAttribute: "expires_at",
      deletionProtection: true,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });

    const logGroup = new logs.LogGroup(this, "LogGroup", {
      retention: logs.RetentionDays.ONE_WEEK,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });
    this.function = new lambdaNode.NodejsFunction(this, "Function", {
      entry: join(import.meta.dirname, "../src/web_auth/web_session_lambda.ts"),
      handler: "handler",
      runtime: lambda.Runtime.NODEJS_22_X,
      architecture: lambda.Architecture.ARM_64,
      memorySize: 512,
      timeout: cdk.Duration.seconds(15),
      logGroup,
      environment: {
        // Activation remains DEV-only and fail-closed to pseudonymous QA subjects.
        FOLOO_WEB_SESSION_ENABLED: props.enabled === true ? "true" : "false",
        WEB_SESSION_QA_SUBJECT_HASHES: (props.qaSubjectHashes ?? []).join(","),
        WEB_SESSION_TABLE_NAME: this.table.tableName,
        WEB_SESSION_KEY_ARN: this.encryptionKey.keyArn,
        WEB_SESSION_ABSOLUTE_SECONDS: String(props.absoluteDurationSeconds),
        WEB_SESSION_IDLE_SECONDS: String(props.idleDurationSeconds),
        WEB_SESSION_REFRESH_SKEW_SECONDS: "60",
        WEB_SESSION_OAUTH_TRANSACTION_SECONDS: "600",
        WEB_AUTH_ALLOWED_ORIGIN: props.allowedOrigin,
        WEB_AUTH_CALLBACK_URL: props.callbackUrl,
        WEB_AUTH_SUCCESS_REDIRECT_PATH: props.successRedirectPath,
        WEB_COGNITO_CLIENT_ID: props.webClientId,
        WEB_COGNITO_ISSUER: `https://cognito-idp.${cdk.Stack.of(this).region}.amazonaws.com/${props.userPoolId}`,
        WEB_COGNITO_DOMAIN: props.cognitoDomain,
        PUBLIC_API_BASE_URL: props.publicApiBaseUrl,
      },
      bundling: { minify: true, sourceMap: true },
    });
    this.function.addToRolePolicy(
      new iam.PolicyStatement({
        actions: [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
        ],
        resources: [this.table.tableArn],
      }),
    );
    this.function.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ["kms:Encrypt", "kms:Decrypt"],
        resources: [this.encryptionKey.keyArn],
      }),
    );

    new cloudwatch.Alarm(this, "FunctionErrorsAlarm", {
      metric: this.function.metricErrors(),
      threshold: 1,
      evaluationPeriods: 1,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });
    new cloudwatch.Alarm(this, "FunctionThrottlesAlarm", {
      metric: this.function.metricThrottles(),
      threshold: 1,
      evaluationPeriods: 1,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });
    new cloudwatch.Alarm(this, "TableSystemErrorsAlarm", {
      metric: this.table.metricSystemErrorsForOperations({
        operations: [
          dynamodb.Operation.GET_ITEM,
          dynamodb.Operation.PUT_ITEM,
          dynamodb.Operation.UPDATE_ITEM,
          dynamodb.Operation.DELETE_ITEM,
        ],
      }),
      threshold: 1,
      evaluationPeriods: 1,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });
  }
}
