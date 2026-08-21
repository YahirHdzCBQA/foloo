# Foloo Flutter Prototype

This directory contains the existing Flutter prototype. It predates the
August 2026 Basic/Pro realignment and is not yet a conforming Basic or Pro
implementation. Current scope lives in `../docs/specifications/current/`, not
in this code or its tests.

## What the prototype demonstrates

- Local demo login and password visibility.
- One-scroll capture with card photo/gallery, editable lead fields, two legacy
  lead types, interest, legacy `siguientePaso`, written note and Voice Note.
- Temporary on-device ML Kit OCR and conservative parsing.
- Session-memory save, demo folio, confirmation and records list.
- Local Voice Note playback from Registros.
- Right drawer, read-only legacy Evento view and non-persisted appearance.

These pieces are implementation evidence for portions of `OCR-*`, `CAP-*`,
`VOZ-*`, `REG-*`, `NAV-*`, `RNF-03`–`RNF-06`; they do not establish full
acceptance. See `../docs/migration/current-implementation-gap-analysis.md`.

## Important current conflicts

- Login is a local gate, not `AUT-01`/`AUT-02` authentication and persistence.
- Leads and files are session-only, contradicting the local durability required
  by Article 2, `AUT-08`, `CAP-15` and `SYN-01`.
- The model has two legacy types and mandatory `siguientePaso`; Basic requires
  three types and excludes `siguientePaso` pending `D-02`.
- There is no event/direct origin or Basic event CRUD.
- OCR runs on-device; production `OCR-03`/`OCR-04` extraction belongs behind
  the Foloo backend.
- Confirmation includes demo email rows. Basic must show no email UI at all.
- The UI mentions future transcription. Basic `VOZ-07` forbids even implying
  transcription; transcription is Pro-only.
- Current theme/touch/copy rules do not fully comply with the Constitution.

Do not “fix forward” any of these without following the migration plan and
resolving the blocking decisions.

## Existing device dependencies

- `image_picker`: camera/gallery bridge.
- `google_mlkit_text_recognition`: temporary on-device prototype exception,
  not the approved production extraction architecture.
- `record`: local microphone recording.
- `audioplayers`: local Voice Note playback.

AAC/M4A remains an implementation detail; production limits and retention are
blocked by `D-11`/`RC-03`.

## Run locally

```sh
cd app
flutter pub get
flutter devices
flutter run -d <device-id>
```

There is no backend, real authentication, durable database, synchronization,
spreadsheet delivery, export, Pro transcription, content or email integration.
