-- FL-016 adds explicit S3 confirmation state without rewriting FL-014 history.

ALTER TABLE lead_media
  ADD COLUMN upload_status text NOT NULL DEFAULT 'pending'
    CHECK (upload_status IN ('pending', 'available')),
  ADD COLUMN uploaded_at timestamptz;

ALTER TABLE lead_media
  ADD CONSTRAINT lead_media_available_object_check CHECK (
    (upload_status = 'pending') OR
    (upload_status = 'available' AND storage_object_key IS NOT NULL AND uploaded_at IS NOT NULL)
  );

CREATE INDEX lead_media_workspace_upload_status_idx
  ON lead_media (workspace_id, upload_status) WHERE deleted_at IS NULL;
