/// FL-023 / SAL-07 / REG-15: sender errors from an offline direct capture.
/// Covers localized preview/retry without changing the saved lead or send ID.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/theme/foloo_theme.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/l10n/app_localizations.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/models/lead_draft.dart';
import 'package:foloo/screens/records_screen.dart';

void main() {
  for (final scenario in [
    (locale: 'es', error: 'http_409_email_connection_required', missing: true),
    (locale: 'en', error: 'http_409_email_connection_required', missing: true),
    (locale: 'es', error: 'http_404_not_found', missing: true),
    (locale: 'en', error: 'http_404_not_found', missing: true),
    (locale: 'es', error: 'http_404_not_found', missing: false),
    (locale: 'en', error: 'http_500_internal_error', missing: false),
  ]) {
    testWidgets(
      'SAL-07 ${scenario.locale} ${scenario.error} missing=${scenario.missing}',
      (tester) async {
        final persistence = LocalPersistence.inMemory();
        addTearDown(persistence.database.close);
        const owner = 'seller-fl023';
        final draft = LeadDraft(
          name: 'QA',
          lastName: '',
          role: '',
          company: '',
          email: 'lead@example.test',
          phone: '',
          type: LeadType.customer,
          interest: InterestLevel.high,
          note: 'Keep this note',
          originKind: LeadOriginKind.direct,
          place: 'Office',
          audioSeconds: 0,
        );
        final record = await persistence.leads.saveDraft(
          owner,
          draft,
          capturedBy: DemoProfile.empty,
        );
        final repository = persistence.emailDelivery;
        await repository.prepareForLead(
          owner: owner,
          leadId: record.localId,
          lead: record.lead,
          seller: DemoProfile.empty,
          language: scenario.locale,
        );
        final followUp = (await repository.forLead(owner, record.localId))!;
        final intentId = await repository.confirm(
          owner: owner,
          followUpId: followUp.localId,
        );
        await persistence.database.emailDeliveryDao.updateIntentState(
          owner,
          intentId,
          'error',
          1,
          scenario.error,
          DateTime.now().toUtc(),
        );
        var queued = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: FolooTheme.light,
            locale: Locale(scenario.locale),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: RecordsScreen(
              records: [record],
              darkMode: false,
              ownerSub: owner,
              deliveryRepository: repository,
              isEmailConnectionMissing: (_) async => scenario.missing,
              onSendQueued: () => queued = true,
              onDestinationSelected: (_) {},
              onAppearanceChanged: (_) {},
              onLogout: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('record-${record.localId}')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('leadFollowUpCard')));
        await tester.tap(find.byKey(const Key('leadFollowUpCard')));
        await tester.pumpAndSettle();
        final message = scenario.locale == 'es'
            ? 'Aún no has conectado ninguna cuenta para enviar seguimientos vía correo.'
            : "You haven't connected an email account to send follow-up emails yet.";
        expect(
          find.text(scenario.missing ? message : scenario.error),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('leadFollowUpRetry')));
        await tester.pumpAndSettle();
        expect(queued, !scenario.missing);
        if (scenario.missing) {
          expect(find.text(message), findsOneWidget);
          expect((await repository.intents(owner)).single.status, 'error');
        }
        expect(
          (await persistence.leads.listAll(owner)).single.lead.note,
          draft.note,
        );
        expect((await repository.intents(owner)).single.localId, intentId);
      },
    );
  }
}
