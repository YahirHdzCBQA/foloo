/// Drift schema and data-access objects for Foloo's durable local-first store.
///
/// CAP-15/SYN-01/SYN-02: structured data is committed locally before any
/// future network delivery. Binary media is intentionally stored elsewhere.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

@DataClassName('StoredProfile')
@TableIndex(name: 'profile_owner_idx', columns: {#ownerUserId}, unique: true)
class LocalProfiles extends Table {
  TextColumn get localId => text()();
  TextColumn get ownerUserId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get company => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get syncState => text().withDefault(const Constant('local'))();

  @override
  Set<Column<Object>> get primaryKey => {localId};
}

@DataClassName('StoredEvent')
@TableIndex(name: 'event_owner_idx', columns: {#ownerUserId})
class LocalEvents extends Table {
  TextColumn get localId => text()();
  TextColumn get ownerUserId => text().nullable()();
  TextColumn get commercialCode => text().nullable()();
  TextColumn get name => text()();
  DateTimeColumn get startsOn => dateTime()();
  DateTimeColumn get endsOn => dateTime()();
  BoolColumn get active => boolean().withDefault(const Constant(false))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  TextColumn get contentFileIdsJson =>
      text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get syncState => text().withDefault(const Constant('local'))();
  IntColumn get remoteRevision => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {localId};
}

@DataClassName('StoredContentFile')
@TableIndex(name: 'content_owner_idx', columns: {#ownerUserId})
class LocalContentFiles extends Table {
  TextColumn get localId => text()();
  TextColumn get ownerUserId => text()();
  TextColumn get displayName => text()();
  TextColumn get fileName => text()();
  IntColumn get byteSize => integer()();
  TextColumn get localPath => text().nullable()();
  BoolColumn get allEvents => boolean().withDefault(const Constant(false))();
  TextColumn get eventIdsJson => text().withDefault(const Constant('[]'))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  TextColumn get uploadState => text().withDefault(const Constant('pending'))();
  TextColumn get syncState => text().withDefault(const Constant('local'))();
  IntColumn get remoteRevision => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {localId};
}

@DataClassName('StoredEmailTemplate')
class LocalEmailTemplates extends Table {
  TextColumn get ownerUserId => text()();
  TextColumn get originKind => text()();
  TextColumn get languageCode => text()();
  TextColumn get subject => text()();
  TextColumn get body => text()();
  TextColumn get signature => text()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get syncState => text().withDefault(const Constant('local'))();

  @override
  Set<Column<Object>> get primaryKey => {ownerUserId, originKind, languageCode};
}

@DataClassName('StoredEventEmailTemplate')
class LocalEventEmailTemplates extends Table {
  TextColumn get ownerUserId => text()();
  TextColumn get eventLocalId => text().references(LocalEvents, #localId)();
  TextColumn get languageCode => text()();
  TextColumn get subject => text()();
  TextColumn get body => text()();
  TextColumn get signature => text()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get syncState => text().withDefault(const Constant('local'))();

  @override
  Set<Column<Object>> get primaryKey => {
    ownerUserId,
    eventLocalId,
    languageCode,
  };
}

@DataClassName('StoredEmailConnection')
class LocalEmailConnections extends Table {
  TextColumn get ownerUserId => text()();
  TextColumn get connectionId => text()();
  TextColumn get provider => text()();
  TextColumn get senderAddress => text()();
  TextColumn get status => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {ownerUserId};
}

@DataClassName('StoredEmailFollowUp')
@TableIndex(
  name: 'email_follow_up_owner_idx',
  columns: {#ownerUserId, #preparedAt},
)
class LocalEmailFollowUps extends Table {
  TextColumn get localId => text()();
  TextColumn get ownerUserId => text()();
  TextColumn get leadLocalId => text().references(LocalLeads, #localId)();
  TextColumn get recipientAddress => text()();
  TextColumn get subject => text()();
  TextColumn get plainBody => text()();
  TextColumn get htmlBody => text()();
  TextColumn get contentFileIdsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get contentNamesJson => text().withDefault(const Constant('[]'))();
  TextColumn get languageCode => text()();
  DateTimeColumn get preparedAt => dateTime()();
  TextColumn get subjectSemanticJson => text().nullable()();
  TextColumn get bodySemanticJson => text().nullable()();
  BoolColumn get subjectManuallyEdited =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get bodyManuallyEdited =>
      boolean().withDefault(const Constant(false))();
  TextColumn get syncState => text().withDefault(const Constant('local'))();

  @override
  Set<Column<Object>> get primaryKey => {localId};
}

@DataClassName('StoredEmailSendIntent')
@TableIndex(
  name: 'email_intent_owner_status_idx',
  columns: {#ownerUserId, #status},
)
class LocalEmailSendIntents extends Table {
  TextColumn get localId => text()();
  TextColumn get ownerUserId => text()();
  TextColumn get followUpLocalId =>
      text().references(LocalEmailFollowUps, #localId)();
  TextColumn get connectionId => text().nullable()();
  TextColumn get senderAddress => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get omittedContentIdsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get parentIntentId => text().nullable()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get errorCode => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {localId};
}

@DataClassName('StoredLead')
@TableIndex(name: 'lead_event_idx', columns: {#eventLocalId})
@TableIndex(name: 'lead_captured_idx', columns: {#capturedAt})
@TableIndex(name: 'lead_owner_idx', columns: {#ownerUserId})
class LocalLeads extends Table {
  TextColumn get localId => text()();
  TextColumn get ownerUserId => text().nullable()();
  TextColumn get commercialFolio => text().nullable()();
  DateTimeColumn get capturedAt => dateTime()();
  TextColumn get capturedBy => text()();
  TextColumn get originKind => text()();
  TextColumn get eventLocalId => text().nullable().references(
    LocalEvents,
    #localId,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get eventNameSnapshot => text().nullable()();
  TextColumn get name => text()();
  TextColumn get lastName => text()();
  TextColumn get role => text()();
  TextColumn get company => text()();
  TextColumn get email => text()();
  TextColumn get phone => text()();
  TextColumn get leadType => text()();
  TextColumn get interestLevel => text()();
  TextColumn get note => text()();
  TextColumn get place => text().nullable()();
  TextColumn get contentFileIdsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get contentNamesJson => text().withDefault(const Constant('[]'))();
  // Legacy nullable column retained to read existing databases without reset.
  // It is no longer mapped into the V1 domain model (VOZ-08).
  TextColumn get transcription => text().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('local'))();
  IntColumn get remoteRevision => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {localId};
}

@DataClassName('StoredLeadMedia')
@TableIndex(name: 'media_lead_idx', columns: {#leadLocalId})
class LocalLeadMedia extends Table {
  TextColumn get localId => text()();
  TextColumn get leadLocalId =>
      text().references(LocalLeads, #localId, onDelete: KeyAction.cascade)();
  TextColumn get mediaType => text()();
  TextColumn get localPath => text().unique()();
  IntColumn get durationSeconds => integer().nullable()();
  TextColumn get uploadState => text().withDefault(const Constant('local'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {localId};
}

@DataClassName('StoredPreference')
class LocalPreferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Per-user settings. Legacy [LocalPreferences] remain global for auth
/// bootstrap and to preserve unowned v1 values without silently assigning them.
@DataClassName('StoredUserPreference')
class LocalUserPreferences extends Table {
  TextColumn get ownerUserId => text()();
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {ownerUserId, key};
}

@DataClassName('StoredSyncOperation')
@TableIndex(name: 'sync_owner_status_idx', columns: {#ownerUserId, #status})
class SyncOperations extends Table {
  TextColumn get operationId => text()();
  TextColumn get ownerUserId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get action => text()();
  TextColumn get payloadJson => text()();
  TextColumn get idempotencyKey => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {operationId};
}

/// Lead plus its durable media metadata.
class StoredLeadBundle {
  const StoredLeadBundle(this.lead, this.media);

  final StoredLead lead;
  final List<StoredLeadMedia> media;
}

@DriftAccessor(tables: [LocalEmailTemplates])
class EmailTemplateDao extends DatabaseAccessor<AppDatabase>
    with _$EmailTemplateDaoMixin {
  EmailTemplateDao(super.db);

  Future<List<StoredEmailTemplate>> listForOwner(String ownerSub) => (select(
    localEmailTemplates,
  )..where((row) => row.ownerUserId.equals(ownerSub))).get();

  Future<void> upsert(LocalEmailTemplatesCompanion template) =>
      into(localEmailTemplates).insertOnConflictUpdate(template);

  Future<void> markSynced(
    String ownerSub,
    String originKind,
    String languageCode,
  ) =>
      (update(localEmailTemplates)..where(
            (row) =>
                row.ownerUserId.equals(ownerSub) &
                row.originKind.equals(originKind) &
                row.languageCode.equals(languageCode),
          ))
          .write(
            const LocalEmailTemplatesCompanion(syncState: Value('synced')),
          );
}

@DriftAccessor(tables: [LocalEventEmailTemplates])
class EventEmailTemplateDao extends DatabaseAccessor<AppDatabase>
    with _$EventEmailTemplateDaoMixin {
  EventEmailTemplateDao(super.db);

  Future<List<StoredEventEmailTemplate>> listForOwner(String owner) => (select(
    localEventEmailTemplates,
  )..where((row) => row.ownerUserId.equals(owner))).get();

  Future<StoredEventEmailTemplate?> forEvent(
    String owner,
    String eventId,
    String language,
  ) =>
      (select(localEventEmailTemplates)..where(
            (row) =>
                row.ownerUserId.equals(owner) &
                row.eventLocalId.equals(eventId) &
                row.languageCode.equals(language),
          ))
          .getSingleOrNull();

  Future<void> upsert(LocalEventEmailTemplatesCompanion value) =>
      into(localEventEmailTemplates).insertOnConflictUpdate(value);

  Future<void> remove(String owner, String eventId, String language) =>
      (delete(localEventEmailTemplates)..where(
            (row) =>
                row.ownerUserId.equals(owner) &
                row.eventLocalId.equals(eventId) &
                row.languageCode.equals(language),
          ))
          .go();

  Future<void> markSynced(String owner, String eventId, String language) =>
      (update(localEventEmailTemplates)..where(
            (row) =>
                row.ownerUserId.equals(owner) &
                row.eventLocalId.equals(eventId) &
                row.languageCode.equals(language),
          ))
          .write(
            const LocalEventEmailTemplatesCompanion(syncState: Value('synced')),
          );
}

@DriftAccessor(
  tables: [LocalEmailConnections, LocalEmailFollowUps, LocalEmailSendIntents],
)
class EmailDeliveryDao extends DatabaseAccessor<AppDatabase>
    with _$EmailDeliveryDaoMixin {
  EmailDeliveryDao(super.db);

  Future<StoredEmailConnection?> connectionForOwner(String owner) => (select(
    localEmailConnections,
  )..where((row) => row.ownerUserId.equals(owner))).getSingleOrNull();

  Future<void> saveConnection(LocalEmailConnectionsCompanion value) =>
      into(localEmailConnections).insertOnConflictUpdate(value);

  Future<List<StoredEmailFollowUp>> followUps(String owner) =>
      (select(localEmailFollowUps)
            ..where((row) => row.ownerUserId.equals(owner))
            ..orderBy([(row) => OrderingTerm.desc(row.preparedAt)]))
          .get();

  Stream<List<StoredEmailFollowUp>> watchFollowUps(String owner) =>
      (select(localEmailFollowUps)
            ..where((row) => row.ownerUserId.equals(owner))
            ..orderBy([(row) => OrderingTerm.desc(row.preparedAt)]))
          .watch();

  Future<StoredEmailFollowUp?> followUpForLead(String owner, String leadId) =>
      (select(localEmailFollowUps)
            ..where(
              (row) =>
                  row.ownerUserId.equals(owner) &
                  row.leadLocalId.equals(leadId),
            )
            ..orderBy([(row) => OrderingTerm.desc(row.preparedAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<StoredEmailFollowUp?> followUpById(String owner, String id) =>
      (select(localEmailFollowUps)..where(
            (row) => row.ownerUserId.equals(owner) & row.localId.equals(id),
          ))
          .getSingleOrNull();

  Future<void> saveFollowUp(LocalEmailFollowUpsCompanion value) =>
      into(localEmailFollowUps).insertOnConflictUpdate(value);

  Future<void> updatePreparedFollowUp(
    String owner,
    String id, {
    required String subject,
    required String plainBody,
    required String htmlBody,
  }) =>
      (update(localEmailFollowUps)..where(
            (row) => row.ownerUserId.equals(owner) & row.localId.equals(id),
          ))
          .write(
            LocalEmailFollowUpsCompanion(
              subject: Value(subject),
              plainBody: Value(plainBody),
              htmlBody: Value(htmlBody),
            ),
          );

  Future<void> updateReviewPreparation(
    String owner,
    String id, {
    required String subject,
    required String plainBody,
    required String htmlBody,
    required String subjectSemanticJson,
    required String bodySemanticJson,
    required bool subjectManuallyEdited,
    required bool bodyManuallyEdited,
  }) =>
      (update(localEmailFollowUps)..where(
            (row) => row.ownerUserId.equals(owner) & row.localId.equals(id),
          ))
          .write(
            LocalEmailFollowUpsCompanion(
              subject: Value(subject),
              plainBody: Value(plainBody),
              htmlBody: Value(htmlBody),
              subjectSemanticJson: Value(subjectSemanticJson),
              bodySemanticJson: Value(bodySemanticJson),
              subjectManuallyEdited: Value(subjectManuallyEdited),
              bodyManuallyEdited: Value(bodyManuallyEdited),
            ),
          );

  Future<void> replacePreparation(
    String owner,
    String id, {
    required String recipientAddress,
    required String subject,
    required String plainBody,
    required String htmlBody,
    required String contentFileIdsJson,
    required String contentNamesJson,
    required String languageCode,
    required DateTime preparedAt,
    required String subjectSemanticJson,
    required String bodySemanticJson,
    required bool subjectManuallyEdited,
    required bool bodyManuallyEdited,
  }) =>
      (update(localEmailFollowUps)..where(
            (row) => row.ownerUserId.equals(owner) & row.localId.equals(id),
          ))
          .write(
            LocalEmailFollowUpsCompanion(
              recipientAddress: Value(recipientAddress),
              subject: Value(subject),
              plainBody: Value(plainBody),
              htmlBody: Value(htmlBody),
              contentFileIdsJson: Value(contentFileIdsJson),
              contentNamesJson: Value(contentNamesJson),
              languageCode: Value(languageCode),
              preparedAt: Value(preparedAt),
              subjectSemanticJson: Value(subjectSemanticJson),
              bodySemanticJson: Value(bodySemanticJson),
              subjectManuallyEdited: Value(subjectManuallyEdited),
              bodyManuallyEdited: Value(bodyManuallyEdited),
            ),
          );

  Future<void> markFollowUpSynced(String owner, String id) =>
      (update(localEmailFollowUps)..where(
            (row) => row.ownerUserId.equals(owner) & row.localId.equals(id),
          ))
          .write(
            const LocalEmailFollowUpsCompanion(syncState: Value('synced')),
          );

  Future<List<StoredEmailSendIntent>> intents(String owner) =>
      (select(localEmailSendIntents)
            ..where((row) => row.ownerUserId.equals(owner))
            ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
          .get();

  Stream<List<StoredEmailSendIntent>> watchIntents(String owner) =>
      (select(localEmailSendIntents)
            ..where((row) => row.ownerUserId.equals(owner))
            ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
          .watch();

  Future<void> saveIntent(LocalEmailSendIntentsCompanion value) =>
      into(localEmailSendIntents).insertOnConflictUpdate(value);

  Future<void> updateIntentState(
    String owner,
    String id,
    String status,
    int attempts,
    String? errorCode,
    DateTime now, {
    List<String>? omittedContentIds,
  }) =>
      (update(localEmailSendIntents)..where(
            (row) => row.ownerUserId.equals(owner) & row.localId.equals(id),
          ))
          .write(
            LocalEmailSendIntentsCompanion(
              status: Value(status),
              attemptCount: Value(attempts),
              errorCode: Value(errorCode),
              omittedContentIdsJson: omittedContentIds == null
                  ? const Value.absent()
                  : Value(jsonEncode(omittedContentIds)),
              updatedAt: Value(now),
            ),
          );
}

@DriftAccessor(tables: [LocalProfiles, LocalPreferences, LocalUserPreferences])
class ProfilePreferencesDao extends DatabaseAccessor<AppDatabase>
    with _$ProfilePreferencesDaoMixin {
  ProfilePreferencesDao(super.db);

  Future<StoredProfile?> profileForUser(String userId) => (select(
    localProfiles,
  )..where((row) => row.ownerUserId.equals(userId))).getSingleOrNull();

  Future<void> saveProfile(LocalProfilesCompanion profile) =>
      into(localProfiles).insertOnConflictUpdate(profile);

  Future<void> markProfileSynced(String userId) =>
      (update(localProfiles)..where((row) => row.ownerUserId.equals(userId)))
          .write(const LocalProfilesCompanion(syncState: Value('synced')));

  Future<String?> globalPreference(String key) async => (await (select(
    localPreferences,
  )..where((row) => row.key.equals(key))).getSingleOrNull())?.value;

  Future<void> saveGlobalPreference(String key, String value) =>
      into(localPreferences).insertOnConflictUpdate(
        LocalPreferencesCompanion.insert(
          key: key,
          value: value,
          updatedAt: DateTime.now().toUtc(),
        ),
      );

  Future<void> deleteGlobalPreference(String key) =>
      (delete(localPreferences)..where((row) => row.key.equals(key))).go();

  Future<String?> userPreference(String userId, String key) async =>
      (await (select(localUserPreferences)..where(
                (row) => row.ownerUserId.equals(userId) & row.key.equals(key),
              ))
              .getSingleOrNull())
          ?.value;

  Future<void> saveUserPreference(String userId, String key, String value) =>
      into(localUserPreferences).insertOnConflictUpdate(
        LocalUserPreferencesCompanion.insert(
          ownerUserId: userId,
          key: key,
          value: value,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
}

@DriftAccessor(tables: [LocalEvents])
class EventDao extends DatabaseAccessor<AppDatabase> with _$EventDaoMixin {
  EventDao(super.db);

  Future<List<StoredEvent>> listActive(String userId) =>
      (select(localEvents)
            ..where(
              (row) =>
                  row.ownerUserId.equals(userId) & row.deleted.equals(false),
            )
            ..orderBy([(row) => OrderingTerm.desc(row.startsOn)]))
          .get();

  Stream<List<StoredEvent>> watchActive(String userId) =>
      (select(localEvents)
            ..where(
              (row) =>
                  row.ownerUserId.equals(userId) & row.deleted.equals(false),
            )
            ..orderBy([(row) => OrderingTerm.desc(row.startsOn)]))
          .watch();

  Future<StoredEvent?> byId(String userId, String id) =>
      (select(localEvents)..where(
            (row) => row.ownerUserId.equals(userId) & row.localId.equals(id),
          ))
          .getSingleOrNull();

  Future<void> upsert(LocalEventsCompanion event) =>
      into(localEvents).insertOnConflictUpdate(event);

  Future<void> deactivateAll(String userId) =>
      (update(localEvents)..where((row) => row.ownerUserId.equals(userId)))
          .write(const LocalEventsCompanion(active: Value(false)));

  Future<void> softDelete(String userId, String id, DateTime now) =>
      (update(localEvents)..where(
            (row) => row.ownerUserId.equals(userId) & row.localId.equals(id),
          ))
          .write(
            LocalEventsCompanion(
              active: const Value(false),
              deleted: const Value(true),
              updatedAt: Value(now),
            ),
          );

  Future<void> setActive(String userId, String id, DateTime now) =>
      (update(localEvents)..where(
            (row) => row.ownerUserId.equals(userId) & row.localId.equals(id),
          ))
          .write(
            LocalEventsCompanion(
              active: const Value(true),
              updatedAt: Value(now),
            ),
          );

  Future<void> markSynced(String userId, String id) =>
      (update(localEvents)..where(
            (row) => row.ownerUserId.equals(userId) & row.localId.equals(id),
          ))
          .write(const LocalEventsCompanion(syncState: Value('synced')));

  Future<void> markRemoteRevision(String userId, String id, int revision) =>
      (update(localEvents)..where(
            (row) => row.ownerUserId.equals(userId) & row.localId.equals(id),
          ))
          .write(
            LocalEventsCompanion(
              syncState: const Value('synced'),
              remoteRevision: Value(revision),
            ),
          );
}

@DriftAccessor(tables: [LocalContentFiles])
class ContentDao extends DatabaseAccessor<AppDatabase> with _$ContentDaoMixin {
  ContentDao(super.db);

  Future<List<StoredContentFile>> list(String owner) =>
      (select(localContentFiles)
            ..where(
              (row) =>
                  row.ownerUserId.equals(owner) & row.deleted.equals(false),
            )
            ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
          .get();

  Future<StoredContentFile?> byId(String owner, String id) =>
      (select(localContentFiles)..where(
            (row) => row.ownerUserId.equals(owner) & row.localId.equals(id),
          ))
          .getSingleOrNull();

  Future<StoredContentFile?> byAnyId(String id) => (select(
    localContentFiles,
  )..where((row) => row.localId.equals(id))).getSingleOrNull();

  Future<void> upsert(LocalContentFilesCompanion file) =>
      into(localContentFiles).insertOnConflictUpdate(file);

  Future<void> markSynced(
    String owner,
    String id,
    int revision, {
    bool uploaded = false,
  }) =>
      (update(localContentFiles)..where(
            (row) => row.ownerUserId.equals(owner) & row.localId.equals(id),
          ))
          .write(
            LocalContentFilesCompanion(
              syncState: const Value('synced'),
              remoteRevision: Value(revision),
              uploadState: uploaded
                  ? const Value('available')
                  : const Value.absent(),
            ),
          );

  Future<void> markState(String owner, String id, String state) =>
      (update(localContentFiles)..where(
            (row) => row.ownerUserId.equals(owner) & row.localId.equals(id),
          ))
          .write(LocalContentFilesCompanion(syncState: Value(state)));
}

@DriftAccessor(tables: [LocalLeads, LocalLeadMedia])
class LeadDao extends DatabaseAccessor<AppDatabase> with _$LeadDaoMixin {
  LeadDao(super.db);

  Future<void> insertLead(LocalLeadsCompanion lead) =>
      into(localLeads).insert(lead);

  Future<void> insertMedia(LocalLeadMediaCompanion media) =>
      into(localLeadMedia).insert(media);

  Future<void> updateLead(StoredLead lead) => update(localLeads).replace(lead);

  Future<List<StoredLeadMedia>> mediaFor(String leadId) =>
      (select(localLeadMedia)
            ..where((row) => row.leadLocalId.equals(leadId))
            ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
          .get();

  Future<StoredLead?> byId(String userId, String id) =>
      (select(localLeads)..where(
            (row) => row.ownerUserId.equals(userId) & row.localId.equals(id),
          ))
          .getSingleOrNull();

  Future<StoredLeadMedia?> mediaById(String id) => (select(
    localLeadMedia,
  )..where((row) => row.localId.equals(id))).getSingleOrNull();

  Future<StoredLeadMedia?> mediaByPath(String path) => (select(
    localLeadMedia,
  )..where((row) => row.localPath.equals(path))).getSingleOrNull();

  Future<List<StoredLeadBundle>> _bundles(List<StoredLead> leads) async =>
      Future.wait(
        leads.map(
          (lead) async => StoredLeadBundle(lead, await mediaFor(lead.localId)),
        ),
      );

  Stream<List<StoredLeadBundle>> watchAll(String userId) =>
      (select(localLeads)
            ..where((row) => row.ownerUserId.equals(userId))
            ..orderBy([
              (row) => OrderingTerm.desc(row.capturedAt),
              (row) => OrderingTerm.asc(row.localId),
            ]))
          .watch()
          .asyncMap(_bundles);

  Future<List<StoredLeadBundle>> listAll(String userId) async => _bundles(
    await (select(localLeads)
          ..where((row) => row.ownerUserId.equals(userId))
          ..orderBy([
            (row) => OrderingTerm.desc(row.capturedAt),
            (row) => OrderingTerm.asc(row.localId),
          ]))
        .get(),
  );

  Future<List<StoredLead>> byEvent(String userId, String eventId) =>
      (select(localLeads)
            ..where(
              (row) =>
                  row.ownerUserId.equals(userId) &
                  row.eventLocalId.equals(eventId),
            )
            ..orderBy([
              (row) => OrderingTerm.desc(row.capturedAt),
              (row) => OrderingTerm.asc(row.localId),
            ]))
          .get();

  Future<List<StoredLead>> byType(String userId, String type) =>
      (select(localLeads)
            ..where(
              (row) =>
                  row.ownerUserId.equals(userId) & row.leadType.equals(type),
            )
            ..orderBy([
              (row) => OrderingTerm.desc(row.capturedAt),
              (row) => OrderingTerm.asc(row.localId),
            ]))
          .get();

  Future<List<StoredLead>> search(String userId, String query) {
    final pattern = '%${query.trim()}%';
    return (select(localLeads)
          ..where(
            (row) =>
                row.ownerUserId.equals(userId) &
                (row.name.like(pattern) |
                    row.lastName.like(pattern) |
                    row.company.like(pattern)),
          )
          ..orderBy([
            (row) => OrderingTerm.desc(row.capturedAt),
            (row) => OrderingTerm.asc(row.localId),
          ]))
        .get();
  }

  Future<List<StoredLeadMedia>> allMedia() => select(localLeadMedia).get();

  Future<void> deleteMediaMetadata(String id) =>
      (delete(localLeadMedia)..where((row) => row.localId.equals(id))).go();

  Future<void> updateVoiceMedia(
    String id, {
    required String path,
    required int durationSeconds,
  }) => (update(localLeadMedia)..where((row) => row.localId.equals(id))).write(
    LocalLeadMediaCompanion(
      localPath: Value(path),
      durationSeconds: Value(durationSeconds),
      uploadState: const Value('local'),
    ),
  );

  Future<void> markLeadSyncState(String userId, String id, String state) =>
      (update(localLeads)..where(
            (row) => row.ownerUserId.equals(userId) & row.localId.equals(id),
          ))
          .write(LocalLeadsCompanion(syncState: Value(state)));

  Future<void> markMediaSyncState(String id, String state) =>
      (update(localLeadMedia)..where((row) => row.localId.equals(id))).write(
        LocalLeadMediaCompanion(uploadState: Value(state)),
      );

  Future<void> markLeadSynced(String userId, String id, int revision) =>
      (update(localLeads)..where(
            (row) => row.ownerUserId.equals(userId) & row.localId.equals(id),
          ))
          .write(
            LocalLeadsCompanion(
              syncState: const Value('synced'),
              remoteRevision: Value(revision),
            ),
          );

  Future<void> updateMediaLocalPath(String id, String path) =>
      (update(localLeadMedia)..where((row) => row.localId.equals(id))).write(
        LocalLeadMediaCompanion(localPath: Value(path)),
      );
}

@DriftAccessor(tables: [SyncOperations])
class SyncDao extends DatabaseAccessor<AppDatabase> with _$SyncDaoMixin {
  SyncDao(super.db);

  Future<void> enqueue(SyncOperationsCompanion operation) =>
      into(syncOperations).insert(operation);

  Future<List<StoredSyncOperation>> pendingForOwner(
    String ownerUserId,
    DateTime now, {
    bool ignoreRetryBackoff = false,
  }) {
    final query = select(syncOperations)
      ..where(
        (row) =>
            row.ownerUserId.equals(ownerUserId) &
            (row.status.equals('pending') | row.status.equals('retryable')),
      );
    if (!ignoreRetryBackoff) {
      query.where(
        (row) =>
            row.nextAttemptAt.isNull() |
            row.nextAttemptAt.isSmallerOrEqualValue(now),
      );
    }
    query.orderBy([(row) => OrderingTerm.asc(row.createdAt)]);
    return query.get();
  }

  Future<List<StoredSyncOperation>> allForOwner(String ownerUserId) => (select(
    syncOperations,
  )..where((row) => row.ownerUserId.equals(ownerUserId))).get();

  Future<List<StoredSyncOperation>> forEntity(
    String ownerUserId,
    String entityType,
    String entityId,
  ) =>
      (select(syncOperations)..where(
            (row) =>
                row.ownerUserId.equals(ownerUserId) &
                row.entityType.equals(entityType) &
                row.entityId.equals(entityId),
          ))
          .get();

  Future<void> deleteForEntity(
    String ownerUserId,
    String entityType,
    String entityId,
  ) =>
      (delete(syncOperations)..where(
            (row) =>
                row.ownerUserId.equals(ownerUserId) &
                row.entityType.equals(entityType) &
                row.entityId.equals(entityId),
          ))
          .go();

  Future<void> completeCreatesForEntity(
    String ownerUserId,
    String entityType,
    String entityId,
  ) =>
      (delete(syncOperations)..where(
            (row) =>
                row.ownerUserId.equals(ownerUserId) &
                row.entityType.equals(entityType) &
                row.entityId.equals(entityId) &
                row.action.equals('create'),
          ))
          .go();

  Future<bool> hasOpenOperation(
    String ownerUserId,
    String entityType,
    String entityId,
  ) async =>
      await (selectOnly(syncOperations)
            ..addColumns([syncOperations.operationId.count()])
            ..where(
              syncOperations.ownerUserId.equals(ownerUserId) &
                  syncOperations.entityType.equals(entityType) &
                  syncOperations.entityId.equals(entityId) &
                  syncOperations.status.isNotValue('completed'),
            ))
          .map((row) => row.read(syncOperations.operationId.count()) ?? 0)
          .getSingle() >
      0;

  Future<void> markRunning(String operationId, DateTime now) =>
      (update(
        syncOperations,
      )..where((row) => row.operationId.equals(operationId))).write(
        SyncOperationsCompanion(
          status: const Value('syncing'),
          updatedAt: Value(now),
          lastError: const Value(null),
        ),
      );

  Future<void> markRetryable(
    String operationId,
    int attemptCount,
    DateTime nextAttemptAt,
    String error,
    DateTime now,
  ) =>
      (update(
        syncOperations,
      )..where((row) => row.operationId.equals(operationId))).write(
        SyncOperationsCompanion(
          status: const Value('retryable'),
          attemptCount: Value(attemptCount),
          nextAttemptAt: Value(nextAttemptAt),
          lastError: Value(error),
          updatedAt: Value(now),
        ),
      );

  Future<void> markFailed(
    String operationId,
    int attemptCount,
    String error,
    DateTime now,
  ) =>
      (update(
        syncOperations,
      )..where((row) => row.operationId.equals(operationId))).write(
        SyncOperationsCompanion(
          status: const Value('failed'),
          attemptCount: Value(attemptCount),
          nextAttemptAt: const Value(null),
          lastError: Value(error),
          updatedAt: Value(now),
        ),
      );

  Future<void> complete(String operationId) => (delete(
    syncOperations,
  )..where((row) => row.operationId.equals(operationId))).go();

  Future<void> markPending(String operationId, DateTime now) =>
      (update(
        syncOperations,
      )..where((row) => row.operationId.equals(operationId))).write(
        SyncOperationsCompanion(
          status: const Value('pending'),
          nextAttemptAt: const Value(null),
          updatedAt: Value(now),
        ),
      );

  /// Repairs the known FL-016 timestamp serialization defect without changing
  /// the logical operation, idempotency key, media ID or local file reference.
  Future<void> repairFailedMediaPayload(
    String operationId,
    String payloadJson,
    DateTime now,
  ) => repairFailedPayload(operationId, payloadJson, now);

  /// Replaces a proven-invalid snapshot while retaining operation identity.
  Future<void> repairFailedPayload(
    String operationId,
    String payloadJson,
    DateTime now,
  ) =>
      (update(
        syncOperations,
      )..where((row) => row.operationId.equals(operationId))).write(
        SyncOperationsCompanion(
          payloadJson: Value(payloadJson),
          status: const Value('pending'),
          nextAttemptAt: const Value(null),
          lastError: const Value(null),
          updatedAt: Value(now),
        ),
      );
}

@DriftDatabase(
  tables: [
    LocalProfiles,
    LocalEvents,
    LocalContentFiles,
    LocalEmailTemplates,
    LocalEventEmailTemplates,
    LocalEmailConnections,
    LocalEmailFollowUps,
    LocalEmailSendIntents,
    LocalLeads,
    LocalLeadMedia,
    LocalPreferences,
    LocalUserPreferences,
    SyncOperations,
  ],
  daos: [
    ProfilePreferencesDao,
    EventDao,
    ContentDao,
    EmailTemplateDao,
    EventEmailTemplateDao,
    EmailDeliveryDao,
    LeadDao,
    SyncDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'foloo',
              native: DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ),
      );

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from > to) {
        throw StateError('Database downgrades are not supported: $from -> $to');
      }
      if (from == 1) {
        await migrator.addColumn(localProfiles, localProfiles.ownerUserId);
        await migrator.addColumn(localEvents, localEvents.ownerUserId);
        await migrator.addColumn(localLeads, localLeads.ownerUserId);
        await migrator.createTable(localUserPreferences);
        await customStatement(
          'CREATE UNIQUE INDEX profile_owner_idx '
          'ON local_profiles (owner_user_id) '
          'WHERE owner_user_id IS NOT NULL',
        );
        await customStatement(
          'CREATE INDEX event_owner_idx '
          'ON local_events (owner_user_id)',
        );
        await customStatement(
          'CREATE INDEX lead_owner_idx '
          'ON local_leads (owner_user_id)',
        );
      }
      if (from < 3) {
        await migrator.addColumn(localProfiles, localProfiles.syncState);
        await migrator.addColumn(localEvents, localEvents.syncState);
        await migrator.createTable(syncOperations);
      }
      if (from < 4) {
        await migrator.addColumn(localLeads, localLeads.remoteRevision);
      }
      if (from < 5) {
        await migrator.addColumn(localEvents, localEvents.remoteRevision);
      }
      if (from < 6) {
        await migrator.createTable(localContentFiles);
      }
      if (from < 7) {
        await migrator.createTable(localEmailTemplates);
      }
      if (from < 8) {
        await migrator.createTable(localEmailConnections);
        await migrator.createTable(localEmailFollowUps);
        await migrator.createTable(localEmailSendIntents);
      }
      if (from < 9) {
        await migrator.createTable(localEventEmailTemplates);
      }
      // Databases from before v8 create the current follow-up table above, so
      // only existing v8/v9 tables need the additive semantic-edit columns.
      if (from >= 8 && from < 10) {
        await migrator.addColumn(
          localEmailFollowUps,
          localEmailFollowUps.subjectSemanticJson,
        );
        await migrator.addColumn(
          localEmailFollowUps,
          localEmailFollowUps.bodySemanticJson,
        );
        await migrator.addColumn(
          localEmailFollowUps,
          localEmailFollowUps.subjectManuallyEdited,
        );
        await migrator.addColumn(
          localEmailFollowUps,
          localEmailFollowUps.bodyManuallyEdited,
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
