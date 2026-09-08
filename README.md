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

The old edition documents were removed after consolidation. Git history remains
the audit source; they must not be recreated as current requirements.

## SDD map

- `docs/product/`: unified V1 authority, scenarios and open decisions.
- `docs/architecture/`: current mobile boundaries and future cloud direction.
- `docs/decisions/`: accepted ADRs only.
- `docs/delivery/`: the sole roadmap and consolidated traceability/audit.

## Reading order

1. `docs/product/product-spec.md`
2. `docs/product/acceptance-scenarios.md`
3. `docs/product/open-decisions.md`
4. Architecture and accepted ADRs
5. `docs/delivery/traceability.md` and the single
   `docs/delivery/roadmap.md`
6. `AGENTS.md` before proposing or implementing changes

The 2026-09-08 operational workbook explicitly updates the 2026-09-07 scope by
restoring per-event XLSX/CSV export. No workbook status is accepted as code
completion without repository evidence.
