import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/app.dart';
import 'package:foloo/widgets/auth_text_form_field.dart';

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
  if (find
      .byKey(const Key('emailOnboardingSkipButton'))
      .evaluate()
      .isNotEmpty) {
    final skip = find.byKey(const Key('emailOnboardingSkipButton'));
    await tester.ensureVisible(skip);
    await tester.tap(skip);
    await tester.pumpAndSettle();
  }
  final continueOrigin = find.byKey(const Key('originContinueButton'));
  await tester.ensureVisible(continueOrigin);
  await tester.tap(continueOrigin);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('validates empty login fields', (tester) async {
    await tester.pumpWidget(const FolooApp());
    await tester.pumpAndSettle();

    await tapLogin(tester);

    expect(find.text('Escribe tu correo'), findsOneWidget);
    expect(find.text('Escribe tu contraseña'), findsOneWidget);
    expect(find.byKey(const Key('hamburgerMenuButton')), findsNothing);
  });

  testWidgets('toggles password visibility without clearing it', (
    tester,
  ) async {
    await tester.pumpWidget(const FolooApp());
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();
    await enterDemoAccess(tester);
    await finishOnboarding(tester);

    await tester.enterText(find.byKey(const Key('nameField')), 'Borrador demo');
    await tester.tap(find.byKey(const Key('hamburgerMenuButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('drawerHome')), findsOneWidget);
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
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();

    final button = find.byKey(const Key('loginButton'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.getRect(button).bottom, lessThanOrEqualTo(568 - 260));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'normal iPhone login fits without scroll and matches auth shapes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const FolooApp());
      await tester.pumpAndSettle();

      final viewport = tester.widget<SingleChildScrollView>(
        find.byKey(const Key('loginScrollViewport')),
      );
      expect(viewport.physics, isA<NeverScrollableScrollPhysics>());
      expect(find.byKey(const Key('loginGoogleButton')), findsOneWidget);
      expect(find.byKey(const Key('loginMicrosoftButton')), findsOneWidget);
      expect(find.byKey(const Key('openSignUpButton')), findsOneWidget);
      expect(find.byKey(const Key('loginButton')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('languageEs'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('loginLogo'))).dy),
      );
      expect(
        tester.widget<Image>(find.byKey(const Key('loginLogo'))).width,
        235,
      );
      expect(
        tester.getRect(find.byKey(const Key('openSignUpButton'))).bottom,
        lessThan(tester.getRect(find.byKey(const Key('loginButton'))).top),
      );
      final createAccount = tester.widget<OutlinedButton>(
        find.byKey(const Key('openSignUpButton')),
      );
      expect(createAccount.style?.shape?.resolve({}), isA<StadiumBorder>());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('create account keeps social and primary actions rounded', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FolooApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('openSignUpButton')));
    await tester.pumpAndSettle();

    for (final key in const [
      Key('signUpGoogleButton'),
      Key('signUpMicrosoftButton'),
    ]) {
      final button = tester.widget<OutlinedButton>(find.byKey(key));
      expect(button.style?.shape?.resolve({}), isA<StadiumBorder>());
    }
    final primary = tester.widget<FilledButton>(
      find.byKey(const Key('signUpButton')),
    );
    expect(primary.style?.shape?.resolve({}), isA<StadiumBorder>());
    expect(find.byKey(const Key('signUpEmailField')), findsOneWidget);
    expect(find.byKey(const Key('signUpPasswordField')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Auth inputs share subtle idle and emphasized focused borders', (
    tester,
  ) async {
    await tester.pumpWidget(const FolooApp());
    await tester.pumpAndSettle();

    final loginField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('loginEmailField')),
        matching: find.byType(TextField),
      ),
    );
    final loginDecoration = loginField.decoration!;
    final idle = loginDecoration.enabledBorder! as OutlineInputBorder;
    final focused = loginDecoration.focusedBorder! as OutlineInputBorder;
    expect(idle.borderSide.width, 1);
    expect(focused.borderSide.width, 2);
    expect(idle.borderSide.color, isNot(focused.borderSide.color));
    expect(
      loginDecoration.contentPadding,
      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    );
    expect(loginField.contextMenuBuilder, folooAuthContextMenuBuilder);

    await tester.tap(find.byKey(const Key('openSignUpButton')));
    await tester.pumpAndSettle();
    final signUpField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('signUpEmailField')),
        matching: find.byType(TextField),
      ),
    );
    expect(
      signUpField.decoration!.contentPadding,
      loginDecoration.contentPadding,
    );
    expect(
      (signUpField.decoration!.enabledBorder! as OutlineInputBorder)
          .borderSide
          .width,
      idle.borderSide.width,
    );
    expect(signUpField.contextMenuBuilder, folooAuthContextMenuBuilder);
  });

  testWidgets('rapid Login focus changes preserve fields and editable states', (
    tester,
  ) async {
    await tester.pumpWidget(const FolooApp());
    await tester.pumpAndSettle();
    final email = find.byKey(const Key('loginEmailField'));
    final password = find.byKey(const Key('loginPasswordField'));

    await tester.tap(email);
    await tester.tap(email);
    await tester.enterText(email, 'seller@example.com');
    final emailState = tester.state<EditableTextState>(
      find.descendant(of: email, matching: find.byType(EditableText)),
    );
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: password, matching: find.byType(EditableText)),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );
    await tester.tap(email);
    await tester.tap(password);
    await tester.tap(password);
    await tester.enterText(password, 'secret');

    expect(
      tester.state<EditableTextState>(
        find.descendant(of: email, matching: find.byType(EditableText)),
      ),
      same(emailState),
    );
    expect(
      tester.widget<TextFormField>(email).controller!.text,
      'seller@example.com',
    );
    expect(tester.widget<TextFormField>(password).controller!.text, 'secret');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile name and company keep stable focus and shared styling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const FolooApp());
    await tester.pumpAndSettle();
    await enterDemoAccess(tester);
    final name = find.byKey(const Key('profileNameField'));
    final company = find.byKey(const Key('profileCompanyField'));

    await tester.tap(name);
    await tester.tap(name);
    await tester.enterText(name, 'Mariana Ruiz');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: company, matching: find.byType(EditableText)),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );
    await tester.ensureVisible(name);
    await tester.tap(name);
    await tester.ensureVisible(company);
    await tester.tap(company);
    await tester.tap(company);
    await tester.enterText(company, 'Lácteos Norte');

    for (final finder in [name, company]) {
      final field = tester.widget<TextField>(
        find.descendant(of: finder, matching: find.byType(TextField)),
      );
      expect(field.contextMenuBuilder, folooAuthContextMenuBuilder);
      expect(
        field.decoration!.contentPadding,
        const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      );
    }
    expect(tester.widget<TextFormField>(name).controller!.text, 'Mariana Ruiz');
    expect(
      tester.widget<TextFormField>(company).controller!.text,
      'Lácteos Norte',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login keeps one EditableText tree when keyboard opens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(const FolooApp());
    await tester.pumpAndSettle();
    final editable = find.descendant(
      of: find.byKey(const Key('loginEmailField')),
      matching: find.byType(EditableText),
    );
    final before = tester.state<EditableTextState>(editable);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    final viewport = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('loginScrollViewport')),
    );

    expect(viewport.physics, isA<ClampingScrollPhysics>());
    expect(tester.state<EditableTextState>(editable), same(before));
    expect(tester.takeException(), isNull);
  });
}
