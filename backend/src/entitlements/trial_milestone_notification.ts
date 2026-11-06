/** Durable, disabled-by-default notification pipeline for the FREE 5/5 milestone.
 *
 * Lead acceptance never depends on this worker. SES delivery and a commercial
 * CTA remain closed until communication content and destination are approved.
 */

import type pg from "pg";

export type TrialMilestoneNotificationMode = "disabled" | "ses";

export type TrialMilestoneRecipient = {
  email: string;
  emailVerified: true;
};

export interface TrialMilestoneRecipientResolver {
  verifiedEmailForSubject(subject: string): Promise<TrialMilestoneRecipient>;
}

export interface TrialMilestoneMailer {
  send(input: {
    recipient: string;
    subject: string;
    text: string;
    html: string;
    idempotencyKey: string;
  }): Promise<{ providerMessageId: string }>;
}

type ClaimedMilestone = {
  id: string;
  accountId: string;
  subject: string;
  attemptCount: number;
};

export class TrialMilestoneNotificationWorker {
  constructor(
    private readonly pool: pg.Pool,
    private readonly recipients: TrialMilestoneRecipientResolver,
    private readonly mailer: TrialMilestoneMailer,
    private readonly mode: TrialMilestoneNotificationMode = "disabled",
  ) {}

  async processOne(): Promise<"disabled" | "empty" | "accepted" | "failed"> {
    if (this.mode === "disabled") return "disabled";
    const event = await this.claim();
    if (!event) return "empty";
    try {
      const recipient = await this.recipients.verifiedEmailForSubject(
        event.subject,
      );
      if (!recipient.emailVerified) throw new Error("recipient_unverified");
      const content = trialMilestoneEmail("es");
      const delivery = await this.mailer.send({
        recipient: recipient.email,
        ...content,
        idempotencyKey: event.id,
      });
      await this.pool.query(
        `UPDATE trial_milestone_events SET delivery_status='accepted',
           provider_message_id=$2, accepted_at=now(), updated_at=now(),
           last_error_code=NULL, next_attempt_at=NULL
         WHERE id=$1 AND delivery_status='in_flight'`,
        [event.id, delivery.providerMessageId],
      );
      return "accepted";
    } catch (error) {
      const delaySeconds = Math.min(3600, 30 * 2 ** event.attemptCount);
      await this.pool.query(
        `UPDATE trial_milestone_events SET delivery_status='failed',
           last_error_code=$2, next_attempt_at=now()+($3 * interval '1 second'),
           updated_at=now() WHERE id=$1 AND delivery_status='in_flight'`,
        [event.id, safeErrorCode(error), delaySeconds],
      );
      return "failed";
    }
  }

  private async claim(): Promise<ClaimedMilestone | undefined> {
    const db = await this.pool.connect();
    try {
      await db.query("BEGIN");
      const result = await db.query<ClaimedMilestone>(
        `SELECT milestone.id, milestone.account_id AS "accountId",
                users.cognito_sub AS subject,
                milestone.attempt_count AS "attemptCount"
         FROM trial_milestone_events milestone
         JOIN accounts account ON account.id=milestone.account_id
           AND account.deleted_at IS NULL
         JOIN app_users users ON users.id=account.owner_user_id
         WHERE milestone.delivery_status IN ('pending','failed')
           AND (milestone.next_attempt_at IS NULL OR milestone.next_attempt_at <= now())
         ORDER BY milestone.created_at
         FOR UPDATE OF milestone SKIP LOCKED LIMIT 1`,
      );
      const event = result.rows[0];
      if (!event) {
        await db.query("COMMIT");
        return undefined;
      }
      await db.query(
        `UPDATE trial_milestone_events SET delivery_status='in_flight',
           attempt_count=attempt_count+1, updated_at=now() WHERE id=$1`,
        [event.id],
      );
      await db.query("COMMIT");
      return { ...event, attemptCount: event.attemptCount + 1 };
    } catch (error) {
      await db.query("ROLLBACK");
      throw error;
    } finally {
      db.release();
    }
  }
}

export function trialMilestoneEmail(language: "es" | "en") {
  if (language === "en") {
    return {
      subject: "Your five free Foloo leads are safe",
      text: "You have used your 5 free leads. Your leads remain available. Unlimited capture is not yet available from this email.",
      html: "<h1>The event continues. Your leads do too.</h1><p>You have used your 5 free leads. Your existing leads remain available.</p><p>Unlimited capture is not yet available from this email.</p>",
    };
  }
  return {
    subject: "Tus cinco leads gratis están seguros",
    text: "Ya utilizaste tus 5 leads gratis. Tus leads siguen disponibles. La contratación de capturas ilimitadas todavía no está disponible desde este correo.",
    html: "<h1>El evento sigue. Tus leads también.</h1><p>Ya utilizaste tus 5 leads gratis. Tus leads existentes siguen disponibles.</p><p>La contratación de capturas ilimitadas todavía no está disponible desde este correo.</p>",
  };
}

function safeErrorCode(error: unknown): string {
  if (error instanceof Error && /^[a-z0-9_]{1,80}$/u.test(error.message)) {
    return error.message;
  }
  return "notification_failed";
}
