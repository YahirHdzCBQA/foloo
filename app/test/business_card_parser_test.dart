import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/utils/business_card_parser.dart';

void main() {
  const parser = BusinessCardParser();

  group('BusinessCardParser', () {
    test('classifies the representative business card', () {
      final result = parser.parse(const [
        'Mariana Sandoval Ruiz',
        'Gerente de Calidad',
        'Grupo Lácteo del Norte',
        'm.sandoval@lacteosnorte.mx',
        '477 123 4567',
      ]);

      expect(result.name, 'Mariana');
      expect(result.lastName, 'Sandoval Ruiz');
      expect(result.role, 'Gerente de Calidad');
      expect(result.company, 'Grupo Lácteo del Norte');
      expect(result.email, 'm.sandoval@lacteosnorte.mx');
      expect(result.phone, '477 123 4567');
    });

    test('leaves email empty when the card has no email', () {
      final result = parser.parse(const [
        'Mariana Sandoval',
        'Directora de Ventas',
        'Soluciones del Bajío',
        '+52 (477) 123-4567',
      ]);

      expect(result.email, isEmpty);
      expect(result.phone, '+52 (477) 123-4567');
      expect(result.name, 'Mariana');
      expect(result.company, 'Soluciones del Bajío');
    });

    test('leaves phone empty when the card has no phone', () {
      final result = parser.parse(const [
        'Luis Ortega',
        'Consultor de Calidad',
        'Acme Consultoría',
        'luis.ortega@acme.mx',
      ]);

      expect(result.phone, isEmpty);
      expect(result.email, 'luis.ortega@acme.mx');
      expect(result.role, 'Consultor de Calidad');
    });

    test(
      'keeps ambiguous incomplete text empty instead of inventing fields',
      () {
        final result = parser.parse(const ['INNOVACIÓN', '2026']);

        expect(result.name, isEmpty);
        expect(result.role, isEmpty);
        expect(result.company, isEmpty);
        expect(result.email, isEmpty);
        expect(result.phone, isEmpty);
      },
    );

    test('ignores empty and whitespace-only lines', () {
      final result = parser.parse(const ['', '   ', '\n', 'Ana López', '']);

      expect(result.name, 'Ana');
      expect(result.lastName, 'López');
      expect(result.email, isEmpty);
      expect(result.phone, isEmpty);
    });

    test('detects email and phone when both share one OCR line', () {
      final result = parser.parse(const [
        'mariana@empresa.com  ·  +52 55 1234 5678',
      ]);

      expect(result.email, 'mariana@empresa.com');
      expect(result.phone, '+52 55 1234 5678');
    });

    test('repairs spaces introduced around email punctuation', () {
      final result = parser.parse(const ['ana.lopez @ empresa . mx']);

      expect(result.email, 'ana.lopez@empresa.mx');
    });

    test('repairs an OCR O in a labeled phone without guessing other text', () {
      final result = parser.parse(const ['Teléfono: +52 55 12O4 5678']);

      expect(result.phone, '+52 55 1204 5678');
      expect(result.name, isEmpty);
    });

    test('detects website only as diagnostic data', () {
      final result = parser.parse(const ['www.foloo.mx']);

      expect(result.detectedWebsite, 'www.foloo.mx');
      expect(result.populatedLeadFieldCount, 0);
    });
  });

  group('OCR prefill policy', () {
    test('allows an extracted value into an untouched empty field', () {
      expect(
        shouldApplyExtractedValue(
          currentValue: '',
          extractedValue: 'Mariana',
          manuallyEdited: false,
        ),
        isTrue,
      );
    });

    test('preserves a manual correction even when the field is now empty', () {
      expect(
        shouldApplyExtractedValue(
          currentValue: '',
          extractedValue: 'Mariana',
          manuallyEdited: true,
        ),
        isFalse,
      );
    });

    test('does not replace a value already populated by an earlier read', () {
      expect(
        shouldApplyExtractedValue(
          currentValue: 'Mariana',
          extractedValue: 'Mariane',
          manuallyEdited: false,
        ),
        isFalse,
      );
    });
  });
}
