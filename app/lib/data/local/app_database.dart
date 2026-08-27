/// Drift schema and data-access objects for Foloo's durable local-first store.
///
/// CAP-15/SYN-01/SYN-02: structured data is committed locally before any
/// future network delivery. Binary media is intentionally stored elsewhere.
library;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

@DataClassName('StoredProfile')
class LocalProfiles extends Table {
  TextColumn get localId => text()();
  TextColumn get name => text()();
  TextColumn get company => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {localId};
}

@DataClassName('StoredEvent')
class LocalEvents extends Table {
  TextColumn get localId => text()();
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

  @override
  Set<Column<Object>> get primaryKey => {localId};
}

@DataClassName('StoredLead')
@TableIndex(name: 'lead_event_idx', columns: {#eventLocalId})
@TableIndex(name: 'lead_captured_idx', columns: {#capturedAt})
class LocalLeads extends Table {
  TextColumn get localId => text()();
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
  TextColumn get transcription => text().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('local'))();
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

/// Lead plus its durable media metadata.
class StoredLeadBundle {
  const StoredLeadBundle(this.lead, this.media);

  final StoredLead lead;
  final List<StoredLeadMedia> media;
}

@DriftAccessor(tables: [LocalProfiles, LocalPreferences])
class ProfilePreferencesDao extends DatabaseAccessor<AppDatabase>
    with _$ProfilePreferencesDaoMixin {
  ProfilePreferencesDao(super.db);

  Future<StoredProfile?> profile() => select(localProfiles).getSingleOrNull();

  Future<void> saveProfile(LocalProfilesCompanion profile) =>
      into(localProfiles).insertOnConflictUpdate(profile);

  Future<String?> preference(String key) async => (await (select(
    localPreferences,
  )..where((row) => row.key.equals(key))).getSingleOrNull())?.value;

  Future<void> savePreference(String key, String value) =>
      into(localPreferences).insertOnConflictUpdate(
        LocalPreferencesCompanion.insert(
          key: key,
          value: value,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
}

@DriftAccessor(tables: [LocalEvents])
class EventDao extends DatabaseAccessor<AppDatabase> with _$EventDaoMixin {
  EventDao(super.db);

  Future<List<StoredEvent>> listActive() =>
      (select(localEvents)
            ..where((row) => row.deleted.equals(false))
            ..orderBy([(row) => OrderingTerm.desc(row.startsOn)]))
          .get();

  Stream<List<StoredEvent>> watchActive() =>
      (select(localEvents)
            ..where((row) => row.deleted.equals(false))
            ..orderBy([(row) => OrderingTerm.desc(row.startsOn)]))
          .watch();

  Future<StoredEvent?> byId(String id) => (select(
    localEvents,
  )..where((row) => row.localId.equals(id))).getSingleOrNull();

  Future<void> upsert(LocalEventsCompanion event) =>
      into(localEvents).insertOnConflictUpdate(event);

  Future<void> deactivateAll() =>
      update(localEvents)
          .write(const LocalEventsCompanion(active: Value(false)));

  Future<void> softDelete(String id, DateTime now) =>
      (update(localEvents)..where((row) => row.localId.equals(id))).write(
        LocalEventsCompanion(
          active: const Value(false),
          deleted: const Value(true),
          updatedAt: Value(now),
        ),
      );

  Future<void> setActive(String id, DateTime now) =>
      (update(localEvents)..where((row) => row.localId.equals(id))).write(
        LocalEventsCompanion(active: const Value(true), updatedAt: Value(now)),
      );
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

  Future<List<StoredLeadBundle>> _bundles(List<StoredLead> leads) async =>
      Future.wait(
        leads.map(
          (lead) async => StoredLeadBundle(lead, await mediaFor(lead.localId)),
        ),
      );

  Stream<List<StoredLeadBundle>> watchAll() =>
      (select(localLeads)
            ..orderBy([(row) => OrderingTerm.desc(row.capturedAt)]))
          .watch()
          .asyncMap(_bundles);

  Future<List<StoredLeadBundle>> listAll() async => _bundles(
    await (select(
      localLeads,
    )..orderBy([(row) => OrderingTerm.desc(row.capturedAt)])).get(),
  );

  Future<List<StoredLead>> byEvent(String eventId) =>
      (select(localLeads)
            ..where((row) => row.eventLocalId.equals(eventId))
            ..orderBy([(row) => OrderingTerm.desc(row.capturedAt)]))
          .get();

  Future<List<StoredLead>> byType(String type) =>
      (select(localLeads)
            ..where((row) => row.leadType.equals(type))
            ..orderBy([(row) => OrderingTerm.desc(row.capturedAt)]))
          .get();

  Future<List<StoredLead>> search(String query) {
    final pattern = '%${query.trim()}%';
    return (select(localLeads)
          ..where(
            (row) =>
                row.name.like(pattern) |
                row.lastName.like(pattern) |
                row.company.like(pattern),
          )
          ..orderBy([(row) => OrderingTerm.desc(row.capturedAt)]))
        .get();
  }

  Future<List<StoredLeadMedia>> allMedia() => select(localLeadMedia).get();

  Future<void> deleteMediaMetadata(String id) =>
      (delete(localLeadMedia)..where((row) => row.localId.equals(id))).go();
}

@DriftDatabase(
  tables: [
    LocalProfiles,
    LocalEvents,
    LocalLeads,
    LocalLeadMedia,
    LocalPreferences,
  ],
  daos: [ProfilePreferencesDao, EventDao, LeadDao],
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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from > to) {
        throw StateError('Database downgrades are not supported: $from -> $to');
      }
      // Add explicit, tested version steps here before raising schemaVersion.
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
