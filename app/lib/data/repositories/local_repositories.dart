/// Repository boundary between Foloo domain models and Drift/private files.
///
/// Widgets must consume these repositories through application state and must
/// not depend on Drift (CAP-09, SYN-01).
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';

import '../../models/app_event.dart';
import '../../models/lead_draft.dart';
import '../../models/session_lead.dart';
import '../../sync/sync_models.dart';
import '../../sync/sync_store.dart';
import '../local/app_database.dart';
import '../local/private_media_storage.dart';

typedef LocalIdFactory = String Function();

String _defaultLocalId() => const Uuid().v4();

/// Persists and restores the local seller identity (AUT-05).
class ProfileRepository {
  ProfileRepository(
    this._database, {
    LocalIdFactory? idFactory,
    SyncStore? syncStore,
  }) : _idFactory = idFactory ?? _defaultLocalId,
       _syncStore = syncStore ?? SyncStore(_database);

  final AppDatabase _database;
  final LocalIdFactory _idFactory;
  final SyncStore _syncStore;

  Future<DemoProfile?> load(String userId) async {
    final stored = await _database.profilePreferencesDao.profileForUser(userId);
    return stored == null
        ? null
        : DemoProfile(name: stored.name, company: stored.company);
  }

  Future<void> save(String userId, DemoProfile profile) async {
    final previous = await _database.profilePreferencesDao.profileForUser(
      userId,
    );
    final now = DateTime.now().toUtc();
    final localId = previous?.localId ?? _idFactory();
    await _database.transaction(() async {
      await _database.profilePreferencesDao.saveProfile(
        LocalProfilesCompanion.insert(
          localId: localId,
          ownerUserId: Value(userId),
          name: profile.name,
          company: profile.company,
          createdAt: previous?.createdAt ?? now,
          updatedAt: now,
          syncState: const Value('local'),
        ),
      );
      await _syncStore.enqueue(
        ownerSub: userId,
        entityType: SyncEntityType.profile,
        entityId: localId,
        action: 'upsert',
        payload: {'name': profile.name, 'company': profile.company},
        now: now,
      );
    });
  }
}

/// Stores only existing local appearance and language preferences.
class PreferencesRepository {
  const PreferencesRepository(this._database);

  final AppDatabase _database;

  Future<String?> read(String userId, String key) =>
      _database.profilePreferencesDao.userPreference(userId, key);

  Future<void> write(String userId, String key, String value) =>
      _database.profilePreferencesDao.saveUserPreference(userId, key, value);
}

/// Device-global values used only before a user-scoped repository is known.
class GlobalPreferencesRepository {
  const GlobalPreferencesRepository(this._database);

  final AppDatabase _database;

  Future<String?> read(String key) =>
      _database.profilePreferencesDao.globalPreference(key);

  Future<void> write(String key, String value) =>
      _database.profilePreferencesDao.saveGlobalPreference(key, value);

  Future<void> delete(String key) =>
      _database.profilePreferencesDao.deleteGlobalPreference(key);
}

/// Maps event CRUD and logical deletion to the local event DAO (EVT-*).
class EventRepository {
  EventRepository(this._database, {SyncStore? syncStore})
    : _syncStore = syncStore ?? SyncStore(_database);

  final AppDatabase _database;
  final SyncStore _syncStore;

  AppEvent _fromStored(StoredEvent event) => AppEvent(
    id: event.localId,
    name: event.name,
    startsOn: event.startsOn.toLocal(),
    endsOn: event.endsOn.toLocal(),
    active: event.active,
    contentFileIds: Set<String>.from(
      (jsonDecode(event.contentFileIdsJson) as List<dynamic>).cast<String>(),
    ),
  );

  Future<List<AppEvent>> list(String userId) async =>
      (await _database.eventDao.listActive(userId)).map(_fromStored).toList();

  Stream<List<AppEvent>> watch(String userId) => _database.eventDao
      .watchActive(userId)
      .map((events) => events.map(_fromStored).toList());

  Future<void> save(
    String userId,
    AppEvent event, {
    bool makeActive = false,
  }) async {
    await _database.transaction(() async {
      if (makeActive || event.active) {
        await _database.eventDao.deactivateAll(userId);
      }
      final previous = await _database.eventDao.byId(userId, event.id);
      final now = DateTime.now().toUtc();
      await _database.eventDao.upsert(
        LocalEventsCompanion.insert(
          localId: event.id,
          ownerUserId: Value(userId),
          commercialCode: Value(previous?.commercialCode),
          name: event.name,
          startsOn: event.startsOn.toUtc(),
          endsOn: event.endsOn.toUtc(),
          active: Value(makeActive || event.active),
          deleted: const Value(false),
          contentFileIdsJson: Value(jsonEncode(event.contentFileIds.toList())),
          createdAt: previous?.createdAt ?? now,
          updatedAt: now,
          syncState: Value(previous?.syncState ?? 'local'),
        ),
      );
      if (previous == null) {
        await _syncStore.enqueue(
          ownerSub: userId,
          entityType: SyncEntityType.event,
          entityId: event.id,
          action: 'create',
          payload: {
            'id': event.id,
            'name': event.name,
            'startsAt': event.startsOn.toUtc().toIso8601String(),
            'endsAt': event.endsOn.toUtc().toIso8601String(),
          },
          now: now,
        );
      }
    });
  }

  Future<void> delete(String userId, AppEvent event) async {
    await _database.eventDao.softDelete(
      userId,
      event.id,
      DateTime.now().toUtc(),
    );
  }

  Future<void> activate(String userId, String eventId) async {
    await _database.transaction(() async {
      final event = await _database.eventDao.byId(userId, eventId);
      if (event == null || event.deleted) {
        throw StateError('Cannot activate an unavailable event.');
      }
      final now = DateTime.now().toUtc();
      await _database.eventDao.deactivateAll(userId);
      await _database.eventDao.setActive(userId, eventId, now);
    });
  }

  Future<void> clearActive(String userId) =>
      _database.eventDao.deactivateAll(userId);
}

/// Commits validated drafts and durable media metadata as one local unit.
class LeadRepository {
  LeadRepository(
    this._database,
    this._mediaStorage, {
    LocalIdFactory? idFactory,
    SyncStore? syncStore,
  }) : _idFactory = idFactory ?? _defaultLocalId,
       _syncStore = syncStore ?? SyncStore(_database);

  final AppDatabase _database;
  final PrivateMediaStorage _mediaStorage;
  final LocalIdFactory _idFactory;
  final SyncStore _syncStore;

  Future<SessionLead> saveDraft(
    String userId,
    LeadDraft draft, {
    required DemoProfile capturedBy,
  }) async {
    final localId = _idFactory();
    String? cardPath;
    String? audioPath;
    final referencePaths = <String>[];
    var mediaIncomplete = false;
    try {
      try {
        cardPath = await _mediaStorage.persist(
          sourcePath: draft.cardImageLocalPath,
          leadLocalId: localId,
          type: LocalMediaType.cardImage,
        );
      } on FileSystemException {
        mediaIncomplete = true;
      } on MediaPersistenceException {
        mediaIncomplete = true;
      }
      try {
        audioPath = await _mediaStorage.persist(
          sourcePath: draft.audioLocalPath,
          leadLocalId: localId,
          type: LocalMediaType.voiceNote,
        );
      } on FileSystemException {
        mediaIncomplete = true;
      } on MediaPersistenceException {
        mediaIncomplete = true;
      }
      for (
        var index = 0;
        index < draft.referenceImageLocalPaths.length;
        index++
      ) {
        try {
          final path = await _mediaStorage.persist(
            sourcePath: draft.referenceImageLocalPaths[index],
            leadLocalId: localId,
            type: LocalMediaType.referenceImage,
            slot: index.toString(),
          );
          if (path != null) referencePaths.add(path);
        } on FileSystemException {
          mediaIncomplete = true;
        } on MediaPersistenceException {
          mediaIncomplete = true;
        }
      }
      final now = DateTime.now().toUtc();
      await _database.transaction(() async {
        await _database.leadDao.insertLead(
          LocalLeadsCompanion.insert(
            localId: localId,
            ownerUserId: Value(userId),
            capturedAt: now,
            capturedBy: capturedBy.name,
            originKind: draft.originKind.name,
            eventLocalId: Value(draft.eventLocalId),
            eventNameSnapshot: Value(draft.eventName),
            name: draft.name,
            lastName: draft.lastName,
            role: draft.role,
            company: draft.company,
            email: draft.email,
            phone: draft.phone,
            leadType: draft.type.name,
            interestLevel: draft.interest.name,
            note: draft.note,
            place: Value(draft.place),
            contentFileIdsJson: Value(jsonEncode(draft.contentFileIds)),
            contentNamesJson: Value(jsonEncode(draft.contentNames)),
            syncState: const Value('local'),
            createdAt: now,
            updatedAt: now,
          ),
        );
        if (cardPath != null) {
          await _insertMedia(
            id: _defaultLocalId(),
            leadId: localId,
            type: LocalMediaType.cardImage,
            path: cardPath,
            now: now,
          );
        }
        if (audioPath != null) {
          await _insertMedia(
            id: _defaultLocalId(),
            leadId: localId,
            type: LocalMediaType.voiceNote,
            path: audioPath,
            durationSeconds: draft.audioSeconds,
            now: now,
          );
        }
        for (var index = 0; index < referencePaths.length; index++) {
          await _insertMedia(
            id: _defaultLocalId(),
            leadId: localId,
            type: LocalMediaType.referenceImage,
            path: referencePaths[index],
            now: now.add(Duration(microseconds: index)),
          );
        }
        await _syncStore.enqueue(
          ownerSub: userId,
          entityType: SyncEntityType.lead,
          entityId: localId,
          action: 'create',
          payload: {
            'id': localId,
            'capturedAt': now.toIso8601String(),
            'origin': draft.originKind.name,
            'eventId': draft.originKind == LeadOriginKind.event
                ? draft.eventLocalId
                : null,
            'place': draft.originKind == LeadOriginKind.direct
                ? draft.place
                : null,
            'firstName': draft.name,
            'lastName': draft.lastName.isEmpty ? null : draft.lastName,
            'position': draft.role.isEmpty ? null : draft.role,
            'company': draft.company,
            'email': draft.email.isEmpty ? null : draft.email,
            'phone': draft.phone.isEmpty ? null : draft.phone,
            'leadType': draft.type.name,
            'interest': draft.interest.name,
            'writtenNote': draft.note.isEmpty ? null : draft.note,
          },
          now: now,
        );
        final media = await _database.leadDao.mediaFor(localId);
        for (final item in media) {
          final file = File(item.localPath);
          await _syncStore.enqueue(
            ownerSub: userId,
            entityType: SyncEntityType.leadMedia,
            entityId: item.localId,
            action: 'create',
            payload: {
              'leadId': localId,
              'id': item.localId,
              'kind': switch (LocalMediaType.values.byName(item.mediaType)) {
                LocalMediaType.cardImage => 'business_card',
                LocalMediaType.referenceImage => 'reference_image',
                LocalMediaType.voiceNote => 'voice_note',
              },
              'contentType': item.mediaType == LocalMediaType.voiceNote.name
                  ? 'audio/m4a'
                  : 'image/jpeg',
              'byteSize': await file.length(),
              'capturedAt': item.createdAt.toIso8601String(),
              'durationMs': item.durationSeconds == null
                  ? null
                  : item.durationSeconds! * 1000,
            },
            now: item.createdAt,
          );
        }
      });
      return SessionLead(
        localId: localId,
        folio: null,
        capturedAt: now.toLocal(),
        lead: draft.copyWith(
          cardImageLocalPath: cardPath,
          audioLocalPath: audioPath,
          clearCardImage: cardPath == null,
          clearAudio: audioPath == null,
          referenceImageLocalPaths: referencePaths,
        ),
        uploadState: SessionUploadState.local,
        mediaIncomplete: mediaIncomplete,
      );
    } catch (_) {
      await _mediaStorage.deleteIfManaged(cardPath);
      await _mediaStorage.deleteIfManaged(audioPath);
      for (final path in referencePaths) {
        await _mediaStorage.deleteIfManaged(path);
      }
      rethrow;
    }
  }

  Future<void> _insertMedia({
    required String id,
    required String leadId,
    required LocalMediaType type,
    required String path,
    required DateTime now,
    int? durationSeconds,
  }) => _database.leadDao.insertMedia(
    LocalLeadMediaCompanion.insert(
      localId: id,
      leadLocalId: leadId,
      mediaType: type.name,
      localPath: path,
      durationSeconds: Value(durationSeconds),
      uploadState: const Value('local'),
      createdAt: now,
    ),
  );

  Stream<List<SessionLead>> watchAll(String userId) => _database.leadDao
      .watchAll(userId)
      .asyncMap((bundles) => _visibleBundles(userId, bundles))
      .map((bundles) => bundles.map(_fromStored).toList());

  Future<List<SessionLead>> listAll(String userId) async =>
      (await _visibleBundles(
        userId,
        await _database.leadDao.listAll(userId),
      )).map(_fromStored).toList();

  Future<List<StoredLead>> byEvent(String userId, String eventId) async {
    final event = await _database.eventDao.byId(userId, eventId);
    if (event == null || event.deleted) return const [];
    return _database.leadDao.byEvent(userId, eventId);
  }

  Future<List<StoredLead>> byType(String userId, LeadType type) async =>
      _visibleRows(userId, await _database.leadDao.byType(userId, type.name));

  Future<List<StoredLead>> search(String userId, String query) async =>
      _visibleRows(userId, await _database.leadDao.search(userId, query));

  Future<void> updateStructured(String userId, StoredLead lead) {
    if (lead.ownerUserId != userId) {
      throw StateError('Cannot update a lead owned by another user.');
    }
    return _database.leadDao.updateLead(
      lead.copyWith(updatedAt: DateTime.now().toUtc()),
    );
  }

  Future<void> reconcileMediaReferences() async {
    for (final media in await _database.leadDao.allMedia()) {
      if (!await _mediaStorage.exists(media.localPath)) {
        await _database.leadDao.deleteMediaMetadata(media.localId);
      }
    }
  }

  Future<List<StoredLeadBundle>> _visibleBundles(
    String userId,
    List<StoredLeadBundle> bundles,
  ) async {
    final visibleEventIds = (await _database.eventDao.listActive(userId))
        .map((event) => event.localId)
        .toSet();
    return bundles
        .where(
          (bundle) =>
              bundle.lead.eventLocalId == null ||
              visibleEventIds.contains(bundle.lead.eventLocalId),
        )
        .toList();
  }

  Future<List<StoredLead>> _visibleRows(
    String userId,
    List<StoredLead> rows,
  ) async {
    final visibleEventIds = (await _database.eventDao.listActive(userId))
        .map((event) => event.localId)
        .toSet();
    return rows
        .where(
          (lead) =>
              lead.eventLocalId == null ||
              visibleEventIds.contains(lead.eventLocalId),
        )
        .toList();
  }

  SessionLead _fromStored(StoredLeadBundle bundle) {
    StoredLeadMedia? card;
    StoredLeadMedia? voice;
    final references = <StoredLeadMedia>[];
    for (final media in bundle.media) {
      if (media.mediaType == LocalMediaType.cardImage.name) card = media;
      if (media.mediaType == LocalMediaType.voiceNote.name) voice = media;
      if (media.mediaType == LocalMediaType.referenceImage.name) {
        references.add(media);
      }
    }
    final stored = bundle.lead;
    final mediaStates = bundle.media.map((item) => item.uploadState).toSet();
    final visibleSyncState = mediaStates.contains('failed')
        ? 'failed'
        : mediaStates.contains('syncing')
        ? 'syncing'
        : mediaStates.any((state) => state != 'synced')
        ? 'pending'
        : stored.syncState;
    return SessionLead(
      localId: stored.localId,
      folio: stored.commercialFolio,
      capturedAt: stored.capturedAt.toLocal(),
      uploadState: switch (visibleSyncState) {
        // Historical values are preserved but interpreted as provider-neutral.
        'enHoja' => SessionUploadState.synced,
        'synced' => SessionUploadState.synced,
        'pendiente' => SessionUploadState.pending,
        'pending' => SessionUploadState.pending,
        'syncing' => SessionUploadState.syncing,
        'failed' => SessionUploadState.failed,
        _ => SessionUploadState.local,
      },
      lead: LeadDraft(
        name: stored.name,
        lastName: stored.lastName,
        role: stored.role,
        company: stored.company,
        email: stored.email,
        phone: stored.phone,
        type: LeadType.values.byName(stored.leadType),
        interest: InterestLevel.values.byName(stored.interestLevel),
        note: stored.note,
        originKind: LeadOriginKind.values.byName(stored.originKind),
        eventLocalId: stored.eventLocalId,
        eventName: stored.eventNameSnapshot,
        cardImageLocalPath: card?.localPath,
        audioLocalPath: voice?.localPath,
        audioSeconds: voice?.durationSeconds ?? 0,
        place: stored.place,
        contentFileIds: List<String>.from(
          (jsonDecode(stored.contentFileIdsJson) as List<dynamic>)
              .cast<String>(),
        ),
        contentNames: List<String>.from(
          (jsonDecode(stored.contentNamesJson) as List<dynamic>).cast<String>(),
        ),
        referenceImageLocalPaths: references
            .map((media) => media.localPath)
            .toList(),
      ),
    );
  }
}

/// Owns the single shared database and repository graph for one app process.
class LocalPersistence {
  LocalPersistence._(
    this.database,
    this.mediaStorage, {
    this.deleteMediaOnClose = false,
  }) : profiles = ProfileRepository(database),
       preferences = PreferencesRepository(database),
       globalPreferences = GlobalPreferencesRepository(database),
       events = EventRepository(database),
       leads = LeadRepository(database, mediaStorage),
       syncStore = SyncStore(database);

  final AppDatabase database;
  final PrivateMediaStorage mediaStorage;
  final bool deleteMediaOnClose;
  final ProfileRepository profiles;
  final PreferencesRepository preferences;
  final GlobalPreferencesRepository globalPreferences;
  final EventRepository events;
  final LeadRepository leads;
  final SyncStore syncStore;

  static Future<LocalPersistence> production() async =>
      LocalPersistence._(AppDatabase(), await PrivateMediaStorage.production());

  static LocalPersistence inMemory({Directory? mediaRoot}) {
    final root =
        mediaRoot ??
        Directory(
          '${Directory.systemTemp.path}/foloo_test_media_${const Uuid().v4()}',
        );
    return LocalPersistence._(
      AppDatabase(NativeDatabase.memory()),
      PrivateMediaStorage(root),
      deleteMediaOnClose: mediaRoot == null,
    );
  }

  Future<void> initialize() => leads.reconcileMediaReferences();

  Future<void> close() async {
    await database.close();
    if (deleteMediaOnClose && await mediaStorage.root.exists()) {
      await mediaStorage.root.delete(recursive: true);
    }
  }
}
