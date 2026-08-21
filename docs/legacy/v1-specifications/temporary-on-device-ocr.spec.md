# Temporary On-device OCR Prototype Specification

## Status and Boundary

This specification records a user-approved, temporary prototype exception for
early Foloo validation. Google ML Kit Text Recognition runs on-device and the
Flutter client classifies its unstructured text with conservative heuristics.

This is not an accepted vision-provider ADR and does not replace the final
architecture. Production extraction remains a structured Foloo-backend
responsibility. No image, lead data, credential, API key, or network request is
sent by this prototype OCR path.

## Related Requirements

- RF-03: attempt to prefill name, role, company, email, and phone.
- RF-04: enable real-device validation with rotated and difficult cards; this
  prototype does not claim that ML Kit plus heuristics satisfies the final
  acceptance threshold.
- RF-05: extracted values remain editable and a later read never overwrites a
  non-empty field or a field manually edited by the user.
- RF-06: recognition or parsing failure is visible and manual capture remains
  available.
- RNF-01: recognition exposes an in-progress state and never locks manual input.
- RNF-02: recognition is local and can operate without venue connectivity.
- RNF-03: the plugin supports the shared Android/iOS Flutter client. Its current
  iOS SDK requires a 15.5 deployment target; Android remains 10+ for Foloo.
- RNF-06: the implementation contains no provider credentials.

No RC behavior is added or changed.

## Approved Temporary Behavior

1. Camera and gallery acquisition continue through `image_picker`.
2. Selecting an image starts Latin-script text recognition automatically.
3. A small parser detects email and reasonable phone candidates first, then
   makes conservative positional/keyword guesses for name, role, and company.
4. Website-like text may be detected for diagnostics but is not added to the
   lead model while OQ-A02 remains unresolved.
5. Empty or ambiguous values stay empty. The user can always finish manually.
6. The existing read control becomes a retry action and contains no hardcoded
   lead data.

## Dependency Rationale

`google_mlkit_text_recognition: ^0.17.1` is the narrow plugin required to turn a
local card image into text for RF-03/RF-04 prototype validation. Flutter and
`image_picker` do not provide OCR, and the broader `google_ml_kit` package would
add unrelated APIs. This dependency is explicitly temporary.

## Acceptance Criteria

- Camera and gallery images are accepted as local `InputImage` values.
- The supplied representative card text reliably detects its email and phone
  and reasonably classifies name, role, and company.
- Missing email, missing phone, incomplete text, empty lines, and combined
  email/phone inputs are covered by parser unit tests.
- A second recognition fills only eligible empty fields and preserves manual
  corrections.
- Failure shows a manual-fallback message and does not block lead submission.

## Deferred Production Work

The backend must later replace local OCR and heuristic parsing with the
approved structured extraction provider and contract. RF-04 must be validated
on the real reference card before it can be considered satisfied.
