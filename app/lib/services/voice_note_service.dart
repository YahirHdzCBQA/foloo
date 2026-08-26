/// Local recording and playback boundary for lead voice notes.
///
/// Basic and Pro share this device lifecycle. Pro transcription is a separate
/// server capability and is never performed by this service.
library;

import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';

/// Signals that capture must fall back to a written note after permission denial.
class VoiceNotePermissionDeniedException implements Exception {
  const VoiceNotePermissionDeniedException();
}

/// Contract consumed by capture and record-detail widgets for local audio.
abstract interface class VoiceNoteService {
  Stream<void> get playbackCompleted;

  Future<String> startRecording();
  Future<String?> stopRecording();
  Future<void> cancelRecording();
  Future<void> play(String path);
  Future<void> pausePlayback();
  Future<void> resumePlayback();
  Future<void> stopPlayback();
  Future<void> deleteFile(String path);
  Future<void> dispose();
}

/// Device-backed implementation using one recorder and one audio player.
///
/// TODO(PRODUCTION): Define media format, duration and retention through the
/// unresolved OQ-A18/D-11 contracts before treating files as durable assets.
class DeviceVoiceNoteService implements VoiceNoteService {
  DeviceVoiceNoteService();

  AudioRecorder? _recorderInstance;
  AudioPlayer? _playerInstance;
  StreamSubscription<void>? _playerCompleteSubscription;
  final _playbackCompletedController = StreamController<void>.broadcast();

  AudioRecorder get _recorder => _recorderInstance ??= AudioRecorder();

  AudioPlayer get _player {
    final existing = _playerInstance;
    if (existing != null) return existing;
    final player = AudioPlayer();
    _playerCompleteSubscription = player.onPlayerComplete.listen(
      _playbackCompletedController.add,
    );
    return _playerInstance = player;
  }

  @override
  Stream<void> get playbackCompleted => _playbackCompletedController.stream;

  @override
  Future<String> startRecording() async {
    if (!await _recorder.hasPermission()) {
      throw const VoiceNotePermissionDeniedException();
    }

    final directory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}foloo_voice_notes',
    );
    await directory.create(recursive: true);
    final path =
        '${directory.path}${Platform.pathSeparator}voice_${DateTime.now().microsecondsSinceEpoch}.m4a';

    // Proposed local format. OQ-A18 must define the production media contract.
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );
    return path;
  }

  @override
  Future<String?> stopRecording() => _recorder.stop();

  @override
  Future<void> cancelRecording() => _recorder.cancel();

  @override
  Future<void> play(String path) async {
    await _player.stop();
    await _player.play(DeviceFileSource(path));
  }

  @override
  Future<void> pausePlayback() => _player.pause();

  @override
  Future<void> resumePlayback() => _player.resume();

  @override
  Future<void> stopPlayback() async {
    await _playerInstance?.stop();
  }

  @override
  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> dispose() async {
    await _playerCompleteSubscription?.cancel();
    await _playerInstance?.dispose();
    await _recorderInstance?.dispose();
    await _playbackCompletedController.close();
  }
}
