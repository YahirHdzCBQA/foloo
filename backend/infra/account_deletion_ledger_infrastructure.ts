/**
 * Defines the durable Account Deletion ledger, queues and encryption boundary.
 * Deployable stacks import an explicitly validated KMS pair; isolated tests may
 * synthesize owned keys to verify their required properties.
 */

import * as cdk from "aws-cdk-lib";
import * as cloudwatch from "aws-cdk-lib/aws-cloudwatch";
import * as dynamodb from "aws-cdk-lib/aws-dynamodb";
import * as iam from "aws-cdk-lib/aws-iam";
import * as kms from "aws-cdk-lib/aws-kms";
import * as sqs from "aws-cdk-lib/aws-sqs";
import { Construct } from "constructs";

export type AccountDeletionLedgerInfrastructureProps = {
  existingIdentityHmacKeyArn?: string;
  existingNotificationRecipientKeyArn?: string;
};

export class AccountDeletionLedgerInfrastructure extends Construct {
  readonly table: dynamodb.Table;
  readonly hmacKey: kms.IKey;
  readonly recipientKey: kms.IKey;
  readonly queue: sqs.Queue;
  readonly deadLetterQueue: sqs.Queue;

  constructor(
    scope: Construct,
    id: string,
    props: AccountDeletionLedgerInfrastructureProps = {},
  ) {
    super(scope, id);

    const importsIdentityKey = props.existingIdentityHmacKeyArn !== undefined;
    const importsRecipientKey =
      props.existingNotificationRecipientKeyArn !== undefined;
    if (importsIdentityKey !== importsRecipientKey) {
      throw new Error(
        "Account Deletion KMS keys must be imported together or created together.",
      );
    }

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
    this.table.addGlobalSecondaryIndex({
      indexName: "entity_type-created_at-index",
      partitionKey: {
        name: "entity_type",
        type: dynamodb.AttributeType.STRING,
      },
      sortKey: { name: "created_at", type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
    });
    this.hmacKey = importsIdentityKey
      ? kms.Key.fromKeyArn(
          this,
          "IdentityHmacKey",
          props.existingIdentityHmacKeyArn!,
        )
      : new kms.Key(this, "IdentityHmacKey", {
          description: "HMAC key for Foloo account-deletion pseudonyms",
          keySpec: kms.KeySpec.HMAC_256,
          keyUsage: kms.KeyUsage.GENERATE_VERIFY_MAC,
          removalPolicy: cdk.RemovalPolicy.RETAIN,
          pendingWindow: cdk.Duration.days(30),
        });
    this.recipientKey = importsRecipientKey
      ? kms.Key.fromKeyArn(
          this,
          "NotificationRecipientKey",
          props.existingNotificationRecipientKeyArn!,
        )
      : new kms.Key(this, "NotificationRecipientKey", {
          description:
            "Envelope-encrypts short-lived Account Deletion recipients",
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
      // Direct upload URLs issued before the PostgreSQL barrier remain valid
      // for ten minutes. Delay inventory until those capabilities expire.
      deliveryDelay: cdk.Duration.minutes(11),
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

  /** Grants the API's workflow, guard and encrypted-recipient operations. */
  grantApiAccess(grantee: iam.IGrantable): void {
    this.grantTableActions(
      grantee,
      "dynamodb:GetItem",
      "dynamodb:BatchGetItem",
      "dynamodb:TransactWriteItems",
      "dynamodb:PutItem",
    );
  }

  /** Grants the deletion worker's workflow, checkpoint and inventory writes. */
  grantWorkerAccess(grantee: iam.IGrantable): void {
    this.grantTableActions(
      grantee,
      "dynamodb:GetItem",
      "dynamodb:TransactWriteItems",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
    );
  }

  /** Grants the scheduled dispatcher table reads/transaction and its one GSI. */
  grantOutboxRecoveryAccess(grantee: iam.IGrantable): void {
    this.grantTableActions(
      grantee,
      "dynamodb:GetItem",
      "dynamodb:TransactWriteItems",
    );
    iam.Grant.addToPrincipal({
      grantee,
      actions: ["dynamodb:Query"],
      resourceArns: [
        `${this.table.tableArn}/index/entity_type-created_at-index`,
      ],
    });
  }

  /** Grants verified-identity guards their only DynamoDB read operation. */
  grantGuardReadAccess(grantee: iam.IGrantable): void {
    this.grantTableActions(grantee, "dynamodb:BatchGetItem");
  }

  /** Grants the SES notification boundary recipient lookup and final purge. */
  grantEmailAccess(grantee: iam.IGrantable): void {
    this.grantTableActions(grantee, "dynamodb:GetItem", "dynamodb:DeleteItem");
  }

  private grantTableActions(
    grantee: iam.IGrantable,
    ...actions: string[]
  ): void {
    iam.Grant.addToPrincipal({
      grantee,
      actions,
      resourceArns: [this.table.tableArn],
    });
  }

  grantHmac(grantee: iam.IGrantable): iam.Grant {
    return this.hmacKey.grant(grantee, "kms:GenerateMac", "kms:VerifyMac");
  }

  grantRecipientEncryption(grantee: iam.IGrantable): iam.Grant {
    return this.recipientKey.grantEncryptDecrypt(grantee);
  }
}
