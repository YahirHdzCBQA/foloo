# Local Voice Note Implementation Specification

## Status and Boundary

This specification records the user-approved implementation of the local
recording portion of Conversation Notes. It implements device recording and
review only. It does not select or implement remote storage, synchronization,
speech-to-text, or a transcription provider.

## Related Requirements

- RF-13: one-touch recording and stopping, elapsed time, and an active
  microphone indication.
- RF-15: local playback, pause, delete, and rerecord before submission.
- RF-17: written notes remain independent and available after audio failure.
- RNF-02: recording, playback, and deletion work without connectivity.
- RNF-03: shared Flutter implementation for supported iOS and Android targets.
- RNF-04: the primary microphone control remains at least 44 px and suitable
  for one-handed use.
- RNF-05: state is communicated with text, icon, timer, semantics, and no
  animation-only meaning.
- RNF-06: no provider credentials or network services are introduced.
- RC-03: production retention remains unresolved and is not implemented here.

RF-14 transcription and RF-16 remote upload/link remain deferred to the Foloo
backend. No RC behavior is claimed as complete.

## Local Behavior

1. The operating system requests microphone permission when recording is first
   attempted.
2. Permission denial or recording failure presents a clear message and leaves
   the written note and lead submission available.
3. The states are idle, recording, recorded, playing, and paused.
4. Only one voice note belongs to the current draft. Rerecording replaces the
   prior draft file; deleting removes its reference and local file.
5. Saving may include the current local path and duration in the session-only
   lead model. Audio is optional and never gates validation.
6. Capturing another lead clears the recorder/player UI. Logout stops active
   resources and clears files owned by the in-memory demo session.
7. App lifecycle interruption stops an active recording and pauses playback.
8. A saved lead that still has a valid session-local audio reference exposes a
   compact play/pause/replay control in Registros. Only one record plays at a
   time, playback stops when leaving Registros, and a missing/unreadable local
   file reports an error without affecting the lead.

The Registros control is a user-approved extension of RF-15 playback for the
current frontend/demo session. It does not claim production persistence,
remote availability, upload, or an authenticated `audioUrl`. Those behaviors
remain bounded by RF-16, RC-03, RC-04, and OQ-A18.

## Dependency Rationale

- `record: ^7.1.1` supplies the maintained native microphone bridge and normal
  permission request required by RF-13. Flutter has no microphone recorder API.
- `audioplayers: ^6.8.1` supplies focused local-file playback/pause required by
  RF-15. No remote source is used.

No permission-management, state-management, storage, or networking package is
added.

## Proposed Media Detail

AAC-LC in an M4A container is used for this local implementation because both
target platforms support it through `record`. This is **Proposed**, not a
required backend contract. OQ-A18 tracks final format, duration, and retention.

## Deferred Backend Flow

```text
local audio
  -> Foloo Backend
  -> protected storage
  -> approved Speech-to-Text provider
  -> editable note update
```

Provider selection, upload, `audioUrl`, transcription, synchronization, and
production persistence are outside this implementation.
