import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/models/lead_draft.dart';
import 'package:foloo/screens/lead_capture_screen.dart';
import 'package:foloo/theme/foloo_theme.dart';

Widget captureApp() => MaterialApp(
  theme: FolooTheme.light,
  home: LeadCaptureScreen(onLogout: () {}),
);

void main() {
  testWidgets('shows required validation without losing the draft', (
    tester,
  ) async {
    await tester.pumpWidget(captureApp());

    await tester.tap(find.byKey(const Key('saveLeadButton')));
    await tester.pumpAndSettle();

    expect(find.text('El nombre es obligatorio'), findsOneWidget);
    expect(find.text('La empresa es obligatoria'), findsOneWidget);
    expect(find.text('Elige Partner o Cliente potencial'), findsOneWidget);
  });

  testWidgets('completes the manual capture flow and starts another lead', (
    tester,
  ) async {
    await tester.pumpWidget(captureApp());

    await tester.enterText(find.byKey(const Key('nameField')), 'Ana López');
    await tester.enterText(
      find.byKey(const Key('companyField')),
      'Estudio Uno',
    );
    await tester.enterText(
      find.byKey(const Key('emailField')),
      'ana@example.com',
    );

    final partner = find.byKey(const Key('leadType-partner'));
    await tester.dragUntilVisible(
      partner,
      find.byType(SingleChildScrollView),
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    await tester.tap(partner);
    await tester.pumpAndSettle();
    final nextStep = find.byKey(const Key('nextStepField'));
    await tester.scrollUntilVisible(
      nextStep,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(nextStep);
    await tester.pumpAndSettle();
    await tester.tap(find.text(NextStep.sendInformation.label).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('saveLeadButton')));
    await tester.pumpAndSettle();

    expect(find.text('REGISTRO COMPLETADO'), findsOneWidget);
    expect(find.text('Ana López'), findsOneWidget);
    expect(find.text('FOLIO DEMO · SIN GENERACIÓN REAL'), findsOneWidget);

    await tester.tap(find.byKey(const Key('captureAnotherButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nameField')), findsOneWidget);
    expect(find.text('Ana López'), findsNothing);
  });

  testWidgets('validates email and accepts a phone-only lead', (tester) async {
    await tester.pumpWidget(captureApp());

    await tester.enterText(find.byKey(const Key('nameField')), 'Luis Pérez');
    await tester.enterText(find.byKey(const Key('companyField')), 'Taller Sur');
    await tester.enterText(
      find.byKey(const Key('emailField')),
      'correo-invalido',
    );
    await tester.tap(find.byKey(const Key('saveLeadButton')));
    await tester.pumpAndSettle();

    expect(find.text('Revisa el formato del correo'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('emailField')), '');
    await tester.enterText(find.byKey(const Key('phoneField')), '55 0000 0000');
    await tester.tap(find.byKey(const Key('saveLeadButton')));
    await tester.pumpAndSettle();

    expect(find.text('Escribe correo o teléfono'), findsNothing);
    expect(find.text('Escribe teléfono o correo'), findsNothing);
  });
}
