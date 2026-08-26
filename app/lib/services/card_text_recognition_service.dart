/// On-device OCR adapter used by the current card-capture prototype.
///
/// It keeps ML Kit APIs outside the UI and selects the best preprocessed image
/// before returning ordered text lines for parsing.
library;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:foloo/utils/ocr/ocr_image_preprocessor.dart';

// DEMO:
// Google ML Kit is used on-device for early Foloo validation.
// Final card extraction will move behind the Foloo backend
// according to Article 3 and OCR-03/OCR-04.
/// Wraps ML Kit recognition without exposing provider types to capture UI.
class CardTextRecognitionService {
  CardTextRecognitionService()
    : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  /// Recognizes an original card image through derived orientation candidates.
  ///
  /// The first sufficiently complete result wins; otherwise the highest-scored
  /// candidate is returned and uncertain field mapping remains the parser's job.
  Future<List<String>> recognizeLines(String imagePath) async {
    final candidates = await OcrImagePreprocessor.prepareTemporaryCandidates(
      imagePath,
    );
    var bestLines = const <String>[];
    var bestScore = -1;

    try {
      for (final candidatePath in candidates) {
        final result = await _recognizer.processImage(
          InputImage.fromFilePath(candidatePath),
        );
        final lines = _orderedLines(result);
        final score = scoreOcrLines(lines);
        if (score > bestScore) {
          bestScore = score;
          bestLines = lines;
        }

        // A complete contact read is a better latency/accuracy trade-off than
        // always invoking ML Kit for all four rotations (RNF-01).
        if (isHighConfidenceBusinessCardRead(lines)) break;
      }
      return bestLines;
    } finally {
      await OcrImagePreprocessor.deleteTemporaryCandidates(candidates);
    }
  }

  Future<void> close() => _recognizer.close();
}

List<String> _orderedLines(RecognizedText result) {
  final lines = result.blocks.expand((block) => block.lines).toList();
  lines.sort((left, right) {
    final vertical = left.boundingBox.top.compareTo(right.boundingBox.top);
    if (vertical != 0) return vertical;
    return left.boundingBox.left.compareTo(right.boundingBox.left);
  });
  return lines
      .map((line) => line.text.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
}

final RegExp _ocrEmailSignal = RegExp(
  r'[A-Z0-9._%+\-]+\s*@\s*[A-Z0-9.\-]+\s*\.\s*[A-Z]{2,}',
  caseSensitive: false,
);
final RegExp _ocrPhoneSignal = RegExp(r'\+?\d[\d\s().\-]{5,}\d');

bool isHighConfidenceBusinessCardRead(Iterable<String> lines) {
  final list = lines.toList(growable: false);
  return list.length >= 4 &&
      list.any(_ocrEmailSignal.hasMatch) &&
      list.any((line) {
        return _ocrPhoneSignal.allMatches(line).any((match) {
          final digits = match.group(0)!.replaceAll(RegExp(r'\D'), '').length;
          return digits >= 7 && digits <= 15;
        });
      });
}

int scoreOcrLines(Iterable<String> lines) {
  final list = lines.where((line) => line.trim().isNotEmpty).toList();
  final meaningfulCharacters = list.join().replaceAll(
    RegExp(r'[^A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9]'),
    '',
  );
  var score = meaningfulCharacters.length.clamp(0, 120) + list.length * 8;
  if (list.any(_ocrEmailSignal.hasMatch)) score += 80;
  if (list.any(_ocrPhoneSignal.hasMatch)) score += 50;
  return score;
}
