# Current High-Level Architecture

This document aligns conceptual responsibilities with the August 2026
Basic/Pro specification. Drift/SQLite is selected by ADR-001 and AWS Cognito is
selected as the production authentication provider by ADR-002. Other backend,
cloud and state-management choices remain undecided.

## Product shape

Foloo uses one Flutter codebase for iOS and Android (`RNF-03`, `RNF-18`). Basic
is the nucleus; Pro is a server-enabled capability delta. The account plan or
capabilities come from the server. A disabled capability is absent from the UI,
not locked, greyed out or advertised.

## Mobile application responsibilities

Shared Basic/Pro responsibilities include:

- authenticated session and locally retained profile/preferences;
- user-scoped local repositories keyed by the stable authentication identity;
- event/direct origin selection and event CRUD with logical deletion;
- date-based automatic event choice only when no valid manual choice exists;
- rear-camera/gallery capture, 1568 px client preparation and editable fields;
- one-screen, one-handed capture with local Voice Note and written fallback;
- durable local-first lead/media storage, visible queues and retry controls;
- records search/filter/detail, local audio playback and XLS/CSV export/share;
- automatic/manual synchronization without duplicate folios;
- accessible light/dark token remapping and 48 dp minimum controls.

The app must remain useful offline. Remote OCR degrades to manual capture; all
other Basic capture, local consultation and export remain available.

Pro additionally presents server-enabled content, template, attachment,
transcription and email states. It locally caches approved content, but does
not send mail or call providers itself. Pro may also retain up to three
contact-reference images as local Lead media; their future backend delivery
contract is not part of this decision.

## Foloo backend responsibilities

For Basic:

- authenticate and supply account/profile/capability context;
- perform structured card extraction;
- accept leads idempotently and reconcile synchronization;
- store card/audio media with authenticated access;
- create/write the correct spreadsheet destination and fixed Basic columns;
- enforce media access, encryption and approved retention.

For Pro, the backend additionally owns:

- content-library upload and server copies;
- server-side Mexican-Spanish transcription after audio upload;
- template storage/validation and variable substitution;
- email delivery, independent retries, status and opt-out enforcement;
- frozen attachment history and independent lead/file queues.

Basic performs no email or transcription. These are capability boundaries,
not merely unfinished integrations.

Authentication details and the FL-013A/FL-013B replacement boundary are in
[`authentication.md`](authentication.md).

## Conceptual data flow

1. The authenticated user selects event or direct origin.
2. Card acquisition optionally requests backend extraction; failure leaves
   manual fields usable.
3. The user classifies the lead and optionally records audio/writes a note.
4. Save commits the complete record and media locally before network work.
5. The acknowledgement truthfully reports local/remote outcomes and returns
   to capture while retaining origin; exact copy is blocked by `D-06`.
6. The queue submits a folio idempotently. The backend stores media and writes
   the Basic spreadsheet row.
7. Pro-only processing may then transcribe and send emails with frozen
   attachments; these operations never block or erase the lead.
8. Status changes reconcile back to the device without resending completed
   work.

## Security and compliance boundaries

- Client traffic uses HTTPS and contains no external-service credentials.
- Lead/media data is personal data from the moment it is stored locally.
- Audio links require authenticated marketing/sales access; media is encrypted
  at rest and deleted only under an approved retention policy.
- Event deletion is logical and does not satisfy legal deletion.
- Basic privacy-notice delivery remains blocked by `D-14`; Pro legal footer and
  opt-out are non-editable.

## Decisions required before implementation branches

See `../decisions/open-questions.md`. Particularly consequential areas are
folio concurrency (`D-03`), backend scope (`D-05`), acknowledgement truth
(`D-06`), privacy delivery/retention (`D-14`, `D-11`), and all Pro file/email
governance (`DP-01`–`DP-04`, `DP-12`). Provider and persistence choices require
accepted ADRs; none exists currently.
