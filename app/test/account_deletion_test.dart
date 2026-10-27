/// Synthetic STORE-02 widget and owner-scoped purge coverage (E-14).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/l10n/app_localizations.dart';
import 'package:foloo/screens/account_deletion_screen.dart';
import 'package:foloo/services/account_deletion_service.dart';
import 'package:foloo/services/local_account_deletion_purger.dart';
import 'package:foloo/sync/sync_models.dart';
import 'package:foloo/theme/foloo_theme.dart';

class FakeDeletionService implements AccountDeletionService {
  FakeDeletionService({
    this.recent = true,
    this.pending = 0,
    this.failFirstConfirmation = false,
    this.confirmationError,
  });

  bool recent;
  int pending;
  int confirmations = 0;
  bool failFirstConfirmation;
  String? confirmationError;
  final confirmationIdempotencyKeys = <String>[];
  int preflights = 0;

  @override
  Future<AccountDeletionProgress> statusByReceipt(String receipt) async =>
      AccountDeletionProgress(
        requestId: '00000000-0000-4000-8000-000000000222',
        status: AccountDeletionStatus.inProgress,
        updatedAt: DateTime.utc(2032),
      );

  @override
  Future<bool> hasRecentAuthentication(String ownerSub) async => recent;

  @override
  Future<AccountDeletionPreflight> createPreflight({
    required String ownerSub,
    required String locale,
    required bool requestedExport,
    required String idempotencyKey,
  }) async {
    preflights += 1;
    return AccountDeletionPreflight(
      requestId: '00000000-0000-4000-8000-000000000222',
      pendingSyncCount: pending,
      exportAvailable: true,
      subscriptionCancellationRequired: false,
    );
  }

  @override
  Future<AccountDeletionAccepted> confirm({
    required String ownerSub,
    required String requestId,
    required bool discardUnsyncedAccepted,
    required bool cancelRenewalAccepted,
    required String idempotencyKey,
  }) async {
    confirmations += 1;
    confirmationIdempotencyKeys.add(idempotencyKey);
    if (failFirstConfirmation && confirmations == 1) {
      throw const AccountDeletionServiceException('network');
    }
    if (confirmationError != null) {
      throw AccountDeletionServiceException(confirmationError!);
    }
    return const AccountDeletionAccepted(
      requestId: '00000000-0000-4000-8000-000000000222',
      receipt: 'synthetic-receipt-not-a-real-credential',
      status: AccountDeletionStatus.requested,
    );
  }
}

class _StatusApi implements SyncApi {
  String? token;
  SyncRequest? request;

  @override
  Future<SyncResponse> send(String accessToken, SyncRequest request) async {
    token = accessToken;
    this.request = request;
    return const SyncResponse(
      statusCode: 200,
      data: {
        'data': {
          'requestId': '00000000-0000-4000-8000-000000000222',
          'status': 'completed',
          'updatedAt': '2032-01-01T00:00:00.000Z',
          'completedAt': '2032-01-01T00:00:00.000Z',
          'supportCode': null,
        },
      },
    );
  }
}

class _NoSession implements SyncSessionProvider {
  @override
  Future<String?> accessTokenFor(String ownerSub) async => null;
}

class _StaticSession implements SyncSessionProvider {
  @override
  Future<String?> accessTokenFor(String ownerSub) async =>
      'synthetic-access-token';
}

class _RejectedApi implements SyncApi {
  @override
  Future<SyncResponse> send(String accessToken, SyncRequest request) async {
    throw const SyncHttpException(401, errorCode: 'unauthenticated');
  }
}

Widget harness(
  FakeDeletionService service, {
  Future<void> Function()? accepted,
  Future<void> Function()? reauthenticate,
  bool prepareImmediately = false,
}) {
  return MaterialApp(
    theme: FolooTheme.light,
    locale: const Locale('es'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: AccountDeletionScreen(
      ownerSub: 'synthetic-owner-a',
      service: service,
      onExport: () async {},
      onSynchronize: () async {},
      pendingSyncCount: () async => 0,
      onReauthenticate: reauthenticate ?? () async {},
      onAccepted: (_) => accepted?.call() ?? Future.value(),
      prepareImmediately: prepareImmediately,
    ),
  );
}

void main() {
  test(
    'AUT-21 receipt status remains available after Cognito logout',
    () async {
      final api = _StatusApi();
      final service = ApiAccountDeletionService(api, _NoSession());

      final progress = await service.statusByReceipt(
        List.filled(43, 'r').join(),
      );

      expect(progress.status, AccountDeletionStatus.completed);
      expect(api.token, isEmpty);
      expect(api.request?.path, '/v1/account-deletion-status');
    },
  );

  test('AUT-19 preserves backend authentication error codes', () async {
    final service = ApiAccountDeletionService(_RejectedApi(), _StaticSession());

    await expectLater(
      service.confirm(
        ownerSub: 'synthetic-owner-a',
        requestId: '00000000-0000-4000-8000-000000000222',
        discardUnsyncedAccepted: false,
        cancelRenewalAccepted: false,
        idempotencyKey: 'synthetic-idempotency-key',
      ),
      throwsA(
        isA<AccountDeletionServiceException>().having(
          (error) => error.code,
          'code',
          'unauthenticated',
        ),
      ),
    );
  });

  testWidgets('AUT-19 unauthenticated confirmation offers reauthentication', (
    tester,
  ) async {
    var requested = false;
    final service = FakeDeletionService(confirmationError: 'unauthenticated');
    await tester.pumpWidget(
      harness(service, reauthenticate: () async => requested = true),
    );
    await tester.tap(find.byKey(const Key('accountDeletionPrepare')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('accountDeletionIrreversible')));
    await tester.pump();
    final confirm = find.byKey(const Key('accountDeletionConfirm'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(service.confirmations, 1);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('accountDeletionReauthenticate')), findsOne);
    await tester.tap(find.byKey(const Key('accountDeletionReauthenticate')));
    await tester.pumpAndSettle();
    expect(requested, true);
  });

  testWidgets('AUT-19 resumed flow verifies reauthentication immediately', (
    tester,
  ) async {
    final service = FakeDeletionService();
    await tester.pumpWidget(harness(service, prepareImmediately: true));
    await tester.pumpAndSettle();
    expect(service.preflights, 1);
    expect(find.byKey(const Key('accountDeletionConfirm')), findsOneWidget);
  });

  testWidgets('AUT-19 reauthentication remains an explicit user action', (
    tester,
  ) async {
    var requested = false;
    await tester.pumpWidget(
      harness(
        FakeDeletionService(recent: false),
        reauthenticate: () async => requested = true,
      ),
    );
    await tester.tap(find.byKey(const Key('accountDeletionPrepare')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('accountDeletionReauthenticate')));
    await tester.pumpAndSettle();
    expect(requested, true);
  });

  testWidgets('AUT-18 requires recent authentication before confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(harness(FakeDeletionService(recent: false)));
    await tester.tap(find.byKey(const Key('accountDeletionPrepare')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('accountDeletionError')), findsOneWidget);
    expect(find.byKey(const Key('accountDeletionConfirm')), findsNothing);
  });

  testWidgets(
    'SYN-11 requires explicit loss consent for pending local changes',
    (tester) async {
      final service = FakeDeletionService(pending: 3);
      var accepted = false;
      await tester.pumpWidget(
        harness(service, accepted: () async => accepted = true),
      );
      await tester.tap(find.byKey(const Key('accountDeletionPrepare')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      final confirm = find.byKey(const Key('accountDeletionConfirm'));
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.tap(find.byKey(const Key('accountDeletionDiscardUnsynced')));
      await tester.tap(find.byKey(const Key('accountDeletionIrreversible')));
      await tester.pump();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(service.confirmations, 1);
      expect(accepted, true);
    },
  );

  testWidgets('RNF-10 confirmation retries reuse the same idempotency key', (
    tester,
  ) async {
    final service = FakeDeletionService(failFirstConfirmation: true);
    await tester.pumpWidget(harness(service));
    await tester.tap(find.byKey(const Key('accountDeletionPrepare')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('accountDeletionIrreversible')));
    await tester.pump();
    final confirm = find.byKey(const Key('accountDeletionConfirm'));
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(service.confirmations, 2);
    expect(service.confirmationIdempotencyKeys.toSet(), hasLength(1));
  });

  test(
    'SYN-12 local purge removes only the accepted owner and managed files',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'foloo_deletion_test_',
      );
      final outside = await File(
        '${Directory.systemTemp.path}/foloo_other_owner_file.txt',
      ).writeAsString('preserve');
      final persistence = LocalPersistence.inMemory(mediaRoot: root);
      final ownerFile = await File('${root.path}/owner-a.jpg')
          .writeAsString('synthetic');
      try {
        final db = persistence.database;
        final now = DateTime(2032).millisecondsSinceEpoch ~/ 1000;
        await db.customStatement(
          'INSERT INTO local_profiles '
          '(local_id,owner_user_id,name,company,created_at,updated_at,sync_state) '
          "VALUES (?,?,?,?,?,?, 'synced')",
          ['profile-a', 'owner-a', 'A', 'A', now, now],
        );
        await db.customStatement(
          'INSERT INTO local_profiles '
          '(local_id,owner_user_id,name,company,created_at,updated_at,sync_state) '
          "VALUES (?,?,?,?,?,?, 'synced')",
          ['profile-b', 'owner-b', 'B', 'B', now, now],
        );
        await db.customStatement(
          'INSERT INTO local_user_preferences '
          '(owner_user_id,key,value,updated_at) VALUES (?,?,?,?)',
          ['owner-a', 'profilePhotoLocalPath', ownerFile.path, now],
        );
        await db.customStatement(
          'INSERT INTO local_user_preferences '
          '(owner_user_id,key,value,updated_at) VALUES (?,?,?,?)',
          ['owner-b', 'profilePhotoLocalPath', outside.path, now],
        );

        await LocalAccountDeletionPurger(
          db,
          persistence.mediaStorage,
        ).purge('owner-a');

        final ownerA = await db
            .customSelect(
              "SELECT COUNT(*) AS count FROM local_profiles WHERE owner_user_id='owner-a'",
            )
            .getSingle();
        final ownerB = await db
            .customSelect(
              "SELECT COUNT(*) AS count FROM local_profiles WHERE owner_user_id='owner-b'",
            )
            .getSingle();
        expect(ownerA.read<int>('count'), 0);
        expect(ownerB.read<int>('count'), 1);
        expect(await ownerFile.exists(), false);
        expect(await outside.exists(), true);
      } finally {
        await persistence.close();
        if (await root.exists()) await root.delete(recursive: true);
        if (await outside.exists()) await outside.delete();
      }
    },
  );

  test('SYN-12 local purge resumes from its durable file manifest', () async {
    final root = await Directory.systemTemp.createTemp(
      'foloo_deletion_resume_test_',
    );
    final persistence = LocalPersistence.inMemory(mediaRoot: root);
    final ownerFile = await File('${root.path}/owner-a.jpg')
        .writeAsString('synthetic');
    final manifest = File('${root.path}/.account_deletion_manifest.json');
    try {
      await manifest.writeAsString(
        '{"owner":"owner-a","paths":["${ownerFile.path}"]}',
      );
      await LocalAccountDeletionPurger(
        persistence.database,
        persistence.mediaStorage,
      ).purge('owner-a');
      expect(await ownerFile.exists(), false);
      expect(await manifest.exists(), false);
    } finally {
      await persistence.close();
      if (await root.exists()) await root.delete(recursive: true);
    }
  });
}
