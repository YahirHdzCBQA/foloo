import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/app.dart';
import 'package:foloo/auth/auth_models.dart';
import 'package:foloo/auth/auth_repository.dart';
import 'package:foloo/auth/auth_service.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/models/session_lead.dart';
import 'package:foloo/services/connectivity_service.dart';
import 'package:foloo/sync/sync_models.dart';

class _FakeConnectivityService implements ConnectivityService {
  _FakeConnectivityService(this.connected);

  bool connected;
  final controller = StreamController<bool>.broadcast();

  @override
  Stream<bool> get changes => controller.stream;

  @override
  Future<bool> isConnected() async => connected;

  void emit(bool value) {
    connected = value;
    controller.add(value);
  }
}

class _RestoredAuthService implements AuthService {
  static const user = AuthUser(id: 'connectivity-owner', username: 'qa');

  @override
  Future<AuthUser?> restoreSession() async => user;

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
  }) async => user;

  @override
  Future<void> signOut() async {}
}

class _RecoveringApi implements SyncApi {
  _RecoveringApi({this.failWritesRemaining = 1});

  int failWritesRemaining;
  int writes = 0;
  final writePaths = <String>[];

  @override
  Future<SyncResponse> send(String accessToken, SyncRequest request) async {
    if (request.method != 'GET') {
      writes += 1;
      writePaths.add(request.path);
      if (failWritesRemaining > 0) {
        failWritesRemaining -= 1;
        throw const SyncTransportException();
      }
      return const SyncResponse(statusCode: 201, data: {'data': {}});
    }
    return const SyncResponse(statusCode: 200, data: {'data': []});
  }
}

class _Session implements SyncSessionProvider {
  @override
  Future<String?> accessTokenFor(String ownerSub) async => 'token';
}

void main() {
  testWidgets(
    'SYN-05 connectivity indicator follows device transport changes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final connectivity = _FakeConnectivityService(false);
      addTearDown(connectivity.controller.close);
      await tester.pumpWidget(FolooApp(connectivityService: connectivity));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('loginEmailField')), 'qa');
      await tester.enterText(
        find.byKey(const Key('loginPasswordField')),
        'demo',
      );
      await tester.tap(find.byKey(const Key('loginButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profileContinueButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('originContinueButton')));
      await tester.pumpAndSettle();

      expect(find.text('SIN CONEXIÓN'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

      connectivity.emit(true);
      await tester.pumpAndSettle();
      expect(find.text('EN LÍNEA'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_rounded), findsOneWidget);

      connectivity.emit(false);
      await tester.pumpAndSettle();
      expect(find.text('SIN CONEXIÓN'), findsOneWidget);
    },
  );

  testWidgets(
    'SYN-05 connectivity recovery drains retryable outbox without restart',
    (tester) async {
      final persistence = LocalPersistence.inMemory();
      final connectivity = _FakeConnectivityService(false);
      addTearDown(connectivity.controller.close);
      await persistence.syncStore.enqueue(
        ownerSub: _RestoredAuthService.user.id,
        entityType: SyncEntityType.lead,
        entityId: '70707070-7070-4070-8070-707070707070',
        action: 'create',
        payload: const {
          'id': '70707070-7070-4070-8070-707070707070',
          'capturedAt': '2026-09-10T12:00:00.000Z',
          'origin': 'direct',
          'eventId': null,
          'place': 'Monterrey',
          'firstName': 'Offline',
          'lastName': 'Lead',
          'position': null,
          'company': 'Foloo',
          'email': 'offline@example.com',
          'phone': null,
          'leadType': 'customer',
          'interest': 'medium',
          'writtenNote': null,
          'commercialFolio': null,
        },
      );
      final api = _RecoveringApi(failWritesRemaining: 2);
      var now = DateTime.utc(2026, 9, 10, 12);

      await tester.pumpWidget(
        FolooApp(
          persistence: persistence,
          useDemoFixtures: false,
          connectivityService: connectivity,
          authRepository: AuthRepository(_RestoredAuthService()),
          syncApi: api,
          syncSessionProvider: _Session(),
          nowProvider: () => now,
        ),
      );
      await tester.pumpAndSettle();

      final deferred = (await persistence.syncStore.all(
        _RestoredAuthService.user.id,
      )).single;
      expect(deferred.status, 'retryable');
      expect(deferred.nextAttemptAt!.isAfter(now), isTrue);

      connectivity.emit(true);
      await tester.pumpAndSettle();
      now = now.add(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(
        await persistence.syncStore.all(_RestoredAuthService.user.id),
        isEmpty,
      );
      expect(api.writes, 3);
    },
  );

  testWidgets('SYN-05 online lead save triggers immediate sync', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final persistence = LocalPersistence.inMemory();
    await persistence.profiles.save(
      _RestoredAuthService.user.id,
      const DemoProfile(name: 'Seller', company: 'Foloo'),
    );
    final connectivity = _FakeConnectivityService(true);
    addTearDown(connectivity.controller.close);
    final api = _RecoveringApi(failWritesRemaining: 0);

    await tester.pumpWidget(
      FolooApp(
        persistence: persistence,
        useDemoFixtures: false,
        connectivityService: connectivity,
        authRepository: AuthRepository(_RestoredAuthService()),
        syncApi: api,
        syncSessionProvider: _Session(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('originDirectTab')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('originPlaceField')),
      'Monterrey',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('originContinueButton')));
    await tester.tap(find.byKey(const Key('originContinueButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nameField')), 'Online Lead');
    await tester.enterText(find.byKey(const Key('companyField')), 'Foloo');
    await tester.enterText(
      find.byKey(const Key('emailField')),
      'online@example.com',
    );
    final customer = find.byKey(const Key('leadType-customer'));
    await tester.dragUntilVisible(
      customer,
      find.byType(SingleChildScrollView),
      const Offset(0, -250),
    );
    await tester.tap(customer);
    await tester.ensureVisible(find.byKey(const Key('saveLeadButton')));
    await tester.tap(find.byKey(const Key('saveLeadButton')));
    await tester.pumpAndSettle();

    expect(api.writePaths, contains('/v1/leads'));
    expect(
      await persistence.syncStore.all(_RestoredAuthService.user.id),
      isEmpty,
    );
    expect(
      (await persistence.leads.listAll(_RestoredAuthService.user.id))
          .single
          .uploadState,
      SessionUploadState.synced,
    );
  });
}
