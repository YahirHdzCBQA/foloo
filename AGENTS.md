# Foloo Agent Instructions

Foloo follows Specification-Driven Development (SDD).

The business requirements in `docs/requirements/` are the source of truth for V1 product scope. Stable RF, RNF, and RC identifiers must be preserved across specifications, architecture, tests, tasks, commits, and implementation reports.

Before implementing or materially changing functionality:

1. Read the original business requirements.
2. Read the relevant files in `docs/specifications/`.
3. Review `docs/architecture/` for boundaries and the conceptual model.
4. Review `docs/decisions/`, including open questions and accepted ADRs.
5. Identify and report every affected RF, RNF, RC, and approved architecture decision.

## Implementation Rules

1. Do not implement code unless the corresponding behavior is specified.
2. Every behavior must trace to an RF/RNF/RC or an approved architecture decision.
3. Do not add functionality that is outside V1, including backlog items.
4. Do not invent business rules, catalogs, defaults, validation, lifecycle behavior, or UX.
5. When requirements are ambiguous or contradictory, document the question in `docs/decisions/open-questions.md`; do not decide silently.
6. Lead preservation takes priority over secondary integrations. Persist locally before network delivery, and never discard a lead because extraction, transcription, Sheets, files, or email failed.
7. Flutter must never contain API keys, spreadsheet credentials, or external-service secrets. Provider calls belong behind the Foloo backend boundary.
8. Preserve required offline behavior and manual fallbacks.
9. Design primary mobile interactions for one-handed use and comply with RNF-04/RNF-05.
10. Do not add a dependency without stating which specification and requirement IDs require it and why the existing platform is insufficient.
11. Do not select state management, local storage, backend/cloud frameworks, or service providers without an accepted ADR when the choice is consequential.
12. Keep proposed implementation details visibly labeled **Proposed** until approved; do not present them as **Required**.

## Change Reporting

Future implementation changes must report:

- specifications read;
- RF/RNF/RC identifiers satisfied or affected;
- accepted ADRs followed;
- acceptance criteria verified;
- unresolved questions or intentionally deferred behavior.

If requested behavior has no specification, stop implementation and first update/clarify the specification without inventing product scope.
