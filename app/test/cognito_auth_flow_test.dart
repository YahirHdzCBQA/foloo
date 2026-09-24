import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/app.dart';
import 'package:foloo/auth/auth_models.dart';
import 'package:foloo/auth/auth_repository.dart';
import 'package:foloo/auth/auth_service.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/models/app_event.dart';

class _FlowAuthService implements AuthService {
  AuthUser? restored;
  AuthUser signedIn = const AuthUser(
    id: 'cognito-sub-flow',
    username: 'signed-in@example.com',
  );
  bool failCode = false;

  @override
  Future<AuthUser?> restoreSession() async => restored;

  @override
  Future<AuthSignUpResult> signUp({
    required String email,
    required String password,
  }) async => const AuthSignUpResult(confirmationRequired: true);

  @override
  Future<void> confirmSignUp({
    required String email,
    required String code,
  }) async {
    if (failCode) {
      throw const FolooAuthException(AuthFailureCode.invalidConfirmationCode);
    }
  }

  @override
  Future<void> resendSignUpCode({required String email}) async {}

  @override
  Future<AuthUser> signIn({
    required String username,
    required String password,
  }) async => signedIn;

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('AUT-10/AUT-11 account creation reaches confirmation and login', (
    tester,
  ) async {
    final service = _FlowAuthService();
    await tester.pumpWidget(FolooApp(authRepository: AuthRepository(service)));
    await tester.pumpAndSettle();

    final createAccount = find.byKey(const Key('openSignUpButton'));
    await tester.ensureVisible(createAccount);
    await tester.tap(createAccount);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('signUpScreen')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('signUpEmailField')),
      'new@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('signUpPasswordField')),
      'Strong-password-1',
    );
    await tester.tap(find.byKey(const Key('signUpButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('confirmationScreen')), findsOneWidget);

    service.failCode = true;
    await tester.enterText(
      find.byKey(const Key('confirmationCodeField')),
      '000000',
    );
    await tester.tap(find.byKey(const Key('confirmSignUpButton')));
    await tester.pumpAndSettle();
    expect(find.textContaining('código no es correcto'), findsOneWidget);

    service.failCode = false;
    await tester.tap(find.byKey(const Key('confirmSignUpButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('loginScreen')), findsOneWidget);
    expect(find.byKey(const Key('accountConfirmedMessage')), findsOneWidget);
  });

  testWidgets('AUT-04 missing Cognito-owned profile routes to profile setup', (
    tester,
  ) async {
    final service = _FlowAuthService()
      ..restored = const AuthUser(
        id: 'cognito-sub-no-profile',
        username: 'new@example.com',
      );
    await tester.pumpWidget(
      FolooApp(
        authRepository: AuthRepository(service),
        persistence: LocalPersistence.inMemory(),
        useDemoFixtures: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profileScreen')), findsOneWidget);
  });

  testWidgets('AUT-04 complete Cognito-owned profile skips profile setup', (
    tester,
  ) async {
    final persistence = LocalPersistence.inMemory();
    await persistence.profiles.save(
      'cognito-sub-profile',
      const DemoProfile(name: 'Seller', company: 'Foloo'),
    );
    final service = _FlowAuthService()
      ..restored = const AuthUser(
        id: 'cognito-sub-profile',
        username: 'seller@example.com',
      );
    await tester.pumpWidget(
      FolooApp(
        authRepository: AuthRepository(service),
        persistence: persistence,
        useDemoFixtures: false,
      ),
    );
    expect(
      find.byKey(const ValueKey('authenticatedStateLoading')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('profileScreen')), findsNothing);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profileScreen')), findsNothing);
    expect(find.byKey(const ValueKey('originScreen')), findsOneWidget);
  });

  testWidgets(
    'AUT-07 existing login resolves owner profile before rendering a route',
    (tester) async {
      final persistence = LocalPersistence.inMemory();
      await persistence.profiles.save(
        'cognito-sub-existing',
        const DemoProfile(name: 'Existing seller', company: 'Foloo'),
      );
      final service = _FlowAuthService()
        ..signedIn = const AuthUser(
          id: 'cognito-sub-existing',
          username: 'existing@example.com',
        );
      final hydration = Completer<void>();
      await tester.pumpWidget(
        FolooApp(
          authRepository: AuthRepository(service),
          persistence: persistence,
          useDemoFixtures: false,
          userStateLoadGate: (_) => hydration.future,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('loginEmailField')),
        'existing@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('loginPasswordField')),
        'password',
      );
      await tester.tap(find.byKey(const Key('loginButton')));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('authenticatedStateLoading')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('profileScreen')), findsNothing);

      hydration.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profileScreen')), findsNothing);
      expect(find.byKey(const ValueKey('originScreen')), findsOneWidget);
    },
  );

  testWidgets('AUT-07 new login reaches profile only after owner resolution', (
    tester,
  ) async {
    final service = _FlowAuthService()
      ..signedIn = const AuthUser(
        id: 'cognito-sub-new',
        username: 'new@example.com',
      );
    final hydration = Completer<void>();
    await tester.pumpWidget(
      FolooApp(
        authRepository: AuthRepository(service),
        persistence: LocalPersistence.inMemory(),
        useDemoFixtures: false,
        userStateLoadGate: (_) => hydration.future,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('loginEmailField')),
      'new@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('loginPasswordField')),
      'password',
    );
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pump();

    expect(find.byKey(const ValueKey('profileScreen')), findsNothing);
    expect(
      find.byKey(const ValueKey('authenticatedStateLoading')),
      findsOneWidget,
    );

    hydration.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profileScreen')), findsOneWidget);
  });
}
