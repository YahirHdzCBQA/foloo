import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/app.dart';
import 'package:foloo/data/repositories/local_repositories.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _login(WidgetTester tester, String username) async {
  await tester.enterText(find.byKey(const Key('loginEmailField')), username);
  await tester.enterText(find.byKey(const Key('loginPasswordField')), 'demo');
  await tester.tap(find.byKey(const Key('loginButton')));
  await tester.pumpAndSettle();
}

Future<void> _completeProfile(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('profileContinueButton')));
  await tester.pumpAndSettle();
}

Future<void> _createEvent(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const Key('originManageEventsButton')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('newEventNameField')), name);
  await tester.tap(find.byKey(const Key('confirmCreateEventButton')));
  await tester.pumpAndSettle();
}

Future<void> _enterCapture(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('originContinueButton')));
  await tester.pumpAndSettle();
}

Future<void> _logout(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('hamburgerMenuButton')).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('logoutButton')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('AUT-08 isolates records and event selector across fake users', (
    tester,
  ) async {
    _phone(tester);
    final persistence = LocalPersistence.inMemory();
    await tester.pumpWidget(
      FolooApp(persistence: persistence, useDemoFixtures: false),
    );
    await tester.pumpAndSettle();

    await _login(tester, 'seller-a@example.com');
    await _completeProfile(tester);
    await _createEvent(tester, 'Event A');
    await _enterCapture(tester);
    await tester.enterText(find.byKey(const Key('nameField')), 'Lead A');
    await tester.enterText(find.byKey(const Key('companyField')), 'Company A');
    await tester.enterText(
      find.byKey(const Key('emailField')),
      'lead-a@example.com',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('leadType-partner')),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('leadType-partner')));
    await tester.tap(find.byKey(const Key('saveLeadButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('captureAnotherButton')));
    await tester.pumpAndSettle();
    await _logout(tester);

    await _login(tester, 'seller-b@example.com');
    await _completeProfile(tester);
    expect(find.text('Event A'), findsNothing);
    await _createEvent(tester, 'Event B');
    await _enterCapture(tester);
    await tester.tap(find.byKey(const Key('hamburgerMenuButton')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drawerRecords')));
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay registros'), findsOneWidget);
    expect(find.text('Lead A'), findsNothing);
    await _logout(tester);

    await _login(tester, 'seller-a@example.com');
    expect(find.text('Event A'), findsOneWidget);
    expect(find.text('Event B'), findsNothing);
    await _enterCapture(tester);
    await tester.tap(find.byKey(const Key('hamburgerMenuButton')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drawerRecords')));
    await tester.pumpAndSettle();
    expect(find.text('Lead A'), findsOneWidget);
  });
}
