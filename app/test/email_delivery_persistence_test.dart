/// Verifies SAL-01/SAL-02 local preparation, owner isolation and durable queue.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/data/local/app_database.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/models/lead_draft.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/models/email_template.dart';
import 'package:foloo/sync/sync_store.dart';

void main() {
  test(
    'lead follow-up is local, owner scoped and confirm creates a new intent',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.utc(2026, 9, 18);
      await db.leadDao.insertLead(
        LocalLeadsCompanion.insert(
          localId: '11111111-1111-4111-8111-111111111111',
          ownerUserId: const Value('seller-a'),
          capturedAt: now,
          capturedBy: 'Ana',
          originKind: 'direct',
          name: 'Renée',
          lastName: '',
          role: '',
          company: 'Niño & Co.',
          email: 'lead@example.com',
          phone: '',
          leadType: 'customer',
          interestLevel: 'high',
          note: '',
          place: const Value('Monterrey'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      final repository = EmailDeliveryRepository(db);
      final draft = LeadDraft(
        name: 'Renée',
        lastName: '',
        role: '',
        company: 'Niño & Co.',
        email: 'lead@example.com',
        phone: '',
        type: LeadType.customer,
        interest: InterestLevel.high,
        note: '',
        originKind: LeadOriginKind.direct,
        audioSeconds: 0,
        place: 'Monterrey',
      );
      await repository.prepareForLead(
        owner: 'seller-a',
        leadId: '11111111-1111-4111-8111-111111111111',
        lead: draft,
        seller: const DemoProfile(name: 'Ana', company: 'Foloo'),
        language: 'es',
      );
      expect(await repository.list('seller-b'), isEmpty);
      final followUp = (await repository.list('seller-a')).single;
      expect(followUp.plainBody, contains('Renée'));
      expect(followUp.subject, 'Damos seguimiento, Renée');
      expect(followUp.subject, isNot(contains('{nombre}')));
      expect(
        (await db.syncDao.allForOwner('seller-a')).map((row) => row.entityType),
        isNot(contains('emailFollowUp')),
      );
      final intentId = await repository.confirm(
        owner: 'seller-a',
        followUpId: followUp.localId,
        subject: 'Seguimiento concreto',
        plainBody: 'Hola Renée,\n\nMensaje revisado.\n\nAna',
      );
      final frozen = (await repository.list('seller-a')).single;
      expect(frozen.subject, 'Seguimiento concreto');
      expect(frozen.plainBody, contains('Mensaje revisado'));
      expect((await repository.intents('seller-a')).single.localId, intentId);
      expect(await repository.intents('seller-b'), isEmpty);
      expect(
        (await db.syncDao.allForOwner('seller-a')).map((row) => row.entityType),
        contains('emailSendIntent'),
      );
      expect(
        (await db.syncDao.allForOwner('seller-a')).map((row) => row.entityType),
        contains('emailFollowUp'),
      );
      final operation = (await db.syncDao.allForOwner('seller-a')).firstWhere(
        (row) => row.entityId == intentId && row.action == 'confirm',
      );
      await SyncStore(db).complete(
        operation,
        remoteData: {
          'intent': {'status': 'pending', 'attemptCount': 0},
          'requiresAttachmentDecision': true,
          'incompatibleAttachmentIds': ['pdf-1'],
        },
      );
      expect(
        (await repository.intents('seller-a')).single.errorCode,
        'attachment_decision:["pdf-1"]',
      );
      await repository.confirm(
        owner: 'seller-a',
        followUpId: followUp.localId,
        intentId: intentId,
        omittedContentIds: const ['pdf-1'],
      );
      final decided = (await repository.intents('seller-a')).single;
      expect(decided.localId, intentId);
      expect(decided.omittedContentIdsJson, '["pdf-1"]');

      await repository.retry(owner: 'seller-a', intent: decided);
      final actions = (await db.syncDao.allForOwner('seller-a'))
          .where((row) => row.entityId == intentId)
          .map((row) => row.action);
      expect(actions, containsAll(<String>['confirm', 'retry']));
    },
  );

  test(
    'preparation is reused and Event override wins seller default',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.utc(2026, 9, 21);
      const leadId = '11111111-1111-4111-8111-111111111111';
      const eventId = '22222222-2222-4222-8222-222222222222';
      await db.eventDao.upsert(
        LocalEventsCompanion.insert(
          localId: eventId,
          ownerUserId: const Value('seller-a'),
          name: 'Expo Uno',
          startsOn: now,
          endsOn: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.leadDao.insertLead(
        LocalLeadsCompanion.insert(
          localId: leadId,
          ownerUserId: const Value('seller-a'),
          capturedAt: now,
          capturedBy: 'Ana',
          originKind: 'event',
          eventLocalId: const Value(eventId),
          eventNameSnapshot: const Value('Expo Uno'),
          name: 'Renée',
          lastName: '',
          role: '',
          company: 'Uno',
          email: 'lead@example.com',
          phone: '',
          leadType: 'customer',
          interestLevel: 'high',
          note: '',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await EmailTemplateRepository(db).save(
        'seller-a',
        const EmailTemplateData(
          origin: 'event',
          language: 'es',
          subject: 'Seller {nombre}',
          body: 'Seller body',
          signature: 'Seller',
        ),
      );
      await EventEmailTemplateRepository(db).save(
        'seller-a',
        const EventEmailTemplateData(
          eventId: eventId,
          language: 'es',
          subject: 'Evento {nombre}',
          body: 'Evento body',
          signature: 'Evento',
        ),
      );
      final repository = EmailDeliveryRepository(db);
      final lead = LeadDraft(
        name: 'Renée',
        lastName: '',
        role: '',
        company: 'Uno',
        email: 'lead@example.com',
        phone: '',
        type: LeadType.customer,
        interest: InterestLevel.high,
        note: '',
        originKind: LeadOriginKind.event,
        eventLocalId: eventId,
        eventName: 'Expo Uno',
        audioSeconds: 0,
      );
      final first = await repository.prepareForLead(
        owner: 'seller-a',
        leadId: leadId,
        lead: lead,
        seller: const DemoProfile(name: 'Ana', company: 'Foloo'),
        language: 'es',
      );
      final second = await repository.prepareForLead(
        owner: 'seller-a',
        leadId: leadId,
        lead: lead,
        seller: const DemoProfile(name: 'Ana', company: 'Foloo'),
        language: 'es',
      );
      expect(first!.localId, second!.localId);
      expect((await repository.list('seller-a')), hasLength(1));
      expect(first.subject, 'Evento Renée');

      await EventEmailTemplateRepository(db).remove('seller-a', eventId, 'es');
      final otherLeadId = '33333333-3333-4333-8333-333333333333';
      await db.leadDao.insertLead(
        LocalLeadsCompanion.insert(
          localId: otherLeadId,
          ownerUserId: const Value('seller-a'),
          capturedAt: now,
          capturedBy: 'Ana',
          originKind: 'event',
          eventLocalId: const Value(eventId),
          eventNameSnapshot: const Value('Expo Uno'),
          name: 'Luis',
          lastName: '',
          role: '',
          company: 'Dos',
          email: 'luis@example.com',
          phone: '',
          leadType: 'customer',
          interestLevel: 'medium',
          note: '',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final inherited = await repository.prepareForLead(
        owner: 'seller-a',
        leadId: otherLeadId,
        lead: lead.copyWith(name: 'Luis'),
        seller: const DemoProfile(name: 'Ana', company: 'Foloo'),
        language: 'es',
      );
      expect(inherited!.subject, 'Seller Luis');
      expect(first.subject, 'Evento Renée');
    },
  );

  test('same preparation reconciles Lead and Content until confirmation while preserving manual Review text', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.utc(2026, 9, 22);
    const leadId = '11111111-1111-4111-8111-111111111111';
    const eventId = '22222222-2222-4222-8222-222222222222';
    await db.eventDao.upsert(
      LocalEventsCompanion.insert(
        localId: eventId,
        ownerUserId: const Value('seller-a'),
        name: 'Expo Inicial',
        startsOn: now,
        endsOn: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.leadDao.insertLead(
      LocalLeadsCompanion.insert(
        localId: leadId,
        ownerUserId: const Value('seller-a'),
        capturedAt: now,
        capturedBy: 'Ana',
        originKind: 'event',
        eventLocalId: const Value(eventId),
        eventNameSnapshot: const Value('Expo Inicial'),
        name: 'Juan',
        lastName: 'Uno',
        role: 'Compras',
        company: 'Empresa Uno',
        email: 'juan@example.com',
        phone: '',
        leadType: 'customer',
        interestLevel: 'high',
        note: '',
        contentFileIdsJson: const Value('["content-a","content-b"]'),
        contentNamesJson: const Value('["Ficha A","Ficha B"]'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await EmailTemplateRepository(db).save(
      'seller-a',
      const EmailTemplateData(
        origin: 'event',
        language: 'es',
        subject: '{nombre} {apellido} · {empresa} · {puesto}',
        body: '{evento}\n{contenido}',
        signature: '{nombreVendedor} · {empresaVendedor}',
      ),
    );
    final repository = EmailDeliveryRepository(db);
    final initialLead = LeadDraft(
      name: 'Juan',
      lastName: 'Uno',
      role: 'Compras',
      company: 'Empresa Uno',
      email: 'juan@example.com',
      phone: '',
      type: LeadType.customer,
      interest: InterestLevel.high,
      note: '',
      originKind: LeadOriginKind.event,
      eventLocalId: eventId,
      eventName: 'Expo Inicial',
      audioSeconds: 0,
      contentFileIds: const ['content-a', 'content-b'],
      contentNames: const ['Ficha A', 'Ficha B'],
    );

    final first = await repository.prepareForLead(
      owner: 'seller-a',
      leadId: leadId,
      lead: initialLead,
      seller: const DemoProfile(name: 'Ana', company: 'Foloo'),
      language: 'es',
    );
    expect(jsonDecode(first!.contentFileIdsJson), ['content-a', 'content-b']);
    expect(jsonDecode(first.contentNamesJson), ['Ficha A', 'Ficha B']);
    expect(first.subject, 'Juan Uno · Empresa Uno · Compras');
    expect(first.plainBody, contains('Expo Inicial'));

    final changedLead = initialLead.copyWith(
      name: 'Pedro',
      lastName: 'Dos',
      company: 'Empresa Dos',
      role: 'Calidad',
      email: 'pedro@example.com',
      eventName: 'Expo Actualizada',
      contentFileIds: const ['content-a'],
      contentNames: const ['Ficha A'],
    );
    final reconciled = await repository.prepareForLead(
      owner: 'seller-a',
      leadId: leadId,
      lead: changedLead,
      seller: const DemoProfile(name: 'Ana', company: 'Foloo'),
      language: 'es',
      reconcileExisting: true,
    );
    expect(reconciled!.localId, first.localId);
    expect(await repository.list('seller-a'), hasLength(1));
    expect(reconciled.recipientAddress, 'pedro@example.com');
    expect(reconciled.subject, 'Pedro Dos · Empresa Dos · Calidad');
    expect(reconciled.plainBody, contains('Expo Actualizada'));
    expect(jsonDecode(reconciled.contentFileIdsJson), ['content-a']);
    expect(jsonDecode(reconciled.contentNamesJson), ['Ficha A']);

    await repository.updatePreparation(
      owner: 'seller-a',
      followUpId: first.localId,
      subject: 'Asunto manual',
      plainBody: 'Mensaje manual específico',
      lead: changedLead,
      seller: const DemoProfile(name: 'Ana', company: 'Foloo'),
    );
    final withManualReview = await repository.prepareForLead(
      owner: 'seller-a',
      leadId: leadId,
      lead: changedLead.copyWith(
        name: 'Luis',
        email: 'luis@example.com',
        contentFileIds: const ['content-a', 'content-b'],
        contentNames: const ['Ficha A', 'Ficha B'],
      ),
      seller: const DemoProfile(name: 'Ana', company: 'Foloo'),
      language: 'es',
      reconcileExisting: true,
    );
    expect(withManualReview!.localId, first.localId);
    expect(withManualReview.recipientAddress, 'luis@example.com');
    expect(withManualReview.subject, 'Asunto manual');
    expect(withManualReview.plainBody, 'Mensaje manual específico');
    expect(jsonDecode(withManualReview.contentFileIdsJson), [
      'content-a',
      'content-b',
    ]);
    expect(await repository.list('seller-a'), hasLength(1));

    await repository.confirm(
      owner: 'seller-a',
      followUpId: first.localId,
      subject: withManualReview.subject,
      plainBody: withManualReview.plainBody,
    );
    await EmailTemplateRepository(db).save(
      'seller-a',
      const EmailTemplateData(
        origin: 'event',
        language: 'es',
        subject: 'Plantilla posterior {nombre}',
        body: 'No debe reemplazar el histórico',
        signature: 'Otra firma',
      ),
    );
    final frozen = (await repository.list('seller-a')).single;
    expect(frozen.localId, first.localId);
    expect(frozen.subject, 'Asunto manual');
    expect(frozen.plainBody, 'Mensaje manual específico');
    expect(jsonDecode(frozen.contentFileIdsJson), ['content-a', 'content-b']);
    expect(await repository.intents('seller-a'), hasLength(1));
  });

  test('direct preparation rerenders every Lead-backed placeholder', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = EmailDeliveryRepository(db);
    final now = DateTime.utc(2026, 9, 22);
    await db.leadDao.insertLead(
      LocalLeadsCompanion.insert(
        localId: 'lead-direct',
        ownerUserId: const Value('seller-a'),
        capturedAt: now,
        capturedBy: 'Ana',
        originKind: 'direct',
        name: 'Juan',
        lastName: 'Uno',
        role: 'Compras',
        company: 'Empresa Uno',
        email: 'juan@example.com',
        phone: '',
        leadType: 'customer',
        interestLevel: 'medium',
        note: '',
        place: const Value('Monterrey'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await EmailTemplateRepository(db).save(
      'seller-a',
      const EmailTemplateData(
        origin: 'direct',
        language: 'es',
        subject: '{nombre} {apellido}',
        body: '{empresa}|{puesto}|{lugar}',
        signature: '{nombreVendedor}|{empresaVendedor}',
      ),
    );
    final initial = LeadDraft(
      name: 'Juan',
      lastName: 'Uno',
      role: 'Compras',
      company: 'Empresa Uno',
      email: 'juan@example.com',
      phone: '',
      type: LeadType.customer,
      interest: InterestLevel.medium,
      note: '',
      originKind: LeadOriginKind.direct,
      audioSeconds: 0,
      place: 'Monterrey',
    );
    final first = await repository.prepareForLead(
      owner: 'seller-a',
      leadId: 'lead-direct',
      lead: initial,
      seller: const DemoProfile(name: 'Ana', company: 'Foloo'),
      language: 'es',
    );
    final second = await repository.prepareForLead(
      owner: 'seller-a',
      leadId: 'lead-direct',
      lead: initial.copyWith(
        name: 'Pedro',
        lastName: 'Dos',
        company: 'Empresa Dos',
        role: 'Calidad',
        place: 'Guadalajara',
      ),
      seller: const DemoProfile(name: 'Ana', company: 'Foloo'),
      language: 'es',
      reconcileExisting: true,
    );

    expect(second!.localId, first!.localId);
    expect(second.subject, 'Pedro Dos');
    expect(second.plainBody, startsWith('Empresa Dos|Calidad|Guadalajara'));
    expect(await repository.list('seller-a'), hasLength(1));
  });

  test(
    'delivery streams publish persisted status transitions in place',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.utc(2026, 9, 21);
      await db.leadDao.insertLead(
        LocalLeadsCompanion.insert(
          localId: 'lead',
          ownerUserId: const Value('seller-a'),
          capturedAt: now,
          capturedBy: 'Ana',
          originKind: 'direct',
          name: 'Lead',
          lastName: '',
          role: '',
          company: 'Company',
          email: 'lead@example.com',
          phone: '',
          leadType: 'customer',
          interestLevel: 'medium',
          note: '',
          place: const Value('Office'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.emailDeliveryDao.saveFollowUp(
        LocalEmailFollowUpsCompanion.insert(
          localId: 'follow-up',
          ownerUserId: 'seller-a',
          leadLocalId: 'lead',
          recipientAddress: 'lead@example.com',
          subject: 'Subject',
          plainBody: 'Body',
          htmlBody: '<p>Body</p>',
          languageCode: 'en',
          preparedAt: now,
        ),
      );
      await db.emailDeliveryDao.saveIntent(
        LocalEmailSendIntentsCompanion.insert(
          localId: 'intent',
          ownerUserId: 'seller-a',
          followUpLocalId: 'follow-up',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final statuses = <String>[];
      final subscription = EmailDeliveryRepository(db)
          .watchIntents('seller-a')
          .listen((rows) => statuses.add(rows.single.status));
      addTearDown(subscription.cancel);
      await Future<void>.delayed(Duration.zero);
      await db.emailDeliveryDao.updateIntentState(
        'seller-a',
        'intent',
        'sending',
        1,
        null,
        now.add(const Duration(seconds: 1)),
      );
      await db.emailDeliveryDao.updateIntentState(
        'seller-a',
        'intent',
        'sent',
        1,
        null,
        now.add(const Duration(seconds: 2)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(statuses, containsAllInOrder(['pending', 'sending', 'sent']));
    },
  );

  test(
    'lead without email is preserved without follow-up or send intent',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = EmailDeliveryRepository(db);
      final prepared = await repository.prepareForLead(
        owner: 'seller-a',
        leadId: 'lead-without-email',
        lead: LeadDraft(
          name: 'Solo Teléfono',
          lastName: '',
          role: '',
          company: 'Empresa',
          email: '',
          phone: '+52 81 0000 0000',
          type: LeadType.customer,
          interest: InterestLevel.medium,
          note: '',
          originKind: LeadOriginKind.direct,
          audioSeconds: 0,
          place: 'Monterrey',
        ),
        seller: const DemoProfile(name: 'Ana', company: 'Foloo'),
        language: 'es',
      );

      expect(prepared, null);
      expect(await repository.list('seller-a'), isEmpty);
      expect(await repository.intents('seller-a'), isEmpty);
    },
  );
}
