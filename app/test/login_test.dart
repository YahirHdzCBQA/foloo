import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/app.dart';

Future<void> tapLogin(WidgetTester tester) async {
  final button = find.byKey(const Key('loginButton'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> enterDemoAccess(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('loginEmailField')),
    'demo@foloo.example',
  );
  await tester.enterText(find.byKey(const Key('loginPasswordField')), 'demo');
  await tapLogin(tester);
}

Future<void> finishOnboarding(WidgetTester tester) async {
  if (find.byKey(const Key('profileContinueButton')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('profileContinueButton')));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const Key('originContinueButton')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('validates empty login fields', (tester) async {
    await tester.pumpWidget(const FolooApp());

    await tapLogin(tester);

    expect(find.text('Escribe tu usuario'), findsOneWidget);
    expect(find.text('Escribe tu contraseña'), findsOneWidget);
    expect(find.byKey(const Key('hamburgerMenuButton')), findsNothing);
  });

  testWidgets('toggles password visibility without clearing it', (
    tester,
  ) async {
    await tester.pumpWidget(const FolooApp());
    await tester.enterText(
      find.byKey(const Key('loginPasswordField')),
      'secreto',
    );

    EditableText passwordField() => tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('loginPasswordField')),
        matching: find.byType(EditableText),
      ),
    );

    expect(passwordField().obscureText, isTrue);
    await tester.tap(find.byKey(const Key('passwordVisibilityButton')));
    await tester.pump();
    expect(passwordField().obscureText, isFalse);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('loginPasswordField')))
          .controller
          ?.text,
      'secreto',
    );
  });

  testWidgets('valid demo login opens profile, origin and lead capture', (
    tester,
  ) async {
    await tester.pumpWidget(const FolooApp());
    await enterDemoAccess(tester);
    expect(find.byKey(const ValueKey('profileScreen')), findsOneWidget);
    expect(find.byKey(const Key('profileCameraButton')), findsOneWidget);
    expect(find.byKey(const Key('profileGalleryButton')), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).width, 56);
    await finishOnboarding(tester);
    expect(find.byKey(const Key('cardSection')), findsOneWidget);
    expect(find.byKey(const Key('hamburgerMenuButton')), findsOneWidget);
    expect(find.byKey(const Key('loginButton')), findsNothing);
  });

  testWidgets('drawer logout returns to clean login and clears draft', (
    tester,
  ) async {
    await tester.pumpWidget(const FolooApp());
    await enterDemoAccess(tester);
    await finishOnboarding(tester);

    await tester.enterText(find.byKey(const Key('nameField')), 'Borrador demo');
    await tester.tap(find.byKey(const Key('hamburgerMenuButton')));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);

    await tester.tap(find.byKey(const Key('logoutButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('loginButton')), findsOneWidget);
    expect(find.byKey(const Key('cardSection')), findsNothing);

    await enterDemoAccess(tester);
    await finishOnboarding(tester);
    final nameField = tester.widget<TextFormField>(
      find.byKey(const Key('nameField')),
    );
    expect(nameField.controller?.text, isEmpty);
  });

  testWidgets('login stays scrollable on a compact viewport with keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(const FolooApp());
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('loginButton'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.getRect(button).bottom, lessThanOrEqualTo(568 - 260));
    expect(tester.takeException(), isNull);
  });
}
