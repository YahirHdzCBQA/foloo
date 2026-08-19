import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/app.dart';
import 'package:foloo/models/lead_draft.dart';

void usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> login(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('loginEmailField')),
    'demo@foloo.example',
  );
  await tester.enterText(find.byKey(const Key('loginPasswordField')), 'demo');
  await tester.tap(find.byKey(const Key('loginButton')));
  await tester.pumpAndSettle();
}

Future<void> openDrawer(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('hamburgerMenuButton')));
  await tester.pumpAndSettle();
}

Future<void> selectDrawerDestination(
  WidgetTester tester,
  Key destination,
) async {
  await openDrawer(tester);
  await tester.tap(find.byKey(destination));
  await tester.pumpAndSettle();
}

Future<void> completeRequiredLead(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('nameField')), 'Ana López');
  await tester.enterText(find.byKey(const Key('companyField')), 'Estudio Uno');
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
  await tester.pumpAndSettle();
  await tester.tap(partner);

  final nextStep = find.byKey(const Key('nextStepField'));
  await tester.scrollUntilVisible(
    nextStep,
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(nextStep);
  await tester.pumpAndSettle();
  await tester.tap(find.text(NextStep.sendInformation.label).last);
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('saveLeadButton')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('drawer navigates to records and closes from the scrim', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(const FolooApp());
    await login(tester);

    await openDrawer(tester);
    expect(find.text('Registros'), findsOneWidget);
    await tester.tapAt(const Offset(8, 300));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('logoutButton')), findsNothing);

    await selectDrawerDestination(tester, const Key('drawerRecords'));
    expect(find.byKey(const ValueKey('recordsScreen')), findsOneWidget);
    expect(find.text('Aún no hay registros'), findsOneWidget);
  });

  testWidgets('drawer opens event and returns to capture', (tester) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(const FolooApp());
    await login(tester);

    await selectDrawerDestination(tester, const Key('drawerEvent'));
    expect(find.byKey(const Key('eventInformationCard')), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byKey(const Key('backToCaptureButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cardSection')), findsOneWidget);
  });

  testWidgets('saved lead appears in records during the current session', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(const FolooApp());
    await login(tester);
    await completeRequiredLead(tester);

    expect(find.text('Lead guardado'), findsOneWidget);
    await tester.tap(find.byKey(const Key('captureAnotherButton')));
    await tester.pumpAndSettle();

    await selectDrawerDestination(tester, const Key('drawerRecords'));
    expect(find.text('Ana López'), findsOneWidget);
    expect(find.text('Estudio Uno'), findsOneWidget);
    expect(find.text('EXP-260812-001'), findsOneWidget);
    expect(find.text('POR SUBIR'), findsOneWidget);

    await openDrawer(tester);
    await tester.tap(find.byKey(const Key('logoutButton')));
    await tester.pumpAndSettle();
    await login(tester);
    await selectDrawerDestination(tester, const Key('drawerRecords'));
    expect(find.text('Aún no hay registros'), findsOneWidget);
    expect(find.text('EXP-260812-001'), findsNothing);
  });

  testWidgets('appearance toggle is local and logout returns to login', (
    tester,
  ) async {
    usePhoneViewport(tester);
    await tester.pumpWidget(const FolooApp());
    await login(tester);
    await openDrawer(tester);

    await tester.tap(find.byKey(const Key('appearanceSwitch')));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byKey(const Key('appDrawer')))).brightness,
      Brightness.dark,
    );

    await tester.tap(find.byKey(const Key('logoutButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('loginButton')), findsOneWidget);
    expect(find.byKey(const Key('cardSection')), findsNothing);
  });
}
