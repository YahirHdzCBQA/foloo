# Business Card Capture Specification

## Purpose

Convert a card image into editable lead fields quickly while retaining a manual path whenever intelligent extraction is unavailable.

## Related Requirements

- RF-01
- RF-02
- RF-03
- RF-04
- RF-05
- RF-06
- RF-07
- RNF-01
- RNF-02
- RNF-06
- RNF-07
- Acceptance criteria 1, 8, and 10

## User Behavior

The user opens the rear camera directly or chooses an image from the gallery. Extracted fields are prefilled and remain editable. If extraction fails or is slow, the user can continue manually.

## Business Rules

- The client resizes the image to 1568 px on its long side and compresses it as JPEG before upload.
- Extraction targets name, company, email, and phone, plus optional job title and website.
- A missing field is returned as an empty string; values must never be invented.
- Cards rotated 90° or 180°, shadowed, or against cluttered backgrounds must be handled, including a vertical card held in one hand.
- Automatic extraction never overwrites a field the user manually corrected.
- Provider calls occur on the server; Flutter contains no provider credentials.
- Keeping the original card image and its record link is a `Debería` requirement (RF-07), still within V1 requirement tracking.

## Data Requirements

Input: original image and client-prepared JPEG. Output contract fields: `nombre`, `puesto`, `empresa`, `correo`, `telefono`; RF-03 additionally calls for `sitio web`, although the example response contract and Section 5 lead model omit it. This mismatch is an open question.

## States

**Proposed implementation states:** image selected, preparing, extracting, extracted, extraction failed, manual capture. They are not mandated business states.

## Validation

Lead-level validation is defined in `lead-information.spec.md`. Extraction must use empty strings for unavailable data and preserve user edits.

## Failure / Degraded Behavior

Show the reason for extraction failure and allow manual completion. After five seconds, show progress and allow manual capture. Offline operation degrades extraction to manual capture.

## Acceptance Criteria

- The real reference card, rotated 90° and held in one hand, prefills name, company, email, and phone correctly (global criterion 1).
- Deliberately disabling extraction still permits manual completion (global criterion 8).
- Inspecting the app binary exposes no API key or spreadsheet credential (global criterion 10).
- Data sent to the backend travels over HTTPS (RNF-07).

## Out of Scope

Choosing a vision provider or embedding classical OCR/provider logic in the client.
