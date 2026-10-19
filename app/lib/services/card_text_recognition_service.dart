/// On-device OCR adapter for Foloo's business-card capture flow.
///
/// It keeps ML Kit APIs outside the UI and selects the best preprocessed image
/// before returning ordered text lines for parsing.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:foloo/utils/ocr/ocr_image_preprocessor.dart';

enum OcrFailureStage { preprocessing, recognition }

enum OcrTechnicalResult {
  preprocessingSucceeded,
  recognitionSucceededWithText,
  recognitionSucceededWithoutText,
  failed,
}

/// Enables sanitized OCR diagnostics only in an explicitly configured QA build.
const bool ocrQaDiagnosticsEnabled = bool.fromEnvironment(
  'FOLOO_OCR_QA_DIAGNOSTICS',
  defaultValue: false,
);

/// Non-sensitive failure metadata emitted for physical Release diagnostics.
class OcrDiagnostic {
  const OcrDiagnostic({
    required this.stage,
    required this.result,
    this.errorType,
    this.platformCode,
    this.candidateIndex,
  });

  final OcrFailureStage stage;
  final OcrTechnicalResult result;
  final String? errorType;
  final String? platformCode;
  final int? candidateIndex;

  String get logMessage =>
      'stage=${stage.name} result=${result.name} '
      'errorType=${errorType ?? 'none'} '
      'platformCode=${platformCode ?? 'none'} '
      'candidate=${candidateIndex ?? 'none'}';
}

/// Technical OCR failure after every viable candidate failed to process.
class OcrRecognitionException implements Exception {
  const OcrRecognitionException(this.diagnostic);

  final OcrDiagnostic diagnostic;
}

abstract interface class CardTextRecognizerEngine {
  Future<List<String>> recognize(String imagePath);

  Future<void> close();
}

class MlKitCardTextRecognizerEngine implements CardTextRecognizerEngine {
  MlKitCardTextRecognizerEngine()
    : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  @override
  Future<List<String>> recognize(String imagePath) async => _orderedLines(
    await _recognizer.processImage(InputImage.fromFilePath(imagePath)),
  );

  @override
  Future<void> close() => _recognizer.close();
}

typedef OcrCandidatePreparer = Future<List<String>> Function(String sourcePath);
typedef OcrCandidateCleaner = Future<void> Function(Iterable<String> paths);
typedef OcrDiagnosticReporter = void Function(OcrDiagnostic diagnostic);

/// Wraps ML Kit recognition without exposing provider types to capture UI.
class CardTextRecognitionService {
  CardTextRecognitionService({
    CardTextRecognizerEngine? engine,
    OcrCandidatePreparer? prepareCandidates,
    OcrCandidateCleaner? cleanCandidates,
    OcrDiagnosticReporter? reportDiagnostic,
  }) : _engine = engine ?? MlKitCardTextRecognizerEngine(),
       _prepareCandidates =
           prepareCandidates ?? OcrImagePreprocessor.prepareTemporaryCandidates,
       _cleanCandidates =
           cleanCandidates ?? OcrImagePreprocessor.deleteTemporaryCandidates,
       _reportDiagnostic = reportDiagnostic ?? _defaultDiagnosticReporter;

  final CardTextRecognizerEngine _engine;
  final OcrCandidatePreparer _prepareCandidates;
  final OcrCandidateCleaner _cleanCandidates;
  final OcrDiagnosticReporter _reportDiagnostic;

  /// Recognizes an original card image through derived orientation candidates.
  ///
  /// The first sufficiently complete result wins; otherwise the highest-scored
  /// candidate is returned and uncertain field mapping remains the parser's job.
  Future<List<String>> recognizeLines(String imagePath) async {
    late final List<String> candidates;
    try {
      candidates = await _prepareCandidates(imagePath);
    } catch (error) {
      final diagnostic = _diagnostic(
        stage: OcrFailureStage.preprocessing,
        error: error,
      );
      _reportDiagnostic(diagnostic);
      throw OcrRecognitionException(diagnostic);
    }
    _reportDiagnostic(
      const OcrDiagnostic(
        stage: OcrFailureStage.preprocessing,
        result: OcrTechnicalResult.preprocessingSucceeded,
      ),
    );
    var bestLines = const <String>[];
    var bestScore = -1;
    OcrDiagnostic? lastFailure;
    var successfulCandidates = 0;

    try {
      for (var index = 0; index < candidates.length; index++) {
        late final List<String> lines;
        try {
          lines = await _engine.recognize(candidates[index]);
          successfulCandidates++;
          _reportDiagnostic(
            OcrDiagnostic(
              stage: OcrFailureStage.recognition,
              result: lines.isEmpty
                  ? OcrTechnicalResult.recognitionSucceededWithoutText
                  : OcrTechnicalResult.recognitionSucceededWithText,
              candidateIndex: index,
            ),
          );
        } catch (error) {
          lastFailure = _diagnostic(
            stage: OcrFailureStage.recognition,
            error: error,
            candidateIndex: index,
          );
          _reportDiagnostic(lastFailure);
          continue;
        }
        final score = scoreOcrLines(lines);
        if (score > bestScore) {
          bestScore = score;
          bestLines = lines;
        }

        // A complete contact read is a better latency/accuracy trade-off than
        // always invoking ML Kit for all four rotations (RNF-01).
        if (isHighConfidenceBusinessCardRead(lines)) break;
      }
      if (successfulCandidates == 0 && lastFailure != null) {
        throw OcrRecognitionException(lastFailure);
      }
      return bestLines;
    } finally {
      await _cleanCandidates(candidates);
    }
  }

  Future<void> close() => _engine.close();
}

OcrDiagnostic _diagnostic({
  required OcrFailureStage stage,
  required Object error,
  int? candidateIndex,
}) => OcrDiagnostic(
  stage: stage,
  result: OcrTechnicalResult.failed,
  errorType: error.runtimeType.toString(),
  platformCode: error is PlatformException ? error.code : null,
  candidateIndex: candidateIndex,
);

void _defaultDiagnosticReporter(OcrDiagnostic diagnostic) {
  if (!ocrQaDiagnosticsEnabled) return;
  // STORE-03D: excludes image/text/path and arbitrary exception messages.
  // debugPrint reaches Android logcat in Release while the compile-time flag
  // keeps ordinary distribution builds silent.
  debugPrint('foloo.ocr: ${diagnostic.logMessage}');
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
