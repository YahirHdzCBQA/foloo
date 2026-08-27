/// Private filesystem storage for card images and voice notes.
///
/// VOZ-02/CAP-15: picker/recorder files are copied out of temporary locations
/// before a lead is considered locally saved.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum LocalMediaType { cardImage, voiceNote }

class MediaPersistenceException implements Exception {
  const MediaPersistenceException(this.message);

  final String message;

  @override
  String toString() => 'MediaPersistenceException: $message';
}

class PrivateMediaStorage {
  const PrivateMediaStorage(this.root);

  final Directory root;

  static Future<PrivateMediaStorage> production() async {
    final support = await getApplicationSupportDirectory();
    return PrivateMediaStorage(Directory(p.join(support.path, 'foloo_media')));
  }

  Directory _directory(LocalMediaType type) => Directory(
    p.join(
      root.path,
      type == LocalMediaType.cardImage ? 'cards' : 'voice_notes',
    ),
  );

  Future<String?> persist({
    required String? sourcePath,
    required String leadLocalId,
    required LocalMediaType type,
  }) async {
    if (sourcePath == null || sourcePath.trim().isEmpty) return null;
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw MediaPersistenceException(
        'Source media does not exist: $sourcePath',
      );
    }
    final directory = _directory(type);
    await directory.create(recursive: true);
    final extension = p.extension(source.path).isEmpty
        ? (type == LocalMediaType.cardImage ? '.jpg' : '.m4a')
        : p.extension(source.path);
    final destination = File(p.join(directory.path, '$leadLocalId$extension'));
    if (p.equals(p.absolute(source.path), p.absolute(destination.path))) {
      return destination.path;
    }
    await source.copy(destination.path);
    return destination.path;
  }

  Future<bool> exists(String path) => File(path).exists();

  Future<void> deleteIfManaged(String? path) async {
    if (path == null || !p.isWithin(root.path, path)) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
