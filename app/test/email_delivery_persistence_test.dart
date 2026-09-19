/// Verifies SAL-01/SAL-02 local preparation, owner isolation and durable queue.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/data/local/app_database.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/models/lead_draft.dart';
import 'package:foloo/models/app_event.dart';
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
      expect(
        (await db.syncDao.allForOwner('seller-a')).map((row) => row.entityType),
        contains('emailFollowUp'),
      );
      final intentId = await repository.confirm(
        owner: 'seller-a',
        followUpId: followUp.localId,
      );
      expect((await repository.intents('seller-a')).single.localId, intentId);
      expect(await repository.intents('seller-b'), isEmpty);
      expect(
        (await db.syncDao.allForOwner('seller-a')).map((row) => row.entityType),
        contains('emailSendIntent'),
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
}
