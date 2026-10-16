-- FL-020.6-A / SAL-11: immutable visible sender identity per send intent.
-- Nullable preserves historical intents without silently recalculating identity.
ALTER TABLE email_send_intents
  ADD COLUMN IF NOT EXISTS sender_display_name text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'email_send_intents_sender_display_name_safe'
  ) THEN
    ALTER TABLE email_send_intents
      ADD CONSTRAINT email_send_intents_sender_display_name_safe
      CHECK (
        sender_display_name IS NULL OR
        (length(sender_display_name) BETWEEN 1 AND 240 AND
         sender_display_name !~ E'[\\r\\n]')
      );
  END IF;
END $$;
