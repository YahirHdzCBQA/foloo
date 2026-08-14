# Event Settings Specification

## Purpose

Capture reusable event context once per event rather than asking for it on every lead.

## Related Requirements

- RF-11
- RF-33
- RF-34

## User Behavior

The user configures event name, capture-person identity, marketing email, and data destination. Values remain available after closing and reopening the app.

## Business Rules

- Settings are configured once per event, not per lead.
- Event and capture-person values are attached automatically to each lead.
- The requirements identify Google Sheets as the V1 spreadsheet output; the meaning and allowed values of the configurable `destino de datos` remain open.

## Data Requirements

`evento`, `capturadoPor`, marketing email, and data destination. Requiredness and validation for the last two settings are not explicitly defined.

## States

**Proposed implementation states:** unconfigured and configured. These are implementation aids, not business requirements.

## Validation

Every saved lead requires non-empty `evento` and `capturadoPor` values inherited from settings. No additional setting-field validation is specified.

## Failure / Degraded Behavior

Settings persistence must not depend on connectivity. Behavior when settings are missing is an open implementation question.

## Acceptance Criteria

- Event settings expose all four RF-33 values.
- Closing and reopening the app preserves them (RF-34).
- A lead records event, capture person, and date/time without per-lead entry (RF-11).

## Out of Scope

User accounts, roles, and per-user authentication.
