# Foloo Flutter Prototype

Frontend prototype for the lead-capture flow. It validates layout, fields, navigation, and mobile interaction; it is not a production implementation.

## SDD scope

Primary requirements represented by this prototype: RF-01, RF-03, RF-05, RF-06, RF-08 through RF-10, RF-13, RF-15, RF-17, and RNF-02 through RNF-06. Product acceptance criterion 2 can be explored manually, but is not proven by this prototype.

The demo does not claim productive compliance with OCR accuracy/performance, original-image retention, audio recording/transcription/upload, local persistence, synchronization, folio generation, Sheets, email, or privacy delivery obligations.

## Temporary dependency

- `image_picker`: provides rear-camera and gallery access required to exercise RF-01. It is maintained by the Flutter team and avoids inventing a device bridge. Production adoption should still be reviewed when image preparation/storage behavior is implemented.

No package was added for audio. The recorder UI is explicitly simulated so this first prototype does not prematurely choose a recording format or plugin while duration/format/retention remain unspecified.

## Run

```sh
cd app
flutter pub get
flutter run
```

Use `flutter devices` to list targets, then `flutter run -d <device-id>` to select one.

## Demo-only behavior

- “Simular lectura · Demo” fills only empty fields with mock data; existing manual edits are preserved.
- The recorder timer is UI-only. It does not request microphone access or produce audio.
- Confirmation retains the lead only in memory while the screen is open.
- “Folio Demo” is a label, not a folio-generation algorithm.

There are no API calls, credentials, backend, OCR, transcription, persistence, synchronization, Sheets, or email integrations.
