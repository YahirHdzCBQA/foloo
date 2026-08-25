import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/app.dart';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> login(
  WidgetTester tester, {
  required bool pro,
  bool direct = false,
}) async {
  await tester.pumpWidget(const FolooApp());
  if (pro) {
    await tester.tap(find.byKey(const Key('planPro')));
    await tester.pump();
  }
  await tester.enterText(find.byKey(const Key('loginEmailField')), 'qa');
  await tester.enterText(find.byKey(const Key('loginPasswordField')), 'demo');
  await tester.tap(find.byKey(const Key('loginButton')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('profileContinueButton')));
  await tester.pumpAndSettle();
  if (direct) {
    await tester.tap(find.byKey(const Key('originDirectTab')));
    await tester.pump();
    if (pro) {
      await tester.enterText(
        find.byKey(const Key('originPlaceField')),
        'Oficinas del cliente',
      );
    }
  }
  await tester.ensureVisible(find.byKey(const Key('originContinueButton')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('originContinueButton')));
  await tester.pumpAndSettle();
}

Future<void> drawer(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('hamburgerMenuButton')).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Pro onboarding requires Lugar and create-event shows content', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(const FolooApp());
    await tester.tap(find.byKey(const Key('planPro')));
    await tester.enterText(find.byKey(const Key('loginEmailField')), 'qa');
    await tester.enterText(find.byKey(const Key('loginPasswordField')), 'demo');
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileContinueButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('originManageEventsButton')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Contenido para este evento'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('originDirectTab')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('originContinueButton')))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const Key('originPlaceField')),
      'Expo vecina',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('originContinueButton')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('development selector keeps Basic free of Pro destinations', (
    tester,
  ) async {
    phone(tester);
    await login(tester, pro: false);
    await drawer(tester);
    expect(find.byKey(const Key('drawerContent')), findsNothing);
    expect(find.byKey(const Key('drawerEmail')), findsNothing);
    expect(find.textContaining('BASIC ·'), findsOneWidget);
  });

  testWidgets('Pro exposes content library and email editor', (tester) async {
    phone(tester);
    await login(tester, pro: true);
    await drawer(tester);
    expect(find.byKey(const Key('drawerContent')), findsOneWidget);
    expect(find.byKey(const Key('drawerEmail')), findsOneWidget);
    expect(find.textContaining('PRO ·'), findsOneWidget);
    await tester.tap(find.byKey(const Key('drawerContent')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('contentScreen')), findsOneWidget);
    expect(find.byKey(const Key('uploadPdfButton')), findsOneWidget);
    await drawer(tester);
    await tester.tap(find.byKey(const Key('drawerEmail')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('emailScreen')), findsOneWidget);
    expect(find.byKey(const Key('emailPreview')), findsOneWidget);
  });

  testWidgets(
    'Pro direct lead requires Lugar and keeps Pro capture deltas visible',
    (tester) async {
      phone(tester);
      await login(tester, pro: true, direct: true);
      expect(find.byKey(const Key('directPlaceField')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('transcriptionDemo')),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('TRANSCRIPCIÓN'), findsOneWidget);
      expect(find.text('Guarda y da “foloo”'), findsOneWidget);
    },
  );

  testWidgets('Pro event capture selects assigned content by default', (
    tester,
  ) async {
    phone(tester);
    await login(tester, pro: true);
    await tester.scrollUntilVisible(
      find.byKey(const Key('captureContent-scanley-ims')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final content = find.byKey(const Key('captureContent-scanley-ims'));
    expect(tester.getSize(content).height, 52);
    expect(
      find.descendant(of: content, matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    await tester.tap(content);
    await tester.pump();
    expect(
      find.descendant(of: content, matching: find.byIcon(Icons.check)),
      findsNothing,
    );
  });

  testWidgets('Todos los eventos preserves individual content selection', (
    tester,
  ) async {
    phone(tester);
    await login(tester, pro: true);
    await drawer(tester);
    await tester.tap(find.byKey(const Key('drawerContent')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('contentFile-scanley-ims')));
    await tester.pumpAndSettle();
    final before = tester.widget<CheckboxListTile>(
      find.byKey(const Key('contentEvent-expo-alimentaria')),
    );
    expect(before.value, isTrue);
    await tester.tap(find.byKey(const Key('allEventsSwitch')));
    await tester.pump();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('contentEvent-expo-alimentaria')),
          )
          .enabled,
      isFalse,
    );
    await tester.tap(find.byKey(const Key('allEventsSwitch')));
    await tester.pump();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const Key('contentEvent-expo-alimentaria')),
          )
          .value,
      isTrue,
    );
  });

  testWidgets('Pro templates are independent and reject unknown variables', (
    tester,
  ) async {
    phone(tester);
    await login(tester, pro: true);
    await drawer(tester);
    await tester.tap(find.byKey(const Key('drawerEmail')));
    await tester.pumpAndSettle();
    final eventSubject = find.byKey(const ValueKey('emailSubject-event'));
    await tester.enterText(eventSubject, 'Evento especial {evento}');
    await tester.tap(find.text('Lead directo'));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('emailSubject-direct')))
          .controller
          ?.text,
      'Seguimiento · {lugar}',
    );
    await tester.enterText(
      find.byKey(const ValueKey('emailSubject-direct')),
      'Hola {variable_inventada}',
    );
    await tester.tap(find.byKey(const Key('saveEmailTemplateButton')));
    await tester.pump();
    expect(find.byKey(const Key('emailVariableError')), findsOneWidget);
  });

  testWidgets('Pro direct save shows four demo confirmations and keeps Lugar', (
    tester,
  ) async {
    phone(tester);
    await login(tester, pro: true, direct: true);
    await tester.enterText(
      find.byKey(const Key('directPlaceField')),
      'Oficinas del cliente',
    );
    await tester.enterText(find.byKey(const Key('nameField')), 'Mariana');
    await tester.enterText(find.byKey(const Key('lastNameField')), 'Sandoval');
    await tester.enterText(
      find.byKey(const Key('companyField')),
      'Grupo Norte',
    );
    await tester.enterText(
      find.byKey(const Key('emailField')),
      'mariana@example.com',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('leadType-partner')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('leadType-partner')));
    await tester.tap(find.byKey(const Key('saveLeadButton')));
    await tester.pumpAndSettle();
    expect(find.text('Correo al lead'), findsOneWidget);
    expect(find.text('Copia Admin'), findsOneWidget);
    expect(find.text('Contenido adjunto'), findsOneWidget);
    await tester.tap(find.byKey(const Key('captureAnotherButton')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('directPlaceField')))
          .controller
          ?.text,
      'Oficinas del cliente',
    );
  });
}
