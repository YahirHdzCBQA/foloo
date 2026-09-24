/// Covers REG-15/REG-16 reactive email state and retry from Lead detail.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/data/local/app_database.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/l10n/app_localizations.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/models/lead_draft.dart';
import 'package:foloo/models/session_lead.dart';
import 'package:foloo/screens/records_screen.dart';
import 'package:foloo/theme/foloo_theme.dart';

void main() {
  testWidgets('mail status and open detail react to Drift and allow retry', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = EmailDeliveryRepository(database);
    final now = DateTime.utc(2026, 9, 23, 12);
    const owner = 'seller-a';
    const leadId = 'lead-a';
    const followUpId = 'follow-up-a';
    const intentId = 'intent-a';
    final lead = LeadDraft(
      name: 'Mariana',
      lastName: 'Sandoval',
      role: 'Compras',
      company: 'Lácteos Norte',
      email: 'mariana@example.com',
      phone: '',
      type: LeadType.customer,
      interest: InterestLevel.high,
      note: 'Enviar catálogo',
      originKind: LeadOriginKind.direct,
      place: 'Oficina',
      audioSeconds: 0,
    );
    await database.leadDao.insertLead(
      LocalLeadsCompanion.insert(
        localId: leadId,
        ownerUserId: const Value(owner),
        capturedAt: now,
        capturedBy: 'Vendedor',
        originKind: 'direct',
        name: lead.name,
        lastName: lead.lastName,
        role: lead.role,
        company: lead.company,
        email: lead.email,
        phone: lead.phone,
        leadType: lead.type.name,
        interestLevel: lead.interest.name,
        note: lead.note,
        place: const Value('Oficina'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await database.emailDeliveryDao.saveFollowUp(
      LocalEmailFollowUpsCompanion.insert(
        localId: followUpId,
        ownerUserId: owner,
        leadLocalId: leadId,
        recipientAddress: lead.email,
        subject: 'Seguimiento concreto',
        plainBody: 'Hola Mariana',
        htmlBody: '<p>Hola Mariana</p>',
        languageCode: 'es',
        preparedAt: now,
      ),
    );
    await database.emailDeliveryDao.saveIntent(
      LocalEmailSendIntentsCompanion.insert(
        localId: intentId,
        ownerUserId: owner,
        followUpLocalId: followUpId,
        status: const Value('pending'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    var queued = false;
    final record = SessionLead(
      localId: leadId,
      folio: null,
      capturedAt: now,
      lead: lead,
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        theme: FolooTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RecordsScreen(
          records: [record],
          darkMode: false,
          profile: DemoProfile.empty,
          ownerSub: owner,
          deliveryRepository: repository,
          onSendQueued: () => queued = true,
          onDestinationSelected: (_) {},
          onAppearanceChanged: (_) {},
          onLogout: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recordEmail-lead-a')), findsOneWidget);
    expect(find.byIcon(Icons.schedule_send_outlined), findsOneWidget);
    await tester.tap(find.byKey(const Key('record-lead-a')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('leadFollowUpSection')), findsOneWidget);
    expect(find.byKey(const Key('leadFollowUpCard')), findsOneWidget);
    expect(find.text('Mariana Sandoval'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const Key('leadFollowUpCard')),
        matching: find.text('mariana@example.com'),
      ),
      findsOneWidget,
    );
    expect(find.text('Seguimiento concreto'), findsNothing);
    expect(find.text('Hola Mariana'), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('leadFollowUpSection'))).dy,
      greaterThan(tester.getTopLeft(find.text('Contenido adjunto')).dy),
    );

    await tester.ensureVisible(find.byKey(const Key('leadFollowUpCard')));
    await tester.tap(find.byKey(const Key('leadFollowUpCard')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('leadFollowUpDetailsDialog')), findsOneWidget);
    expect(find.byKey(const Key('leadFollowUpSubject')), findsOneWidget);
    expect(find.text('Seguimiento concreto'), findsOneWidget);
    expect(find.byKey(const Key('leadFollowUpBody')), findsOneWidget);
    expect(find.text('Hola Mariana'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();

    await database.emailDeliveryDao.updateIntentState(
      owner,
      intentId,
      'error',
      1,
      'provider_safe_retry',
      now.add(const Duration(seconds: 1)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('leadFollowUpCard')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('leadFollowUpRetry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('leadFollowUpRetry')));
    await tester.pumpAndSettle();
    expect(queued, isTrue);
    final operations = await database.syncDao.allForOwner(owner);
    expect(operations.any((item) => item.action == 'retry'), isTrue);
  });
}
