import 'dart:async';

import 'package:foloo/services/voice_note_service.dart';

class FakeVoiceNoteService implements VoiceNoteService {
  FakeVoiceNoteService({this.permissionDenied = false});

  final bool permissionDenied;
  final _completed = StreamController<void>.broadcast();
  int startCount = 0;
  int stopCount = 0;
  int playCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;
  int stopPlaybackCount = 0;
  int cancelCount = 0;
  final List<String> deletedPaths = [];
  String? activePath;

  @override
  Stream<void> get playbackCompleted => _completed.stream;

  @override
  Future<String> startRecording() async {
    if (permissionDenied) {
      throw const VoiceNotePermissionDeniedException();
    }
    startCount++;
    activePath = '/tmp/foloo_voice_$startCount.m4a';
    return activePath!;
  }

  @override
  Future<String?> stopRecording() async {
    stopCount++;
    return activePath;
  }

  @override
  Future<void> cancelRecording() async {
    cancelCount++;
  }

  @override
  Future<void> play(String path) async {
    playCount++;
  }

  @override
  Future<void> pausePlayback() async {
    pauseCount++;
  }

  @override
  Future<void> resumePlayback() async {
    resumeCount++;
  }

  @override
  Future<void> stopPlayback() async {
    stopPlaybackCount++;
  }

  @override
  Future<void> deleteFile(String path) async {
    deletedPaths.add(path);
  }

  void completePlayback() => _completed.add(null);

  @override
  Future<void> dispose() async {
    await _completed.close();
  }
}
