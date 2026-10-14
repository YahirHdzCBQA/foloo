import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/services/card_text_recognition_service.dart';

class _FakeRecognizerEngine implements CardTextRecognizerEngine {
  _FakeRecognizerEngine(this.responses);

  final List<Object> responses;
  var calls = 0;

  @override
  Future<List<String>> recognize(String imagePath) async {
    final response = responses[calls++];
    if (response is Exception) throw response;
    return response as List<String>;
  }

  @override
  Future<void> close() async {}
}

void main() {
  group('OCR candidate selection', () {
    test('accepts a complete normal card without unnecessary fallbacks', () {
      const lines = [
        'Mariana Sandoval Ruiz',
        'Gerente de Calidad',
        'Grupo Lácteo del Norte',
        'm.sandoval@lacteosnorte.mx',
        '+52 477 123 4567',
      ];

      expect(isHighConfidenceBusinessCardRead(lines), isTrue);
      expect(scoreOcrLines(lines), greaterThan(150));
    });

    test('keeps missing contact data in low-confidence fallback path', () {
      const missingEmail = [
        'Mariana Sandoval',
        'Directora',
        '+52 477 123 4567',
      ];
      const missingPhone = [
        'Mariana Sandoval',
        'Directora',
        'mariana@empresa.mx',
      ];

      expect(isHighConfidenceBusinessCardRead(missingEmail), isFalse);
      expect(isHighConfidenceBusinessCardRead(missingPhone), isFalse);
    });

    test('recognizes spaced OCR email as a confidence signal', () {
      const lines = [
        'Ana López Rivera',
        'Gerente de Ventas',
        'Soluciones Norte',
        'ana.lopez @ empresa . mx',
        '55 1234 5678',
      ];

      expect(isHighConfidenceBusinessCardRead(lines), isTrue);
    });
  });

  group('OCR technical diagnostics', () {
    test(
      'continues with another candidate after one platform failure',
      () async {
        final diagnostics = <OcrDiagnostic>[];
        final engine = _FakeRecognizerEngine([
          PlatformException(code: 'image-error'),
          <String>['Ana', 'ana@example.com'],
        ]);
        final service = CardTextRecognitionService(
          engine: engine,
          prepareCandidates: (_) async => ['/tmp/a.jpg', '/tmp/b.jpg'],
          cleanCandidates: (_) async {},
          reportDiagnostic: diagnostics.add,
        );

        expect(await service.recognizeLines('/private/source.jpg'), [
          'Ana',
          'ana@example.com',
        ]);
        expect(engine.calls, 2);
        final failure = diagnostics.singleWhere(
          (item) => item.result == OcrTechnicalResult.failed,
        );
        expect(failure.stage, OcrFailureStage.recognition);
        expect(failure.platformCode, 'image-error');
        expect(failure.logMessage, isNot(contains('/private')));
        expect(
          diagnostics.last.result,
          OcrTechnicalResult.recognitionSucceededWithText,
        );
      },
    );

    test('reports a safe typed failure when every candidate fails', () async {
      final diagnostics = <OcrDiagnostic>[];
      final service = CardTextRecognitionService(
        engine: _FakeRecognizerEngine([
          PlatformException(code: 'recognizer-unavailable'),
        ]),
        prepareCandidates: (_) async => ['/tmp/candidate.jpg'],
        cleanCandidates: (_) async {},
        reportDiagnostic: diagnostics.add,
      );

      await expectLater(
        service.recognizeLines('/private/source.jpg'),
        throwsA(isA<OcrRecognitionException>()),
      );
      final failure = diagnostics.singleWhere(
        (item) => item.result == OcrTechnicalResult.failed,
      );
      expect(failure.platformCode, 'recognizer-unavailable');
      expect(failure.errorType, 'PlatformException');
    });

    test('empty successful recognition remains a no-text result', () async {
      final diagnostics = <OcrDiagnostic>[];
      final service = CardTextRecognitionService(
        engine: _FakeRecognizerEngine([<String>[]]),
        prepareCandidates: (_) async => ['/tmp/blank.jpg'],
        cleanCandidates: (_) async {},
        reportDiagnostic: diagnostics.add,
      );

      expect(await service.recognizeLines('/private/source.jpg'), isEmpty);
      expect(
        diagnostics.last.result,
        OcrTechnicalResult.recognitionSucceededWithoutText,
      );
    });

    test('QA diagnostics are disabled by default', () {
      expect(ocrQaDiagnosticsEnabled, isFalse);
    });

    test('safe log format excludes exception messages and source data', () {
      final diagnostic = OcrDiagnostic(
        stage: OcrFailureStage.recognition,
        result: OcrTechnicalResult.failed,
        errorType: 'PlatformException',
        platformCode: 'recognizer-unavailable',
        candidateIndex: 2,
      );

      expect(diagnostic.logMessage, contains('result=failed'));
      expect(diagnostic.logMessage, contains('candidate=2'));
      expect(diagnostic.logMessage, isNot(contains('message')));
      expect(diagnostic.logMessage, isNot(contains('/private')));
    });
  });
}
