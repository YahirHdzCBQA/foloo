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
import '../data/local/private_media_storage.dart';
import 'sync_models.dart';

class LegacyMediaRepairResult {
  const LegacyMediaRepairResult({
    required this.operationId,
    required this.mediaId,
    required this.result,
  });

  final String operationId;
  final String mediaId;
  final String result;
}

class SyncStore {
  SyncStore(this.database, {this.mediaStorage, String Function()? idFactory})
    : _idFactory = idFactory ?? const Uuid().v4;

  final AppDatabase database;
  final PrivateMediaStorage? mediaStorage;
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

  /// Reactivates only operations failed by the shipped FL-016 naive timestamp.
  /// Other 4xx contract failures remain terminal until their cause is fixed.
  Future<List<LegacyMediaRepairResult>> repairFailedMediaTimestamps(
    String ownerSub,
  ) async {
    final results = <LegacyMediaRepairResult>[];
    for (final operation in await all(ownerSub)) {
      if (operation.entityType != SyncEntityType.leadMedia.name ||
          operation.status != SyncOperationStatus.failed.name ||
          operation.lastError != 'http_400_validation_error') {
        continue;
      }
      Map<String, Object?> payload;
      try {
        payload = _payloadMap(operation.payloadJson);
      } on FormatException {
        results.add(_repairResult(operation, 'skipped_invalid_payload_json'));
        continue;
      }
      final capturedAt = payload['capturedAt'];
      final leadId = payload['leadId'];
      final byteSize = payload['byteSize'];
      final durationMs = payload['durationMs'];
      if (operation.action != 'create' ||
          leadId is! String ||
          !_isUuid(leadId) ||
          await database.leadDao.byId(ownerSub, leadId) == null ||
          payload['id'] != operation.entityId ||
          !_isUuid(operation.entityId) ||
          byteSize is! int ||
          byteSize <= 0 ||
          (durationMs != null && (durationMs is! int || durationMs < 0)) ||
          capturedAt is! String ||
          !_legacyNaiveTimestamp.hasMatch(capturedAt)) {
        results.add(_repairResult(operation, 'skipped_contract_mismatch'));
        continue;
      }
      LocalMediaType mediaType;
      try {
        mediaType = _localType(payload['kind'] as String);
      } on Object {
        results.add(_repairResult(operation, 'skipped_contract_mismatch'));
        continue;
      }
      final expectedContentType = mediaType == LocalMediaType.voiceNote
          ? 'audio/m4a'
          : 'image/jpeg';
      final maximumBytes = mediaType == LocalMediaType.voiceNote
          ? 100 * 1024 * 1024
          : 25 * 1024 * 1024;
      if (payload['contentType'] != expectedContentType ||
          byteSize > maximumBytes ||
          (mediaType != LocalMediaType.voiceNote && durationMs != null) ||
          (durationMs is int && durationMs % 1000 != 0)) {
        results.add(_repairResult(operation, 'skipped_contract_mismatch'));
        continue;
      }
      final parsedTimestamp = DateTime.tryParse(capturedAt);
      if (parsedTimestamp == null) {
        results.add(_repairResult(operation, 'skipped_contract_mismatch'));
        continue;
      }
      final storage = mediaStorage;
      if (storage == null) {
        results.add(_repairResult(operation, 'skipped_storage_unavailable'));
        continue;
      }
      final media = await mediaById(operation.entityId);
      final reconstructed = media == null;
      String? resolvedPath;
      if (media == null) {
        resolvedPath = await storage.findUniqueRecoveryFile(
          leadId: leadId,
          type: mediaType,
          byteSize: byteSize,
        );
        if (resolvedPath == null ||
            await database.leadDao.mediaByPath(resolvedPath) != null) {
          results.add(
            _repairResult(operation, 'skipped_media_file_not_unique'),
          );
          continue;
        }
      } else {
        if (media.leadLocalId != leadId || media.mediaType != mediaType.name) {
          results.add(_repairResult(operation, 'skipped_contract_mismatch'));
          continue;
        }
        resolvedPath = await storage.resolveExistingPath(media.localPath);
        if (resolvedPath == null) {
          results.add(_repairResult(operation, 'skipped_local_file_missing'));
          continue;
        }
      }
      if (await File(resolvedPath).length() != byteSize) {
        results.add(_repairResult(operation, 'skipped_contract_mismatch'));
        continue;
      }
      payload['capturedAt'] = parsedTimestamp.toUtc().toIso8601String();
      await database.transaction(() async {
        if (media == null) {
          await database.leadDao.insertMedia(
            LocalLeadMediaCompanion.insert(
              localId: operation.entityId,
              leadLocalId: leadId,
              mediaType: mediaType.name,
              localPath: resolvedPath!,
              durationSeconds: Value(
                durationMs is int ? durationMs ~/ 1000 : null,
              ),
              uploadState: const Value('pending'),
              createdAt: parsedTimestamp.toUtc(),
            ),
          );
        } else if (resolvedPath != media.localPath) {
          await database.leadDao.updateMediaLocalPath(
            operation.entityId,
            resolvedPath!,
          );
        }
        await database.syncDao.repairFailedMediaPayload(
          operation.operationId,
          jsonEncode(payload),
          DateTime.now().toUtc(),
        );
        await database.leadDao.markMediaSyncState(
          operation.entityId,
          'pending',
        );
      });
      results.add(
        _repairResult(
          operation,
          reconstructed
              ? 'reconstructed_legacy_media_and_captured_at'
              : 'repaired_legacy_captured_at',
        ),
      );
    }
    return results;
  }

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
          'startsAt': event.startsOn.toUtc().toIso8601String(),
          'endsAt': event.endsOn.toUtc().toIso8601String(),
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
            'capturedAt': lead.capturedAt.toUtc().toIso8601String(),
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
        if (media.uploadState != 'synced') {
          await enqueueMediaIfNeeded(ownerSub, lead.localId, media);
        }
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

  Future<StoredLeadMedia?> mediaById(String mediaId) =>
      database.leadDao.mediaById(mediaId);

  Future<void> enqueueMediaIfNeeded(
    String ownerSub,
    String leadId,
    StoredLeadMedia media,
  ) async {
    if (!_isUuid(media.localId) ||
        !await File(media.localPath).exists() ||
        await hasPending(ownerSub, SyncEntityType.leadMedia, media.localId)) {
      return;
    }
    final file = File(media.localPath);
    await enqueue(
      ownerSub: ownerSub,
      entityType: SyncEntityType.leadMedia,
      entityId: media.localId,
      action: 'create',
      payload: {
        'leadId': leadId,
        'id': media.localId,
        'kind': _apiKind(media.mediaType),
        'contentType': media.mediaType == LocalMediaType.voiceNote.name
            ? 'audio/m4a'
            : 'image/jpeg',
        'byteSize': await file.length(),
        'capturedAt': media.createdAt.toUtc().toIso8601String(),
        'durationMs': media.durationSeconds == null
            ? null
            : media.durationSeconds! * 1000,
      },
      now: media.createdAt,
    );
  }

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
    List<Map<String, Object?>> media, {
    Future<String> Function(Uri url, String contentType)? download,
  }) async {
    final lead = await database.leadDao.byId(ownerSub, leadId);
    if (lead == null) return;
    for (final item in media) {
      final id = item['id'] as String;
      final local = await database.leadDao.mediaById(id);
      final available = item['uploadStatus'] == 'available';
      if (local != null && available) {
        await reconcileRemoteCreate(ownerSub, SyncEntityType.leadMedia, id);
        await database.leadDao.markMediaSyncState(id, 'synced');
        continue;
      }
      if (local != null) {
        await database.leadDao.markMediaSyncState(id, 'pending');
        await enqueueMediaIfNeeded(ownerSub, leadId, local);
        continue;
      }
      final storage = mediaStorage;
      final downloadData = item['download'];
      if (!available ||
          storage == null ||
          download == null ||
          downloadData is! Map ||
          downloadData['url'] is! String ||
          item['contentType'] is! String) {
        continue;
      }
      final temporaryPath = await download(
        Uri.parse(downloadData['url'] as String),
        item['contentType'] as String,
      );
      try {
        final type = _localType(item['kind'] as String);
        final localPath = await storage.persist(
          sourcePath: temporaryPath,
          leadLocalId: leadId,
          type: type,
          slot: type == LocalMediaType.referenceImage ? id : null,
        );
        if (localPath == null) continue;
        await database.leadDao.insertMedia(
          LocalLeadMediaCompanion.insert(
            localId: id,
            leadLocalId: leadId,
            mediaType: type.name,
            localPath: localPath,
            durationSeconds: Value(
              item['durationMs'] is int
                  ? (item['durationMs'] as int) ~/ 1000
                  : null,
            ),
            uploadState: const Value('synced'),
            createdAt: DateTime.parse(item['capturedAt'] as String).toUtc(),
          ),
        );
      } finally {
        final temporary = File(temporaryPath);
        if (await temporary.exists()) await temporary.delete();
      }
    }
  }

  String _apiKind(String localType) => switch (localType) {
    'cardImage' => 'business_card',
    'referenceImage' => 'reference_image',
    'voiceNote' => 'voice_note',
    _ => throw const FormatException('Unsupported local media type'),
  };

  LocalMediaType _localType(String apiKind) => switch (apiKind) {
    'business_card' => LocalMediaType.cardImage,
    'reference_image' => LocalMediaType.referenceImage,
    'voice_note' => LocalMediaType.voiceNote,
    _ => throw const FormatException('Unsupported remote media type'),
  };

  DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;

  Map<String, Object?> _payloadMap(String value) =>
      (jsonDecode(value) as Map).cast<String, Object?>();

  LegacyMediaRepairResult _repairResult(
    StoredSyncOperation operation,
    String result,
  ) => LegacyMediaRepairResult(
    operationId: operation.operationId,
    mediaId: operation.entityId,
    result: result,
  );

  static final RegExp _legacyNaiveTimestamp = RegExp(
    r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}(?:\d{3})?$',
  );

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
