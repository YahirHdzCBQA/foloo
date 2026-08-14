# Event Leads and Export Specification

## Purpose

Provide an event-level operational view of captured leads and a portable export that opens correctly in Spanish Excel.

## Related Requirements

- RF-22
- RF-23
- RF-31
- Acceptance criterion 9

## User Behavior

The user views the event's records, their count, and each record's status, then exports and shares the event data as CSV.

## Business Rules

- The CSV is encoded as UTF-8 with BOM so Spanish Excel displays accented characters correctly.
- The list is scoped to the event.
- Synchronization status is visible per record. Email statuses are required to be visible to marketing; whether that visibility is in this mobile list or another surface is unspecified.

## Data Requirements

Event identifier/name, lead rows, total count, synchronization status, and both email statuses. The requirements do not explicitly define CSV columns or whether they exactly match the Section 5 spreadsheet order.

## States

Synchronization includes the required visible `pendiente` state. Email states are `enviado`, `en cola`, and `fallido`.

## Validation

Export bytes must begin with a UTF-8 BOM and preserve accents. No XLSX artifact is required; V1 explicitly names CSV for export.

## Failure / Degraded Behavior

The event list and export must remain useful offline from locally available records. Share-sheet behavior and export failure messaging are unspecified.

## Acceptance Criteria

- The list shows all locally known event records, count, and per-record status.
- The exported CSV opens in Spanish Excel with correct accents (global criterion 9).
- Email state is visible to marketing as required by RF-31, on a surface to be resolved.

## Out of Scope

Metrics dashboards, analytics by event/salesperson, and direct CRM export.
