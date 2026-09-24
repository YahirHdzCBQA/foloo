/// Private filesystem storage and JPEG normalization for Lead media.
///
/// CAP-08/CAP-09/VOZ-04: picker and recorder files leave temporary locations
/// before local save; image bytes are normalized to the FL-016 JPEG contract.
library;

import 'dart:io';

import 'package:image/image.dart' as image_codec;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum LocalMediaType { cardImage, voiceNote, referenceImage }

enum LocalImageFormat { jpeg, png, unsupported }

class NormalizedLocalImage {
  const NormalizedLocalImage({
    required this.path,
    required this.byteSize,
    required this.sourceFormat,
  });

  final String path;
  final int byteSize;
  final LocalImageFormat sourceFormat;
}

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

  /// Copies the optional seller avatar into owner-scoped private storage.
  Future<String> persistProfileImage({
    required String sourcePath,
    required String ownerSub,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw MediaPersistenceException(
        'Selected profile image is no longer available.',
      );
    }
    final directory = Directory(p.join(root.path, 'profiles'));
    await directory.create(recursive: true);
    final safeOwner = ownerSub.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final destination = File(p.join(directory.path, '$safeOwner.jpg'));
    final normalized = await _normalizeImage(source, destination);
    if (normalized == null) {
      throw const MediaPersistenceException(
        'Selected profile image is not a supported decodable image.',
      );
    }
    return normalized.path;
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
    final suffix = slot == null ? '' : '-$slot';
    if (type != LocalMediaType.voiceNote) {
      final destination = File(
        p.join(directory.path, '$leadLocalId$suffix.jpg'),
      );
      final normalized = await _normalizeImage(source, destination);
      if (normalized == null) {
        throw const MediaPersistenceException(
          'Selected image is not a supported decodable image.',
        );
      }
      return normalized.path;
    }
    final extension = p.extension(source.path).isEmpty
        ? '.m4a'
        : p.extension(source.path);
    final destination = File(
      p.join(directory.path, '$leadLocalId$suffix$extension'),
    );
    if (p.equals(p.absolute(source.path), p.absolute(destination.path))) {
      return destination.path;
    }
    await source.copy(destination.path);
    return destination.path;
  }

  /// Converts a recoverable failed image to the JPEG bytes promised by FL-016.
  ///
  /// A non-JPEG source is retained; the returned `.jpg` becomes the durable
  /// logical file only after the caller updates Drift in the same repair flow.
  Future<NormalizedLocalImage?> normalizeExistingImage(
    String storedPath,
  ) async {
    final source = File(storedPath);
    if (!await source.exists()) return null;
    final bytes = await source.readAsBytes();
    final format = _imageFormat(bytes);
    final decoded = image_codec.decodeImage(bytes);
    if (decoded == null) return null;
    if (format == LocalImageFormat.jpeg) {
      return NormalizedLocalImage(
        path: source.path,
        byteSize: bytes.length,
        sourceFormat: format,
      );
    }
    final destination = File(p.setExtension(source.path, '.jpg'));
    return _normalizeImage(
      source,
      destination,
      decoded: decoded,
      sourceFormat: format,
    );
  }

  Future<NormalizedLocalImage?> _normalizeImage(
    File source,
    File destination, {
    image_codec.Image? decoded,
    LocalImageFormat? sourceFormat,
  }) async {
    final sourceBytes = await source.readAsBytes();
    final image = decoded ?? image_codec.decodeImage(sourceBytes);
    if (image == null) return null;
    final jpeg = image_codec.encodeJpg(
      image_codec.bakeOrientation(image),
      quality: 85,
    );
    final temporary = File('${destination.path}.normalizing');
    await temporary.writeAsBytes(jpeg, flush: true);
    try {
      await temporary.rename(destination.path);
    } on FileSystemException {
      await temporary.copy(destination.path);
      await temporary.delete();
    }
    return NormalizedLocalImage(
      path: destination.path,
      byteSize: jpeg.length,
      sourceFormat: sourceFormat ?? _imageFormat(sourceBytes),
    );
  }

  LocalImageFormat _imageFormat(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return LocalImageFormat.jpeg;
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a) {
      return LocalImageFormat.png;
    }
    return LocalImageFormat.unsupported;
  }

  Future<bool> exists(String path) => File(path).exists();

  Future<void> deleteIfManaged(String? path) async {
    if (path == null || !p.isWithin(root.path, path)) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
