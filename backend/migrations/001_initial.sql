-- FL-014 cloud foundation. UUIDs may originate offline; binary media stays out.
BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE app_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cognito_sub text NOT NULL UNIQUE CHECK (length(cognito_sub) BETWEEN 1 AND 255),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind text NOT NULL DEFAULT 'personal' CHECK (kind IN ('personal', 'organization')),
  owner_user_id uuid REFERENCES app_users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE UNIQUE INDEX one_personal_account_per_user
  ON accounts (owner_user_id)
  WHERE kind = 'personal' AND deleted_at IS NULL;

CREATE TABLE workspaces (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id uuid NOT NULL REFERENCES accounts(id),
  name text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (account_id, id)
);

CREATE TABLE workspace_members (
  workspace_id uuid NOT NULL REFERENCES workspaces(id),
  user_id uuid NOT NULL REFERENCES app_users(id),
  role text NOT NULL CHECK (role IN ('owner', 'member')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (workspace_id, user_id)
);

CREATE TABLE seller_profiles (
  workspace_id uuid PRIMARY KEY REFERENCES workspaces(id),
  user_id uuid NOT NULL REFERENCES app_users(id),
  name text NOT NULL CHECK (length(name) BETWEEN 1 AND 160),
  company text NOT NULL CHECK (length(company) BETWEEN 1 AND 160),
  position text,
  phone text,
  photo_url text,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE events (
  id uuid PRIMARY KEY,
  workspace_id uuid NOT NULL REFERENCES workspaces(id),
  name text NOT NULL CHECK (length(name) BETWEEN 1 AND 160),
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CHECK (ends_at >= starts_at),
  UNIQUE (workspace_id, id)
);

CREATE INDEX events_workspace_dates_idx
  ON events (workspace_id, starts_at, ends_at) WHERE deleted_at IS NULL;

CREATE TABLE leads (
  id uuid PRIMARY KEY,
  workspace_id uuid NOT NULL REFERENCES workspaces(id),
  event_id uuid,
  captured_by_user_id uuid NOT NULL REFERENCES app_users(id),
  captured_at timestamptz NOT NULL,
  origin text NOT NULL CHECK (origin IN ('event', 'direct')),
  place text,
  first_name text NOT NULL CHECK (length(first_name) BETWEEN 1 AND 160),
  last_name text,
  position text,
  company text NOT NULL CHECK (length(company) BETWEEN 1 AND 160),
  email text,
  phone text,
  lead_type text NOT NULL CHECK (lead_type IN ('customer', 'partner', 'supplier')),
  interest text NOT NULL CHECK (interest IN ('low', 'medium', 'high')),
  written_note text,
  commercial_folio text,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CHECK (
    (origin = 'event' AND event_id IS NOT NULL AND place IS NULL) OR
    (origin = 'direct' AND event_id IS NULL AND length(trim(place)) > 0)
  ),
  CHECK (email IS NOT NULL OR phone IS NOT NULL),
  UNIQUE (workspace_id, id),
  FOREIGN KEY (workspace_id, event_id) REFERENCES events(workspace_id, id)
);

CREATE INDEX leads_workspace_captured_idx
  ON leads (workspace_id, captured_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX leads_workspace_event_idx
  ON leads (workspace_id, event_id) WHERE deleted_at IS NULL;

CREATE TABLE lead_media (
  id uuid PRIMARY KEY,
  workspace_id uuid NOT NULL REFERENCES workspaces(id),
  lead_id uuid NOT NULL,
  kind text NOT NULL CHECK (kind IN ('business_card', 'reference_image', 'voice_note')),
  content_type text NOT NULL CHECK (length(content_type) BETWEEN 1 AND 120),
  byte_size bigint NOT NULL CHECK (byte_size >= 0),
  captured_at timestamptz NOT NULL,
  duration_ms bigint CHECK (duration_ms IS NULL OR duration_ms >= 0),
  sha256 char(64) CHECK (sha256 IS NULL OR sha256 ~ '^[0-9a-fA-F]{64}$'),
  storage_object_key text,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (workspace_id, id),
  FOREIGN KEY (workspace_id, lead_id) REFERENCES leads(workspace_id, id)
);

CREATE INDEX lead_media_workspace_lead_idx
  ON lead_media (workspace_id, lead_id) WHERE deleted_at IS NULL;

CREATE TABLE content_files (
  id uuid PRIMARY KEY,
  workspace_id uuid NOT NULL REFERENCES workspaces(id),
  display_name text NOT NULL CHECK (length(display_name) BETWEEN 1 AND 160),
  content_type text NOT NULL DEFAULT 'application/pdf' CHECK (content_type = 'application/pdf'),
  byte_size bigint NOT NULL CHECK (byte_size >= 0),
  sha256 char(64) CHECK (sha256 IS NULL OR sha256 ~ '^[0-9a-fA-F]{64}$'),
  storage_object_key text,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (workspace_id, id)
);

CREATE TABLE idempotency_records (
  workspace_id uuid NOT NULL REFERENCES workspaces(id),
  operation text NOT NULL CHECK (length(operation) BETWEEN 1 AND 120),
  idempotency_key text NOT NULL CHECK (length(idempotency_key) BETWEEN 8 AND 128),
  request_hash char(64) NOT NULL CHECK (request_hash ~ '^[0-9a-f]{64}$'),
  response_status integer NOT NULL CHECK (response_status BETWEEN 200 AND 299),
  response_body jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '7 days'),
  PRIMARY KEY (workspace_id, operation, idempotency_key)
);

CREATE OR REPLACE FUNCTION touch_revision() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  NEW.revision = OLD.revision + 1;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER seller_profiles_touch BEFORE UPDATE ON seller_profiles
  FOR EACH ROW EXECUTE FUNCTION touch_revision();
CREATE TRIGGER events_touch BEFORE UPDATE ON events
  FOR EACH ROW EXECUTE FUNCTION touch_revision();
CREATE TRIGGER leads_touch BEFORE UPDATE ON leads
  FOR EACH ROW EXECUTE FUNCTION touch_revision();
CREATE TRIGGER lead_media_touch BEFORE UPDATE ON lead_media
  FOR EACH ROW EXECUTE FUNCTION touch_revision();
CREATE TRIGGER content_files_touch BEFORE UPDATE ON content_files
  FOR EACH ROW EXECUTE FUNCTION touch_revision();

-- Serializes first-request provisioning for one Cognito subject without using email.
CREATE OR REPLACE FUNCTION ensure_personal_workspace(p_subject text)
RETURNS TABLE(user_id uuid, account_id uuid, workspace_id uuid) AS $$
DECLARE
  v_user_id uuid;
  v_account_id uuid;
  v_workspace_id uuid;
BEGIN
  IF p_subject IS NULL OR length(trim(p_subject)) = 0 THEN
    RAISE EXCEPTION 'subject is required';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext(p_subject));

  SELECT u.id, w.account_id, wm.workspace_id
    INTO v_user_id, v_account_id, v_workspace_id
  FROM app_users u
  JOIN workspace_members wm ON wm.user_id = u.id AND wm.role = 'owner'
  JOIN workspaces w ON w.id = wm.workspace_id AND w.deleted_at IS NULL
  JOIN accounts a ON a.id = w.account_id AND a.owner_user_id = u.id
    AND a.kind = 'personal' AND a.deleted_at IS NULL
  WHERE u.cognito_sub = p_subject
  LIMIT 1;

  IF v_workspace_id IS NULL THEN
    INSERT INTO app_users (cognito_sub) VALUES (p_subject)
      ON CONFLICT (cognito_sub) DO UPDATE SET updated_at = now()
      RETURNING id INTO v_user_id;
    INSERT INTO accounts (owner_user_id) VALUES (v_user_id)
      RETURNING id INTO v_account_id;
    INSERT INTO workspaces (account_id) VALUES (v_account_id)
      RETURNING id INTO v_workspace_id;
    INSERT INTO workspace_members (workspace_id, user_id, role)
      VALUES (v_workspace_id, v_user_id, 'owner');
  END IF;

  RETURN QUERY SELECT v_user_id, v_account_id, v_workspace_id;
END;
$$ LANGUAGE plpgsql;

GRANT USAGE ON SCHEMA public TO foloo_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO foloo_app;
GRANT EXECUTE ON FUNCTION ensure_personal_workspace(text) TO foloo_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO foloo_app;

COMMIT;
