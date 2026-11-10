/// FL-021 fifth-lead acknowledgement and backend-confirmation regression tests.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/data/local/app_database.dart';
import 'package:foloo/l10n/app_localizations.dart';
import 'package:foloo/sync/sync_models.dart';
import 'package:foloo/sync/sync_store.dart';
import 'package:foloo/theme/foloo_theme.dart';
import 'package:foloo/widgets/trial_milestone_dialog.dart';

void main() {
  test(
    'MON-22 records the modal only after backend confirms lead five',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = SyncStore(database, idFactory: () => 'operation-a');
      await store.enqueue(
        ownerSub: 'owner-a',
        entityType: SyncEntityType.lead,
        entityId: 'lead-a',
        action: 'create',
        payload: const {'id': 'lead-a'},
        now: DateTime.utc(2026, 11, 5),
      );
      final operation = (await store.all('owner-a')).single;

      await store.complete(
        operation,
        remoteData: const {
          'revision': 1,
          'trialMilestoneReached': true,
          'trialMilestoneDeliveryStatus': 'pending',
        },
      );

      expect(
        await database.profilePreferencesDao.userPreference(
          'owner-a',
          'trialMilestone5State',
        ),
        'pending',
      );
    },
  );

  testWidgets('MON-22 modal has no checkout or false delivery claim', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        theme: FolooTheme.light,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: TrialMilestoneDialog()),
      ),
    );
    expect(find.text('5 de 5 leads capturados'), findsOneWidget);
    expect(find.textContaining('todavía no está habilitado'), findsOneWidget);
    expect(
      find.text('Tus 5 leads siguen disponibles en Registros.'),
      findsOneWidget,
    );
    expect(find.textContaining('Reenviar'), findsNothing);
    expect(find.textContaining('Stripe'), findsNothing);
    expect(find.byType(Uri), findsNothing);
  });
}
