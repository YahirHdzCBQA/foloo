/**
 * Operational SLA reconciliation for durable Account Deletion requests.
 * It retries only resumable states and emits deduplicated, PII-free milestones
 * measured from durable acceptance (INF-15, RNF-09, RNF-10).
 */

import type {
  AccountDeletionDispatcher,
  AccountDeletionRecipientVault,
  AccountDeletionRecord,
  AccountDeletionWorkflowStore,
} from "./account_deletion_workflow.js";
import { accountDeletionOperationalDeadline } from "./account_deletion_workflow.js";

export type AccountDeletionOperationalMilestone =
  "day_10" | "day_13" | "day_15";

export interface AccountDeletionOperationalAlertSink {
  emit(input: {
    requestId: string;
    milestone: AccountDeletionOperationalMilestone;
    status: AccountDeletionRecord["status"];
    acceptedAt: Date;
    operationalDeadline: Date;
  }): Promise<void>;
}

export type AccountDeletionOperationalResult = Readonly<{
  inspected: number;
  pending: number;
  blocked: number;
  failed: number;
  overdue: number;
  redispatched: number;
  alerts: number;
  day10Alerts: number;
  day13Alerts: number;
  criticalDay15Alerts: number;
}>;

const dayMs = 24 * 60 * 60 * 1000;
const retryLeaseMs = 15 * 60 * 1000;

export class AccountDeletionOperationalReconciler {
  constructor(
    private readonly store: AccountDeletionWorkflowStore,
    private readonly dispatcher: AccountDeletionDispatcher,
    private readonly recipientVault: AccountDeletionRecipientVault,
    private readonly alerts: AccountDeletionOperationalAlertSink,
    private readonly clock: { now(): Date } = { now: () => new Date() },
  ) {}

  async reconcile(limit = 250): Promise<AccountDeletionOperationalResult> {
    const records = await this.store.activeRequests(limit);
    const now = this.clock.now();
    let pending = 0;
    let blocked = 0;
    let failed = 0;
    let overdue = 0;
    let redispatched = 0;
    let alerts = 0;
    let day10Alerts = 0;
    let day13Alerts = 0;
    let criticalDay15Alerts = 0;

    for (const record of records) {
      if (!record.acceptedAt) continue;
      const deadline =
        record.operationalDeadline ??
        accountDeletionOperationalDeadline(record.acceptedAt);
      if (record.status === "blocked") blocked += 1;
      else pending += 1;
      if (record.supportCode) failed += 1;
      if (now.getTime() >= deadline.getTime()) overdue += 1;

      for (const milestone of dueMilestones(record.acceptedAt, now)) {
        if (
          await this.store.claimOperationalAction({
            requestId: record.requestId,
            action: `alert:${milestone}`,
            now,
          })
        ) {
          await this.alerts.emit({
            requestId: record.requestId,
            milestone,
            status: record.status,
            acceptedAt: record.acceptedAt,
            operationalDeadline: deadline,
          });
          alerts += 1;
          if (milestone === "day_10") day10Alerts += 1;
          if (milestone === "day_13") day13Alerts += 1;
          if (milestone === "day_15") criticalDay15Alerts += 1;
        }
      }

      if (record.status !== "requested" && record.status !== "blocked") {
        continue;
      }
      const claimed = await this.store.claimOperationalAction({
        requestId: record.requestId,
        action: "retry_dispatch",
        now,
        leaseUntil: new Date(now.getTime() + retryLeaseMs),
      });
      if (!claimed) continue;
      try {
        const ownerSubject = await this.recipientVault.recoverOwnerSubject(
          record.requestId,
        );
        await this.dispatcher.dispatch({
          requestId: record.requestId,
          ownerSubject,
        });
        redispatched += 1;
      } catch (error) {
        failed += 1;
        console.warn("Account deletion operational retry failed.", {
          requestId: record.requestId,
          errorType: error instanceof Error ? error.name : "UnknownError",
        });
      }
    }
    return {
      inspected: records.length,
      pending,
      blocked,
      failed,
      overdue,
      redispatched,
      alerts,
      day10Alerts,
      day13Alerts,
      criticalDay15Alerts,
    };
  }
}

export class JsonAccountDeletionOperationalAlertSink implements AccountDeletionOperationalAlertSink {
  async emit(input: {
    requestId: string;
    milestone: AccountDeletionOperationalMilestone;
    status: AccountDeletionRecord["status"];
    acceptedAt: Date;
    operationalDeadline: Date;
  }): Promise<void> {
    console.warn(
      JSON.stringify({
        scope: "account_deletion_sla",
        owner: "CBQA_IT",
        requestId: input.requestId,
        milestone: input.milestone,
        status: input.status,
        acceptedAt: input.acceptedAt.toISOString(),
        operationalDeadline: input.operationalDeadline.toISOString(),
      }),
    );
  }
}

export function emitAccountDeletionOperationalMetrics(
  result: AccountDeletionOperationalResult,
  now = new Date(),
): void {
  console.info(
    JSON.stringify({
      _aws: {
        Timestamp: now.getTime(),
        CloudWatchMetrics: [
          {
            Namespace: "Foloo/AccountDeletion",
            Dimensions: [[]],
            Metrics: [
              { Name: "PendingRequests", Unit: "Count" },
              { Name: "BlockedRequests", Unit: "Count" },
              { Name: "FailedRequests", Unit: "Count" },
              { Name: "OverdueRequests", Unit: "Count" },
              { Name: "Day10Alerts", Unit: "Count" },
              { Name: "Day13Alerts", Unit: "Count" },
              { Name: "CriticalDay15Alerts", Unit: "Count" },
            ],
          },
        ],
      },
      PendingRequests: result.pending,
      BlockedRequests: result.blocked,
      FailedRequests: result.failed,
      OverdueRequests: result.overdue,
      Day10Alerts: result.day10Alerts,
      Day13Alerts: result.day13Alerts,
      CriticalDay15Alerts: result.criticalDay15Alerts,
    }),
  );
}

function dueMilestones(
  acceptedAt: Date,
  now: Date,
): AccountDeletionOperationalMilestone[] {
  const age = now.getTime() - acceptedAt.getTime();
  const milestones: AccountDeletionOperationalMilestone[] = [];
  if (age >= 10 * dayMs) milestones.push("day_10");
  if (age >= 13 * dayMs) milestones.push("day_13");
  if (age >= 15 * dayMs) milestones.push("day_15");
  return milestones;
}
