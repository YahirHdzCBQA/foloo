# Mockup-aligned Frontend Prototype Specification

## Status and Visual Source

This specification records the user-approved frontend-only implementation of
the six views in `Mockups aplicación móvil Foloo.pdf`: Login, Home/Captura,
Confirmación, Menú lateral, Registros, and Evento.

The business requirements remain authoritative for behavior. The PDF is
authoritative for composition, spacing, visual hierarchy, and styling. This
prototype does not claim production persistence, synchronization, Sheets,
email, OCR, audio, transcription, or authentication.

## Related Requirements

- RF-01, RF-03, RF-05: card acquisition and editable lead fields.
- RF-08, RF-09, RF-10: type, interest, and next-step controls.
- RF-11, RF-12: automatic event metadata and readable folio presentation.
- RF-13, RF-17: audio-control concept and written fallback.
- RF-18 through RF-22: local-first acknowledgement, pending state, manual sync
  affordance, folio identity, and event record list.
- RF-23: CSV export affordance. Export generation remains deferred in this
  frontend prototype.
- RF-31: processing-state presentation. All displayed processing states in the
  confirmation view are explicitly demo-only.
- RF-33, RF-34: event settings context. The mockup's read-only Evento view does
  not fulfill the required editable and persistent settings workflow.
- RNF-02 through RNF-06: offline/manual degradation, shared Flutter codebase,
  one-hand ergonomics, accessibility, and server-held secrets.

No RC behavior is changed or implemented by this visual prototype.

## Approved Prototype Behavior

1. Home keeps the four capture sections in one vertical scroll view between a
   fixed progress header and fixed 56 px primary action.
2. The first and last-name controls are a presentation-only split. On save,
   both values are recombined into the existing conceptual `nombre` field.
   No `apellido` domain or Sheet column is introduced.
3. Audio recording, waveform, timer, and confirmation processing statuses are
   visual/local demonstrations only.
4. Saving appends a session-memory record before showing confirmation.
   Session memory is not RF-18 production persistence and is cleared on
   logout or process restart.
5. Registros lists only records saved in the current demo session. Every new
   record remains visibly `Por subir`; the sync and CSV controls do not perform
   remote synchronization or file export.
6. Evento presents centralized demo event/session information as read-only
   content and returns to Home.
7. Apariencia switches locally between light and dark themes without
   production persistence.

## Visual Rules

- Paper `#EFEDE3`, card `#FFFFFF`, ink `#1F1F1F`, and lime `#C9FA00`.
- Lime is reserved for the primary action, active selection, and brand detail.
- Interest and upload/processing states include text or icons in addition to
  color.
- Primary actions are fixed at the bottom and at least 56 px high; touch
  targets are at least 44 px.
- Existing supplied Foloo image assets are reused; logos are not recreated in
  text.

## Explicit Discrepancies and Deferrals

- `apellido` is not a separate V1 data-model field (OQ-A14).
- The mockup's `solución de interés` catalog is not specified and is omitted
  rather than converted into a business rule (OQ-A15).
- The read-only Evento mockup does not provide the editable settings required
  by RF-33/RF-34 (OQ-A16).
- Confirmation retains the explicit `Capturar otro ahora` action and does not
  auto-navigate until the three-second behavior is resolved (OQ-A17).
- Demo folio sequencing does not resolve OQ-A04.
- Demo upload/processing labels do not resolve OQ-A05, OQ-A06, or OQ-A10.

## Acceptance Criteria

- Login, capture, confirmation, drawer, records, and event views follow the
  supplied visual hierarchy at a 390×844 reference viewport.
- Drawer navigation opens Home, Registros, and Evento; tapping outside closes
  the drawer; logout returns to Login and clears session records.
- A valid captured lead appears in Registros during the same session.
- Evento contains no editable fields or save action and returns to capture.
- The capture form remains a single scrollable view and remains usable with
  the keyboard visible.
- No backend or persistence dependency is added.
