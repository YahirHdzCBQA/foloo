# Foloo Agent Instructions

Foloo follows Specification-Driven Development (SDD). The current product is
defined by the official Basic/Pro package in `docs/specifications/current/`.
The existing Flutter code and all material under `docs/legacy/` are evidence
and history, not product authority.

## Authority and Reading Order

1. `00-constitucion.md` contains non-negotiable product and design principles.
   An implementation that contradicts it is defective even if it works.
2. `01-especificacion.md` defines the complete Foloo Basic nucleus.
3. `05-especificacion-pro.md` is a delta. Foloo Pro is Basic plus that delta;
   it is never interpreted as a standalone specification.
4. `04-matriz-de-capacidades.md` is the sole authority for the commercial
   Basic/Pro boundary. A Pro-only capability must never leak into Basic.
5. `02-escenarios-de-aceptacion.md` defines Basic acceptance behavior; Pro
   adds and modifies it through `06-escenarios-pro.md`.
6. `03-decisiones-abiertas.md` and `07-decisiones-abiertas-pro.md` remain open
   until an approved ADR or product decision explicitly resolves them.

The historical PDF in `docs/requirements/` explains the original business
motivation. Where it conflicts with the current package, the current package
wins and the change is recorded in `docs/migration/specification-realignment.md`.

### Work on Basic

Read, in order:

1. `docs/specifications/current/00-constitucion.md`
2. `docs/specifications/current/01-especificacion.md`
3. `docs/specifications/current/02-escenarios-de-aceptacion.md`
4. `docs/specifications/current/03-decisiones-abiertas.md`
5. relevant current architecture and migration/gap documents

Consult `04-matriz-de-capacidades.md` when a scope boundary is in doubt. Do
not import `CON-*`, `PLT-*`, `TRA-*`, Pro email behavior, or any other
Pro-only capability into Basic.

### Work on Pro

Read the complete Basic sequence above, then:

1. `docs/specifications/current/04-matriz-de-capacidades.md`
2. `docs/specifications/current/05-especificacion-pro.md`
3. `docs/specifications/current/06-escenarios-pro.md`
4. `docs/specifications/current/07-decisiones-abiertas-pro.md`

Apply Pro only as a capability delta over Basic. Use one codebase, with the
account capability supplied by the server as required by `RNF-18`; do not
create a second app or branch.

### Work on Shared Functionality

Read the Basic sequence and `04-matriz-de-capacidades.md`. If the matrix marks
the capability with differences, also read the exact Pro delta and scenarios.
Verify both account behaviors and confirm that disabled capabilities are
absent rather than shown locked or disabled.

## Implementation Rules

1. Do not implement behavior without a current `AUT-*`, `EVT-*`, `CAP-*`,
   `OCR-*`, `VOZ-*`, `SYN-*`, `REG-*`, `NAV-*`, `SAL-*`, `CON-*`, `PLT-*`,
   `TRA-*`, `RNF-*`, or `RC-*` trace, plus applicable acceptance scenarios.
2. A blocking open decision stops implementation of the affected branch. A
   recommendation or documented assumption is not an approved decision.
3. What is not specified is asked. Never invent fields, catalogs, defaults,
   states, validation, lifecycle behavior, navigation, copy, or UX.
4. Existing code has no authority over the specification. Record conflicts;
   do not rewrite requirements to justify the implementation.
5. Preserve the Constitution: local save before network, no lost leads,
   offline as normal, no client credentials, one-handed ergonomics, accessible
   state communication, and the closed design system.
6. Basic does not send emails or expose transcription. Those capabilities are
   Pro-only according to `04-matriz-de-capacidades.md`.
7. Do not select providers, storage, state management, synchronization, or
   backend technologies without the relevant decision and accepted ADR.
8. Keep implementation proposals visibly labeled **Proposed** until approved.
9. Do not add a dependency without citing the current requirement IDs and why
   the platform or existing dependencies are insufficient.
10. Every task, test, commit, and implementation report cites current IDs.
    Legacy RF mappings may appear only as migration context.

## Change Reporting

Report:

- current specifications and scenarios read;
- Basic, Pro, or shared scope;
- current requirement IDs affected;
- capability-boundary checks;
- open/blocking decisions and accepted ADRs followed;
- acceptance criteria verified;
- legacy/code conflicts found and intentionally deferred behavior.

No accepted ADR currently overrides the official package. Historical
specifications are retained in `docs/legacy/` only for auditability.
