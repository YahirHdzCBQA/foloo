/** FL-021 durable 5/5 notification behavior without real email delivery. */

import assert from "node:assert/strict";
import test from "node:test";

import type pg from "pg";

import {
  TrialMilestoneNotificationWorker,
  trialMilestoneEmail,
} from "../src/entitlements/trial_milestone_notification.js";

class NotificationDatabase {
  queries: string[] = [];
  deliveryStatus = "pending";

  async query<Row extends Record<string, unknown> = Record<string, unknown>>(
    sql: string,
  ) {
    this.queries.push(sql);
    if (sql.includes("FROM trial_milestone_events")) {
      return {
        rows: [
          {
            id: "milestone-a",
            accountId: "account-a",
            subject: "subject-a",
            attemptCount: 0,
          } as unknown as Row,
        ],
        rowCount: 1,
      };
    }
    if (sql.includes("delivery_status='in_flight'")) {
      this.deliveryStatus = "in_flight";
    }
    if (sql.includes("delivery_status='accepted'")) {
      this.deliveryStatus = "accepted";
    }
    if (sql.includes("delivery_status='failed'")) {
      this.deliveryStatus = "failed";
    }
    return { rows: [], rowCount: 0 };
  }

  async connect() {
    return { query: this.query.bind(this), release() {} };
  }
}

test("disabled delivery does not claim or send an event", async () => {
  const database = new NotificationDatabase();
  let sent = 0;
  const worker = new TrialMilestoneNotificationWorker(
    database as unknown as pg.Pool,
    {
      verifiedEmailForSubject: async () => ({
        email: "qa@example.test",
        emailVerified: true,
      }),
    },
    {
      send: async () => {
        sent += 1;
        return { providerMessageId: "message-a" };
      },
    },
    "disabled",
  );
  assert.equal(await worker.processOne(), "disabled");
  assert.equal(sent, 0);
  assert.equal(database.queries.length, 0);
});

test("enabled delivery claims once and records provider acceptance", async () => {
  const database = new NotificationDatabase();
  const keys: string[] = [];
  const worker = new TrialMilestoneNotificationWorker(
    database as unknown as pg.Pool,
    {
      verifiedEmailForSubject: async () => ({
        email: "qa@example.test",
        emailVerified: true,
      }),
    },
    {
      send: async (input) => {
        keys.push(input.idempotencyKey);
        return { providerMessageId: "message-a" };
      },
    },
    "ses",
  );
  assert.equal(await worker.processOne(), "accepted");
  assert.deepEqual(keys, ["milestone-a"]);
  assert.equal(database.deliveryStatus, "accepted");
});

test("provider failure is retryable and never blocks lead persistence", async () => {
  const database = new NotificationDatabase();
  const worker = new TrialMilestoneNotificationWorker(
    database as unknown as pg.Pool,
    {
      verifiedEmailForSubject: async () => ({
        email: "qa@example.test",
        emailVerified: true,
      }),
    },
    {
      send: async () => {
        throw new Error("provider_unavailable");
      },
    },
    "ses",
  );
  assert.equal(await worker.processOne(), "failed");
  assert.equal(database.deliveryStatus, "failed");
});

test("prepared content has no checkout URL or delivery claim", () => {
  for (const language of ["es", "en"] as const) {
    const content = trialMilestoneEmail(language);
    assert.doesNotMatch(
      `${content.text}${content.html}`,
      /stripe|checkout|https?:\/\//iu,
    );
    assert.doesNotMatch(`${content.text}${content.html}`, /sent|enviado/iu);
  }
});
