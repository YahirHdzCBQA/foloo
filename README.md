# Foloo

Foloo is a mobile, offline-first lead-capture product for commercial teams
working at events. The repository contains the current Specification-Driven
Development foundation and an existing Flutter prototype under `app/`.

## Product editions

- **Foloo Basic** is the complete capture nucleus defined in
  `docs/specifications/current/01-especificacion.md`.
- **Foloo Pro = Basic + delta** from
  `docs/specifications/current/05-especificacion-pro.md`.
- `docs/specifications/current/04-matriz-de-capacidades.md` is the sole source
  of truth for which edition owns each capability.

The Flutter prototype predates this realignment. It demonstrates portions of
capture, local OCR, Voice Note, confirmation, navigation and session records,
but is not yet an implementation of current Basic or Pro. See the gap analysis
before using existing code as a starting point.

## SDD map

- `docs/specifications/current/`: current official Basic/Pro package.
- `docs/architecture/`: current conceptual boundaries and data model.
- `docs/decisions/`: ADR process and routing to unresolved decisions.
- `docs/migration/`: old-to-current comparison, implementation gaps and the
  recommended migration sequence.
- `docs/requirements/`: original historical business requirements.
- `docs/legacy/`: superseded specifications and decisions, retained only for
  traceability.

## Reading order

1. `00-constitucion.md`
2. `01-especificacion.md` and `02-escenarios-de-aceptacion.md`
3. `03-decisiones-abiertas.md`
4. For Pro or shared scope: `04`, `05`, `06` and `07` in order
5. Current architecture, traceability and migration documents
6. `AGENTS.md` before proposing or implementing changes

Do not treat recommendations as decisions, or the current Flutter behavior as
product authority.

## Flutter prototype

The app is located in `app/`. Its current capabilities and known conflicts are
documented in `docs/migration/current-implementation-gap-analysis.md`; its
local run instructions remain in `app/README.md`.
