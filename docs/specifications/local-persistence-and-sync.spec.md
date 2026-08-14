# Local Persistence and Offline Synchronization Specification

## Purpose

Guarantee that saving a lead does not depend on network availability and that later delivery is observable, retryable, and idempotent.

## Related Requirements

- RF-18
- RF-19
- RF-20
- RF-21
- RNF-02
- RNF-07
- Acceptance criterion 3

## User Behavior

When the user submits, Foloo saves on the device before attempting network delivery. Offline records visibly show as pending. Synchronization retries automatically after connectivity returns and can also be triggered manually.

## Business Rules

- Local persistence precedes every network attempt.
- The folio is the idempotency key; resending the same folio must not create a second spreadsheet row.
- Offline operation includes the complete flow except automatic card extraction and transcription, which have manual fallbacks.
- Network delivery uses HTTPS.

## Data Requirements

The full lead record, folio, visible synchronization condition, and sufficient locally retained media/references to complete later upload. Exact local storage schema is intentionally undecided.

## States

`pendiente` is explicitly required when offline. Other lifecycle states are not specified. **Proposed implementation states:** local, pending, syncing, synced, failed. Names and transition details require an architecture decision/specification refinement.

## Validation

A local save must be confirmed before delivery begins. The backend must treat repeated submissions with the same folio idempotently.

## Failure / Degraded Behavior

Connectivity and remote-service failures retain the local lead and expose a retry path. Automatic retry resumes after network recovery; manual retry is always available.

## Acceptance Criteria

- In airplane mode, submission saves locally and appears pending.
- Restoring connectivity uploads it automatically, without user intervention or duplication (global criterion 3).
- Repeated delivery of one folio creates at most one destination row.

## Out of Scope

Selecting a local database, sync library, conflict-resolution framework, or backend framework.
