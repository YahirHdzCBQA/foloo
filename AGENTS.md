# Foloo Agent Instructions

Foloo follows Specification-Driven Development (SDD). The current product is
the single, unified Foloo V1 defined in `docs/product/`. There
are no Basic/Pro editions, feature gates, upgrade paths or plan selector in the
current product model. Existing edition code is implementation evidence only.
Removed historical documents remain available through Git history.

## Authority and Reading Order

1. `docs/product/product-spec.md` defines principles, scope and requirements.
2. `docs/product/acceptance-scenarios.md` defines acceptance behavior.
3. `docs/product/open-decisions.md` blocks only the branches named there.
4. `docs/delivery/traceability.md` connects requirements to evidence/FLs.
5. `docs/delivery/roadmap.md` is the only current implementation roadmap.
6. Accepted ADRs govern technology without overriding product scope.

The validated 2026-09-07 MVP scope is the primary source for this package. The
2026-09-08 operational workbook is a later update where it explicitly changes
that scope; notably, XLSX/CSV export re-enters V1 and Google Sheets remains
backlog. Contradictions without a dated resolution stay open.

### Required reading for any change

Read, in order:

1. `docs/product/product-spec.md`
2. the relevant scenarios in `docs/product/acceptance-scenarios.md`
3. `docs/product/open-decisions.md`
4. `docs/architecture/overview.md` and relevant domain/ADR material
5. `docs/delivery/traceability.md` and `docs/delivery/roadmap.md`

No historical SDD is kept in the operational documentation tree. Git history
is the audit source for removed Basic/Pro documents; never reconstruct them as
current requirements.

## Implementation Rules

1. Do not implement behavior without a current `AUT-*`, `EVT-*`, `CAP-*`,
   `OCR-*`, `VOZ-*`, `SYN-*`, `REG-*`, `NAV-*`, `SAL-*`, `CON-*`,
   `PLT-*`, `MON-*`, `INF-*`, `RNF-*`, `RC-*` or `REL-*` trace plus
   acceptance coverage.
2. A blocking open decision stops only its affected branch. Never turn a
   proposal, workbook placeholder or existing demo into an approved rule.
3. What is not specified is asked. Never invent fields, defaults, limits,
   providers, lifecycle behavior, payment policy, copy or UX.
4. Preserve the Constitution: local save before network, no lost/hidden leads,
   offline as normal, no client secrets, one-handed ergonomics and accessible
   state communication.
5. Every V1 user receives the same product capabilities. Do not add edition or
   subscription capability gating. Subscription may block only creation of a
   new lead after the five-lead trial; existing data stays accessible.
6. Automatic/AI transcription and Google Sheets are backlog, not V1. Voice
   recording/playback and XLSX/CSV export per event are V1.
7. Do not select a cloud database, email provider or store-payment strategy
   without the corresponding accepted decision/ADR.
8. Do not add a dependency without citing current requirement IDs and why the
   platform or existing dependencies are insufficient.
9. Every task, test, commit and implementation report cites current IDs.
   Historical Basic/Pro or `RF-*` mappings may appear only as migration context.

## Code Documentation Standard

Every new hand-maintained file under `app/lib/` must keep documentation useful
without narrating self-explanatory code:

1. Start with a brief 2–6 line English header explaining purpose, ownership and
   relevant flow context; a short Spanish summary is optional.
2. Add DartDoc to important screens, services, models, state holders and shared
   components, including the boundary they own.
3. Use section comments only to make complex blocks easier to navigate.
4. Explain non-obvious intent, restrictions and risks rather than restating the
   implementation.
5. Mark genuine temporary behavior consistently with `DEMO:` and approved
   future work with a specific `TODO(PRODUCTION):`; do not invent TODOs.
6. Cite current SDD IDs only for critical rules or decisions that would
   otherwise appear arbitrary.
7. Never comment imports, trivial getters/setters, `build`, `setState`, returns,
   padding, colors or simple widget composition. Generated files are excluded.

## Change Reporting

Report current specifications/scenarios read, current IDs affected, open
decisions and ADRs followed, acceptance criteria verified, source conflicts,
implementation evidence used and intentionally deferred behavior.
