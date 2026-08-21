# Foloo Flutter Prototype

Frontend prototype for the lead-capture flow. It validates layout, fields, navigation, and mobile interaction; it is not a production implementation.

## SDD scope

Primary requirements represented visually by this prototype: RF-01, RF-03,
RF-05, RF-06, RF-08 through RF-13, RF-15, RF-17 through RF-23, RF-31,
RF-33, RF-34, and RNF-02 through RNF-06. Session-only UI does not prove
production persistence, synchronization, export, event-settings persistence,
or delivery behavior. Product acceptance criterion 2 can be explored manually,
but is not proven by this prototype.

The demo does not claim productive compliance with OCR accuracy/performance, original-image retention, audio recording/transcription/upload, local persistence, synchronization, folio generation, Sheets, email, or privacy delivery obligations.

## Device dependencies

- `image_picker`: provides rear-camera and gallery access required to exercise RF-01. It is maintained by the Flutter team and avoids inventing a device bridge. Production adoption should still be reviewed when image preparation/storage behavior is implemented.
- `google_mlkit_text_recognition`: temporary, on-device OCR validation for
  RF-03/RF-04. Final structured extraction remains a backend responsibility.
- `record`: native local microphone recording required by RF-13.
- `audioplayers`: focused playback/pause of the local recording required by
  RF-15.

AAC/M4A is a proposed local implementation detail. Format, maximum duration,
and production retention remain open in OQ-A18; upload and transcription are
not implemented.

## Run

```sh
cd app
flutter pub get
flutter run
```

Use `flutter devices` to list targets, then `flutter run -d <device-id>` to select one.

## Demo-only behavior

- Card OCR runs locally through the temporary ML Kit implementation; fields
  remain editable and manual corrections win.
- Voice notes record, play, pause, delete, and rerecord locally. They are not
  uploaded or transcribed.
- Saved leads remain only in memory for the current demo session and appear in
  Registros. Logout or process restart clears them.
- Demo folios use the mockup event prefix and an in-memory sequence; this is
  not the production folio-generation algorithm.
- Confirmation processing rows, upload states, synchronization, and CSV
  controls are visual demonstrations and do not perform those operations.
- Evento uses centralized mock data and is read-only. It does not fulfill the
  editable, persistent RF-33/RF-34 settings workflow.
- Appearance switches locally and is not persisted.

There are no API calls, credentials, backend, remote transcription,
production persistence, synchronization, Sheets, or email integrations.
