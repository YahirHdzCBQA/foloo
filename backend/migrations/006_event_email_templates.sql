-- FL-019 optional Event-scoped template overrides; absence means inheritance.
CREATE TABLE event_email_templates (
  workspace_id uuid NOT NULL REFERENCES workspaces(id),
  owner_user_id uuid NOT NULL REFERENCES app_users(id),
  event_id uuid NOT NULL,
  language text NOT NULL CHECK (language IN ('es', 'en')),
  subject text NOT NULL,
  body text NOT NULL,
  signature text NOT NULL,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (workspace_id, owner_user_id, event_id, language),
  FOREIGN KEY (workspace_id, event_id) REFERENCES events(workspace_id, id)
);

CREATE TRIGGER event_email_templates_touch
  BEFORE UPDATE ON event_email_templates
  FOR EACH ROW EXECUTE FUNCTION touch_revision();
