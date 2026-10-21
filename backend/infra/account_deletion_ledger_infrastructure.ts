/**
 * Standalone CDK construct for the future Account Deletion ledger.
 * It is intentionally not instantiated by FolooBackendStack, so synthesizing
 * or deploying the current application cannot create these resources yet.
 */

import * as cdk from "aws-cdk-lib";
import * as cloudwatch from "aws-cdk-lib/aws-cloudwatch";
import * as dynamodb from "aws-cdk-lib/aws-dynamodb";
import * as iam from "aws-cdk-lib/aws-iam";
import * as kms from "aws-cdk-lib/aws-kms";
import * as sqs from "aws-cdk-lib/aws-sqs";
import { Construct } from "constructs";

export class AccountDeletionLedgerInfrastructure extends Construct {
  readonly table: dynamodb.Table;
  readonly hmacKey: kms.Key;
  readonly recipientKey: kms.Key;
  readonly queue: sqs.Queue;
  readonly deadLetterQueue: sqs.Queue;

  constructor(scope: Construct, id: string) {
    super(scope, id);

    this.table = new dynamodb.Table(this, "LedgerTable", {
      partitionKey: { name: "pk", type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      encryption: dynamodb.TableEncryption.AWS_MANAGED,
      pointInTimeRecoverySpecification: {
        pointInTimeRecoveryEnabled: true,
      },
      timeToLiveAttribute: "expires_at",
      deletionProtection: true,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
    });
    this.hmacKey = new kms.Key(this, "IdentityHmacKey", {
      description: "HMAC key for Foloo account-deletion pseudonyms",
      keySpec: kms.KeySpec.HMAC_256,
      keyUsage: kms.KeyUsage.GENERATE_VERIFY_MAC,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      pendingWindow: cdk.Duration.days(30),
    });
    this.recipientKey = new kms.Key(this, "NotificationRecipientKey", {
      description: "Envelope-encrypts short-lived Account Deletion recipients",
      enableKeyRotation: true,
      removalPolicy: cdk.RemovalPolicy.RETAIN,
      pendingWindow: cdk.Duration.days(30),
    });
    this.deadLetterQueue = new sqs.Queue(this, "DeletionDeadLetterQueue", {
      fifo: true,
      encryption: sqs.QueueEncryption.KMS_MANAGED,
      retentionPeriod: cdk.Duration.days(14),
      enforceSSL: true,
    });
    this.queue = new sqs.Queue(this, "DeletionQueue", {
      fifo: true,
      contentBasedDeduplication: false,
      encryption: sqs.QueueEncryption.KMS_MANAGED,
      visibilityTimeout: cdk.Duration.minutes(15),
      retentionPeriod: cdk.Duration.days(14),
      deadLetterQueue: { queue: this.deadLetterQueue, maxReceiveCount: 5 },
      enforceSSL: true,
    });

    new cloudwatch.Alarm(this, "SystemErrorsAlarm", {
      metric: this.table.metricSystemErrorsForOperations({
        operations: [
          dynamodb.Operation.GET_ITEM,
          dynamodb.Operation.BATCH_GET_ITEM,
          dynamodb.Operation.TRANSACT_WRITE_ITEMS,
        ],
      }),
      threshold: 1,
      evaluationPeriods: 1,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });
    new cloudwatch.Alarm(this, "ThrottledRequestsAlarm", {
      metric: this.table.metricThrottledRequestsForOperations({
        operations: [
          dynamodb.Operation.GET_ITEM,
          dynamodb.Operation.BATCH_GET_ITEM,
          dynamodb.Operation.TRANSACT_WRITE_ITEMS,
        ],
      }),
      threshold: 1,
      evaluationPeriods: 1,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });
    new cloudwatch.Alarm(this, "DeletionDlqAlarm", {
      metric: this.deadLetterQueue.metricApproximateNumberOfMessagesVisible(),
      threshold: 1,
      evaluationPeriods: 1,
      treatMissingData: cloudwatch.TreatMissingData.NOT_BREACHING,
    });
  }

  /** Grants only the three DynamoDB operations used by the isolated adapter. */
  grantAdapterAccess(grantee: iam.IGrantable): iam.Grant {
    return this.table.grant(
      grantee,
      "dynamodb:GetItem",
      "dynamodb:BatchGetItem",
      "dynamodb:TransactWriteItems",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
    );
  }

  grantHmac(grantee: iam.IGrantable): iam.Grant {
    return this.hmacKey.grant(grantee, "kms:GenerateMac", "kms:VerifyMac");
  }

  grantRecipientEncryption(grantee: iam.IGrantable): iam.Grant {
    return this.recipientKey.grantEncryptDecrypt(grantee);
  }
}
