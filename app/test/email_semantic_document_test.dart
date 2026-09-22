/// Verifies token-aware Review edits without replacing coincidental text.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/models/email_semantic_document.dart';

void main() {
  test('manual insertion survives while the semantic name changes', () {
    final document = EmailSemanticDocument.fromTemplate(
      'Hola {nombre}, fue un gusto conocerte.',
    );
    final edited = document.captureEdit(
      previousConcrete: 'Hola Pedro, fue un gusto conocerte.',
      editedConcrete: 'Hola Pedro ❤️❤️, fue un gusto conocerte.',
      values: const {'nombre': 'Pedro'},
    );

    expect(
      edited.render(const {'nombre': 'Carlos'}),
      'Hola Carlos ❤️❤️, fue un gusto conocerte.',
    );
    expect(
      EmailSemanticDocument.fromJson(edited.toJson())
          .render(const {'nombre': 'Carlos'}),
      'Hola Carlos ❤️❤️, fue un gusto conocerte.',
    );
  });

  test('coincidental old name in manual text is not globally replaced', () {
    final document = EmailSemanticDocument.fromTemplate('Hola {nombre}.');
    final edited = document.captureEdit(
      previousConcrete: 'Hola Pedro.',
      editedConcrete: 'Hola Pedro. Hablé con Pedro de logística.',
      values: const {'nombre': 'Pedro'},
    );

    expect(
      edited.render(const {'nombre': 'Carlos'}),
      'Hola Carlos. Hablé con Pedro de logística.',
    );
  });

  test('different manual edits preserve every untouched canonical token', () {
    final document = EmailSemanticDocument.fromTemplate(
      '{nombre} {apellido}|{empresa}|{puesto}|{evento}|{contenido}',
    );
    const oldValues = {
      'nombre': 'Pedro',
      'apellido': 'Pérez',
      'empresa': 'Uno',
      'puesto': 'Compras',
      'evento': 'Expo Uno',
      'contenido': 'Ficha A',
    };
    final oldConcrete = document.render(oldValues);
    final edited = document.captureEdit(
      previousConcrete: oldConcrete,
      editedConcrete: 'IMPORTANTE: $oldConcrete ❤️',
      values: oldValues,
    );

    expect(
      edited.render(const {
        'nombre': 'Carlos',
        'apellido': 'López',
        'empresa': 'Dos',
        'puesto': 'Calidad',
        'evento': 'Expo Dos',
        'contenido': 'Ficha A y Ficha B',
      }),
      'IMPORTANTE: Carlos López|Dos|Calidad|Expo Dos|Ficha A y Ficha B ❤️',
      reason: edited.toJson(),
    );
  });
}
