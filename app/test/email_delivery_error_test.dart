/// Covers terminal SAL-07 delivery classification without provider calls.
library;

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/data/local/app_database.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/models/email_delivery_error.dart';
import 'package:foloo/sync/sync_models.dart';
import 'package:foloo/sync/sync_store.dart';

void main() {
  test('superseded opt-out errors no longer block active delivery', () {
    for (final value in [
      'recipient_opted_out',
      'http_409_recipient_opted_out',
    ]) {
      expect(isTerminalEmailDeliveryError(value), isFalse, reason: value);
    }
    for (final value in [
      'email_retry_not_allowed',
      'http_409_email_retry_not_allowed',
    ]) {
      expect(isTerminalEmailDeliveryError(value), isTrue, reason: value);
    }
    expect(isRecipientOptedOutError('recipient_opted_out'), isTrue);
    expect(isRecipientOptedOutError('email_retry_not_allowed'), isFalse);
    expect(isTerminalEmailDeliveryError('provider_safe_retry'), isFalse);
  });

  test('historical opt-out intent can enqueue a manual retry', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = EmailDeliveryRepository(database);
    final now = DateTime.utc(2026, 9, 21);

    await repository.retry(
      owner: 'seller-a',
      intent: StoredEmailSendIntent(
        localId: 'intent-a',
        ownerUserId: 'seller-a',
        followUpLocalId: 'follow-up-a',
        status: 'error',
        omittedContentIdsJson: '[]',
        attemptCount: 1,
        errorCode: 'http_409_recipient_opted_out',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final operations = await database.syncDao.allForOwner('seller-a');
    expect(operations, hasLength(1));
    expect(operations.single.entityType, SyncEntityType.emailSendIntent.name);
  });

  test(
    'legacy failed outbox restores terminal intent without retrying',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final now = DateTime.utc(2026, 9, 21, 19, 4);
      await database.leadDao.insertLead(
        LocalLeadsCompanion.insert(
          localId: 'lead-a',
          ownerUserId: const Value('seller-a'),
          capturedAt: now,
          capturedBy: 'Seller',
          originKind: 'direct',
          name: 'Mariana',
          lastName: '',
          role: '',
          company: 'Lácteos Norte',
          email: 'lead@example.com',
          phone: '',
          leadType: 'customer',
          interestLevel: 'high',
          note: '',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await database.emailDeliveryDao.saveFollowUp(
        LocalEmailFollowUpsCompanion.insert(
          localId: 'follow-up-a',
          ownerUserId: 'seller-a',
          leadLocalId: 'lead-a',
          recipientAddress: 'lead@example.com',
          subject: 'Damos seguimiento, Mariana',
          plainBody: 'Hola Mariana',
          htmlBody: '<p>Hola Mariana</p>',
          languageCode: 'es',
          preparedAt: now,
        ),
      );
      await database.emailDeliveryDao.saveIntent(
        LocalEmailSendIntentsCompanion.insert(
          localId: 'intent-a',
          ownerUserId: 'seller-a',
          followUpLocalId: 'follow-up-a',
          status: const Value('error'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      final store = SyncStore(database, idFactory: () => 'operation-a');
      await store.enqueue(
        ownerSub: 'seller-a',
        entityType: SyncEntityType.emailSendIntent,
        entityId: 'intent-a',
        action: 'retry',
        payload: {'intentId': 'intent-a'},
        now: now,
      );
      await database.syncDao.markFailed(
        'operation-a',
        1,
        'http_409_email_retry_not_allowed',
        now,
      );

      expect(await store.reconcileTerminalEmailFailures('seller-a'), 1);
      final intent = (await database.emailDeliveryDao.intents('seller-a'))
          .single;
      expect(intent.status, 'error');
      expect(intent.errorCode, 'http_409_email_retry_not_allowed');
      expect((await store.all('seller-a')).single.status, 'failed');
      expect(await store.due('seller-a', now), isEmpty);
    },
  );
}
