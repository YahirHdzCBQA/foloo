# High-Level Architecture

This document assigns responsibilities required by business constraints without choosing frameworks, providers, databases, or cloud platforms.

## Mobile Application

The future Flutter application is responsible for:

- rear-camera and gallery image acquisition;
- client-side resize to a 1568 px long side and JPEG compression;
- editable lead input, classification, settings, notes, statuses, and event list;
- one-handed and accessible interaction on iOS 15+ and Android 10+ from one codebase;
- audio recording, playback, deletion, and rerecording;
- local-first persistence before any network attempt;
- offline queue visibility, automatic retry on connectivity recovery, and manual retry;
- CSV export/share from event records;
- manual card/note entry whenever remote intelligence is unavailable.

The mobile application must not contain external-service API keys, sheet credentials, or other provider secrets.

## Foloo Backend

Server execution is required for:

- card-image extraction through a vision/classification service;
- audio transcription through a speech-to-text service;
- idempotent lead acceptance keyed by folio;
- Google Sheets row creation/update and first-use header/sheet creation;
- storing card images/audio and returning protected links;
- sending, retrying, and tracking both emails;
- enforcing provider credentials, media access controls, opt-out, and approved retention/deletion rules.

The business requirements explicitly assign extraction, transcription, Sheets, file, and email operations to the server. Open question 2 asks whether these responsibilities live in one consolidated service; it does not remove the server-side boundary.

## External Services

Provider selection remains open for:

- vision and business-card field extraction;
- Mexican-Spanish speech-to-text;
- protected file storage;
- Google Sheets as the V1 spreadsheet destination;
- transactional email delivery.

Equivalent providers are acceptable only if they satisfy the documented requirements and acceptance tests. No provider is selected here.

## Conceptual Data Flow

1. The user captures/selects a card; the mobile client prepares a 1568 px-long-side JPEG.
2. If connected, the client sends the image over HTTPS to Foloo's backend for field extraction; failure/latency returns control to manual input.
3. The user corrects fields, classifies the lead, and optionally records audio or writes a note.
4. On submit, the complete lead and required local media are saved on-device first.
5. The app acknowledges the record with its folio and either synchronizes or visibly queues it.
6. The backend accepts the folio idempotently, stores media, transcribes audio asynchronously if needed, and writes one Sheets row.
7. The backend sends the lead and marketing emails, retaining independent statuses and retrying failures.
8. Subsequent status/data updates return to the app when connectivity allows. The exact reconciliation protocol is undecided.

## Offline-first Boundary

Available offline:

- settings already stored on device;
- manual lead entry and classification;
- audio recording and written notes;
- local save, folio acknowledgement, pending visibility, event list, and locally sourced export;
- queueing for later delivery.

Requires remote service:

- automatic card extraction;
- transcription;
- remote media storage and protected links;
- Google Sheets delivery;
- email sending and remote status confirmation.

Remote unavailability may delay enrichment/integration but must not prevent or erase the local record.

## Security and Compliance Boundaries

- All lead transport uses HTTPS.
- Secrets exist only on the server.
- Sheets and media access are restricted to marketing and sales; audio links require authenticated access.
- Opt-out and media-retention enforcement belong to backend/integration processing once their open policy details are approved.

## Deferred Technology Decisions

State management, local database, sync mechanism, backend framework/deployment, providers, credential management, observability, and exact API contracts require future ADRs. Nothing in this overview selects them.
