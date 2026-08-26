/// Immutable UI state for the local voice-note lifecycle.
///
/// Recording/playback is shared by Basic and Pro; transcription is Pro-only
/// and is intentionally not represented here (VOZ-07 / TRA-*).
library;

/// Mutually exclusive phases of local recording and playback.
enum VoiceNotePhase { idle, recording, recorded, playing, paused }

/// Value object consumed while handling one local audio file.
class VoiceNoteState {
  const VoiceNoteState({
    this.phase = VoiceNotePhase.idle,
    this.localPath,
    this.elapsed = Duration.zero,
  });

  final VoiceNotePhase phase;
  final String? localPath;
  final Duration elapsed;

  bool get isRecording => phase == VoiceNotePhase.recording;
  bool get isPlaying => phase == VoiceNotePhase.playing;
  bool get isPaused => phase == VoiceNotePhase.paused;
  bool get hasRecording =>
      localPath != null && phase != VoiceNotePhase.idle && !isRecording;

  VoiceNoteState startRecording(String path) =>
      VoiceNoteState(phase: VoiceNotePhase.recording, localPath: path);

  VoiceNoteState updateElapsed(Duration value) =>
      VoiceNoteState(phase: phase, localPath: localPath, elapsed: value);

  VoiceNoteState finishRecording(String path, Duration duration) =>
      VoiceNoteState(
        phase: VoiceNotePhase.recorded,
        localPath: path,
        elapsed: duration,
      );

  VoiceNoteState startPlayback() => VoiceNoteState(
    phase: VoiceNotePhase.playing,
    localPath: localPath,
    elapsed: elapsed,
  );

  VoiceNoteState pausePlayback() => VoiceNoteState(
    phase: VoiceNotePhase.paused,
    localPath: localPath,
    elapsed: elapsed,
  );

  VoiceNoteState completePlayback() => VoiceNoteState(
    phase: VoiceNotePhase.recorded,
    localPath: localPath,
    elapsed: elapsed,
  );
}
