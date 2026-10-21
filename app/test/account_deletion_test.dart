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
import 'package:foloo/theme/foloo_theme.dart';

class FakeDeletionService implements AccountDeletionService {
  FakeDeletionService({this.recent = true, this.pending = 0});

  bool recent;
  int pending;
  int confirmations = 0;

  @override
  Future<bool> hasRecentAuthentication(String ownerSub) async => recent;

  @override
  Future<AccountDeletionPreflight> createPreflight({
    required String ownerSub,
    required String locale,
    required bool requestedExport,
    required String idempotencyKey,
  }) async => AccountDeletionPreflight(
    requestId: '00000000-0000-4000-8000-000000000222',
    pendingSyncCount: pending,
    exportAvailable: true,
    subscriptionCancellationRequired: false,
  );

  @override
  Future<AccountDeletionAccepted> confirm({
    required String ownerSub,
    required String requestId,
    required bool discardUnsyncedAccepted,
    required bool cancelRenewalAccepted,
    required String idempotencyKey,
  }) async {
    confirmations += 1;
    return const AccountDeletionAccepted(
      requestId: '00000000-0000-4000-8000-000000000222',
      receipt: 'synthetic-receipt-not-a-real-credential',
      status: AccountDeletionStatus.requested,
    );
  }
}

Widget harness(
  FakeDeletionService service, {
  Future<void> Function()? accepted,
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
      onAccepted: (_) => accepted?.call() ?? Future.value(),
    ),
  );
}

void main() {
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
}
