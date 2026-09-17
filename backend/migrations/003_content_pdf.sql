-- FL-018: private PDF metadata and owner-scoped event assignments.
ALTER TABLE content_files
  ADD COLUMN file_name text NOT NULL DEFAULT 'document.pdf',
  ADD COLUMN all_events boolean NOT NULL DEFAULT false,
  ADD COLUMN event_ids uuid[] NOT NULL DEFAULT '{}',
  ADD COLUMN upload_status text NOT NULL DEFAULT 'pending'
    CHECK (upload_status IN ('pending', 'available')),
  ADD COLUMN uploaded_at timestamptz;

ALTER TABLE content_files
  ADD CONSTRAINT content_available_object_check CHECK (
    upload_status = 'pending' OR
    (storage_object_key IS NOT NULL AND uploaded_at IS NOT NULL)
  );

ALTER TABLE content_files
  ADD CONSTRAINT content_pdf_size_check CHECK (
    byte_size BETWEEN 1 AND 25000000
  );

CREATE INDEX content_files_workspace_active_idx
  ON content_files (workspace_id, created_at DESC);

-- Snapshot selected attachments on the Lead; later Content edits/deletes
-- must not rewrite what the seller selected at capture time (CON-08).
ALTER TABLE leads
  ADD COLUMN content_file_ids uuid[] NOT NULL DEFAULT '{}',
  ADD COLUMN content_names text[] NOT NULL DEFAULT '{}';
