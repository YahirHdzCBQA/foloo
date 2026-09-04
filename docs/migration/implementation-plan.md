# Proposed Implementation Migration Plan

This is sequencing guidance, not authorization to implement and not a delivery
estimate. Each phase starts from current IDs and acceptance scenarios. Blocking
decisions must be resolved before the affected branch begins.

## Phase 0 — Resolve specification and architecture blockers

**Objective:** make the contracts implementable without silent assumptions.

- Resolve `D-02`, `D-03`, `D-05`, `D-06`, `D-14` and time-sensitive `D-11`,
  `D-12`.
- Clarify `RQ-01`–`RQ-08`, especially the Pro column count, export schema,
  phone-only Pro email and missing design-system/mockup assets.
- Create reviewed ADRs for authentication/session boundary, durable local
  persistence, synchronization/reconciliation, backend boundary, protected
  media access and capability delivery.
- **Affects:** nearly every current model and `FolooApp`; no code should infer
  answers from the prototype.

## Phase 1 — Establish the closed shared design system

**Objective:** implement Constitution tokens/components once before screen
adaptation.

- IDs: `RNF-04`, `RNF-05`, `RNF-08`, `RNF-09`, `RNF-13`, `NAV-05`.
- Deliver semantic color/type/spacing/radius/motion/focus/state components;
  48 dp controls; 56 dp dock; reduced motion; localization-ready copy.
- Dependencies: production font assets and license (`D-12`), missing `_ds`
  source (`RQ-08`), logout placement clarification (`RQ-02`).
- **Affects:** `foloo_theme.dart`, `brand_theme.dart`, headers, drawer, cards,
  controls and every visual test.

## Phase 2 — Build Basic domain and durable local foundation

**Objective:** ensure a lead can never be lost before adding remote behavior.

- IDs: Basic §3.2, `AUT-02`, `AUT-05`, `AUT-08`, `CAP-15`, `SYN-01`,
  `SYN-02`, `RNF-12`, Article 2.
- Introduce current Usuario/Evento/Lead/origin/sync concepts and durable local
  media references. Migrate or discard demo-only models intentionally.
- Dependencies: persistence ADR, `D-02`, `D-03`, `D-11`.
- **Affects:** `LeadDraft`, `SessionLead`, app-level state, local audio/photo
  lifecycle and most tests.

## Phase 3 — Align authentication, profile, origin and events

**Objective:** implement the beginning-of-day flow before per-lead capture.

- IDs/scenarios: `AUT-01`–`AUT-09`, `EVT-01`–`EVT-13`, `CAP-01`–`CAP-04`,
  `E-01`, `E-02`, `E-10`.
- `EVT-12` agrega la selección automática por fecha local, con prioridad de
  cualquier selección manual válida y reevaluación diaria de selecciones auto.
- `EVT-13` presenta Mis eventos en bloques activo/futuros/pasados con orden
  estable por fechas locales y sin duplicar el activo.
- Replace demo login, add first-use profile, session persistence, origin
  selection and Mis eventos CRUD/logical deletion.
- Dependencies: auth/backend and persistence ADRs, `D-03`, `D-09`, `D-10`,
  legal deletion boundary `RC-07`.
- **Affects:** `FolooApp`, login, drawer, hard-coded Evento and DemoEventData.

## Phase 4 — Align Basic capture and OCR boundary

**Objective:** conform the existing continuous flow without Pro leakage.

- IDs/scenarios: `OCR-01`–`OCR-09`, `CAP-05`–`CAP-14`, `CAP-16`, `E-03`,
  `E-04`, `E-06`.
- Keep single-scroll mechanics; add origin area; separate apellido in the
  model; replace two types with three; remove Basic `siguientePaso`; implement
  validation navigation and exact card states/copy.
- Move production extraction behind Foloo backend; keep manual fallback.
- Dependencies: `D-02`, `D-05`, design-system phase.
- **Affects:** lead capture, parser/service boundary, model and capture tests.

## Phase 5 — Make Basic Voice Note durable and compliant

**Objective:** retain the working recorder while satisfying offline survival.

- IDs/scenarios: `VOZ-01`–`VOZ-07`, `E-05`, `RC-03`, `RC-04`, `RC-06`.
- Remove every Basic transcription hint. Persist audio with the lead, show the
  required calm offline copy, preserve permission fallback and prepare secure
  asynchronous upload without making it required for save.
- Dependencies: persistence/media ADR, `D-11`, `RQ-07`, backend scope `D-05`.
- **Affects:** voice service/state, capture, records playback and cleanup rules.

## Phase 6 — Implement Basic sync, media and sheet delivery

**Objective:** complete the local-to-business path without duplicates.

- IDs/scenarios: `SYN-01`–`SYN-08`, `SAL-01`–`SAL-04`, `SAL-11`, `SAL-12`,
  `E-07`, `E-12`.
- Implement connectivity state, resumable queue, manual/automatic retry,
  idempotent backend acceptance, protected media and fixed Basic sheet rows.
- Dependencies: `D-03`, `D-05`, `D-10`, `D-11`, accepted backend/sync/media
  ADRs and Legal access/retention decisions.
- **Affects:** app state, records states, header, backend contracts and native
  lifecycle.

## Phase 7 — Complete Basic records, detail and export

**Objective:** make locally captured data operable without connectivity.

- IDs/scenarios: `REG-01`–`REG-12`, `E-08`, `E-09`, `RNF-12`.
- Add event selector, live search, four filters, filtered counts, read-only
  detail, local/remote audio playback, truthful empty state, XLS/CSV generation
  and system share.
- Dependencies: durable model; `D-04`; export contract `RQ-05`.
- **Affects:** RecordsScreen, new detail/export surfaces and list performance
  tests. Reuse current audio control/card foundations.

## Phase 8 — Align acknowledgement, navigation and appearance persistence

**Objective:** finish the Basic shell with truthful state and no Pro leakage.

- IDs/scenarios: `CAP-17`–`CAP-19`, `NAV-01`–`NAV-07`, `E-06`, `E-11`.
- Replace demo email rows with the approved Basic outcome; add visible
  three-second return and retained origin/event; persist appearance; replace
  Evento destination with Mis eventos and validate system back.
- Dependencies: `D-06`, sync truth model, `RQ-02`.
- **Affects:** confirmation, drawer, headers, app routing and lifecycle tests.

## Phase 9 — Basic compliance and end-to-end acceptance

**Objective:** prove all 13 Basic acceptance criteria on real iOS/Android.

- IDs: `RNF-01`–`RNF-13`, `RC-01`–`RC-07`; scenarios `E-01`–`E-13`.
- Validate <60 s capture, <5 s extraction behavior, airplane-mode recovery,
  300 leads/event, protected links, no credentials, both themes and exact
  absence of email/transcription UI.
- Dependencies: Legal resolution `D-14`, retention `D-11`, font license
  `D-12`, backend and devices.
- **Affects:** whole Basic product and release evidence.

## Phase 10 — Introduce and verify the capability boundary

**Objective:** prepare one codebase for Pro without exposing Pro to Basic.

- IDs/scenarios: `RNF-18`, `NAV-08`, `EP-10`, capability matrix.
- Read server capability/account plan, route modules by capability and test
  Basic absence plus upgrade/downgrade history.
- Dependencies: `DP-08` and auth/capability ADR.
- **Affects:** app shell, navigation, domain serialization and every edition
  acceptance test.

## Phase 11 — Pro email foundation before attachments

**Objective:** deliver the Pro contact promise with the smallest complete email
path, following the package recommendation to defer attachments.

- IDs: `SAL-05`–`SAL-10`, `SAL-13`, `SAL-14`, `PLT-*`, Pro `RC-01`/`RC-02`.
- Build provider-backed server templates, legal footer, two messages, retries,
  status and opt-out without content attachments first.
- Dependencies: blocking `DP-03`, `DP-04`, `DP-12`, sending account/volume
  `D-08`, provider/queue ADRs and `RQ-06`.
- **Affects:** new Pro template UI, backend and Pro detail/acknowledgement.

## Phase 12 — Pro content and attachments

**Objective:** add the PDF library, assignment and frozen attachment history.

- IDs/scenarios: `CON-01`–`CON-16`, `SYN-10`, `SYN-11`, `RNF-14`–`RNF-16`,
  `EP-01`–`EP-03`, `EP-08`, `EP-09`.
- `CAP-22`/`CAP-23`/`REG-13` agregan hasta tres imágenes locales de referencia
  por Lead Pro, una sesión continua de cámara y su consulta posterior, sin
  exponer el bloque en Basic.
- Dependencies: `DP-01`, `DP-02`, `DP-09`–`DP-11`, file/cache ADR and email
  foundation.
- **Affects:** five Pro-related surfaces/deltas, event create, capture step 03,
  sync and backend storage/email.

## Phase 13 — Pro transcription and final acknowledgement

**Objective:** add asynchronous server transcription and truthful four-line
Pro acknowledgement.

- IDs/scenarios: `TRA-01`–`TRA-07`, `CAP-20`, `CAP-21`, `EP-05`–`EP-07`.
- Do not implement `TRA-08` editing until `DP-06` resolves.
- Dependencies: `DP-05`, `DP-06`, `DP-07`, `D-06`, provider ADR, `RQ-01` and
  finalized Pro schema.
- **Affects:** direct flow, capture step 04, detail, sheet, Copia Admin and
  confirmation.

## Completion rule

A phase is not complete because screens exist. Its traced scenarios and
capability-boundary tests must pass, open blockers must be resolved explicitly,
and no prior Constitution guarantee may regress.
