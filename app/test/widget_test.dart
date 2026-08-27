import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/models/lead_draft.dart';
import 'package:foloo/models/session_lead.dart';
import 'package:foloo/screens/lead_capture_screen.dart';
import 'package:foloo/theme/foloo_theme.dart';

Widget captureApp({FutureOr<SessionLead> Function(LeadDraft)? onLeadSaved}) =>
    MaterialApp(
      theme: FolooTheme.light,
      home: LeadCaptureScreen(
        originKind: LeadOriginKind.event,
        eventName: DemoEventData.eventName,
        events: DemoBasicData.events,
        recordsCount: 0,
        darkMode: false,
        onLeadSaved:
            onLeadSaved ??
            (lead) => DemoEventData.createSessionLead(lead: lead, sequence: 1),
        onOriginChanged: (_, _) {},
        onCreateEvent: (_) {},
        onDestinationSelected: (_) {},
        onAppearanceChanged: (_) {},
        onLogout: () {},
      ),
    );

void main() {
  testWidgets('shows required validation without losing the draft', (
    tester,
  ) async {
    await tester.pumpWidget(captureApp());

    expect(find.text('Sin foto aún'), findsOneWidget);
    expect(find.text('Tipo de Lead'), findsOneWidget);
    expect(find.byKey(const Key('interestBubble')), findsOneWidget);

    await tester.tap(find.byKey(const Key('saveLeadButton')));
    await tester.pumpAndSettle();

    expect(find.text('El nombre es obligatorio'), findsOneWidget);
    expect(find.text('La empresa es obligatoria'), findsOneWidget);
    expect(find.text('Elige Proveedor, Partner o Cliente'), findsOneWidget);
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
    await tester.tap(find.byKey(const Key('saveLeadButton')));
    await tester.pumpAndSettle();

    expect(find.text('Lead guardado'), findsOneWidget);
    expect(find.textContaining('Ana López'), findsOneWidget);
    expect(find.text('FOL-260812-001'), findsOneWidget);
    expect(find.byKey(const Key('confirmationMark')), findsOneWidget);
    expect(find.byKey(const Key('confirmationStatusCard')), findsOneWidget);
    expect(
      find.byKey(const Key('confirmationCountdownProgress')),
      findsOneWidget,
    );

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

  testWidgets('local write failure never opens success confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      captureApp(
        onLeadSaved: (_) async => throw StateError('simulated disk failure'),
      ),
    );
    await tester.enterText(find.byKey(const Key('nameField')), 'Ana');
    await tester.enterText(
      find.byKey(const Key('companyField')),
      'Estudio Uno',
    );
    await tester.enterText(
      find.byKey(const Key('emailField')),
      'ana@example.com',
    );
    final partner = find.byKey(const Key('leadType-partner'));
    await tester.scrollUntilVisible(
      partner,
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(partner);
    await tester.tap(find.byKey(const Key('saveLeadButton')));
    await tester.pumpAndSettle();

    expect(find.text('Lead guardado'), findsNothing);
    expect(
      find.textContaining('No se pudo guardar en el dispositivo'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('nameField')), findsOneWidget);
  });

  testWidgets('clears only the lead data fields from the section action', (
    tester,
  ) async {
    await tester.pumpWidget(captureApp());
    await tester.enterText(find.byKey(const Key('nameField')), 'Mariana');
    await tester.enterText(find.byKey(const Key('lastNameField')), 'Ruiz');
    await tester.enterText(find.byKey(const Key('roleField')), 'Gerente');
    await tester.enterText(find.byKey(const Key('companyField')), 'Empresa');
    await tester.enterText(
      find.byKey(const Key('emailField')),
      'mariana@example.com',
    );
    await tester.enterText(find.byKey(const Key('phoneField')), '5500000000');

    final clear = find.byKey(const Key('clearLeadFieldsButton'));
    await tester.scrollUntilVisible(
      clear,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(clear);
    await tester.pump();

    for (final key in const [
      Key('nameField'),
      Key('lastNameField'),
      Key('roleField'),
      Key('companyField'),
      Key('emailField'),
      Key('phoneField'),
    ]) {
      final field = tester.widget<TextFormField>(find.byKey(key));
      expect(field.controller?.text, isEmpty);
    }
  });
}
