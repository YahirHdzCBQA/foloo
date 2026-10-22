BEGIN;

-- Every owner-scoped write uses the same transaction advisory lock as
-- mark_account_deletion_pending(). This closes the gap where a request that
-- started before the HTTP guard could commit after the deletion barrier.
CREATE OR REPLACE FUNCTION account_owner_subject_for_workspace(p_workspace_id uuid)
RETURNS text AS $$
  SELECT u.cognito_sub
  FROM workspaces w
  JOIN accounts a ON a.id = w.account_id
  JOIN app_users u ON u.id = a.owner_user_id
  WHERE w.id = p_workspace_id
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION fence_account_owner_write(p_subject text)
RETURNS void AS $$
BEGIN
  IF p_subject IS NULL OR length(trim(p_subject)) = 0 THEN
    RAISE EXCEPTION 'account_owner_not_resolved' USING ERRCODE = 'P0001';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtext(p_subject));
  PERFORM assert_account_active(p_subject);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fence_workspace_owner_write()
RETURNS trigger AS $$
DECLARE
  v_old_workspace uuid;
  v_new_workspace uuid;
  v_subject text;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    v_old_workspace := NULLIF(to_jsonb(OLD)->>'workspace_id', '')::uuid;
  END IF;
  v_new_workspace := NULLIF(to_jsonb(NEW)->>'workspace_id', '')::uuid;

  FOR v_subject IN
    SELECT DISTINCT account_owner_subject_for_workspace(workspace_id)
    FROM (VALUES (v_old_workspace), (v_new_workspace)) AS scopes(workspace_id)
    WHERE workspace_id IS NOT NULL
  LOOP
    PERFORM fence_account_owner_write(v_subject);
  END LOOP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fence_account_row_owner_write()
RETURNS trigger AS $$
DECLARE
  v_user_id uuid;
  v_subject text;
BEGIN
  FOR v_user_id IN
    SELECT DISTINCT user_id
    FROM (VALUES
      (CASE WHEN TG_OP = 'UPDATE' THEN OLD.owner_user_id ELSE NULL END),
      (NEW.owner_user_id)
    ) AS owners(user_id)
    WHERE user_id IS NOT NULL
  LOOP
    SELECT cognito_sub INTO v_subject FROM app_users WHERE id = v_user_id;
    PERFORM fence_account_owner_write(v_subject);
  END LOOP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fence_workspace_row_owner_write()
RETURNS trigger AS $$
DECLARE
  v_account_id uuid;
  v_subject text;
BEGIN
  FOR v_account_id IN
    SELECT DISTINCT account_id
    FROM (VALUES
      (CASE WHEN TG_OP = 'UPDATE' THEN OLD.account_id ELSE NULL END),
      (NEW.account_id)
    ) AS accounts(account_id)
    WHERE account_id IS NOT NULL
  LOOP
    SELECT u.cognito_sub INTO v_subject
    FROM accounts a JOIN app_users u ON u.id = a.owner_user_id
    WHERE a.id = v_account_id;
    PERFORM fence_account_owner_write(v_subject);
  END LOOP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fence_membership_owner_write()
RETURNS trigger AS $$
DECLARE
  v_old_workspace uuid;
  v_new_workspace uuid;
  v_subject text;
BEGIN
  IF TG_OP = 'UPDATE' THEN v_old_workspace := OLD.workspace_id; END IF;
  v_new_workspace := NEW.workspace_id;
  FOR v_subject IN
    SELECT DISTINCT account_owner_subject_for_workspace(workspace_id)
    FROM (VALUES (v_old_workspace), (v_new_workspace)) AS scopes(workspace_id)
    WHERE workspace_id IS NOT NULL
  LOOP
    PERFORM fence_account_owner_write(v_subject);
  END LOOP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS account_deletion_write_fence ON accounts;
CREATE TRIGGER account_deletion_write_fence
BEFORE INSERT OR UPDATE ON accounts
FOR EACH ROW EXECUTE FUNCTION fence_account_row_owner_write();

DROP TRIGGER IF EXISTS account_deletion_write_fence ON workspaces;
CREATE TRIGGER account_deletion_write_fence
BEFORE INSERT OR UPDATE ON workspaces
FOR EACH ROW EXECUTE FUNCTION fence_workspace_row_owner_write();

DROP TRIGGER IF EXISTS account_deletion_write_fence ON workspace_members;
CREATE TRIGGER account_deletion_write_fence
BEFORE INSERT OR UPDATE ON workspace_members
FOR EACH ROW EXECUTE FUNCTION fence_membership_owner_write();

DO $migration$
DECLARE
  v_table text;
BEGIN
  FOREACH v_table IN ARRAY ARRAY[
    'seller_profiles', 'events', 'leads', 'lead_media', 'content_files',
    'idempotency_records', 'email_templates', 'event_email_templates',
    'email_connections', 'email_oauth_states', 'email_opt_outs',
    'email_owner_opt_outs', 'email_unsubscribe_tokens', 'email_follow_ups',
    'email_send_intents'
  ]
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS account_deletion_write_fence ON %I', v_table);
    EXECUTE format(
      'CREATE TRIGGER account_deletion_write_fence BEFORE INSERT OR UPDATE ON %I '
      'FOR EACH ROW EXECUTE FUNCTION fence_workspace_owner_write()',
      v_table
    );
  END LOOP;
END;
$migration$;

GRANT EXECUTE ON FUNCTION account_owner_subject_for_workspace(uuid) TO foloo_app;
GRANT EXECUTE ON FUNCTION fence_account_owner_write(text) TO foloo_app;

COMMIT;
