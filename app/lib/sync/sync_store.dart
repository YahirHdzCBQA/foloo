/// Drift adapter for persistent outbox state and safe server reconciliation.
///
/// Local dirty rows win over pull results. All reads and writes are scoped by
/// Cognito sub, and successful pushes update the visible entity state.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../data/local/app_database.dart';
import 'sync_models.dart';

class SyncStore {
  SyncStore(this.database, {String Function()? idFactory})
    : _idFactory = idFactory ?? const Uuid().v4;

  final AppDatabase database;
  final String Function() _idFactory;

  Future<void> enqueue({
    required String ownerSub,
    required SyncEntityType entityType,
    required String entityId,
    required String action,
    required Map<String, Object?> payload,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final operationId = _idFactory();
    return database.syncDao.enqueue(
      SyncOperationsCompanion.insert(
        operationId: operationId,
        ownerUserId: ownerSub,
        entityType: entityType.name,
        entityId: entityId,
        action: action,
        payloadJson: jsonEncode(payload),
        idempotencyKey: operationId,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );
  }

  Future<List<StoredSyncOperation>> due(
    String ownerSub,
    DateTime now, {
    bool ignoreRetryBackoff = false,
  }) async {
    final operations = await database.syncDao.pendingForOwner(
      ownerSub,
      now.toUtc(),
      ignoreRetryBackoff: ignoreRetryBackoff,
    );
    const priority = {'profile': 0, 'event': 1, 'lead': 2, 'leadMedia': 3};
    operations.sort((a, b) {
      final typeOrder = (priority[a.entityType] ?? 9).compareTo(
        priority[b.entityType] ?? 9,
      );
      return typeOrder != 0 ? typeOrder : a.createdAt.compareTo(b.createdAt);
    });
    return operations;
  }

  Future<List<StoredSyncOperation>> all(String ownerSub) =>
      database.syncDao.allForOwner(ownerSub);

  /// Backfills valid pre-FL-015 rows without changing their local identity.
  Future<void> prepareOwner(String ownerSub) async {
    final profile = await database.profilePreferencesDao.profileForUser(
      ownerSub,
    );
    if (profile != null &&
        profile.syncState != 'synced' &&
        !await hasPending(ownerSub, SyncEntityType.profile, profile.localId)) {
      await enqueue(
        ownerSub: ownerSub,
        entityType: SyncEntityType.profile,
        entityId: profile.localId,
        action: 'upsert',
        payload: {'name': profile.name, 'company': profile.company},
        now: profile.updatedAt,
      );
    }
    for (final event in await database.eventDao.listActive(ownerSub)) {
      if (event.syncState == 'synced' ||
          !_isUuid(event.localId) ||
          await hasPending(ownerSub, SyncEntityType.event, event.localId)) {
        continue;
      }
      await enqueue(
        ownerSub: ownerSub,
        entityType: SyncEntityType.event,
        entityId: event.localId,
        action: 'create',
        payload: {
          'id': event.localId,
          'name': event.name,
          'startsAt': event.startsOn.toIso8601String(),
          'endsAt': event.endsOn.toIso8601String(),
        },
        now: event.updatedAt,
      );
    }
    for (final bundle in await database.leadDao.listAll(ownerSub)) {
      final lead = bundle.lead;
      final validEvent =
          lead.eventLocalId == null || _isUuid(lead.eventLocalId!);
      if (lead.syncState != 'synced' &&
          _isUuid(lead.localId) &&
          validEvent &&
          !await hasPending(ownerSub, SyncEntityType.lead, lead.localId)) {
        await enqueue(
          ownerSub: ownerSub,
          entityType: SyncEntityType.lead,
          entityId: lead.localId,
          action: 'create',
          payload: {
            'id': lead.localId,
            'capturedAt': lead.capturedAt.toIso8601String(),
            'origin': lead.originKind,
            'eventId': lead.eventLocalId,
            'place': lead.place,
            'firstName': lead.name,
            'lastName': lead.lastName.isEmpty ? null : lead.lastName,
            'position': lead.role.isEmpty ? null : lead.role,
            'company': lead.company,
            'email': lead.email.isEmpty ? null : lead.email,
            'phone': lead.phone.isEmpty ? null : lead.phone,
            'leadType': lead.leadType,
            'interest': lead.interestLevel,
            'writtenNote': lead.note.isEmpty ? null : lead.note,
            'commercialFolio': lead.commercialFolio,
          },
          now: lead.updatedAt,
        );
      }
      for (final media in bundle.media) {
        if (media.uploadState == 'synced' ||
            !_isUuid(media.localId) ||
            !await File(media.localPath).exists() ||
            await hasPending(
              ownerSub,
              SyncEntityType.leadMedia,
              media.localId,
            )) {
          continue;
        }
        final file = File(media.localPath);
        await enqueue(
          ownerSub: ownerSub,
          entityType: SyncEntityType.leadMedia,
          entityId: media.localId,
          action: 'create',
          payload: {
            'leadId': lead.localId,
            'id': media.localId,
            'kind': switch (media.mediaType) {
              'cardImage' => 'business_card',
              'referenceImage' => 'reference_image',
              'voiceNote' => 'voice_note',
              _ => throw const FormatException('Unsupported local media type'),
            },
            'contentType': media.mediaType == 'voiceNote'
                ? 'audio/m4a'
                : 'image/jpeg',
            'byteSize': await file.length(),
            'capturedAt': media.createdAt.toIso8601String(),
            'durationMs': media.durationSeconds == null
                ? null
                : media.durationSeconds! * 1000,
          },
          now: media.createdAt,
        );
      }
    }
  }

  Future<void> markSyncing(StoredSyncOperation operation, DateTime now) async {
    await database.syncDao.markRunning(operation.operationId, now.toUtc());
    await _markEntity(operation, 'syncing');
  }

  Future<void> pause(StoredSyncOperation operation, DateTime now) async {
    await database.syncDao.markPending(operation.operationId, now.toUtc());
    await _markEntity(operation, 'pending');
  }

  Future<void> complete(StoredSyncOperation operation) async {
    await database.transaction(() async {
      await _markEntity(operation, 'synced');
      await database.syncDao.complete(operation.operationId);
    });
  }

  Future<void> markRetryable(
    StoredSyncOperation operation,
    DateTime nextAttemptAt,
    String error,
    DateTime now,
  ) async {
    await database.transaction(() async {
      await database.syncDao.markRetryable(
        operation.operationId,
        operation.attemptCount + 1,
        nextAttemptAt.toUtc(),
        error,
        now.toUtc(),
      );
      await _markEntity(operation, 'pending');
    });
  }

  Future<void> markFailed(
    StoredSyncOperation operation,
    String error,
    DateTime now,
  ) async {
    await database.transaction(() async {
      await database.syncDao.markFailed(
        operation.operationId,
        operation.attemptCount + 1,
        error,
        now.toUtc(),
      );
      await _markEntity(operation, 'failed');
    });
  }

  Future<void> _markEntity(StoredSyncOperation operation, String state) async {
    switch (SyncEntityType.values.byName(operation.entityType)) {
      case SyncEntityType.profile:
        if (state == 'synced') {
          await database.profilePreferencesDao.markProfileSynced(
            operation.ownerUserId,
          );
        }
        return;
      case SyncEntityType.event:
        if (state == 'synced') {
          await database.eventDao.markSynced(
            operation.ownerUserId,
            operation.entityId,
          );
        }
        return;
      case SyncEntityType.lead:
        await database.leadDao.markLeadSyncState(
          operation.ownerUserId,
          operation.entityId,
          state,
        );
        return;
      case SyncEntityType.leadMedia:
        await database.leadDao.markMediaSyncState(operation.entityId, state);
        return;
    }
  }

  Future<bool> hasPending(
    String ownerSub,
    SyncEntityType type,
    String entityId,
  ) => database.syncDao.hasOpenOperation(ownerSub, type.name, entityId);

  Future<void> reconcileRemoteCreate(
    String ownerSub,
    SyncEntityType type,
    String entityId,
  ) => database.syncDao.completeCreatesForEntity(ownerSub, type.name, entityId);

  Future<void> applyRemoteProfile(
    String ownerSub,
    Map<String, Object?> profile,
  ) async {
    final existing = await database.profilePreferencesDao.profileForUser(
      ownerSub,
    );
    if (existing != null &&
        await hasPending(ownerSub, SyncEntityType.profile, existing.localId)) {
      return;
    }
    final now = DateTime.now().toUtc();
    await database.profilePreferencesDao.saveProfile(
      LocalProfilesCompanion.insert(
        localId: existing?.localId ?? 'profile-$ownerSub',
        ownerUserId: Value(ownerSub),
        name: profile['name'] as String,
        company: profile['company'] as String,
        createdAt: existing?.createdAt ?? now,
        updatedAt: _date(profile['updatedAt']) ?? now,
        syncState: const Value('synced'),
      ),
    );
  }

  Future<void> applyRemoteEvents(
    String ownerSub,
    List<Map<String, Object?>> events,
  ) async {
    for (final event in events) {
      final id = event['id'] as String;
      final hadLocalCreate = await hasPending(
        ownerSub,
        SyncEntityType.event,
        id,
      );
      await reconcileRemoteCreate(ownerSub, SyncEntityType.event, id);
      if (hadLocalCreate) {
        await database.eventDao.markSynced(ownerSub, id);
        continue;
      }
      if (await hasPending(ownerSub, SyncEntityType.event, id)) continue;
      final existing = await database.eventDao.byId(ownerSub, id);
      final now = DateTime.now().toUtc();
      await database.eventDao.upsert(
        LocalEventsCompanion.insert(
          localId: id,
          ownerUserId: Value(ownerSub),
          name: event['name'] as String,
          startsOn: DateTime.parse(event['startsAt'] as String).toUtc(),
          endsOn: DateTime.parse(event['endsAt'] as String).toUtc(),
          active: Value(existing?.active ?? false),
          deleted: const Value(false),
          contentFileIdsJson: Value(existing?.contentFileIdsJson ?? '[]'),
          createdAt: _date(event['createdAt']) ?? existing?.createdAt ?? now,
          updatedAt: _date(event['updatedAt']) ?? now,
          syncState: const Value('synced'),
        ),
      );
    }
  }

  Future<void> applyRemoteLeads(
    String ownerSub,
    List<Map<String, Object?>> leads,
  ) async {
    final profile = await database.profilePreferencesDao.profileForUser(
      ownerSub,
    );
    for (final lead in leads) {
      final id = lead['id'] as String;
      final hadLocalCreate = await hasPending(
        ownerSub,
        SyncEntityType.lead,
        id,
      );
      await reconcileRemoteCreate(ownerSub, SyncEntityType.lead, id);
      if (hadLocalCreate) {
        await database.leadDao.markLeadSyncState(ownerSub, id, 'synced');
        continue;
      }
      if (await hasPending(ownerSub, SyncEntityType.lead, id)) continue;
      final existing = await database.leadDao.byId(ownerSub, id);
      final now = DateTime.now().toUtc();
      await database.localLeads.insertOnConflictUpdate(
        LocalLeadsCompanion.insert(
          localId: id,
          ownerUserId: Value(ownerSub),
          capturedAt: DateTime.parse(lead['capturedAt'] as String).toUtc(),
          capturedBy: existing?.capturedBy ?? profile?.name ?? 'Foloo',
          originKind: lead['origin'] as String,
          eventLocalId: Value(lead['eventId'] as String?),
          eventNameSnapshot: Value(existing?.eventNameSnapshot),
          name: lead['firstName'] as String,
          lastName: (lead['lastName'] as String?) ?? '',
          role: (lead['position'] as String?) ?? '',
          company: lead['company'] as String,
          email: (lead['email'] as String?) ?? '',
          phone: (lead['phone'] as String?) ?? '',
          leadType: _leadTypeFromApi(lead['leadType'] as String),
          interestLevel: lead['interest'] as String,
          note: (lead['writtenNote'] as String?) ?? '',
          place: Value(lead['place'] as String?),
          commercialFolio: Value(lead['commercialFolio'] as String?),
          contentFileIdsJson: Value(existing?.contentFileIdsJson ?? '[]'),
          contentNamesJson: Value(existing?.contentNamesJson ?? '[]'),
          transcription: Value(existing?.transcription),
          syncState: const Value('synced'),
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    }
  }

  Future<void> applyRemoteMedia(
    String ownerSub,
    String leadId,
    List<Map<String, Object?>> media,
  ) async {
    final lead = await database.leadDao.byId(ownerSub, leadId);
    if (lead == null) return;
    for (final item in media) {
      final id = item['id'] as String;
      final local = await database.leadDao.mediaById(id);
      if (local != null) {
        await reconcileRemoteCreate(ownerSub, SyncEntityType.leadMedia, id);
        await database.leadDao.markMediaSyncState(id, 'synced');
      }
    }
  }

  DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;

  String _leadTypeFromApi(String value) => switch (value) {
    'supplier' => 'supplier',
    'partner' => 'partner',
    'customer' => 'customer',
    _ => throw FormatException('Unknown lead type'),
  };

  bool _isUuid(String value) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}
