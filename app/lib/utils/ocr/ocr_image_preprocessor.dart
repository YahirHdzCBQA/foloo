/// Image preparation for the temporary on-device card OCR pipeline.
///
/// Derived candidates normalize EXIF, size, illumination and orientation while
/// preserving the selected source image for preview and reprocessing.
library;

import 'dart:isolate';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// One derived OCR input. The source image is never modified (OCR-08).
class OcrImageCandidate {
  const OcrImageCandidate({
    required this.rotation,
    required this.enhanced,
    required this.jpegBytes,
  });

  final int rotation;
  final bool enhanced;
  final Uint8List jpegBytes;
}

/// Pixel preprocessing for the isolated, on-device OCR prototype.
///
/// Production structured extraction remains behind the Foloo backend boundary.
class OcrImagePreprocessor {
  const OcrImagePreprocessor._();

  static const int maxLongSide = 1568;
  static const List<int> fallbackRotations = <int>[0, 90, 180, 270];

  /// Runs decoding and pixel transforms outside the UI isolate (RNF-01).
  static Future<List<String>> prepareTemporaryCandidates(String sourcePath) =>
      Isolate.run(() => _prepareTemporaryCandidates(sourcePath));

  static List<OcrImageCandidate> buildCandidates(Uint8List sourceBytes) {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      throw const FormatException('Unsupported OCR image format.');
    }

    // Camera/gallery files can store rotation only in EXIF. Bake it into a
    // fresh image before removing metadata and trying fallback rotations.
    var normalized = img.bakeOrientation(decoded);
    normalized = _resizeForOcr(normalized);
    final originalCandidate = OcrImageCandidate(
      rotation: 0,
      enhanced: false,
      jpegBytes: Uint8List.fromList(img.encodeJpg(normalized, quality: 92)),
    );
    final enhanced = _enhanceForOcr(normalized);

    final fallbackCandidates = fallbackRotations.map((rotation) {
      final candidate = rotation == 0
          ? img.Image.from(enhanced)
          : img.copyRotate(enhanced, angle: rotation);
      return OcrImageCandidate(
        rotation: rotation,
        enhanced: true,
        jpegBytes: Uint8List.fromList(img.encodeJpg(candidate, quality: 92)),
      );
    });
    return <OcrImageCandidate>[originalCandidate, ...fallbackCandidates];
  }

  static img.Image _enhanceForOcr(img.Image source) {
    final grayscale = img.grayscale(img.Image.from(source));
    final shortSide = grayscale.width < grayscale.height
        ? grayscale.width
        : grayscale.height;
    final blurRadius = (shortSide ~/ 55).clamp(4, 18);
    final illumination = img.gaussianBlur(
      img.Image.from(grayscale),
      radius: blurRadius,
    );

    // Flatten gradual illumination changes (for example, a hand shadow)
    // while retaining the local difference between glyphs and paper.
    for (final pixel in grayscale) {
      final localLight = illumination.getPixel(pixel.x, pixel.y).luminance;
      final corrected = ((pixel.luminance + 1) * 210 / (localLight + 1)).clamp(
        0,
        255,
      );
      pixel
        ..r = corrected
        ..g = corrected
        ..b = corrected;
    }

    var result = img.normalize(grayscale, min: 8, max: 247);
    result = img.adjustColor(result, contrast: 1.22, gamma: 0.92);
    return result;
  }

  static img.Image _resizeForOcr(img.Image source) {
    final longSide = source.width > source.height
        ? source.width
        : source.height;
    if (longSide <= maxLongSide) return img.Image.from(source);

    final scale = maxLongSide / longSide;
    return img.copyResize(
      source,
      width: (source.width * scale).round(),
      height: (source.height * scale).round(),
      interpolation: img.Interpolation.cubic,
    );
  }

  static Future<List<String>> _prepareTemporaryCandidates(
    String sourcePath,
  ) async {
    final sourceBytes = await File(sourcePath).readAsBytes();
    final candidates = buildCandidates(sourceBytes);
    final token = DateTime.now().microsecondsSinceEpoch;
    final paths = <String>[];

    try {
      for (var index = 0; index < candidates.length; index++) {
        final path =
            '${Directory.systemTemp.path}/foloo_ocr_${token}_$index.jpg';
        await File(path).writeAsBytes(candidates[index].jpegBytes, flush: true);
        paths.add(path);
      }
      return paths;
    } catch (_) {
      await deleteTemporaryCandidates(paths);
      rethrow;
    }
  }

  static Future<void> deleteTemporaryCandidates(Iterable<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Best-effort cleanup must not turn a successful OCR read into failure.
      }
    }
  }
}
