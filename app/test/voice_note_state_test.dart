import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/models/voice_note_state.dart';

void main() {
  test('voice note starts idle', () {
    const state = VoiceNoteState();

    expect(state.phase, VoiceNotePhase.idle);
    expect(state.hasRecording, isFalse);
    expect(state.elapsed, Duration.zero);
  });

  test('voice note moves from recording to recorded', () {
    final recording = const VoiceNoteState()
        .startRecording('/tmp/note.m4a')
        .updateElapsed(const Duration(seconds: 12));
    final recorded = recording.finishRecording(
      '/tmp/note.m4a',
      recording.elapsed,
    );

    expect(recording.isRecording, isTrue);
    expect(recorded.phase, VoiceNotePhase.recorded);
    expect(recorded.hasRecording, isTrue);
    expect(recorded.elapsed, const Duration(seconds: 12));
  });

  test('recorded voice note supports play pause and completion', () {
    final recorded = const VoiceNoteState().finishRecording(
      '/tmp/note.m4a',
      const Duration(seconds: 8),
    );
    final playing = recorded.startPlayback();
    final paused = playing.pausePlayback();
    final completed = paused.startPlayback().completePlayback();

    expect(playing.isPlaying, isTrue);
    expect(paused.isPaused, isTrue);
    expect(completed.phase, VoiceNotePhase.recorded);
    expect(completed.localPath, '/tmp/note.m4a');
  });

  test('a cleared voice note returns to the initial state', () {
    const cleared = VoiceNoteState();

    expect(cleared.phase, VoiceNotePhase.idle);
    expect(cleared.localPath, isNull);
    expect(cleared.hasRecording, isFalse);
  });
}
