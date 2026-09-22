import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/models/lead_draft.dart';
import 'package:foloo/models/session_lead.dart';
import 'package:foloo/screens/lead_capture_screen.dart';
import 'package:foloo/theme/foloo_theme.dart';
import 'package:foloo/widgets/progress_header.dart';

Widget captureApp({FutureOr<SessionLead> Function(LeadDraft)? onLeadSaved}) =>
    MaterialApp(
      theme: FolooTheme.light,
      home: LeadCaptureScreen(
        originKind: LeadOriginKind.event,
        eventName: DemoEventData.eventName,
        events: DemoAppData.events,
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

Finder editableFor(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(EditableText));

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

  testWidgets('invalid submission scrolls to and focuses the first field', (
    tester,
  ) async {
    await tester.pumpWidget(captureApp());
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('saveLeadButton')));
    await tester.pumpAndSettle();

    final name = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('nameField')),
        matching: find.byType(EditableText),
      ),
    );
    expect(name.focusNode.hasFocus, isTrue);
    expect(
      tester.getTopLeft(find.byKey(const Key('nameField'))).dy,
      greaterThanOrEqualTo(0),
    );
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

  testWidgets(
    'Capture text selection keeps one editable connection and persists edits',
    (tester) async {
      await tester.pumpWidget(captureApp());
      const emailKey = Key('emailField');
      await tester.scrollUntilVisible(
        find.byKey(emailKey),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byKey(emailKey), 'thomas@airbagtech.io');
      await tester.pump();
      final editable = editableFor(emailKey);
      final initialState = tester.state<EditableTextState>(editable);
      final initialWidget = tester.widget<EditableText>(editable);
      final headerBeforeSelection = tester.widget<ProgressHeader>(
        find.byType(ProgressHeader),
      );

      expect(initialWidget.focusNode.hasFocus, isTrue);
      initialWidget.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 6,
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        identical(tester.state<EditableTextState>(editable), initialState),
        isTrue,
      );
      expect(
        identical(
          tester.widget<ProgressHeader>(find.byType(ProgressHeader)),
          headerBeforeSelection,
        ),
        isTrue,
      );
      expect(initialWidget.focusNode.hasFocus, isTrue);
      expect(
        initialWidget.controller.selection.textInside(
          initialWidget.controller.text,
        ),
        'thomas',
      );

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'tom@airbagtech.io',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      await tester.pump();
      expect(initialWidget.controller.text, 'tom@airbagtech.io');
      expect(
        identical(
          tester.widget<ProgressHeader>(find.byType(ProgressHeader)),
          headerBeforeSelection,
        ),
        isFalse,
      );
      expect(
        identical(tester.state<EditableTextState>(editable), initialState),
        isTrue,
      );
    },
  );

  testWidgets('Capture focus traversal and drag dismissal do not refocus', (
    tester,
  ) async {
    await tester.pumpWidget(captureApp());
    const emailKey = Key('emailField');
    const phoneKey = Key('phoneField');
    await tester.scrollUntilVisible(
      find.byKey(emailKey),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(editableFor(emailKey));
    await tester.pump();
    expect(
      tester.widget<EditableText>(editableFor(emailKey)).focusNode.hasFocus,
      isTrue,
    );

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(
      tester.widget<EditableText>(editableFor(phoneKey)).focusNode.hasFocus,
      isTrue,
    );

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(editableFor(phoneKey)).focusNode.hasFocus,
      isFalse,
    );
    await tester.pump();
    expect(
      tester.widget<EditableText>(editableFor(phoneKey)).focusNode.hasFocus,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}
