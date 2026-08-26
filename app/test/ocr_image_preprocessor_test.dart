import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/utils/ocr/ocr_image_preprocessor.dart';
import 'package:image/image.dart' as img;

void main() {
  group('OcrImagePreprocessor OCR-02/OCR-04/OCR-08', () {
    test('normal image yields original plus rotations without mutation', () {
      final source = _testImage(width: 900, height: 520);
      final original = Uint8List.fromList(img.encodeJpg(source));

      final candidates = OcrImagePreprocessor.buildCandidates(original);

      expect(candidates.map((item) => item.rotation), [0, 0, 90, 180, 270]);
      expect(candidates.map((item) => item.enhanced), [
        false,
        true,
        true,
        true,
        true,
      ]);
      expect(img.decodeImage(original)!.width, 900);
      expect(_decode(candidates.first).width, 900);
      expect(_decode(candidates.first).height, 520);
    });

    test(
      'rotated and vertical cards receive landscape fallback candidates',
      () {
        final vertical = _testImage(width: 520, height: 900);
        final candidates = OcrImagePreprocessor.buildCandidates(
          Uint8List.fromList(img.encodeJpg(vertical)),
        );

        expect(_decode(candidates[0]).width, 520);
        expect(_decode(candidates[2]).width, 900);
        expect(_decode(candidates[2]).height, 520);
        expect(_decode(candidates[3]).width, 520);
      },
    );

    test('large camera image is resized to the OCR long-side limit', () {
      final large = _testImage(width: 2400, height: 1200);
      final candidates = OcrImagePreprocessor.buildCandidates(
        Uint8List.fromList(img.encodeJpg(large)),
      );
      final decoded = _decode(candidates.first);

      expect(decoded.width, OcrImagePreprocessor.maxLongSide);
      expect(decoded.height, 784);
    });

    test('low-contrast shadow image is normalized for text recognition', () {
      final source = img.Image(width: 120, height: 60);
      img.fill(source, color: img.ColorRgb8(128, 128, 128));
      img.fillRect(
        source,
        x1: 0,
        y1: 0,
        x2: 59,
        y2: 59,
        color: img.ColorRgb8(105, 105, 105),
      );
      img.fillRect(
        source,
        x1: 20,
        y1: 20,
        x2: 100,
        y2: 30,
        color: img.ColorRgb8(92, 92, 92),
      );
      final beforeRange = _luminanceRange(source);

      final processed = _decode(
        OcrImagePreprocessor.buildCandidates(
          Uint8List.fromList(img.encodePng(source)),
        )[1],
      );

      expect(_luminanceRange(processed), greaterThan(beforeRange));
    });
  });
}

img.Image _testImage({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(225, 225, 225));
  img.fillRect(
    image,
    x1: width ~/ 8,
    y1: height ~/ 3,
    x2: width * 7 ~/ 8,
    y2: height ~/ 2,
    color: img.ColorRgb8(45, 45, 45),
  );
  return image;
}

img.Image _decode(OcrImageCandidate candidate) =>
    img.decodeImage(candidate.jpegBytes)!;

int _luminanceRange(img.Image image) {
  var minimum = 255;
  var maximum = 0;
  for (final pixel in image) {
    final value = pixel.luminance.round();
    if (value < minimum) minimum = value;
    if (value > maximum) maximum = value;
  }
  return maximum - minimum;
}
