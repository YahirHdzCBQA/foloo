-- FL-019 delivery metadata; additive to the template/follow-up foundation.
DROP INDEX email_connections_current_idx;
CREATE UNIQUE INDEX email_connections_current_owner_idx
  ON email_connections (workspace_id, owner_user_id)
  WHERE status = 'connected';

ALTER TABLE email_templates DROP CONSTRAINT email_templates_pkey;
ALTER TABLE email_templates
  ADD PRIMARY KEY (workspace_id, owner_user_id, origin, language);

ALTER TABLE email_oauth_states
  ADD COLUMN failure_code text;

ALTER TABLE email_follow_ups
  ADD COLUMN plain_body text,
  ADD COLUMN html_body text,
  ADD COLUMN footer text,
  ADD COLUMN unsubscribe_token_hash char(64);

ALTER TABLE email_unsubscribe_tokens
  ADD COLUMN owner_user_id uuid REFERENCES app_users(id);

CREATE TABLE email_owner_opt_outs (
  workspace_id uuid NOT NULL REFERENCES workspaces(id),
  owner_user_id uuid NOT NULL REFERENCES app_users(id),
  recipient_hash char(64) NOT NULL,
  opted_out_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (workspace_id, owner_user_id, recipient_hash)
);

ALTER TABLE email_send_intents
  ADD COLUMN revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  ADD COLUMN omitted_content_ids uuid[] NOT NULL DEFAULT '{}',
  ADD COLUMN parent_intent_id uuid,
  ADD COLUMN last_attempt_kind text CHECK
    (last_attempt_kind IS NULL OR last_attempt_kind IN ('initial','safe_retry','manual_resend')),
  ADD COLUMN provider_error_class text,
  ADD COLUMN accepted_sender_address text,
  ADD CONSTRAINT email_send_intents_parent_fk
    FOREIGN KEY (workspace_id, parent_intent_id)
    REFERENCES email_send_intents(workspace_id, id);

CREATE TRIGGER email_send_intents_touch BEFORE UPDATE ON email_send_intents
  FOR EACH ROW EXECUTE FUNCTION touch_revision();

CREATE INDEX email_send_intents_parent_idx
  ON email_send_intents (workspace_id, parent_intent_id);
