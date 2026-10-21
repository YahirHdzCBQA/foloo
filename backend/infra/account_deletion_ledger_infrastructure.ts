/**
 * Standalone CDK construct for the future Account Deletion ledger.
 * It is intentionally not instantiated by FolooBackendStack, so synthesizing
 * or deploying the current application cannot create these resources yet.
 */

import * as cdk from "aws-cdk-lib";
import * as cloudwatch from "aws-cdk-lib/aws-cloudwatch";
import * as dynamodb from "aws-cdk-lib/aws-dynamodb";
import * as iam from "aws-cdk-lib/aws-iam";
import { Construct } from "constructs";

export class AccountDeletionLedgerInfrastructure extends Construct {
  readonly table: dynamodb.Table;

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
  }

  /** Grants only the three DynamoDB operations used by the isolated adapter. */
  grantAdapterAccess(grantee: iam.IGrantable): iam.Grant {
    return this.table.grant(
      grantee,
      "dynamodb:GetItem",
      "dynamodb:BatchGetItem",
      "dynamodb:TransactWriteItems",
    );
  }
}
