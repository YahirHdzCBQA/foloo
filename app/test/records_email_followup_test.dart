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
  testWidgets(
    'REG-F16–22/30/34: accepted snapshot, omitted file and owner filters',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = EmailDeliveryRepository(db);
      final now = DateTime(2026, 11, 27);
      const owner = 'filter-owner-a';
      final records = <SessionLead>[];
      for (final (id, status, name) in [
        ('a', 'sent', 'Accepted'),
        ('b', 'pending', 'Pending'),
        ('c', 'error', 'Failed'),
        ('d', 'draft', 'Draft'),
      ]) {
        final lead = LeadDraft(
          name: name,
          lastName: '',
          role: '',
          company: 'Synthetic',
          email: 'lead@example.test',
          phone: '',
          type: LeadType.customer,
          interest: InterestLevel.high,
          note: '',
          originKind: LeadOriginKind.direct,
          audioSeconds: 0,
        );
        records.add(
          SessionLead(localId: id, folio: null, capturedAt: now, lead: lead),
        );
        await db.leadDao.insertLead(
          LocalLeadsCompanion.insert(
            localId: id,
            ownerUserId: const Value(owner),
            capturedAt: now,
            capturedBy: 'QA',
            originKind: 'direct',
            name: name,
            lastName: '',
            role: '',
            company: 'Synthetic',
            email: lead.email,
            phone: '',
            leadType: 'customer',
            interestLevel: 'high',
            note: '',
            createdAt: now,
            updatedAt: now,
          ),
        );
        await db.emailDeliveryDao.saveFollowUp(
          LocalEmailFollowUpsCompanion.insert(
            localId: 'follow-$id',
            ownerUserId: owner,
            leadLocalId: id,
            recipientAddress: lead.email,
            subject: 'Test',
            plainBody: 'Test',
            htmlBody: 'Test',
            languageCode: 'es',
            preparedAt: now,
            contentFileIdsJson: const Value('["historical","omitted"]'),
            contentNamesJson: const Value('["Histórico","Omitido"]'),
          ),
        );
        if (status != 'draft') {
          await db.emailDeliveryDao.saveIntent(
            LocalEmailSendIntentsCompanion.insert(
              localId: 'intent-$id',
              ownerUserId: owner,
              followUpLocalId: 'follow-$id',
              status: Value(status),
              createdAt: now,
              updatedAt: now,
              omittedContentIdsJson: const Value('["omitted"]'),
            ),
          );
        }
      }
      Widget screen(String sub, List<SessionLead> entries) => MaterialApp(
        locale: const Locale('es'),
        theme: FolooTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RecordsScreen(
          records: entries,
          darkMode: false,
          ownerSub: sub,
          deliveryRepository: repository,
          onDestinationSelected: (_) {},
          onAppearanceChanged: (_) {},
          onLogout: () {},
        ),
      );
      await tester.pumpWidget(screen(owner, records));
      await tester.pumpAndSettle();
      Future<void> tap(String key) async {
        final finder = find.byKey(Key(key));
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tap('recordsAllFilters');
      expect(find.byKey(const Key('recordsContent-omitted')), findsNothing);
      expect(find.text('Ver 4 leads'), findsOneWidget);
      await tap('recordsContent-historical');
      expect(find.text('Ver 1 lead'), findsOneWidget);
      await tap('recordsWithoutContent');
      expect(find.text('Ver 4 leads'), findsOneWidget);
      await tap('recordsWithoutContent');
      await tap('recordsApplyFilters');
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Pending'), findsNothing);
      expect(find.text('Failed'), findsNothing);
      expect(find.text('Draft'), findsNothing);
      await tap('recordsAllFilters');
      await tap('recordsClearAdditional');
      expect(find.text('Ver 4 leads'), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.text('Pending'), findsNothing);
      await tap('recordsAllFilters');
      await tester.pumpWidget(screen('filter-owner-b', const []));
      await tester.pumpAndSettle();
      expect(find.text('Histórico'), findsNothing);
      expect(find.text('Más filtros'), findsNothing);
      expect(find.text('Accepted'), findsNothing);
      expect(tester.takeException(), equals(null));
    },
  );

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
    expect(find.text('Contenido adjunto'), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('leadFollowUpSection'))).dy,
      greaterThan(tester.getTopLeft(find.text('Registro')).dy),
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

    queued = false;
    await database.emailDeliveryDao.updateIntentState(
      owner,
      intentId,
      'error',
      2,
      'http_409_sender_confirmation_required',
      now.add(const Duration(seconds: 2)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('leadFollowUpCard')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'La cuenta de envío conectada cambió. Confirma un reenvío manual para usar el remitente actual; Foloo no reintentará automáticamente.',
      ),
      findsOneWidget,
    );
    expect(find.text('http_409_sender_confirmation_required'), findsNothing);
    expect(find.byKey(const Key('leadFollowUpRetry')), findsNothing);
    expect(find.byKey(const Key('leadFollowUpResend')), findsOneWidget);
    await tester.tap(find.byKey(const Key('leadFollowUpResend')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reenviar'));
    await tester.pumpAndSettle();
    final intents = await repository.intents(owner);
    expect(intents, hasLength(2));
    expect(intents.first.parentIntentId, intentId);
    expect(queued, isTrue);
  });
}
