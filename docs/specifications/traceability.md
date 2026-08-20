# Requirements Traceability Matrix

Status describes specification coverage, not implementation completeness.

| Requirement | Description | Specification | Status |
| --- | --- | --- | --- |
| RF-01 | Rear camera and gallery selection | `business-card-capture.spec.md` | Specified |
| RF-02 | Resize to 1568 px and JPEG-compress client-side | `business-card-capture.spec.md` | Specified |
| RF-03 | Extract core and additional card fields | `business-card-capture.spec.md`; `lead-information.spec.md`; `temporary-on-device-ocr.spec.md` | Open question (website model mismatch); temporary prototype |
| RF-04 | Handle rotated, shadowed, cluttered cards | `business-card-capture.spec.md`; `temporary-on-device-ocr.spec.md` | Specified; final acceptance not claimed by temporary OCR |
| RF-05 | Editable fields; manual corrections win | `business-card-capture.spec.md`; `lead-information.spec.md`; `temporary-on-device-ocr.spec.md` | Specified |
| RF-06 | Explain extraction failure and allow manual capture | `business-card-capture.spec.md`; `temporary-on-device-ocr.spec.md` | Specified |
| RF-07 | Retain original card photo and link | `business-card-capture.spec.md`; `spreadsheet-and-file-delivery.spec.md` | Specified |
| RF-08 | Required Partner/client-potential large controls | `lead-information.spec.md` | Specified |
| RF-09 | Interest values; medium default | `lead-information.spec.md` | Specified |
| RF-10 | Next-step catalog | `lead-information.spec.md` | Specified |
| RF-11 | Automatic event, capture person, timestamp | `event-settings.spec.md`; `lead-information.spec.md` | Specified |
| RF-12 | Readable folio format | `lead-information.spec.md`; `local-persistence-and-sync.spec.md` | Open question (generation semantics) |
| RF-13 | One-tap audio controls, timer, active indicator | `conversation-notes.spec.md` | Specified |
| RF-14 | Editable Mexican-Spanish transcription | `conversation-notes.spec.md` | Specified |
| RF-15 | Play, delete, and rerecord before send | `conversation-notes.spec.md` | Specified |
| RF-16 | Upload audio and store link | `conversation-notes.spec.md`; `spreadsheet-and-file-delivery.spec.md` | Specified |
| RF-17 | Written fallback when transcription unavailable | `conversation-notes.spec.md` | Specified |
| RF-18 | Local save before any network attempt | `local-persistence-and-sync.spec.md` | Specified |
| RF-19 | Offline queue and visible pending state | `local-persistence-and-sync.spec.md` | Specified |
| RF-20 | Automatic and manual synchronization retry | `local-persistence-and-sync.spec.md` | Specified |
| RF-21 | Folio idempotency; no duplicate rows | `local-persistence-and-sync.spec.md`; `spreadsheet-and-file-delivery.spec.md` | Specified |
| RF-22 | Event lead list with count and status | `event-leads-and-export.spec.md` | Specified |
| RF-23 | Shareable UTF-8 BOM CSV | `event-leads-and-export.spec.md` | Specified |
| RF-24 | One fixed-order Google Sheets row per lead | `spreadsheet-and-file-delivery.spec.md`; `../architecture/domain-model.md` | Open question (required fields absent from Section 5) |
| RF-25 | Create sheet/headers on first execution if absent | `spreadsheet-and-file-delivery.spec.md` | Specified |
| RF-26 | Store media as files; put links in sheet | `spreadsheet-and-file-delivery.spec.md` | Specified |
| RF-27 | Trigger lead and marketing emails | `email-follow-up.spec.md` | Specified |
| RF-28 | Company-identified visible sender | `email-follow-up.spec.md` | Open question (sending account) |
| RF-29 | Marketing email includes fields, note, audio link | `email-follow-up.spec.md` | Specified |
| RF-30 | Preserve lead and retry failed email | `email-follow-up.spec.md`; `privacy-and-compliance.spec.md` | Specified |
| RF-31 | Track three-state delivery status per email | `email-follow-up.spec.md`; `event-leads-and-export.spec.md` | Open question (marketing visibility surface) |
| RF-32 | Email templates editable without code | `email-follow-up.spec.md` | Specified |
| RF-33 | Event settings expose four values | `event-settings.spec.md` | Open question (`destino de datos` semantics) |
| RF-34 | Persist settings across app restart | `event-settings.spec.md` | Specified |
| RNF-01 | Extraction under 5 seconds or progress/manual path | `business-card-capture.spec.md` | Specified |
| RNF-02 | Complete offline operation except manual-degraded intelligence | `business-card-capture.spec.md`; `conversation-notes.spec.md`; `local-persistence-and-sync.spec.md` | Specified |
| RNF-03 | One codebase; iOS 15 and Android 10 minimum | `product-spec.md`; `../architecture/overview.md` | Specified |
| RNF-04 | One-hand layout, 44 px targets, bottom primary action | `lead-information.spec.md`; `product-spec.md` | Specified |
| RNF-05 | Visible keyboard focus, labels, reduced motion | `lead-information.spec.md` | Specified |
| RNF-06 | API keys/credentials only on server | `business-card-capture.spec.md`; `conversation-notes.spec.md`; `spreadsheet-and-file-delivery.spec.md`; `../architecture/overview.md` | Specified |
| RNF-07 | Lead data always uses HTTPS | `business-card-capture.spec.md`; `local-persistence-and-sync.spec.md`; `privacy-and-compliance.spec.md` | Specified |
| RNF-08 | Verify event volume against email limits | `email-follow-up.spec.md` | Open question (expected volume/provider capacity) |
| RC-01 | LFPDPPP notice, privacy link, contact reason | `privacy-and-compliance.spec.md`; `email-follow-up.spec.md` | Open question (approved notice URL/content) |
| RC-02 | Clear opt-out, recorded and respected | `privacy-and-compliance.spec.md`; `email-follow-up.spec.md` | Open question (scope and model field) |
| RC-03 | Legal-defined media retention and deletion | `privacy-and-compliance.spec.md`; `spreadsheet-and-file-delivery.spec.md` | Open question (retention period) |
| RC-04 | Marketing/sales-only access; authenticated audio URLs | `privacy-and-compliance.spec.md`; `spreadsheet-and-file-delivery.spec.md` | Open question (access mechanism) |
| RC-05 | Capture person gives verbal email notice | `privacy-and-compliance.spec.md`; `email-follow-up.spec.md` | Specified |

## Coverage Summary

- RF: 34 of 34 represented.
- RNF: 8 of 8 represented.
- RC: 5 of 5 represented.
- Implementation status: a partial Flutter frontend prototype exists;
  production implementation is not complete.

The local demo access shell is documented in `demo-access-shell.spec.md`. It
supports RNF-03 through RNF-06 for prototype validation but adds no RF or RC
and is explicitly not production authentication.

The six-screen, mockup-aligned UI prototype is documented in
`mockup-frontend-prototype.spec.md`. Its session-only list and demo statuses do
not claim completion of production persistence, synchronization, export,
event-settings, Sheets, or email requirements.

The user-approved `temporary-on-device-ocr.spec.md` exception enables local
ML Kit validation without selecting the production vision architecture. It
does not claim final RF-04 acceptance or alter the server-side boundary.
