# Foloo

Foloo is a planned mobile application for capturing and following up business leads during in-person events. It is intended to prevent physical cards from being lost or processed late by supporting fast, offline-first capture and same-day follow-up.

## Current Status

Foloo is in the Specification-Driven Development (SDD) foundation stage. The application and backend have not been implemented, and no Flutter project exists yet. The agreed product target is one Flutter codebase for iOS and Android, subject to the documented requirements and future architecture decisions.

## Specification-Driven Development

The business requirements are the source of truth for V1 scope. Stable `RF`, `RNF`, and `RC` identifiers connect requirements to specifications, architecture, future tests, tasks, and commits. Implementation must begin from a documented behavior and must not resolve ambiguity silently.

## Documentation Structure

- `docs/requirements/`: original, authoritative business requirements.
- `docs/specifications/`: product/domain behavior, acceptance criteria, and traceability.
- `docs/architecture/`: conceptual model and high-level responsibility boundaries.
- `docs/decisions/`: open questions and the process for future ADRs.

## Start Here

1. Read `docs/requirements/foloo-business-requirements-v1.pdf`.
2. Read `docs/specifications/product-spec.md`.
3. Use `docs/specifications/traceability.md` to find the relevant domain specification.
4. Review `docs/architecture/overview.md` and `docs/architecture/domain-model.md`.
5. Check `docs/decisions/open-questions.md` before making assumptions.
6. Follow `AGENTS.md` before proposing or implementing any change.

There are currently no build, run, or Flutter setup instructions because no application code has been created.
