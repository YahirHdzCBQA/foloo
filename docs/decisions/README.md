# Architecture Decision Records

ADRs record consequential technical or architectural choices only after they are intentionally made. Business requirements remain the source of product scope; an ADR explains how an approved constraint will be implemented and must cite the affected RF/RNF/RC IDs.

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

Do not silently turn an open question into an ADR decision. Provider, state-management, database, backend-framework, and cloud choices remain unresolved until an ADR is reviewed and accepted.
