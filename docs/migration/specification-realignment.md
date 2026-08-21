# Specification Realignment: Legacy v1 to Basic/Pro

## Purpose and precedence

This document records the August 2026 realignment without changing product
behavior. Authority now follows:

1. Constitution.
2. Complete Basic specification.
3. Pro delta over Basic.
4. Capability matrix for edition membership.
5. Basic/Pro acceptance scenarios.
6. Open decisions, which remain unresolved.

The original PDF and former `RF-*` specifications are historical inputs. The
existing Flutter implementation is audited evidence only.

## Before → now

### Added

| Area | Before | Now | Current trace |
|---|---|---|---|
| Authentication | Explicitly out of V1; demo gate only | Real login, persistent session, first-use profile and profile editing | `AUT-01`–`AUT-09` |
| Events | Four reusable settings values | Full event entity, active event, create/list/edit/logical delete and counts | `EVT-01`–`EVT-11` |
| Lead origin | Event only | Event or direct lead, persisted across captures | `CAP-01`–`CAP-04` |
| Lead type | Partner/customer | Adds `Proveedor`; selection is three large controls | `CAP-09`, `CAP-10` |
| Records | Event list/count/status | Event selector, live search, type filters, read-only detail and audio player | `REG-01`–`REG-08` |
| Export | CSV only | XLS default plus CSV, offline, share sheet | `REG-09`–`REG-12` |
| Appearance/navigation | Not a product requirement | Persistent light/dark theme and defined right drawer | `NAV-01`–`NAV-07` |
| Scale/design | General one-hand/accessibility guidance | Closed token system, 48 dp minimum, motion budget, WCAG 2.2 AA, 300 leads/event | Constitution; `RNF-04`, `RNF-05`, `RNF-08`–`RNF-13` |
| Pro content | Absent | PDF library, event assignment, local cache and frozen per-lead attachments | `CON-01`–`CON-16` |
| Pro templates | Configurable outside code | Two in-app/server templates with variables, validation and preview | `PLT-01`–`PLT-10` |
| Pro direct context | Absent | Required `lugar` for direct leads | `CAP-20` |
| Edition model | One V1 | One codebase, server-enabled Basic/Pro capabilities | `04-matriz`; `RNF-18` |

### Changed

| Area | Before | Now | Consequence |
|---|---|---|---|
| Product promise | Capture plus automatic same-day contact | Basic guarantees complete same-day sheet data; only Pro automates contact | Basic acceptance must contain no email behavior. |
| Lead model | Single `nombre`; two types; mandatory `siguientePaso`; email states | Separate `nombre`/`apellido`; three types; no Basic `siguientePaso`; sync state | Model and sheet contract require replacement, blocked in part by `D-02`/`D-03`. |
| Acknowledgement | Folio and multiple delivery/email statuses; return unclear | Basic confirms one truthful outcome and auto-returns in 3 s; Pro has four confirmations | Current confirmation is contradictory; exact Basic copy waits on `D-06`. |
| Event settings | Event/capture/admin/destination settings | Profile owns capture identity; event owns name/dates/active state; sheet topology remains open | Legacy read-only Evento screen is not the required workflow. |
| OCR contract | Included optional website and generic extraction | Structured six-field response including apellido; provider remains server-side | Local ML Kit is prototype evidence only. |
| Touch target | 44 px | Absolute 48 dp | Existing 44 px controls must be audited/adapted. |
| Platforms | iOS 15+/Android 10+ | Same baseline, now explicit with performance/scale requirements | Shared Flutter approach remains valid. |

### Removed from Basic

| Legacy capability | Current disposition |
|---|---|
| Mandatory `siguientePaso` (`RF-10`) | Not in the Basic model; decision confirmation remains `D-02`. |
| Automatic transcription (`RF-14`) | Forbidden in Basic by `VOZ-07`; Pro-only `TRA-*`. |
| Automatic lead/marketing emails (`RF-27`–`RF-32`) | Pro-only `SAL-05`–`SAL-10`, `SAL-13`–`SAL-15`. |
| Email delivery statuses in Basic | Not Basic fields or UI. |
| Marketing email setting in Basic app | No Basic email; Pro Copia Admin configuration is blocked by `DP-04`. |

### Moved to Pro

| Capability | Legacy | Pro |
|---|---|---|
| Mexican-Spanish transcription | `RF-14` | `TRA-01`–`TRA-08` |
| Two automatic emails and retry/status | `RF-27`–`RF-31` | `SAL-05`–`SAL-09`, `SAL-13`–`SAL-15` |
| Editable templates | `RF-32` | `SAL-10`, `PLT-01`–`PLT-10` |
| Digital privacy notice and opt-out | `RC-01`, `RC-02` via email | Pro `PLT-08`, `RC-01`, `RC-02`, `RC-10`, `RC-11` |

### Clarified

- Local-first means durable survival across app close and logout, not
  session-memory storage (`AUT-08`, `CAP-15`, `SYN-01`).
- Offline is a normal grey, icon-plus-text state, never a red error.
- Event deletion is logical and does not touch the spreadsheet or satisfy
  legal retention/deletion.
- The folio is both readable and the idempotency key, while concurrency remains
  explicitly blocked by `D-03`.
- Voice recording/playback belongs to both editions; transcription is a
  distinct Pro capability.
- Basic sheet output is the only operational exit and therefore has a fixed,
  complete column contract.
- Pro is not a separate app. Disabled capabilities disappear completely.

### Conflicts with current implementation/documentation

- Demo login, session clearing and in-memory leads contradict `AUT-01`,
  `AUT-02`, `AUT-08`, Article 2 and `SYN-01`.
- Local ML Kit/provider classification in Flutter contradicts the production
  server boundary of Article 3 and `OCR-03`/`OCR-04`.
- Two lead types and mandatory `siguientePaso` contradict current Basic.
- Confirmation and Evento surfaces expose email/admin concepts that Basic must
  not show.
- The sentence offering future transcription violates `VOZ-07` in Basic.
- Current Evento is read-only; Basic requires Mis eventos CRUD.
- Current visual tokens, typography, lime usage, touch sizes and copy do not
  satisfy the Constitution. See the gap analysis.

## Basic, shared and Pro-only boundary

### Basic nucleus

Authentication/profile; event CRUD; event/direct origin; four-step capture;
server OCR with manual fallback; three lead types and interest; local Voice
Note and written note; durable local-first queue; Basic sheet/file delivery;
records/search/filters/detail; XLS/CSV export; right drawer and persisted
appearance; Basic compliance requirements.

### Shared by Basic and Pro

All Basic behavior is inherited by Pro except the explicit modifications in
the delta: direct `lugar`, content/transcription additions to capture, Pro CTA,
four-line acknowledgement, extra menu destinations and appended columns.

### Exclusive Pro

`CON-*`, `PLT-*`, `TRA-*`, automated-email `SAL-*`, Pro acknowledgement/email
states, content attachments, direct-lead `lugar`, Pro compliance additions and
the Pro-only navigation destinations. None may appear in Basic, even disabled.

## Disposition of former specifications

All former files moved to `docs/legacy/v1-specifications/` and are superseded:

| Former document | Disposition/reason |
|---|---|
| `product-spec.md` | Replaced by Basic nucleus plus Pro delta; old scope promised emails/transcription and excluded auth. |
| `business-card-capture.spec.md` | Replaced by `OCR-*`; retained for legacy RF rationale. |
| `conversation-notes.spec.md` | Split into shared Basic voice (`VOZ-*`) and Pro transcription (`TRA-*`). |
| `lead-information.spec.md` | Replaced by current Lead model and `CAP-*`; catalogs changed. |
| `event-settings.spec.md` | Replaced by `AUT-*`, `EVT-*`, origin flows and `D-10`. |
| `local-persistence-and-sync.spec.md` | Replaced and expanded by `SYN-*`. |
| `event-leads-and-export.spec.md` | Replaced and expanded by `REG-*`, including XLS and detail. |
| `spreadsheet-and-file-delivery.spec.md` | Replaced by Basic `SAL-*` plus Pro delta. |
| `email-follow-up.spec.md` | Removed from Basic and moved conceptually to Pro `SAL-*`/`PLT-*`. |
| `privacy-and-compliance.spec.md` | Replaced by current edition-specific `RC-*`; Basic notice gap is explicit. |
| `traceability.md` | Replaced by the current-ID matrix. |
| prototype specs (`demo-access-shell`, `mockup-frontend-prototype`, temporary OCR, local voice) | Retained only as implementation history; none can override current product behavior. |

## Legacy open-question reconciliation

| Legacy issue | Current location/status |
|---|---|
| Destination/CRM (`OQ-A01`) | `D-07`, `D-10` |
| Website field (`OQ-A02`) | Website is absent from current OCR/Lead contract; historical issue superseded. |
| Opt-out/sync/retention fields (`OQ-A03`) | Current Basic Lead adds `estadoSync`; retention `D-11`; Pro owns opt-out. |
| Folio semantics (`OQ-A04`) | `D-03` blocking. |
| Email initial states/visibility (`OQ-A05`, `OQ-A06`) | Removed from Basic; defined in Pro `SAL-09`/detail, subject to Pro decisions. |
| Export columns (`OQ-A07`) | Basic export now XLS/CSV; exact sheet contract exists, but exported column selection is not independently stated. |
| Retention/access (`OQ-A08`, `OQ-A09`) | `D-11`, `RC-03`, `RC-04`; mechanisms still need ADRs. |
| Retry behavior (`OQ-A10`) | Expanded by `SYN-*`; backend/reconciliation still needs ADR. |
| Transcription equivalence (`OQ-A11`) | Pro `TRA-*`, `EP-05`; provider/test threshold still not selected. |
| Privacy notice (`OQ-A12`) | `D-14` blocking Basic; Pro legal footer. |
| Phone-only email (`OQ-A13`) | Not relevant to Basic email; Pro behavior remains insufficiently explicit. |
| Separate apellido (`OQ-A14`) | Resolved: current Basic model has `apellido`. |
| Solution-of-interest chips (`OQ-A15`) | Not Basic; Pro uses content files, not an inferred solution catalog. |
| Editable event configuration (`OQ-A16`) | Resolved structurally by `EVT-*`; current code remains outdated. |
| Auto-return (`OQ-A17`) | Resolved by `CAP-18`: visible 3-second return plus immediate action. |
| Audio format/limits/retention (`OQ-A18`) | Retention `D-11`; format/duration still not specified and require a new decision before production contract. |

## Newly detected package reconciliation issues

These are questions, not decisions:

1. Pro §2.3 says five Lead columns are appended but lists six changes
   (`lugar`, `transcripcion`, `adjuntos`, `estadoTranscripcion`, and two email
   states). Confirm the exact Pro sheet-column contract.
2. Constitution Article 7 forbids destructive actions in the lower third,
   while `AUT-07` says logout lives at the bottom of the drawer. Design must
   clarify a composition that satisfies both; Constitution wins meanwhile.
3. `05-especificacion-pro.md` says Pro adds acceptance criteria after the 12
   Basic criteria, but Basic §10 enumerates 13. Confirm numbering only; do not
   drop a Basic criterion.
4. `D-01` remains labelled blocking while the capability matrix definitively
   excludes transcription from Basic and includes it in Pro. The edition
   boundary is clear, but the stated Marketing approval remains open.
5. The official mockup HTML and `_ds/foloo-design-system/` cited by the package
   were not included in the supplied folder. Textual visual rules can be
   audited now; pixel-level mockup/token conformance cannot.

## Validation record — 2026-08-21

- All eight official numbered Markdown documents were read completely and
  copied byte-for-byte; SHA-1 values match the supplied sources.
- Basic is documented as the complete nucleus and Pro only as its delta.
- The capability matrix is the sole commercial-boundary authority.
- Recommendations and assumptions remain labelled as such; no ADR or product
  decision was silently approved.
- Blocking `D-*`/`DP-*` decisions remain open and are indexed in
  `docs/decisions/open-questions.md`.
- Former specifications are preserved under `docs/legacy/` and clearly marked
  superseded.
- `AGENTS.md`, repository README, architecture and traceability point to the
  current authority order.
- The current Flutter source, tests, native configuration and dependency files
  are byte-identical to the pre-realignment snapshot.
- Gap analysis and a blocker-aware migration plan exist; no migration phase was
  started.
