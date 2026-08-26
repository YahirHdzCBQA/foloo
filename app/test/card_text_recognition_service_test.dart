import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/services/card_text_recognition_service.dart';

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
}
