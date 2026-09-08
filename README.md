# Foloo

Foloo V1 is one mobile, offline-first product for capturing and following up
commercial leads at events or direct encounters. The repository contains its
current Specification-Driven Development foundation and a Flutter application
under `app/`.

## One product version

The former Basic/Pro split was superseded on 2026-09-07. Every V1 account has
the same functional capabilities. Commercial access is volume-based: five
saved leads are free; attempting to save the sixth requires an annual
subscription. Lack of payment never deletes or hides existing data.

The old edition documents and implementation artifacts remain under
`docs/legacy/` for auditability only. They must not drive new work.

## SDD map

- `docs/specifications/current/`: unified V1 authority and acceptance criteria.
- `docs/specifications/traceability.md`: IDs to scenarios, evidence and work.
- `docs/architecture/`: current mobile boundaries and future cloud direction.
- `docs/decisions/`: accepted ADRs and unresolved construction decisions.
- `docs/migration/`: source reconciliation, 65-item audit and V1 roadmap.
- `docs/requirements/`: register of product inputs.
- `docs/legacy/`: superseded Basic/Pro and earlier specifications.

## Reading order

1. `docs/specifications/current/00-constitucion.md`
2. `01-especificacion.md`
3. `02-escenarios-de-aceptacion.md`
4. `04-matriz-de-capacidades.md`
5. `03-decisiones-abiertas.md`
6. Current traceability, architecture, ADRs and implementation plan
7. `AGENTS.md` before proposing or implementing changes

The 2026-09-08 operational workbook explicitly updates the 2026-09-07 scope by
restoring per-event XLSX/CSV export. No workbook status is accepted as code
completion without repository evidence.
