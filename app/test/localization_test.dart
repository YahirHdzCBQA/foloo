import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/app.dart';
import 'package:foloo/l10n/app_localizations_en.dart';
import 'package:foloo/l10n/app_localizations_es.dart';

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> enterShell(WidgetTester tester, {bool pro = false}) async {
  if (pro) await tester.tap(find.byKey(const Key('planPro')));
  await tester.enterText(find.byKey(const Key('loginEmailField')), 'qa');
  await tester.enterText(find.byKey(const Key('loginPasswordField')), 'demo');
  await tester.tap(find.byKey(const Key('loginButton')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('profileContinueButton')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('originContinueButton')));
  await tester.pumpAndSettle();
}

Future<void> openDrawer(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('hamburgerMenuButton')).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Spanish is the unsupported-locale fallback', (tester) async {
    await tester.pumpWidget(const FolooApp(initialLocale: Locale('fr')));
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('Login switches ES to EN immediately', (tester) async {
    phone(tester);
    await tester.pumpWidget(const FolooApp());
    expect(find.text('Entrar'), findsOneWidget);

    await tester.tap(find.byKey(const Key('languageEn')));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Entrar'), findsNothing);

    await tester.tap(find.byKey(const Key('languageEs')));
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('Drawer and capture share one English locale state', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(const FolooApp());
    await tester.tap(find.byKey(const Key('languageEn')));
    await enterShell(tester);
    expect(find.text('The card'), findsOneWidget);
    expect(find.text('Lead details'), findsOneWidget);
    expect(find.text('Lead type'), findsOneWidget);
    expect(find.text('Supplier'), findsOneWidget);
    expect(find.text('Low'), findsOneWidget);
    expect(find.text('Conversation note'), findsOneWidget);
    expect(find.text('Voice note (optional)'), findsOneWidget);
    expect(find.text('La tarjeta'), findsNothing);
    expect(find.text('Datos del lead'), findsNothing);
    expect(find.text('Tipo de Lead'), findsNothing);
    expect(find.text('Nota de la plática'), findsNothing);

    await openDrawer(tester);
    expect(find.text('Records'), findsOneWidget);
    expect(find.text('My events'), findsOneWidget);
    expect(find.byKey(const Key('drawerContent')), findsNothing);

    await tester.tap(find.byKey(const Key('languageEs')));
    await tester.pumpAndSettle();
    expect(find.text('Registros'), findsOneWidget);
    expect(find.text('Records'), findsNothing);
  });

  testWidgets('Pro destinations are localized but remain Pro-only', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(const FolooApp(initialLocale: Locale('en')));
    await enterShell(tester, pro: true);
    await openDrawer(tester);
    expect(find.text('Content'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);

    await tester.tap(find.byKey(const Key('drawerContent')));
    await tester.pumpAndSettle();
    expect(find.text('Content'), findsOneWidget);
    expect(find.text('Upload PDF'), findsOneWidget);

    await tester.tap(find.byKey(const Key('moduleBackButton')));
    await tester.pumpAndSettle();
    await openDrawer(tester);
    await tester.tap(find.byKey(const Key('drawerEmail')));
    await tester.pumpAndSettle();
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Subject'), findsOneWidget);
    expect(find.text('Body'), findsOneWidget);
    expect(find.text('Variables'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
  });

  testWidgets('English records and events remain consistently localized', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(const FolooApp(initialLocale: Locale('en')));
    await enterShell(tester);
    await openDrawer(tester);
    await tester.tap(find.byKey(const Key('drawerRecords')));
    await tester.pumpAndSettle();
    expect(find.text('Records'), findsOneWidget);
    expect(find.text('Search by name or company'), findsOneWidget);
    expect(find.text('Registros'), findsNothing);

    await openDrawer(tester);
    await tester.tap(find.byKey(const Key('drawerEvents')));
    await tester.pumpAndSettle();
    expect(find.text('My events'), findsOneWidget);
    expect(find.text('Create event'), findsOneWidget);
    expect(find.text('Mis eventos'), findsNothing);
  });

  test('pluralized event counts use the active language', () {
    final es = AppLocalizationsEs();
    final en = AppLocalizationsEn();
    expect(es.eventCount(1), '1 evento');
    expect(es.eventCount(2), '2 eventos');
    expect(en.eventCount(1), '1 event');
    expect(en.eventCount(2), '2 events');
  });
}
