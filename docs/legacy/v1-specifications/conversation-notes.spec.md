# Conversation Notes Specification

## Purpose

Capture conversation context as audio and editable Mexican-Spanish transcription, while preserving a written-note fallback.

## Related Requirements

- RF-13
- RF-14
- RF-15
- RF-16
- RF-17
- RNF-02
- RNF-06
- RNF-07
- Acceptance criteria 6, 7, and 10

## User Behavior

The user starts recording with one tap and stops with another, sees elapsed time and an active-microphone indicator, and may play, delete, or rerecord before sending. Transcribed text is editable; a written note can complete the record without transcription.

## Business Rules

- Server-side transcription operates on uploaded audio and targets Spanish as spoken in Mexico.
- Transcription may complete asynchronously after the record and audio are saved.
- Audio is uploaded and its link stored with the lead.
- iOS and Android must produce consistent usable results; OS-specific dictation is not the required transcription path.

## Data Requirements

Audio content, `audioSegundos`, `audioUrl`, and editable `nota`. Audio format, duration limit, and local retention before/after upload are unspecified.

## States

**Proposed implementation states:** idle, recording, recorded, upload pending, uploaded, transcription pending, transcribed, transcription failed, deleted. These are technical proposals, not business requirements.

## Validation

The note and all audio fields are optional in the conceptual model. No maximum duration or text length is specified.

## Failure / Degraded Behavior

Offline or unavailable transcription must not block completion; written input remains available. Audio and the lead are retained for later processing. Failed secondary processing must not lose the record.

## Acceptance Criteria

- Recording controls, timer, active indicator, playback, delete, and rerecord meet RF-13 and RF-15.
- A 30-second note on Android and iPhone yields usable transcription with equivalent results (global criterion 7).
- Marketing receives a playable authenticated audio link when audio exists (global criterion 6 plus RC-04).
- No transcription-provider credentials appear in the client binary (global criterion 10).

## Out of Scope

Selecting a speech-to-text provider or requiring live transcription while recording.
