# Spreadsheet and File Delivery Specification

## Purpose

Deliver one idempotent row per lead to Google Sheets and store media as protected files referenced by links.

## Related Requirements

- RF-07
- RF-16
- RF-21
- RF-24
- RF-25
- RF-26
- RNF-06
- RNF-07
- RC-03
- RC-04
- Acceptance criteria 4, 6, and 10

## User Behavior

The user does not interact directly with Sheets or file providers during capture. Backend processing writes the row and media links after local submission/synchronization.

## Business Rules

- Google Sheets receives one row per lead with fixed headers in the Section 5 order.
- On first execution, the system should create the sheet and headers if absent (RF-25, `Debería`).
- Audio and card photos live in file storage; the sheet contains links, not embedded files.
- File access is restricted to marketing and sales; audio links require authenticated access and cannot be public-by-URL.
- Folio enforces row idempotency.
- File retention and deletion follow the period that Legal or Dirección must define.
- Sheets and file operations run on the server over HTTPS; credentials stay off the client.

## Data Requirements

The exact ordered fields are defined in `../architecture/domain-model.md`. Media storage needs the content, link, access policy, lead association, and retention metadata. Provider-specific schemas are undecided.

## States

No business states are defined for row or file delivery. **Proposed:** pending, delivered, failed, with retry metadata.

## Validation

The row preserves all Section 5 columns and accents. Links replace file blobs. The same folio cannot create a duplicate row.

## Failure / Degraded Behavior

Sheets or file-storage failure must not discard the locally saved lead. Retry behavior beyond general synchronization and email-specific retry is not fully specified and is an open architecture question.

## Acceptance Criteria

- A row appears in Google Sheets with every Section 5 column and correct accents (global criterion 4).
- Marketing's audio link plays for an authorized user (global criterion 6 and RC-04).
- Client binary inspection reveals no API keys or sheet credentials (global criterion 10).

## Out of Scope

Selecting storage, cloud, or spreadsheet libraries; CRM delivery; public media links.
