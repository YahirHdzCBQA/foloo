# Foloo

Foloo V1 is one mobile, offline-first product for capturing and following up
commercial leads at events or direct encounters. The repository contains its
current Specification-Driven Development foundation, a Flutter application
under `app/`, and the AWS backend under `backend/`.

## One product version

The former Basic/Pro split was superseded on 2026-09-07. Every V1 account has
the same functional capabilities. Commercial access is volume-based: five
historical lead captures are free; a PRO administrative entitlement permits
unlimited capture in the initial release. Public payments are deferred to
FL-022. No entitlement state deletes or hides existing data.

The old edition documents were removed after consolidation. Git history remains
the audit source; they must not be recreated as current requirements.

## SDD map

- `docs/product/`: unified V1 authority, scenarios and open decisions.
- `docs/architecture/`: current mobile boundaries and future cloud direction.
- `docs/decisions/`: accepted ADRs and explicitly labeled proposals.
- `docs/delivery/`: the sole roadmap and consolidated traceability/audit.
- `backend/`: Node.js/TypeScript API, PostgreSQL migrations and AWS CDK IaC for
  sync, private media/Content and Google/Microsoft follow-up.

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

## Where to work

- [Development and local validation](app/README.md) · [Backend and deployment](backend/README.md)
- [Store roadmap and gates](docs/delivery/roadmap.md#gates-de-publicación-de-tiendas) · [iOS/TestFlight](docs/delivery/ios-testflight-distribution.md) · [Android private distribution](docs/delivery/android-private-distribution.md)
- [Account deletion contract](docs/delivery/account-deletion-contract.md) · [Operations and restore](docs/delivery/account-deletion-operations.md) · [DEV evidence](docs/delivery/store-02-account-deletion-closure.md)
- [Private PRO operations](docs/delivery/fl021-administrative-entitlement-operations.md) · [PROD readiness](docs/delivery/prod-environment-readiness.md) · [Privacy](docs/delivery/privacy-compliance.md)
