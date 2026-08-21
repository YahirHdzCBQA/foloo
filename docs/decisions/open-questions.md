# Current Open-Decision Index

This file does not restate or resolve decisions. The full, authoritative text,
owners, assumptions and recommendations lives in the official package:

- Basic/shared: `../specifications/current/03-decisiones-abiertas.md`
- Pro delta: `../specifications/current/07-decisiones-abiertas-pro.md`

## Blocking Basic/shared decisions

| ID | Area blocked |
|---|---|
| `D-01` | Basic transcription boundary and related retention implications |
| `D-02` | Removal of `siguientePaso` and the Basic data/sheet model |
| `D-03` | Folio uniqueness/idempotency and acknowledgement |
| `D-04` | Post-save editing and read-only detail |
| `D-05` | Backend ownership of extraction, sheet and files |
| `D-06` | Exact acknowledgement content |
| `D-13` | Product success metric after email moved to Pro; no code blocked |
| `D-14` | Basic privacy-notice delivery (`RC-01`) |

## Non-blocking Basic/shared decisions

`D-07` destination/CRM alignment; `D-08` volume and sending account;
`D-09` user provisioning; `D-10` sheet topology; `D-11` media retention;
`D-12` font licensing.

## Blocking Pro decisions

| ID | Area blocked |
|---|---|
| `DP-01` | Content storage model, attachments and independent file queue |
| `DP-02` | Attachment limits and email delivery |
| `DP-03` | Template ownership and editor |
| `DP-04` | Copia Admin configuration |
| `DP-12` | Entire Pro email subsystem |
| `DP-05` | Transcription construction/rollout planning |

Pro also inherits applicable Basic/shared decisions. `DP-05` changes how
`D-01` applies to Pro; it does not authorize a provider choice.

## Non-blocking Pro decisions

`DP-06` transcription editing; `DP-07` offline acknowledgement;
`DP-08` capability delivery/downgrade; `DP-09` event/content editing;
`DP-10` content naming safeguards; `DP-11` cache limit and eviction.

## Historical questions

The former `OQ-A*` list is preserved at
`../legacy/decisions/open-questions-v1.md`. It is superseded. Several topics
now map to `D-*`/`DP-*`, but no equivalence should be assumed unless recorded
in the migration analysis.
