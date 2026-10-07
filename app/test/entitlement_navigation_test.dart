import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/app.dart';
import 'package:foloo/auth/auth_models.dart';
import 'package:foloo/auth/auth_repository.dart';
import 'package:foloo/auth/auth_service.dart';
import 'package:foloo/data/local/app_database.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/models/app_event.dart';

class _RestoredAuthService implements AuthService {
  const _RestoredAuthService(this.owner);

  final String owner;

  @override
  Future<AuthUser?> restoreSession() async => AuthUser(
    id: owner,
    username: 'technical-$owner',
    email: '$owner@example.com',
  );

  @override
  Future<AuthSignUpResult> signUp({
    required String email,
    required String password,
  }) async => const AuthSignUpResult(confirmationRequired: true);

  @override
  Future<void> confirmSignUp({
    required String email,
    required String code,
  }) async {}

  @override
  Future<void> resendSignUpCode({required String email}) async {}

  @override
  Future<AuthUser> signIn({
    required String username,
    required String password,
  }) async => AuthUser(id: owner, username: username, email: username);

  @override
  Future<void> signOut() async {}
}

void main() {
  Future<LocalPersistence> persistenceFor(
    String owner,
    String status,
    int used,
  ) async {
    final persistence = LocalPersistence.inMemory();
    await persistence.profiles.save(
      owner,
      const DemoProfile(name: 'Seller', company: 'Foloo'),
    );
    await persistence.database.entitlementDao.saveSnapshot(
      LocalEntitlementsCompanion.insert(
        ownerUserId: owner,
        subscriptionStatus: status,
        trialLeadsUsed: used,
        serverUpdatedAt: Value(DateTime.utc(2026, 10, 6)),
        cachedAt: DateTime.utc(2026, 10, 6),
      ),
    );
    return persistence;
  }

  testWidgets('blocked owner reaches Paywall only when starting capture', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const owner = 'blocked-owner';
    final persistence = await persistenceFor(owner, 'trial_exhausted', 5);
    addTearDown(persistence.close);

    await tester.pumpWidget(
      FolooApp(
        persistence: persistence,
        authRepository: AuthRepository(const _RestoredAuthService(owner)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('originScreen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('originContinueButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paywallScreen')), findsOneWidget);
    expect(find.byKey(const Key('leadCaptureScreen')), findsNothing);

    await tester.tap(find.byKey(const Key('paywallViewRecords')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recordsScreen')), findsOneWidget);
  });

  testWidgets('trial owner with balance enters capture without Paywall', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const owner = 'trial-owner';
    final persistence = await persistenceFor(owner, 'trial', 4);
    addTearDown(persistence.close);

    await tester.pumpWidget(
      FolooApp(
        persistence: persistence,
        authRepository: AuthRepository(const _RestoredAuthService(owner)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('originContinueButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('leadCaptureScreen')), findsOneWidget);
    expect(find.byKey(const ValueKey('paywallScreen')), findsNothing);
  });
}
