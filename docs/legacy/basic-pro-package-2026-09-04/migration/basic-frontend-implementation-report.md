# Basic Frontend Implementation Report

Date: 2026-08-21

## Authority reviewed

- `AGENTS.md` and the original requirements under `docs/requirements/`.
- Current Constitution and Basic specification:
  `docs/specifications/current/00-constitucion.md`,
  `01-especificacion.md`, `02-escenarios.md`, `03-decisiones-abiertas.md`,
  `04-matriz-de-capacidades.md`, `05-especificacion-pro.md`,
  `06-escenarios-pro.md`, and `07-decisiones-abiertas-pro.md`.
- `docs/architecture/`, `docs/decisions/`, and `docs/migration/`.
- Official visual source `Foloo Mockups Basic.html`, including its light/dark
  token definitions and embedded component states.

The specification remains authoritative for behavior. The HTML is authoritative
for composition and appearance where it does not conflict with Basic.

## Traceability

The implementation affects or provides frontend evidence for:

- Authentication/profile: `AUT-01`–`AUT-08` (demo/local shell only).
- Events and origin: `EVT-01`–`EVT-11`.
- Capture/OCR: `CAP-01`–`CAP-15`, `OCR-01`–`OCR-07`.
- Voice note: `VOZ-01`–`VOZ-07`.
- Records and synchronization presentation: `REG-01`–`REG-12`, `SYN-01`–`SYN-08`.
- Navigation: `NAV-01`–`NAV-07`.
- Mobile usability and accessibility: `RNF-01`, `RNF-03`–`RNF-06`,
  `RNF-09`–`RNF-13`.
- Compliance boundaries affected by local media: `RC-03`–`RC-07`.

No accepted ADR selected a production backend, storage, OCR, audio or export
provider. Those boundaries remain unchanged. No new dependency was added.

## Acceptance evidence

- Login leads to first-use profile and then origin selection.
- Event and direct origins both lead to the same continuous four-section
  capture surface.
- Capture exposes exactly Proveedor, Partner and Cliente; it has no
  `siguientePaso`, transcription, content, templates or email UI.
- A saved lead appears in session Registros and opens in a read-only detail.
- A recorded local Voice Note can be controlled from Registros and detail.
- Drawer navigation covers Home, Registros and Mis eventos; appearance is
  shared and logout returns to Login.
- The fixed 56 dp primary actions and scrollable content preserve access on
  compact screens and with the keyboard visible.
- Status is conveyed with text/icon as well as color. Interest uses the exact
  bright semaphore from the mockup; pending upload uses mockup gray, not a dark
  semantic variant.

## Basic-only cleanup

Removed legacy Basic exposure of `siguientePaso`, email-processing rows and
transcription hints. The UI does not expose disabled Pro placeholders or
capability flags. Export and synchronization controls are visual demos only.

The existing ML Kit reader remains isolated as an explicitly demo-only local
prototype. Production extraction still belongs behind the Foloo backend under
`OCR-03`/`OCR-04`.

## Visual fidelity

| Surface | Status | Difference or blocker |
|---|---|---|
| Login | MINOR DIFFERENCE | Platform sans is used because brand font files are not an approved Flutter asset. |
| First-use profile | MINOR DIFFERENCE | Profile photo selection is a visual demo only. |
| Initial/subsequent origin | MINOR DIFFERENCE | Event data and dates are centralized demo data. |
| Capture | MINOR DIFFERENCE | Basic specification overrides legacy embedded capture fragments: three types, no next step and CTA `Guardar`. |
| Confirmation | BLOCKED BY OPEN DECISION | Exact final copy remains subject to `D-06`; the screen shows the single truthful Basic processing line as demo. |
| Drawer | MINOR DIFFERENCE | Logout placement follows the supplied HTML while `RQ-02` remains documented. |
| Registros/export/detail | MINOR DIFFERENCE | Records are session-only; export and synchronization do not produce external effects. |
| Mis eventos/create/edit | MINOR DIFFERENCE | CRUD is local demo state and date controls use fixed demo dates. |
| Dark appearance | MINOR DIFFERENCE | Tokens follow HTML, but typography remains blocked by `D-12` and missing approved font binaries. |

No surface is classified as a pixel-exact match because the approved brand
font assets are unavailable to Flutter. Logos reuse the existing PNG assets.

## Open decisions and intentional deferrals

- `D-03`: production folio format; current folios are visibly demo data.
- `D-01`: no transcription in Basic; the Basic/Pro matrix remains the working boundary.
- `D-02`: `siguientePaso` remains absent from the Basic model and UI.
- `D-04`: connection detail remains read-only.
- `D-05`: production backend ownership and hosting.
- `D-06`: final Basic acknowledgement copy.
- `D-09`: production account provisioning and recovery.
- `D-10`: final spreadsheet topology.
- `D-11` and `RC-03`: retention and deletion policy for local lead/media data.
- `D-12`: approved typography assets.
- `D-14`: privacy notice treatment.
- `RQ-02`: final drawer/logout interpretation.

Durable persistence, real authentication, backend OCR, Sheets, real sync,
generated exports, email, Pro capabilities, transcription and production media
retention are intentionally deferred.

## Validation

Executed from `app/` on 2026-08-21 without starting a simulator, emulator or
physical device:

- `flutter pub get`: completed (`Got dependencies!`).
- `flutter analyze`: completed with `No issues found!`.
- `flutter test`: 35 tests passed.
- `git diff --check`: completed without whitespace errors.
