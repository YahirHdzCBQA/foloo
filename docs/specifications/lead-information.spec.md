# Lead Information and Classification Specification

## Purpose

Define the editable lead identity, classification, automatic metadata, validation, and readable folio needed before a record can be completed.

## Related Requirements

- RF-03
- RF-05
- RF-08
- RF-09
- RF-10
- RF-11
- RF-12
- RNF-04
- RNF-05
- Acceptance criterion 2

## User Behavior

The user reviews/corrects card fields, chooses one lead type, confirms interest, and chooses the next step. Event, capture person, timestamp, and folio are automatic.

## Business Rules

- Type is exactly `Partner` or `Cliente potencial` and is selected with two large controls, not a dropdown.
- Interest is `Alto`, `Medio`, or `Bajo`, defaulting to `Medio`.
- Next step is `enviar información`, `agendar llamada`, `cotizar`, or `solo seguimiento`.
- Folio format is `EXP-YYMMDD-NNN`, illustrated by `EXP-260812-001`; the event-code derivation, sequence reset, and concurrency rules are not defined.
- Primary controls have a minimum 44 px touch area and the primary action is fixed near the bottom.
- Fields have labels, keyboard focus is visible, and reduced-motion preference is respected.

## Data Requirements

See `../architecture/domain-model.md` for the complete conceptual record.

## States

No business lifecycle states are defined for classification. **Proposed:** incomplete and valid-for-save.

## Validation

- `nombre` and `empresa` are required.
- At least one of `correo` and `telefono` is required.
- If present, `correo` must have valid email format before sending.
- `tipo`, `interes`, and `siguientePaso` are required; interest initially equals `Medio`.

## Failure / Degraded Behavior

Invalid input must not be silently sent. Exact validation messages and timing are not specified. Existing local lead data must remain intact.

## Acceptance Criteria

- A user can complete classification with the specified values and controls.
- Automatic metadata requires no per-lead typing.
- Validation enforces the Section 5 rules.
- The complete app-to-acknowledgement flow takes under 60 seconds on a real phone (global criterion 2).

## Out of Scope

CRM-specific classification values until the future destination question is resolved.
