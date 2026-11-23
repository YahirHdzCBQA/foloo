import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/app.dart';
import 'package:foloo/auth/auth_models.dart';
import 'package:foloo/auth/auth_repository.dart';
import 'package:foloo/auth/auth_service.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/sync/sync_models.dart';

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

class _OwnerSession implements SyncSessionProvider {
  const _OwnerSession();

  @override
  Future<String?> accessTokenFor(String ownerSub) async => 'token:$ownerSub';
}

class _ProfileResolutionApi implements SyncApi {
  _ProfileResolutionApi({this.profileGate});

  final Completer<void>? profileGate;
  final Map<String, Map<String, Object?>?> profiles = {};
  bool failProfile = false;
  int profileReads = 0;

  @override
  Future<SyncResponse> send(String accessToken, SyncRequest request) async {
    final ownerSub = accessToken.substring('token:'.length);
    if (request.path == '/v1/profile') {
      profileReads += 1;
      final gate = profileGate;
      if (gate != null && !gate.isCompleted) await gate.future;
      if (failProfile) throw const SyncTransportException();
      return SyncResponse(statusCode: 200, data: {'data': profiles[ownerSub]});
    }
    if (request.path == '/v1/events' ||
        request.path == '/v1/leads' ||
        request.path == '/v1/content' ||
        request.path == '/v1/email/templates' ||
        request.path == '/v1/email/event-templates' ||
        request.path == '/v1/email/follow-ups') {
      return const SyncResponse(statusCode: 200, data: {'data': []});
    }
    return const SyncResponse(statusCode: 200, data: {'data': null});
  }
}

Future<void> _submitLogin(WidgetTester tester, String email) async {
  await tester.enterText(find.byKey(const Key('loginEmailField')), email);
  await tester.enterText(
    find.byKey(const Key('loginPasswordField')),
    'password',
  );
  await tester.tap(find.byKey(const Key('loginButton')));
  await tester.pump();
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

  testWidgets(
    'AUT-07 delayed remote profile never renders onboarding before origin',
    (tester) async {
      final profileGate = Completer<void>();
      final api = _ProfileResolutionApi(profileGate: profileGate)
        ..profiles['cognito-sub-remote'] = {
          'name': 'Remote seller',
          'company': 'Foloo',
          'updatedAt': '2026-11-23T12:00:00.000Z',
        };
      final service = _FlowAuthService()
        ..signedIn = const AuthUser(
          id: 'cognito-sub-remote',
          username: 'remote@example.com',
        );
      await tester.pumpWidget(
        FolooApp(
          authRepository: AuthRepository(service),
          persistence: LocalPersistence.inMemory(),
          useDemoFixtures: false,
          syncApi: api,
          syncSessionProvider: const _OwnerSession(),
        ),
      );
      await tester.pumpAndSettle();

      await _submitLogin(tester, 'remote@example.com');
      await tester.pump(const Duration(seconds: 3));

      expect(
        find.byKey(const ValueKey('authenticatedStateLoading')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('profileScreen')), findsNothing);
      expect(find.byKey(const ValueKey('originScreen')), findsNothing);

      profileGate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profileScreen')), findsNothing);
      expect(find.byKey(const ValueKey('originScreen')), findsOneWidget);
    },
  );

  testWidgets(
    'AUT-07 confirmed remote absence opens onboarding after resolution',
    (tester) async {
      final api = _ProfileResolutionApi()
        ..profiles['cognito-sub-incomplete'] = null;
      final service = _FlowAuthService()
        ..signedIn = const AuthUser(
          id: 'cognito-sub-incomplete',
          username: 'incomplete@example.com',
        );
      await tester.pumpWidget(
        FolooApp(
          authRepository: AuthRepository(service),
          persistence: LocalPersistence.inMemory(),
          useDemoFixtures: false,
          syncApi: api,
          syncSessionProvider: const _OwnerSession(),
        ),
      );
      await tester.pumpAndSettle();

      await _submitLogin(tester, 'incomplete@example.com');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('profileScreen')), findsOneWidget);
      expect(api.profileReads, greaterThanOrEqualTo(1));
    },
  );

  testWidgets(
    'AUT-07 transient profile failure is retryable and not onboarding',
    (tester) async {
      final api = _ProfileResolutionApi()
        ..failProfile = true
        ..profiles['cognito-sub-retry'] = {
          'name': 'Recovered seller',
          'company': 'Foloo',
          'updatedAt': '2026-11-23T12:00:00.000Z',
        };
      final service = _FlowAuthService()
        ..signedIn = const AuthUser(
          id: 'cognito-sub-retry',
          username: 'retry@example.com',
        );
      await tester.pumpWidget(
        FolooApp(
          authRepository: AuthRepository(service),
          persistence: LocalPersistence.inMemory(),
          useDemoFixtures: false,
          syncApi: api,
          syncSessionProvider: const _OwnerSession(),
        ),
      );
      await tester.pumpAndSettle();

      await _submitLogin(tester, 'retry@example.com');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('profileResolutionError')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('profileScreen')), findsNothing);

      api.failProfile = false;
      await tester.tap(find.byKey(const Key('retryProfileResolutionButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('originScreen')), findsOneWidget);
      expect(find.byKey(const ValueKey('profileScreen')), findsNothing);
    },
  );

  testWidgets(
    'AUT-07 account B remote profile replaces A without transient onboarding',
    (tester) async {
      final persistence = LocalPersistence.inMemory();
      await persistence.profiles.save(
        'cognito-sub-a',
        const DemoProfile(name: 'Seller A', company: 'Company A'),
      );
      final profileGate = Completer<void>();
      final api = _ProfileResolutionApi(profileGate: profileGate)
        ..profiles['cognito-sub-b'] = {
          'name': 'Seller B',
          'company': 'Company B',
          'updatedAt': '2026-11-23T12:00:00.000Z',
        };
      final service = _FlowAuthService()
        ..restored = const AuthUser(
          id: 'cognito-sub-a',
          username: 'a@example.com',
        );
      await tester.pumpWidget(
        FolooApp(
          authRepository: AuthRepository(service),
          persistence: persistence,
          useDemoFixtures: false,
          syncApi: api,
          syncSessionProvider: const _OwnerSession(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('originScreen')), findsOneWidget);

      await tester.tap(find.byKey(const Key('hamburgerMenuButton')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('logoutButton')));
      await tester.pumpAndSettle();

      service.signedIn = const AuthUser(
        id: 'cognito-sub-b',
        username: 'b@example.com',
      );
      await _submitLogin(tester, 'b@example.com');
      await tester.pump(const Duration(seconds: 3));
      expect(
        find.byKey(const ValueKey('authenticatedStateLoading')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('profileScreen')), findsNothing);

      profileGate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('originScreen')), findsOneWidget);
      expect(find.byKey(const ValueKey('profileScreen')), findsNothing);
    },
  );

  testWidgets(
    'AUT-07 late profile response after logout cannot change navigation',
    (tester) async {
      final profileGate = Completer<void>();
      final api = _ProfileResolutionApi(profileGate: profileGate)
        ..profiles['cognito-sub-late'] = {
          'name': 'Late seller',
          'company': 'Foloo',
          'updatedAt': '2026-11-23T12:00:00.000Z',
        };
      final service = _FlowAuthService()
        ..signedIn = const AuthUser(
          id: 'cognito-sub-late',
          username: 'late@example.com',
        );
      final repository = AuthRepository(service);
      await tester.pumpWidget(
        FolooApp(
          authRepository: repository,
          persistence: LocalPersistence.inMemory(),
          useDemoFixtures: false,
          syncApi: api,
          syncSessionProvider: const _OwnerSession(),
        ),
      );
      await tester.pumpAndSettle();

      await _submitLogin(tester, 'late@example.com');
      await repository.signOut();
      await tester.pump();
      profileGate.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('loginScreen')), findsOneWidget);
      expect(find.byKey(const ValueKey('profileScreen')), findsNothing);
      expect(find.byKey(const ValueKey('originScreen')), findsNothing);
    },
  );
}
