import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/data/local/app_database.dart';
import 'package:foloo/data/repositories/entitlement_repository.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/models/entitlement.dart';
import 'package:foloo/models/lead_draft.dart';

const profile = DemoProfile(name: 'Yahir', company: 'Foloo');

LeadDraft trialDraft(
  int index, {
  LeadOriginKind origin = LeadOriginKind.direct,
}) => LeadDraft(
  name: 'Lead $index',
  lastName: '',
  role: '',
  company: 'Foloo',
  email: 'lead$index@example.com',
  phone: '',
  type: LeadType.customer,
  interest: InterestLevel.medium,
  note: '',
  originKind: origin,
  eventLocalId: origin == LeadOriginKind.event ? 'event-1' : null,
  eventName: origin == LeadOriginKind.event ? 'Expo' : null,
  audioSeconds: 0,
  place: origin == LeadOriginKind.direct ? 'León' : null,
);

void main() {
  const owner = 'owner-a';

  test(
    'new account starts with five offline uses and sixth is blocked',
    () async {
      final persistence = LocalPersistence.inMemory();
      addTearDown(persistence.close);
      await persistence.events.save(
        owner,
        AppEvent(
          id: 'event-1',
          name: 'Expo',
          startsOn: DateTime(2026, 10, 6),
          endsOn: DateTime(2026, 10, 7),
          active: true,
        ),
        makeActive: true,
      );

      for (var index = 1; index <= 5; index++) {
        await persistence.leads.saveDraft(
          owner,
          trialDraft(
            index,
            origin: index.isEven ? LeadOriginKind.event : LeadOriginKind.direct,
          ),
          capturedBy: profile,
        );
      }

      final exhausted = await persistence.entitlements.load(owner);
      expect(exhausted.trialLeadsUsed, 5);
      expect(exhausted.effectiveStatus, SubscriptionStatus.trialExhausted);
      expect(exhausted.canCreateLead, isFalse);
      await expectLater(
        persistence.leads.saveDraft(owner, trialDraft(6), capturedBy: profile),
        throwsA(isA<LeadCreationBlockedException>()),
      );
    },
  );

  test('delete never restores historical trial usage', () async {
    final persistence = LocalPersistence.inMemory();
    addTearDown(persistence.close);
    final lead = await persistence.leads.saveDraft(
      owner,
      trialDraft(1),
      capturedBy: profile,
    );
    await persistence.leads.delete(owner, lead);
    expect((await persistence.entitlements.load(owner)).trialLeadsUsed, 1);
  });

  test(
    'cached active allows unlimited creation while expired blocks',
    () async {
      final persistence = LocalPersistence.inMemory();
      addTearDown(persistence.close);
      final now = DateTime.utc(2026, 10, 6);
      await persistence.database.entitlementDao.saveSnapshot(
        LocalEntitlementsCompanion.insert(
          ownerUserId: owner,
          subscriptionStatus: 'active',
          trialLeadsUsed: 5,
          serverUpdatedAt: Value(now),
          cachedAt: now,
        ),
      );
      for (var index = 1; index <= 6; index++) {
        await persistence.leads.saveDraft(
          owner,
          trialDraft(index),
          capturedBy: profile,
        );
      }
      await persistence.database.entitlementDao.saveSnapshot(
        LocalEntitlementsCompanion.insert(
          ownerUserId: owner,
          subscriptionStatus: 'expired',
          trialLeadsUsed: 5,
          serverUpdatedAt: Value(now),
          cachedAt: now,
        ),
      );
      await expectLater(
        persistence.leads.saveDraft(owner, trialDraft(7), capturedBy: profile),
        throwsA(isA<LeadCreationBlockedException>()),
      );
      expect(await persistence.leads.listAll(owner), hasLength(6));
    },
  );

  test(
    'server acknowledgement is idempotent and removes one reservation',
    () async {
      final persistence = LocalPersistence.inMemory();
      addTearDown(persistence.close);
      final lead = await persistence.leads.saveDraft(
        owner,
        trialDraft(1),
        capturedBy: profile,
      );
      await persistence.entitlements.applyServerSnapshot(owner, {
        'subscriptionStatus': 'trial',
        'trialLeadsUsed': 0,
        'entitlementUpdatedAt': '2026-10-06T10:00:00Z',
      });
      await persistence.entitlements.acknowledgeLead(
        owner,
        lead.localId,
        incrementCachedUsage: true,
      );
      await persistence.entitlements.acknowledgeLead(
        owner,
        lead.localId,
        incrementCachedUsage: true,
      );
      final entitlement = await persistence.entitlements.load(owner);
      expect(entitlement.serverTrialLeadsUsed, 1);
      expect(entitlement.pendingLocalLeads, 0);
    },
  );

  test('offline usage survives restart and remains owner scoped', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'foloo_entitlement_',
    );
    addTearDown(() async {
      if (await temporary.exists()) await temporary.delete(recursive: true);
    });
    final file = File('${temporary.path}/foloo.sqlite');

    var database = AppDatabase(NativeDatabase(file));
    var entitlements = EntitlementRepository(database);
    await entitlements.reserveLead(owner, 'offline-lead-1', DateTime.now());
    expect((await entitlements.load(owner)).trialLeadsUsed, 1);
    await database.close();

    database = AppDatabase(NativeDatabase(file));
    entitlements = EntitlementRepository(database);
    expect((await entitlements.load(owner)).trialLeadsUsed, 1);
    expect((await entitlements.load('owner-b')).trialLeadsUsed, 0);
    expect((await entitlements.load('owner-b')).canCreateLead, isTrue);
    await database.close();
  });
}
