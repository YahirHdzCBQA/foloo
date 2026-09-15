/// Private filesystem storage for card images and voice notes.
///
/// VOZ-02/CAP-15: picker/recorder files are copied out of temporary locations
/// before a lead is considered locally saved.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum LocalMediaType { cardImage, voiceNote, referenceImage }

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

  /// Resolves a persisted media path after iOS changes the application
  /// container UUID while retaining the Application Support contents.
  Future<String?> resolveExistingPath(String storedPath) async {
    if (await File(storedPath).exists()) return storedPath;
    const marker = 'foloo_media';
    final segments = p.split(p.normalize(storedPath));
    final markerIndex = segments.lastIndexOf(marker);
    if (markerIndex < 0 || markerIndex == segments.length - 1) return null;
    final candidate = p.joinAll([root.path, ...segments.skip(markerIndex + 1)]);
    if (!p.isWithin(root.path, candidate) || !await File(candidate).exists()) {
      return null;
    }
    return candidate;
  }

  /// Finds an orphaned FL-016 file only when the persisted outbox metadata
  /// identifies exactly one binary in the expected private-media directory.
  Future<String?> findUniqueRecoveryFile({
    required String leadId,
    required LocalMediaType type,
    required int byteSize,
  }) async {
    final directory = _directory(type);
    if (!await directory.exists()) return null;
    final matches = <String>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final stem = p.basenameWithoutExtension(entity.path);
      final belongsToLead = type == LocalMediaType.referenceImage
          ? stem.startsWith('$leadId-')
          : stem == leadId;
      if (!belongsToLead || await entity.length() != byteSize) continue;
      if (await _hasExpectedSignature(entity, type)) matches.add(entity.path);
      if (matches.length > 1) return null;
    }
    return matches.length == 1 ? matches.single : null;
  }

  Future<bool> _hasExpectedSignature(File file, LocalMediaType type) async {
    final handle = await file.open();
    try {
      final header = await handle.read(12);
      if (type == LocalMediaType.voiceNote) {
        return header.length >= 8 &&
            header[4] == 0x66 &&
            header[5] == 0x74 &&
            header[6] == 0x79 &&
            header[7] == 0x70;
      }
      return header.length >= 3 &&
          header[0] == 0xff &&
          header[1] == 0xd8 &&
          header[2] == 0xff;
    } finally {
      await handle.close();
    }
  }

  Directory _directory(LocalMediaType type) => Directory(
    p.join(root.path, switch (type) {
      LocalMediaType.cardImage => 'cards',
      LocalMediaType.voiceNote => 'voice_notes',
      LocalMediaType.referenceImage => 'reference_images',
    }),
  );

  Future<String?> persist({
    required String? sourcePath,
    required String leadLocalId,
    required LocalMediaType type,
    String? slot,
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
        ? (type == LocalMediaType.voiceNote ? '.m4a' : '.jpg')
        : p.extension(source.path);
    final suffix = slot == null ? '' : '-$slot';
    final destination = File(
      p.join(directory.path, '$leadLocalId$suffix$extension'),
    );
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
