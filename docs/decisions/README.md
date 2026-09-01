# Architecture Decision Records

ADRs record consequential technical or architectural choices only after they
are intentionally made. Current product scope lives in
`../specifications/current/`; an ADR explains how an approved constraint will
be implemented and cites current requirement IDs.

The authoritative unresolved decisions are:

- Basic/shared: `../specifications/current/03-decisiones-abiertas.md`
- Pro delta: `../specifications/current/07-decisiones-abiertas-pro.md`

`open-questions.md` is a routing summary only. Recommendations and documented
assumptions in the source decision files are not approvals.

## Naming

Use sequential names such as:

- `ADR-001-short-decision-name.md`
- `ADR-002-short-decision-name.md`

## Required Sections

Each ADR includes:

- **Status:** Proposed, Accepted, Superseded, or Rejected.
- **Context:** requirement IDs, constraints, and problem.
- **Decision:** the approved choice; empty while merely exploring.
- **Alternatives Considered:** credible options and evaluation criteria.
- **Consequences:** benefits, costs, risks, and follow-up work.

Do not silently turn an open question into an ADR decision. Provider,
state-management, backend-framework, and cloud choices remain unresolved until
an ADR is reviewed and accepted.

## Accepted

- [`ADR-001-persistencia-local-drift-sqlite.md`](ADR-001-persistencia-local-drift-sqlite.md)
  — Drift/SQLite for structured local data and private filesystem storage for
  binary media (FL-012).
- [`ADR-002-autenticacion-aws-cognito.md`](ADR-002-autenticacion-aws-cognito.md)
  — Cognito as the production provider behind AuthService; FL-013A uses only
  the replaceable development adapter until AWS DEV exists.
