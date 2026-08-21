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
state-management, database, backend-framework, and cloud choices remain
unresolved until an ADR is reviewed and accepted. No accepted ADR exists in
this repository at the time of the Basic/Pro realignment.
