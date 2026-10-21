BEGIN;

ALTER TABLE app_users
  ADD COLUMN IF NOT EXISTS deletion_request_id uuid,
  ADD COLUMN IF NOT EXISTS deletion_pending_at timestamptz;

DO $migration$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'app_users_deletion_barrier_consistent'
      AND conrelid = 'app_users'::regclass
  ) THEN
    ALTER TABLE app_users
      ADD CONSTRAINT app_users_deletion_barrier_consistent CHECK (
        (deletion_request_id IS NULL AND deletion_pending_at IS NULL) OR
        (deletion_request_id IS NOT NULL AND deletion_pending_at IS NOT NULL)
      );
  END IF;
END;
$migration$;

CREATE UNIQUE INDEX IF NOT EXISTS app_users_deletion_request_unique
  ON app_users(deletion_request_id) WHERE deletion_request_id IS NOT NULL;

CREATE OR REPLACE FUNCTION assert_account_active(p_subject text)
RETURNS void AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM app_users
    WHERE cognito_sub = p_subject AND deletion_pending_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'account_deletion_pending' USING ERRCODE = 'P0001';
  END IF;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION mark_account_deletion_pending(
  p_subject text,
  p_request_id uuid,
  p_accepted_at timestamptz
)
RETURNS void AS $$
DECLARE
  v_updated integer;
BEGIN
  IF p_subject IS NULL OR length(trim(p_subject)) = 0 THEN
    RAISE EXCEPTION 'subject is required';
  END IF;
  IF p_request_id IS NULL OR p_accepted_at IS NULL THEN
    RAISE EXCEPTION 'deletion barrier fields are required';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext(p_subject));
  UPDATE app_users
  SET deletion_request_id = p_request_id,
      deletion_pending_at = p_accepted_at,
      updated_at = now()
  WHERE cognito_sub = p_subject
    AND (deletion_request_id IS NULL OR deletion_request_id = p_request_id);
  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated <> 1 THEN
    RAISE EXCEPTION 'account_deletion_barrier_not_established'
      USING ERRCODE = 'P0001';
  END IF;
END;
$$ LANGUAGE plpgsql;

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
  PERFORM assert_account_active(p_subject);

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

GRANT EXECUTE ON FUNCTION assert_account_active(text) TO foloo_app;
GRANT EXECUTE ON FUNCTION mark_account_deletion_pending(text, uuid, timestamptz)
  TO foloo_app;
GRANT EXECUTE ON FUNCTION ensure_personal_workspace(text) TO foloo_app;

COMMIT;
