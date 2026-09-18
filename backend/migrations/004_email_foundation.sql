-- FL-019 additive, owner-scoped template and follow-up foundation.
CREATE TABLE email_templates (
  workspace_id uuid NOT NULL REFERENCES workspaces(id),
  owner_user_id uuid NOT NULL REFERENCES app_users(id),
  origin text NOT NULL CHECK (origin IN ('event', 'direct')),
  language text NOT NULL CHECK (language IN ('es', 'en')),
  subject text NOT NULL,
  body text NOT NULL,
  signature text NOT NULL,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (workspace_id, origin, language)
);
CREATE TRIGGER email_templates_touch BEFORE UPDATE ON email_templates
  FOR EACH ROW EXECUTE FUNCTION touch_revision();

CREATE TABLE email_connections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES workspaces(id),
  owner_user_id uuid NOT NULL REFERENCES app_users(id),
  provider text NOT NULL CHECK (provider IN ('google', 'microsoft')),
  provider_subject text NOT NULL,
  sender_address text NOT NULL,
  encrypted_credentials bytea NOT NULL,
  credential_key_id text NOT NULL,
  credential_version integer NOT NULL DEFAULT 1,
  status text NOT NULL CHECK (status IN ('connected', 'reconnect_required', 'disconnected')),
  connected_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  disconnected_at timestamptz,
  UNIQUE (workspace_id, id)
);
CREATE UNIQUE INDEX email_connections_current_idx
  ON email_connections (workspace_id) WHERE status = 'connected';

CREATE TABLE email_oauth_states (
  state_hash char(64) PRIMARY KEY,
  workspace_id uuid NOT NULL REFERENCES workspaces(id),
  owner_user_id uuid NOT NULL REFERENCES app_users(id),
  provider text NOT NULL CHECK (provider IN ('google', 'microsoft')),
  code_verifier_ciphertext bytea NOT NULL,
  redirect_uri text NOT NULL,
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX email_oauth_states_expires_idx ON email_oauth_states (expires_at);

CREATE TABLE email_opt_outs (
  workspace_id uuid NOT NULL REFERENCES workspaces(id),
  recipient_hash char(64) NOT NULL,
  recipient_ciphertext bytea,
  opted_out_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (workspace_id, recipient_hash)
);

CREATE TABLE email_unsubscribe_tokens (
  token_hash char(64) PRIMARY KEY,
  workspace_id uuid NOT NULL REFERENCES workspaces(id),
  recipient_hash char(64) NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz
);
CREATE INDEX email_unsubscribe_scope_idx
  ON email_unsubscribe_tokens (workspace_id, recipient_hash);

CREATE TABLE email_follow_ups (
  id uuid PRIMARY KEY,
  workspace_id uuid NOT NULL REFERENCES workspaces(id),
  lead_id uuid NOT NULL,
  owner_user_id uuid NOT NULL REFERENCES app_users(id),
  origin text NOT NULL CHECK (origin IN ('event', 'direct')),
  language text NOT NULL CHECK (language IN ('es', 'en')),
  recipient_address text,
  subject text NOT NULL,
  body text NOT NULL,
  signature text NOT NULL,
  content_file_ids uuid[] NOT NULL DEFAULT '{}',
  content_names text[] NOT NULL DEFAULT '{}',
  prepared_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (workspace_id, id),
  FOREIGN KEY (workspace_id, lead_id) REFERENCES leads(workspace_id, id)
);
CREATE INDEX email_follow_ups_lead_idx
  ON email_follow_ups (workspace_id, lead_id, prepared_at DESC);

CREATE TABLE email_send_intents (
  id uuid PRIMARY KEY,
  workspace_id uuid NOT NULL REFERENCES workspaces(id),
  follow_up_id uuid NOT NULL,
  connection_id uuid,
  provider text CHECK (provider IN ('google', 'microsoft')),
  sender_address text,
  recipient_address text NOT NULL,
  subject text NOT NULL,
  plain_body text NOT NULL,
  html_body text NOT NULL,
  attached_content_ids uuid[] NOT NULL DEFAULT '{}',
  status text NOT NULL DEFAULT 'pending' CHECK
    (status IN ('pending', 'sending', 'sent', 'error', 'confirmation_required')),
  error_code text,
  provider_message_id text,
  attempt_count integer NOT NULL DEFAULT 0,
  confirmed_at timestamptz NOT NULL DEFAULT now(),
  request_started_at timestamptz,
  accepted_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (workspace_id, id),
  FOREIGN KEY (workspace_id, follow_up_id)
    REFERENCES email_follow_ups(workspace_id, id),
  FOREIGN KEY (workspace_id, connection_id)
    REFERENCES email_connections(workspace_id, id)
);
CREATE INDEX email_send_intents_status_idx
  ON email_send_intents (workspace_id, status, confirmed_at);
