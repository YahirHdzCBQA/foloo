// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
mixin _$EmailTemplateDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalEmailTemplatesTable get localEmailTemplates =>
      attachedDatabase.localEmailTemplates;
  EmailTemplateDaoManager get managers => EmailTemplateDaoManager(this);
}

class EmailTemplateDaoManager {
  final _$EmailTemplateDaoMixin _db;
  EmailTemplateDaoManager(this._db);
  $$LocalEmailTemplatesTableTableManager get localEmailTemplates =>
      $$LocalEmailTemplatesTableTableManager(
        _db.attachedDatabase,
        _db.localEmailTemplates,
      );
}

mixin _$EmailDeliveryDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalEmailConnectionsTable get localEmailConnections =>
      attachedDatabase.localEmailConnections;
  $LocalEventsTable get localEvents => attachedDatabase.localEvents;
  $LocalLeadsTable get localLeads => attachedDatabase.localLeads;
  $LocalEmailFollowUpsTable get localEmailFollowUps =>
      attachedDatabase.localEmailFollowUps;
  $LocalEmailSendIntentsTable get localEmailSendIntents =>
      attachedDatabase.localEmailSendIntents;
  EmailDeliveryDaoManager get managers => EmailDeliveryDaoManager(this);
}

class EmailDeliveryDaoManager {
  final _$EmailDeliveryDaoMixin _db;
  EmailDeliveryDaoManager(this._db);
  $$LocalEmailConnectionsTableTableManager get localEmailConnections =>
      $$LocalEmailConnectionsTableTableManager(
        _db.attachedDatabase,
        _db.localEmailConnections,
      );
  $$LocalEventsTableTableManager get localEvents =>
      $$LocalEventsTableTableManager(_db.attachedDatabase, _db.localEvents);
  $$LocalLeadsTableTableManager get localLeads =>
      $$LocalLeadsTableTableManager(_db.attachedDatabase, _db.localLeads);
  $$LocalEmailFollowUpsTableTableManager get localEmailFollowUps =>
      $$LocalEmailFollowUpsTableTableManager(
        _db.attachedDatabase,
        _db.localEmailFollowUps,
      );
  $$LocalEmailSendIntentsTableTableManager get localEmailSendIntents =>
      $$LocalEmailSendIntentsTableTableManager(
        _db.attachedDatabase,
        _db.localEmailSendIntents,
      );
}

mixin _$ProfilePreferencesDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalProfilesTable get localProfiles => attachedDatabase.localProfiles;
  $LocalPreferencesTable get localPreferences =>
      attachedDatabase.localPreferences;
  $LocalUserPreferencesTable get localUserPreferences =>
      attachedDatabase.localUserPreferences;
  ProfilePreferencesDaoManager get managers =>
      ProfilePreferencesDaoManager(this);
}

class ProfilePreferencesDaoManager {
  final _$ProfilePreferencesDaoMixin _db;
  ProfilePreferencesDaoManager(this._db);
  $$LocalProfilesTableTableManager get localProfiles =>
      $$LocalProfilesTableTableManager(_db.attachedDatabase, _db.localProfiles);
  $$LocalPreferencesTableTableManager get localPreferences =>
      $$LocalPreferencesTableTableManager(
        _db.attachedDatabase,
        _db.localPreferences,
      );
  $$LocalUserPreferencesTableTableManager get localUserPreferences =>
      $$LocalUserPreferencesTableTableManager(
        _db.attachedDatabase,
        _db.localUserPreferences,
      );
}

mixin _$EventDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalEventsTable get localEvents => attachedDatabase.localEvents;
  EventDaoManager get managers => EventDaoManager(this);
}

class EventDaoManager {
  final _$EventDaoMixin _db;
  EventDaoManager(this._db);
  $$LocalEventsTableTableManager get localEvents =>
      $$LocalEventsTableTableManager(_db.attachedDatabase, _db.localEvents);
}

mixin _$ContentDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalContentFilesTable get localContentFiles =>
      attachedDatabase.localContentFiles;
  ContentDaoManager get managers => ContentDaoManager(this);
}

class ContentDaoManager {
  final _$ContentDaoMixin _db;
  ContentDaoManager(this._db);
  $$LocalContentFilesTableTableManager get localContentFiles =>
      $$LocalContentFilesTableTableManager(
        _db.attachedDatabase,
        _db.localContentFiles,
      );
}

mixin _$LeadDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalEventsTable get localEvents => attachedDatabase.localEvents;
  $LocalLeadsTable get localLeads => attachedDatabase.localLeads;
  $LocalLeadMediaTable get localLeadMedia => attachedDatabase.localLeadMedia;
  LeadDaoManager get managers => LeadDaoManager(this);
}

class LeadDaoManager {
  final _$LeadDaoMixin _db;
  LeadDaoManager(this._db);
  $$LocalEventsTableTableManager get localEvents =>
      $$LocalEventsTableTableManager(_db.attachedDatabase, _db.localEvents);
  $$LocalLeadsTableTableManager get localLeads =>
      $$LocalLeadsTableTableManager(_db.attachedDatabase, _db.localLeads);
  $$LocalLeadMediaTableTableManager get localLeadMedia =>
      $$LocalLeadMediaTableTableManager(
        _db.attachedDatabase,
        _db.localLeadMedia,
      );
}

mixin _$SyncDaoMixin on DatabaseAccessor<AppDatabase> {
  $SyncOperationsTable get syncOperations => attachedDatabase.syncOperations;
  SyncDaoManager get managers => SyncDaoManager(this);
}

class SyncDaoManager {
  final _$SyncDaoMixin _db;
  SyncDaoManager(this._db);
  $$SyncOperationsTableTableManager get syncOperations =>
      $$SyncOperationsTableTableManager(
        _db.attachedDatabase,
        _db.syncOperations,
      );
}

class $LocalProfilesTable extends LocalProfiles
    with TableInfo<$LocalProfilesTable, StoredProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
    'local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyMeta = const VerificationMeta(
    'company',
  );
  @override
  late final GeneratedColumn<String> company = GeneratedColumn<String>(
    'company',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    localId,
    ownerUserId,
    name,
    company,
    createdAt,
    updatedAt,
    syncState,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('company')) {
      context.handle(
        _companyMeta,
        company.isAcceptableOrUnknown(data['company']!, _companyMeta),
      );
    } else if (isInserting) {
      context.missing(_companyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  StoredProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredProfile(
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_id'],
      )!,
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      company: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
    );
  }

  @override
  $LocalProfilesTable createAlias(String alias) {
    return $LocalProfilesTable(attachedDatabase, alias);
  }
}

class StoredProfile extends DataClass implements Insertable<StoredProfile> {
  final String localId;
  final String? ownerUserId;
  final String name;
  final String company;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncState;
  const StoredProfile({
    required this.localId,
    this.ownerUserId,
    required this.name,
    required this.company,
    required this.createdAt,
    required this.updatedAt,
    required this.syncState,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<String>(localId);
    if (!nullToAbsent || ownerUserId != null) {
      map['owner_user_id'] = Variable<String>(ownerUserId);
    }
    map['name'] = Variable<String>(name);
    map['company'] = Variable<String>(company);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['sync_state'] = Variable<String>(syncState);
    return map;
  }

  LocalProfilesCompanion toCompanion(bool nullToAbsent) {
    return LocalProfilesCompanion(
      localId: Value(localId),
      ownerUserId: ownerUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerUserId),
      name: Value(name),
      company: Value(company),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      syncState: Value(syncState),
    );
  }

  factory StoredProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredProfile(
      localId: serializer.fromJson<String>(json['localId']),
      ownerUserId: serializer.fromJson<String?>(json['ownerUserId']),
      name: serializer.fromJson<String>(json['name']),
      company: serializer.fromJson<String>(json['company']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      syncState: serializer.fromJson<String>(json['syncState']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<String>(localId),
      'ownerUserId': serializer.toJson<String?>(ownerUserId),
      'name': serializer.toJson<String>(name),
      'company': serializer.toJson<String>(company),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'syncState': serializer.toJson<String>(syncState),
    };
  }

  StoredProfile copyWith({
    String? localId,
    Value<String?> ownerUserId = const Value.absent(),
    String? name,
    String? company,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncState,
  }) => StoredProfile(
    localId: localId ?? this.localId,
    ownerUserId: ownerUserId.present ? ownerUserId.value : this.ownerUserId,
    name: name ?? this.name,
    company: company ?? this.company,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncState: syncState ?? this.syncState,
  );
  StoredProfile copyWithCompanion(LocalProfilesCompanion data) {
    return StoredProfile(
      localId: data.localId.present ? data.localId.value : this.localId,
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      name: data.name.present ? data.name.value : this.name,
      company: data.company.present ? data.company.value : this.company,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredProfile(')
          ..write('localId: $localId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('name: $name, ')
          ..write('company: $company, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncState: $syncState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localId,
    ownerUserId,
    name,
    company,
    createdAt,
    updatedAt,
    syncState,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredProfile &&
          other.localId == this.localId &&
          other.ownerUserId == this.ownerUserId &&
          other.name == this.name &&
          other.company == this.company &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.syncState == this.syncState);
}

class LocalProfilesCompanion extends UpdateCompanion<StoredProfile> {
  final Value<String> localId;
  final Value<String?> ownerUserId;
  final Value<String> name;
  final Value<String> company;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> syncState;
  final Value<int> rowid;
  const LocalProfilesCompanion({
    this.localId = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.name = const Value.absent(),
    this.company = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncState = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalProfilesCompanion.insert({
    required String localId,
    this.ownerUserId = const Value.absent(),
    required String name,
    required String company,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.syncState = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : localId = Value(localId),
       name = Value(name),
       company = Value(company),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<StoredProfile> custom({
    Expression<String>? localId,
    Expression<String>? ownerUserId,
    Expression<String>? name,
    Expression<String>? company,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? syncState,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (name != null) 'name': name,
      if (company != null) 'company': company,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncState != null) 'sync_state': syncState,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalProfilesCompanion copyWith({
    Value<String>? localId,
    Value<String?>? ownerUserId,
    Value<String>? name,
    Value<String>? company,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? syncState,
    Value<int>? rowid,
  }) {
    return LocalProfilesCompanion(
      localId: localId ?? this.localId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      name: name ?? this.name,
      company: company ?? this.company,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncState: syncState ?? this.syncState,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (company.present) {
      map['company'] = Variable<String>(company.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalProfilesCompanion(')
          ..write('localId: $localId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('name: $name, ')
          ..write('company: $company, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncState: $syncState, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalEventsTable extends LocalEvents
    with TableInfo<$LocalEventsTable, StoredEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
    'local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commercialCodeMeta = const VerificationMeta(
    'commercialCode',
  );
  @override
  late final GeneratedColumn<String> commercialCode = GeneratedColumn<String>(
    'commercial_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startsOnMeta = const VerificationMeta(
    'startsOn',
  );
  @override
  late final GeneratedColumn<DateTime> startsOn = GeneratedColumn<DateTime>(
    'starts_on',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endsOnMeta = const VerificationMeta('endsOn');
  @override
  late final GeneratedColumn<DateTime> endsOn = GeneratedColumn<DateTime>(
    'ends_on',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _contentFileIdsJsonMeta =
      const VerificationMeta('contentFileIdsJson');
  @override
  late final GeneratedColumn<String> contentFileIdsJson =
      GeneratedColumn<String>(
        'content_file_ids_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _remoteRevisionMeta = const VerificationMeta(
    'remoteRevision',
  );
  @override
  late final GeneratedColumn<int> remoteRevision = GeneratedColumn<int>(
    'remote_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    localId,
    ownerUserId,
    commercialCode,
    name,
    startsOn,
    endsOn,
    active,
    deleted,
    contentFileIdsJson,
    createdAt,
    updatedAt,
    syncState,
    remoteRevision,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    }
    if (data.containsKey('commercial_code')) {
      context.handle(
        _commercialCodeMeta,
        commercialCode.isAcceptableOrUnknown(
          data['commercial_code']!,
          _commercialCodeMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('starts_on')) {
      context.handle(
        _startsOnMeta,
        startsOn.isAcceptableOrUnknown(data['starts_on']!, _startsOnMeta),
      );
    } else if (isInserting) {
      context.missing(_startsOnMeta);
    }
    if (data.containsKey('ends_on')) {
      context.handle(
        _endsOnMeta,
        endsOn.isAcceptableOrUnknown(data['ends_on']!, _endsOnMeta),
      );
    } else if (isInserting) {
      context.missing(_endsOnMeta);
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('content_file_ids_json')) {
      context.handle(
        _contentFileIdsJsonMeta,
        contentFileIdsJson.isAcceptableOrUnknown(
          data['content_file_ids_json']!,
          _contentFileIdsJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('remote_revision')) {
      context.handle(
        _remoteRevisionMeta,
        remoteRevision.isAcceptableOrUnknown(
          data['remote_revision']!,
          _remoteRevisionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  StoredEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredEvent(
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_id'],
      )!,
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      ),
      commercialCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commercial_code'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      startsOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}starts_on'],
      )!,
      endsOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ends_on'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      contentFileIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_file_ids_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      remoteRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_revision'],
      ),
    );
  }

  @override
  $LocalEventsTable createAlias(String alias) {
    return $LocalEventsTable(attachedDatabase, alias);
  }
}

class StoredEvent extends DataClass implements Insertable<StoredEvent> {
  final String localId;
  final String? ownerUserId;
  final String? commercialCode;
  final String name;
  final DateTime startsOn;
  final DateTime endsOn;
  final bool active;
  final bool deleted;
  final String contentFileIdsJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncState;
  final int? remoteRevision;
  const StoredEvent({
    required this.localId,
    this.ownerUserId,
    this.commercialCode,
    required this.name,
    required this.startsOn,
    required this.endsOn,
    required this.active,
    required this.deleted,
    required this.contentFileIdsJson,
    required this.createdAt,
    required this.updatedAt,
    required this.syncState,
    this.remoteRevision,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<String>(localId);
    if (!nullToAbsent || ownerUserId != null) {
      map['owner_user_id'] = Variable<String>(ownerUserId);
    }
    if (!nullToAbsent || commercialCode != null) {
      map['commercial_code'] = Variable<String>(commercialCode);
    }
    map['name'] = Variable<String>(name);
    map['starts_on'] = Variable<DateTime>(startsOn);
    map['ends_on'] = Variable<DateTime>(endsOn);
    map['active'] = Variable<bool>(active);
    map['deleted'] = Variable<bool>(deleted);
    map['content_file_ids_json'] = Variable<String>(contentFileIdsJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['sync_state'] = Variable<String>(syncState);
    if (!nullToAbsent || remoteRevision != null) {
      map['remote_revision'] = Variable<int>(remoteRevision);
    }
    return map;
  }

  LocalEventsCompanion toCompanion(bool nullToAbsent) {
    return LocalEventsCompanion(
      localId: Value(localId),
      ownerUserId: ownerUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerUserId),
      commercialCode: commercialCode == null && nullToAbsent
          ? const Value.absent()
          : Value(commercialCode),
      name: Value(name),
      startsOn: Value(startsOn),
      endsOn: Value(endsOn),
      active: Value(active),
      deleted: Value(deleted),
      contentFileIdsJson: Value(contentFileIdsJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      syncState: Value(syncState),
      remoteRevision: remoteRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteRevision),
    );
  }

  factory StoredEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredEvent(
      localId: serializer.fromJson<String>(json['localId']),
      ownerUserId: serializer.fromJson<String?>(json['ownerUserId']),
      commercialCode: serializer.fromJson<String?>(json['commercialCode']),
      name: serializer.fromJson<String>(json['name']),
      startsOn: serializer.fromJson<DateTime>(json['startsOn']),
      endsOn: serializer.fromJson<DateTime>(json['endsOn']),
      active: serializer.fromJson<bool>(json['active']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      contentFileIdsJson: serializer.fromJson<String>(
        json['contentFileIdsJson'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      syncState: serializer.fromJson<String>(json['syncState']),
      remoteRevision: serializer.fromJson<int?>(json['remoteRevision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<String>(localId),
      'ownerUserId': serializer.toJson<String?>(ownerUserId),
      'commercialCode': serializer.toJson<String?>(commercialCode),
      'name': serializer.toJson<String>(name),
      'startsOn': serializer.toJson<DateTime>(startsOn),
      'endsOn': serializer.toJson<DateTime>(endsOn),
      'active': serializer.toJson<bool>(active),
      'deleted': serializer.toJson<bool>(deleted),
      'contentFileIdsJson': serializer.toJson<String>(contentFileIdsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'syncState': serializer.toJson<String>(syncState),
      'remoteRevision': serializer.toJson<int?>(remoteRevision),
    };
  }

  StoredEvent copyWith({
    String? localId,
    Value<String?> ownerUserId = const Value.absent(),
    Value<String?> commercialCode = const Value.absent(),
    String? name,
    DateTime? startsOn,
    DateTime? endsOn,
    bool? active,
    bool? deleted,
    String? contentFileIdsJson,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncState,
    Value<int?> remoteRevision = const Value.absent(),
  }) => StoredEvent(
    localId: localId ?? this.localId,
    ownerUserId: ownerUserId.present ? ownerUserId.value : this.ownerUserId,
    commercialCode: commercialCode.present
        ? commercialCode.value
        : this.commercialCode,
    name: name ?? this.name,
    startsOn: startsOn ?? this.startsOn,
    endsOn: endsOn ?? this.endsOn,
    active: active ?? this.active,
    deleted: deleted ?? this.deleted,
    contentFileIdsJson: contentFileIdsJson ?? this.contentFileIdsJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncState: syncState ?? this.syncState,
    remoteRevision: remoteRevision.present
        ? remoteRevision.value
        : this.remoteRevision,
  );
  StoredEvent copyWithCompanion(LocalEventsCompanion data) {
    return StoredEvent(
      localId: data.localId.present ? data.localId.value : this.localId,
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      commercialCode: data.commercialCode.present
          ? data.commercialCode.value
          : this.commercialCode,
      name: data.name.present ? data.name.value : this.name,
      startsOn: data.startsOn.present ? data.startsOn.value : this.startsOn,
      endsOn: data.endsOn.present ? data.endsOn.value : this.endsOn,
      active: data.active.present ? data.active.value : this.active,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      contentFileIdsJson: data.contentFileIdsJson.present
          ? data.contentFileIdsJson.value
          : this.contentFileIdsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      remoteRevision: data.remoteRevision.present
          ? data.remoteRevision.value
          : this.remoteRevision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredEvent(')
          ..write('localId: $localId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('commercialCode: $commercialCode, ')
          ..write('name: $name, ')
          ..write('startsOn: $startsOn, ')
          ..write('endsOn: $endsOn, ')
          ..write('active: $active, ')
          ..write('deleted: $deleted, ')
          ..write('contentFileIdsJson: $contentFileIdsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncState: $syncState, ')
          ..write('remoteRevision: $remoteRevision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localId,
    ownerUserId,
    commercialCode,
    name,
    startsOn,
    endsOn,
    active,
    deleted,
    contentFileIdsJson,
    createdAt,
    updatedAt,
    syncState,
    remoteRevision,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredEvent &&
          other.localId == this.localId &&
          other.ownerUserId == this.ownerUserId &&
          other.commercialCode == this.commercialCode &&
          other.name == this.name &&
          other.startsOn == this.startsOn &&
          other.endsOn == this.endsOn &&
          other.active == this.active &&
          other.deleted == this.deleted &&
          other.contentFileIdsJson == this.contentFileIdsJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.syncState == this.syncState &&
          other.remoteRevision == this.remoteRevision);
}

class LocalEventsCompanion extends UpdateCompanion<StoredEvent> {
  final Value<String> localId;
  final Value<String?> ownerUserId;
  final Value<String?> commercialCode;
  final Value<String> name;
  final Value<DateTime> startsOn;
  final Value<DateTime> endsOn;
  final Value<bool> active;
  final Value<bool> deleted;
  final Value<String> contentFileIdsJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> syncState;
  final Value<int?> remoteRevision;
  final Value<int> rowid;
  const LocalEventsCompanion({
    this.localId = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.commercialCode = const Value.absent(),
    this.name = const Value.absent(),
    this.startsOn = const Value.absent(),
    this.endsOn = const Value.absent(),
    this.active = const Value.absent(),
    this.deleted = const Value.absent(),
    this.contentFileIdsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncState = const Value.absent(),
    this.remoteRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalEventsCompanion.insert({
    required String localId,
    this.ownerUserId = const Value.absent(),
    this.commercialCode = const Value.absent(),
    required String name,
    required DateTime startsOn,
    required DateTime endsOn,
    this.active = const Value.absent(),
    this.deleted = const Value.absent(),
    this.contentFileIdsJson = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.syncState = const Value.absent(),
    this.remoteRevision = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : localId = Value(localId),
       name = Value(name),
       startsOn = Value(startsOn),
       endsOn = Value(endsOn),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<StoredEvent> custom({
    Expression<String>? localId,
    Expression<String>? ownerUserId,
    Expression<String>? commercialCode,
    Expression<String>? name,
    Expression<DateTime>? startsOn,
    Expression<DateTime>? endsOn,
    Expression<bool>? active,
    Expression<bool>? deleted,
    Expression<String>? contentFileIdsJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? syncState,
    Expression<int>? remoteRevision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (commercialCode != null) 'commercial_code': commercialCode,
      if (name != null) 'name': name,
      if (startsOn != null) 'starts_on': startsOn,
      if (endsOn != null) 'ends_on': endsOn,
      if (active != null) 'active': active,
      if (deleted != null) 'deleted': deleted,
      if (contentFileIdsJson != null)
        'content_file_ids_json': contentFileIdsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncState != null) 'sync_state': syncState,
      if (remoteRevision != null) 'remote_revision': remoteRevision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalEventsCompanion copyWith({
    Value<String>? localId,
    Value<String?>? ownerUserId,
    Value<String?>? commercialCode,
    Value<String>? name,
    Value<DateTime>? startsOn,
    Value<DateTime>? endsOn,
    Value<bool>? active,
    Value<bool>? deleted,
    Value<String>? contentFileIdsJson,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? syncState,
    Value<int?>? remoteRevision,
    Value<int>? rowid,
  }) {
    return LocalEventsCompanion(
      localId: localId ?? this.localId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      commercialCode: commercialCode ?? this.commercialCode,
      name: name ?? this.name,
      startsOn: startsOn ?? this.startsOn,
      endsOn: endsOn ?? this.endsOn,
      active: active ?? this.active,
      deleted: deleted ?? this.deleted,
      contentFileIdsJson: contentFileIdsJson ?? this.contentFileIdsJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncState: syncState ?? this.syncState,
      remoteRevision: remoteRevision ?? this.remoteRevision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (commercialCode.present) {
      map['commercial_code'] = Variable<String>(commercialCode.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (startsOn.present) {
      map['starts_on'] = Variable<DateTime>(startsOn.value);
    }
    if (endsOn.present) {
      map['ends_on'] = Variable<DateTime>(endsOn.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (contentFileIdsJson.present) {
      map['content_file_ids_json'] = Variable<String>(contentFileIdsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (remoteRevision.present) {
      map['remote_revision'] = Variable<int>(remoteRevision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalEventsCompanion(')
          ..write('localId: $localId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('commercialCode: $commercialCode, ')
          ..write('name: $name, ')
          ..write('startsOn: $startsOn, ')
          ..write('endsOn: $endsOn, ')
          ..write('active: $active, ')
          ..write('deleted: $deleted, ')
          ..write('contentFileIdsJson: $contentFileIdsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncState: $syncState, ')
          ..write('remoteRevision: $remoteRevision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalContentFilesTable extends LocalContentFiles
    with TableInfo<$LocalContentFilesTable, StoredContentFile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalContentFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
    'local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byteSizeMeta = const VerificationMeta(
    'byteSize',
  );
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
    'byte_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _allEventsMeta = const VerificationMeta(
    'allEvents',
  );
  @override
  late final GeneratedColumn<bool> allEvents = GeneratedColumn<bool>(
    'all_events',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("all_events" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _eventIdsJsonMeta = const VerificationMeta(
    'eventIdsJson',
  );
  @override
  late final GeneratedColumn<String> eventIdsJson = GeneratedColumn<String>(
    'event_ids_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _uploadStateMeta = const VerificationMeta(
    'uploadState',
  );
  @override
  late final GeneratedColumn<String> uploadState = GeneratedColumn<String>(
    'upload_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _remoteRevisionMeta = const VerificationMeta(
    'remoteRevision',
  );
  @override
  late final GeneratedColumn<int> remoteRevision = GeneratedColumn<int>(
    'remote_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    localId,
    ownerUserId,
    displayName,
    fileName,
    byteSize,
    localPath,
    allEvents,
    eventIdsJson,
    deleted,
    uploadState,
    syncState,
    remoteRevision,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_content_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredContentFile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerUserIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('byte_size')) {
      context.handle(
        _byteSizeMeta,
        byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_byteSizeMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('all_events')) {
      context.handle(
        _allEventsMeta,
        allEvents.isAcceptableOrUnknown(data['all_events']!, _allEventsMeta),
      );
    }
    if (data.containsKey('event_ids_json')) {
      context.handle(
        _eventIdsJsonMeta,
        eventIdsJson.isAcceptableOrUnknown(
          data['event_ids_json']!,
          _eventIdsJsonMeta,
        ),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('upload_state')) {
      context.handle(
        _uploadStateMeta,
        uploadState.isAcceptableOrUnknown(
          data['upload_state']!,
          _uploadStateMeta,
        ),
      );
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('remote_revision')) {
      context.handle(
        _remoteRevisionMeta,
        remoteRevision.isAcceptableOrUnknown(
          data['remote_revision']!,
          _remoteRevisionMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  StoredContentFile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredContentFile(
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_id'],
      )!,
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      byteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_size'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      allEvents: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}all_events'],
      )!,
      eventIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_ids_json'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      uploadState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}upload_state'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      remoteRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_revision'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalContentFilesTable createAlias(String alias) {
    return $LocalContentFilesTable(attachedDatabase, alias);
  }
}

class StoredContentFile extends DataClass
    implements Insertable<StoredContentFile> {
  final String localId;
  final String ownerUserId;
  final String displayName;
  final String fileName;
  final int byteSize;
  final String? localPath;
  final bool allEvents;
  final String eventIdsJson;
  final bool deleted;
  final String uploadState;
  final String syncState;
  final int? remoteRevision;
  final DateTime createdAt;
  final DateTime updatedAt;
  const StoredContentFile({
    required this.localId,
    required this.ownerUserId,
    required this.displayName,
    required this.fileName,
    required this.byteSize,
    this.localPath,
    required this.allEvents,
    required this.eventIdsJson,
    required this.deleted,
    required this.uploadState,
    required this.syncState,
    this.remoteRevision,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<String>(localId);
    map['owner_user_id'] = Variable<String>(ownerUserId);
    map['display_name'] = Variable<String>(displayName);
    map['file_name'] = Variable<String>(fileName);
    map['byte_size'] = Variable<int>(byteSize);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    map['all_events'] = Variable<bool>(allEvents);
    map['event_ids_json'] = Variable<String>(eventIdsJson);
    map['deleted'] = Variable<bool>(deleted);
    map['upload_state'] = Variable<String>(uploadState);
    map['sync_state'] = Variable<String>(syncState);
    if (!nullToAbsent || remoteRevision != null) {
      map['remote_revision'] = Variable<int>(remoteRevision);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalContentFilesCompanion toCompanion(bool nullToAbsent) {
    return LocalContentFilesCompanion(
      localId: Value(localId),
      ownerUserId: Value(ownerUserId),
      displayName: Value(displayName),
      fileName: Value(fileName),
      byteSize: Value(byteSize),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      allEvents: Value(allEvents),
      eventIdsJson: Value(eventIdsJson),
      deleted: Value(deleted),
      uploadState: Value(uploadState),
      syncState: Value(syncState),
      remoteRevision: remoteRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteRevision),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredContentFile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredContentFile(
      localId: serializer.fromJson<String>(json['localId']),
      ownerUserId: serializer.fromJson<String>(json['ownerUserId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      fileName: serializer.fromJson<String>(json['fileName']),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      allEvents: serializer.fromJson<bool>(json['allEvents']),
      eventIdsJson: serializer.fromJson<String>(json['eventIdsJson']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      uploadState: serializer.fromJson<String>(json['uploadState']),
      syncState: serializer.fromJson<String>(json['syncState']),
      remoteRevision: serializer.fromJson<int?>(json['remoteRevision']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<String>(localId),
      'ownerUserId': serializer.toJson<String>(ownerUserId),
      'displayName': serializer.toJson<String>(displayName),
      'fileName': serializer.toJson<String>(fileName),
      'byteSize': serializer.toJson<int>(byteSize),
      'localPath': serializer.toJson<String?>(localPath),
      'allEvents': serializer.toJson<bool>(allEvents),
      'eventIdsJson': serializer.toJson<String>(eventIdsJson),
      'deleted': serializer.toJson<bool>(deleted),
      'uploadState': serializer.toJson<String>(uploadState),
      'syncState': serializer.toJson<String>(syncState),
      'remoteRevision': serializer.toJson<int?>(remoteRevision),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredContentFile copyWith({
    String? localId,
    String? ownerUserId,
    String? displayName,
    String? fileName,
    int? byteSize,
    Value<String?> localPath = const Value.absent(),
    bool? allEvents,
    String? eventIdsJson,
    bool? deleted,
    String? uploadState,
    String? syncState,
    Value<int?> remoteRevision = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StoredContentFile(
    localId: localId ?? this.localId,
    ownerUserId: ownerUserId ?? this.ownerUserId,
    displayName: displayName ?? this.displayName,
    fileName: fileName ?? this.fileName,
    byteSize: byteSize ?? this.byteSize,
    localPath: localPath.present ? localPath.value : this.localPath,
    allEvents: allEvents ?? this.allEvents,
    eventIdsJson: eventIdsJson ?? this.eventIdsJson,
    deleted: deleted ?? this.deleted,
    uploadState: uploadState ?? this.uploadState,
    syncState: syncState ?? this.syncState,
    remoteRevision: remoteRevision.present
        ? remoteRevision.value
        : this.remoteRevision,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredContentFile copyWithCompanion(LocalContentFilesCompanion data) {
    return StoredContentFile(
      localId: data.localId.present ? data.localId.value : this.localId,
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      allEvents: data.allEvents.present ? data.allEvents.value : this.allEvents,
      eventIdsJson: data.eventIdsJson.present
          ? data.eventIdsJson.value
          : this.eventIdsJson,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      uploadState: data.uploadState.present
          ? data.uploadState.value
          : this.uploadState,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      remoteRevision: data.remoteRevision.present
          ? data.remoteRevision.value
          : this.remoteRevision,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredContentFile(')
          ..write('localId: $localId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('displayName: $displayName, ')
          ..write('fileName: $fileName, ')
          ..write('byteSize: $byteSize, ')
          ..write('localPath: $localPath, ')
          ..write('allEvents: $allEvents, ')
          ..write('eventIdsJson: $eventIdsJson, ')
          ..write('deleted: $deleted, ')
          ..write('uploadState: $uploadState, ')
          ..write('syncState: $syncState, ')
          ..write('remoteRevision: $remoteRevision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localId,
    ownerUserId,
    displayName,
    fileName,
    byteSize,
    localPath,
    allEvents,
    eventIdsJson,
    deleted,
    uploadState,
    syncState,
    remoteRevision,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredContentFile &&
          other.localId == this.localId &&
          other.ownerUserId == this.ownerUserId &&
          other.displayName == this.displayName &&
          other.fileName == this.fileName &&
          other.byteSize == this.byteSize &&
          other.localPath == this.localPath &&
          other.allEvents == this.allEvents &&
          other.eventIdsJson == this.eventIdsJson &&
          other.deleted == this.deleted &&
          other.uploadState == this.uploadState &&
          other.syncState == this.syncState &&
          other.remoteRevision == this.remoteRevision &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalContentFilesCompanion extends UpdateCompanion<StoredContentFile> {
  final Value<String> localId;
  final Value<String> ownerUserId;
  final Value<String> displayName;
  final Value<String> fileName;
  final Value<int> byteSize;
  final Value<String?> localPath;
  final Value<bool> allEvents;
  final Value<String> eventIdsJson;
  final Value<bool> deleted;
  final Value<String> uploadState;
  final Value<String> syncState;
  final Value<int?> remoteRevision;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalContentFilesCompanion({
    this.localId = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.fileName = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.localPath = const Value.absent(),
    this.allEvents = const Value.absent(),
    this.eventIdsJson = const Value.absent(),
    this.deleted = const Value.absent(),
    this.uploadState = const Value.absent(),
    this.syncState = const Value.absent(),
    this.remoteRevision = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalContentFilesCompanion.insert({
    required String localId,
    required String ownerUserId,
    required String displayName,
    required String fileName,
    required int byteSize,
    this.localPath = const Value.absent(),
    this.allEvents = const Value.absent(),
    this.eventIdsJson = const Value.absent(),
    this.deleted = const Value.absent(),
    this.uploadState = const Value.absent(),
    this.syncState = const Value.absent(),
    this.remoteRevision = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : localId = Value(localId),
       ownerUserId = Value(ownerUserId),
       displayName = Value(displayName),
       fileName = Value(fileName),
       byteSize = Value(byteSize),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<StoredContentFile> custom({
    Expression<String>? localId,
    Expression<String>? ownerUserId,
    Expression<String>? displayName,
    Expression<String>? fileName,
    Expression<int>? byteSize,
    Expression<String>? localPath,
    Expression<bool>? allEvents,
    Expression<String>? eventIdsJson,
    Expression<bool>? deleted,
    Expression<String>? uploadState,
    Expression<String>? syncState,
    Expression<int>? remoteRevision,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (displayName != null) 'display_name': displayName,
      if (fileName != null) 'file_name': fileName,
      if (byteSize != null) 'byte_size': byteSize,
      if (localPath != null) 'local_path': localPath,
      if (allEvents != null) 'all_events': allEvents,
      if (eventIdsJson != null) 'event_ids_json': eventIdsJson,
      if (deleted != null) 'deleted': deleted,
      if (uploadState != null) 'upload_state': uploadState,
      if (syncState != null) 'sync_state': syncState,
      if (remoteRevision != null) 'remote_revision': remoteRevision,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalContentFilesCompanion copyWith({
    Value<String>? localId,
    Value<String>? ownerUserId,
    Value<String>? displayName,
    Value<String>? fileName,
    Value<int>? byteSize,
    Value<String?>? localPath,
    Value<bool>? allEvents,
    Value<String>? eventIdsJson,
    Value<bool>? deleted,
    Value<String>? uploadState,
    Value<String>? syncState,
    Value<int?>? remoteRevision,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalContentFilesCompanion(
      localId: localId ?? this.localId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      displayName: displayName ?? this.displayName,
      fileName: fileName ?? this.fileName,
      byteSize: byteSize ?? this.byteSize,
      localPath: localPath ?? this.localPath,
      allEvents: allEvents ?? this.allEvents,
      eventIdsJson: eventIdsJson ?? this.eventIdsJson,
      deleted: deleted ?? this.deleted,
      uploadState: uploadState ?? this.uploadState,
      syncState: syncState ?? this.syncState,
      remoteRevision: remoteRevision ?? this.remoteRevision,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (allEvents.present) {
      map['all_events'] = Variable<bool>(allEvents.value);
    }
    if (eventIdsJson.present) {
      map['event_ids_json'] = Variable<String>(eventIdsJson.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (uploadState.present) {
      map['upload_state'] = Variable<String>(uploadState.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (remoteRevision.present) {
      map['remote_revision'] = Variable<int>(remoteRevision.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalContentFilesCompanion(')
          ..write('localId: $localId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('displayName: $displayName, ')
          ..write('fileName: $fileName, ')
          ..write('byteSize: $byteSize, ')
          ..write('localPath: $localPath, ')
          ..write('allEvents: $allEvents, ')
          ..write('eventIdsJson: $eventIdsJson, ')
          ..write('deleted: $deleted, ')
          ..write('uploadState: $uploadState, ')
          ..write('syncState: $syncState, ')
          ..write('remoteRevision: $remoteRevision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalEmailTemplatesTable extends LocalEmailTemplates
    with TableInfo<$LocalEmailTemplatesTable, StoredEmailTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalEmailTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originKindMeta = const VerificationMeta(
    'originKind',
  );
  @override
  late final GeneratedColumn<String> originKind = GeneratedColumn<String>(
    'origin_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageCodeMeta = const VerificationMeta(
    'languageCode',
  );
  @override
  late final GeneratedColumn<String> languageCode = GeneratedColumn<String>(
    'language_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _signatureMeta = const VerificationMeta(
    'signature',
  );
  @override
  late final GeneratedColumn<String> signature = GeneratedColumn<String>(
    'signature',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerUserId,
    originKind,
    languageCode,
    subject,
    body,
    signature,
    updatedAt,
    syncState,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_email_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredEmailTemplate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerUserIdMeta);
    }
    if (data.containsKey('origin_kind')) {
      context.handle(
        _originKindMeta,
        originKind.isAcceptableOrUnknown(data['origin_kind']!, _originKindMeta),
      );
    } else if (isInserting) {
      context.missing(_originKindMeta);
    }
    if (data.containsKey('language_code')) {
      context.handle(
        _languageCodeMeta,
        languageCode.isAcceptableOrUnknown(
          data['language_code']!,
          _languageCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_languageCodeMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('signature')) {
      context.handle(
        _signatureMeta,
        signature.isAcceptableOrUnknown(data['signature']!, _signatureMeta),
      );
    } else if (isInserting) {
      context.missing(_signatureMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    ownerUserId,
    originKind,
    languageCode,
  };
  @override
  StoredEmailTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredEmailTemplate(
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      )!,
      originKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_kind'],
      )!,
      languageCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language_code'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      signature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signature'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
    );
  }

  @override
  $LocalEmailTemplatesTable createAlias(String alias) {
    return $LocalEmailTemplatesTable(attachedDatabase, alias);
  }
}

class StoredEmailTemplate extends DataClass
    implements Insertable<StoredEmailTemplate> {
  final String ownerUserId;
  final String originKind;
  final String languageCode;
  final String subject;
  final String body;
  final String signature;
  final DateTime updatedAt;
  final String syncState;
  const StoredEmailTemplate({
    required this.ownerUserId,
    required this.originKind,
    required this.languageCode,
    required this.subject,
    required this.body,
    required this.signature,
    required this.updatedAt,
    required this.syncState,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_user_id'] = Variable<String>(ownerUserId);
    map['origin_kind'] = Variable<String>(originKind);
    map['language_code'] = Variable<String>(languageCode);
    map['subject'] = Variable<String>(subject);
    map['body'] = Variable<String>(body);
    map['signature'] = Variable<String>(signature);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['sync_state'] = Variable<String>(syncState);
    return map;
  }

  LocalEmailTemplatesCompanion toCompanion(bool nullToAbsent) {
    return LocalEmailTemplatesCompanion(
      ownerUserId: Value(ownerUserId),
      originKind: Value(originKind),
      languageCode: Value(languageCode),
      subject: Value(subject),
      body: Value(body),
      signature: Value(signature),
      updatedAt: Value(updatedAt),
      syncState: Value(syncState),
    );
  }

  factory StoredEmailTemplate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredEmailTemplate(
      ownerUserId: serializer.fromJson<String>(json['ownerUserId']),
      originKind: serializer.fromJson<String>(json['originKind']),
      languageCode: serializer.fromJson<String>(json['languageCode']),
      subject: serializer.fromJson<String>(json['subject']),
      body: serializer.fromJson<String>(json['body']),
      signature: serializer.fromJson<String>(json['signature']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      syncState: serializer.fromJson<String>(json['syncState']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerUserId': serializer.toJson<String>(ownerUserId),
      'originKind': serializer.toJson<String>(originKind),
      'languageCode': serializer.toJson<String>(languageCode),
      'subject': serializer.toJson<String>(subject),
      'body': serializer.toJson<String>(body),
      'signature': serializer.toJson<String>(signature),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'syncState': serializer.toJson<String>(syncState),
    };
  }

  StoredEmailTemplate copyWith({
    String? ownerUserId,
    String? originKind,
    String? languageCode,
    String? subject,
    String? body,
    String? signature,
    DateTime? updatedAt,
    String? syncState,
  }) => StoredEmailTemplate(
    ownerUserId: ownerUserId ?? this.ownerUserId,
    originKind: originKind ?? this.originKind,
    languageCode: languageCode ?? this.languageCode,
    subject: subject ?? this.subject,
    body: body ?? this.body,
    signature: signature ?? this.signature,
    updatedAt: updatedAt ?? this.updatedAt,
    syncState: syncState ?? this.syncState,
  );
  StoredEmailTemplate copyWithCompanion(LocalEmailTemplatesCompanion data) {
    return StoredEmailTemplate(
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      originKind: data.originKind.present
          ? data.originKind.value
          : this.originKind,
      languageCode: data.languageCode.present
          ? data.languageCode.value
          : this.languageCode,
      subject: data.subject.present ? data.subject.value : this.subject,
      body: data.body.present ? data.body.value : this.body,
      signature: data.signature.present ? data.signature.value : this.signature,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredEmailTemplate(')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('originKind: $originKind, ')
          ..write('languageCode: $languageCode, ')
          ..write('subject: $subject, ')
          ..write('body: $body, ')
          ..write('signature: $signature, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncState: $syncState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerUserId,
    originKind,
    languageCode,
    subject,
    body,
    signature,
    updatedAt,
    syncState,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredEmailTemplate &&
          other.ownerUserId == this.ownerUserId &&
          other.originKind == this.originKind &&
          other.languageCode == this.languageCode &&
          other.subject == this.subject &&
          other.body == this.body &&
          other.signature == this.signature &&
          other.updatedAt == this.updatedAt &&
          other.syncState == this.syncState);
}

class LocalEmailTemplatesCompanion
    extends UpdateCompanion<StoredEmailTemplate> {
  final Value<String> ownerUserId;
  final Value<String> originKind;
  final Value<String> languageCode;
  final Value<String> subject;
  final Value<String> body;
  final Value<String> signature;
  final Value<DateTime> updatedAt;
  final Value<String> syncState;
  final Value<int> rowid;
  const LocalEmailTemplatesCompanion({
    this.ownerUserId = const Value.absent(),
    this.originKind = const Value.absent(),
    this.languageCode = const Value.absent(),
    this.subject = const Value.absent(),
    this.body = const Value.absent(),
    this.signature = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncState = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalEmailTemplatesCompanion.insert({
    required String ownerUserId,
    required String originKind,
    required String languageCode,
    required String subject,
    required String body,
    required String signature,
    required DateTime updatedAt,
    this.syncState = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerUserId = Value(ownerUserId),
       originKind = Value(originKind),
       languageCode = Value(languageCode),
       subject = Value(subject),
       body = Value(body),
       signature = Value(signature),
       updatedAt = Value(updatedAt);
  static Insertable<StoredEmailTemplate> custom({
    Expression<String>? ownerUserId,
    Expression<String>? originKind,
    Expression<String>? languageCode,
    Expression<String>? subject,
    Expression<String>? body,
    Expression<String>? signature,
    Expression<DateTime>? updatedAt,
    Expression<String>? syncState,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (originKind != null) 'origin_kind': originKind,
      if (languageCode != null) 'language_code': languageCode,
      if (subject != null) 'subject': subject,
      if (body != null) 'body': body,
      if (signature != null) 'signature': signature,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncState != null) 'sync_state': syncState,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalEmailTemplatesCompanion copyWith({
    Value<String>? ownerUserId,
    Value<String>? originKind,
    Value<String>? languageCode,
    Value<String>? subject,
    Value<String>? body,
    Value<String>? signature,
    Value<DateTime>? updatedAt,
    Value<String>? syncState,
    Value<int>? rowid,
  }) {
    return LocalEmailTemplatesCompanion(
      ownerUserId: ownerUserId ?? this.ownerUserId,
      originKind: originKind ?? this.originKind,
      languageCode: languageCode ?? this.languageCode,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      signature: signature ?? this.signature,
      updatedAt: updatedAt ?? this.updatedAt,
      syncState: syncState ?? this.syncState,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (originKind.present) {
      map['origin_kind'] = Variable<String>(originKind.value);
    }
    if (languageCode.present) {
      map['language_code'] = Variable<String>(languageCode.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (signature.present) {
      map['signature'] = Variable<String>(signature.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalEmailTemplatesCompanion(')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('originKind: $originKind, ')
          ..write('languageCode: $languageCode, ')
          ..write('subject: $subject, ')
          ..write('body: $body, ')
          ..write('signature: $signature, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncState: $syncState, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalEmailConnectionsTable extends LocalEmailConnections
    with TableInfo<$LocalEmailConnectionsTable, StoredEmailConnection> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalEmailConnectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _connectionIdMeta = const VerificationMeta(
    'connectionId',
  );
  @override
  late final GeneratedColumn<String> connectionId = GeneratedColumn<String>(
    'connection_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderAddressMeta = const VerificationMeta(
    'senderAddress',
  );
  @override
  late final GeneratedColumn<String> senderAddress = GeneratedColumn<String>(
    'sender_address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerUserId,
    connectionId,
    provider,
    senderAddress,
    status,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_email_connections';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredEmailConnection> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerUserIdMeta);
    }
    if (data.containsKey('connection_id')) {
      context.handle(
        _connectionIdMeta,
        connectionId.isAcceptableOrUnknown(
          data['connection_id']!,
          _connectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_connectionIdMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('sender_address')) {
      context.handle(
        _senderAddressMeta,
        senderAddress.isAcceptableOrUnknown(
          data['sender_address']!,
          _senderAddressMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_senderAddressMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerUserId};
  @override
  StoredEmailConnection map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredEmailConnection(
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      )!,
      connectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}connection_id'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      senderAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_address'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalEmailConnectionsTable createAlias(String alias) {
    return $LocalEmailConnectionsTable(attachedDatabase, alias);
  }
}

class StoredEmailConnection extends DataClass
    implements Insertable<StoredEmailConnection> {
  final String ownerUserId;
  final String connectionId;
  final String provider;
  final String senderAddress;
  final String status;
  final DateTime updatedAt;
  const StoredEmailConnection({
    required this.ownerUserId,
    required this.connectionId,
    required this.provider,
    required this.senderAddress,
    required this.status,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_user_id'] = Variable<String>(ownerUserId);
    map['connection_id'] = Variable<String>(connectionId);
    map['provider'] = Variable<String>(provider);
    map['sender_address'] = Variable<String>(senderAddress);
    map['status'] = Variable<String>(status);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalEmailConnectionsCompanion toCompanion(bool nullToAbsent) {
    return LocalEmailConnectionsCompanion(
      ownerUserId: Value(ownerUserId),
      connectionId: Value(connectionId),
      provider: Value(provider),
      senderAddress: Value(senderAddress),
      status: Value(status),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredEmailConnection.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredEmailConnection(
      ownerUserId: serializer.fromJson<String>(json['ownerUserId']),
      connectionId: serializer.fromJson<String>(json['connectionId']),
      provider: serializer.fromJson<String>(json['provider']),
      senderAddress: serializer.fromJson<String>(json['senderAddress']),
      status: serializer.fromJson<String>(json['status']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerUserId': serializer.toJson<String>(ownerUserId),
      'connectionId': serializer.toJson<String>(connectionId),
      'provider': serializer.toJson<String>(provider),
      'senderAddress': serializer.toJson<String>(senderAddress),
      'status': serializer.toJson<String>(status),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredEmailConnection copyWith({
    String? ownerUserId,
    String? connectionId,
    String? provider,
    String? senderAddress,
    String? status,
    DateTime? updatedAt,
  }) => StoredEmailConnection(
    ownerUserId: ownerUserId ?? this.ownerUserId,
    connectionId: connectionId ?? this.connectionId,
    provider: provider ?? this.provider,
    senderAddress: senderAddress ?? this.senderAddress,
    status: status ?? this.status,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredEmailConnection copyWithCompanion(LocalEmailConnectionsCompanion data) {
    return StoredEmailConnection(
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      connectionId: data.connectionId.present
          ? data.connectionId.value
          : this.connectionId,
      provider: data.provider.present ? data.provider.value : this.provider,
      senderAddress: data.senderAddress.present
          ? data.senderAddress.value
          : this.senderAddress,
      status: data.status.present ? data.status.value : this.status,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredEmailConnection(')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('connectionId: $connectionId, ')
          ..write('provider: $provider, ')
          ..write('senderAddress: $senderAddress, ')
          ..write('status: $status, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerUserId,
    connectionId,
    provider,
    senderAddress,
    status,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredEmailConnection &&
          other.ownerUserId == this.ownerUserId &&
          other.connectionId == this.connectionId &&
          other.provider == this.provider &&
          other.senderAddress == this.senderAddress &&
          other.status == this.status &&
          other.updatedAt == this.updatedAt);
}

class LocalEmailConnectionsCompanion
    extends UpdateCompanion<StoredEmailConnection> {
  final Value<String> ownerUserId;
  final Value<String> connectionId;
  final Value<String> provider;
  final Value<String> senderAddress;
  final Value<String> status;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalEmailConnectionsCompanion({
    this.ownerUserId = const Value.absent(),
    this.connectionId = const Value.absent(),
    this.provider = const Value.absent(),
    this.senderAddress = const Value.absent(),
    this.status = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalEmailConnectionsCompanion.insert({
    required String ownerUserId,
    required String connectionId,
    required String provider,
    required String senderAddress,
    required String status,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : ownerUserId = Value(ownerUserId),
       connectionId = Value(connectionId),
       provider = Value(provider),
       senderAddress = Value(senderAddress),
       status = Value(status),
       updatedAt = Value(updatedAt);
  static Insertable<StoredEmailConnection> custom({
    Expression<String>? ownerUserId,
    Expression<String>? connectionId,
    Expression<String>? provider,
    Expression<String>? senderAddress,
    Expression<String>? status,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (connectionId != null) 'connection_id': connectionId,
      if (provider != null) 'provider': provider,
      if (senderAddress != null) 'sender_address': senderAddress,
      if (status != null) 'status': status,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalEmailConnectionsCompanion copyWith({
    Value<String>? ownerUserId,
    Value<String>? connectionId,
    Value<String>? provider,
    Value<String>? senderAddress,
    Value<String>? status,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalEmailConnectionsCompanion(
      ownerUserId: ownerUserId ?? this.ownerUserId,
      connectionId: connectionId ?? this.connectionId,
      provider: provider ?? this.provider,
      senderAddress: senderAddress ?? this.senderAddress,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (connectionId.present) {
      map['connection_id'] = Variable<String>(connectionId.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (senderAddress.present) {
      map['sender_address'] = Variable<String>(senderAddress.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalEmailConnectionsCompanion(')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('connectionId: $connectionId, ')
          ..write('provider: $provider, ')
          ..write('senderAddress: $senderAddress, ')
          ..write('status: $status, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalLeadsTable extends LocalLeads
    with TableInfo<$LocalLeadsTable, StoredLead> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalLeadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
    'local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commercialFolioMeta = const VerificationMeta(
    'commercialFolio',
  );
  @override
  late final GeneratedColumn<String> commercialFolio = GeneratedColumn<String>(
    'commercial_folio',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
    'captured_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedByMeta = const VerificationMeta(
    'capturedBy',
  );
  @override
  late final GeneratedColumn<String> capturedBy = GeneratedColumn<String>(
    'captured_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originKindMeta = const VerificationMeta(
    'originKind',
  );
  @override
  late final GeneratedColumn<String> originKind = GeneratedColumn<String>(
    'origin_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventLocalIdMeta = const VerificationMeta(
    'eventLocalId',
  );
  @override
  late final GeneratedColumn<String> eventLocalId = GeneratedColumn<String>(
    'event_local_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_events (local_id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _eventNameSnapshotMeta = const VerificationMeta(
    'eventNameSnapshot',
  );
  @override
  late final GeneratedColumn<String> eventNameSnapshot =
      GeneratedColumn<String>(
        'event_name_snapshot',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastNameMeta = const VerificationMeta(
    'lastName',
  );
  @override
  late final GeneratedColumn<String> lastName = GeneratedColumn<String>(
    'last_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyMeta = const VerificationMeta(
    'company',
  );
  @override
  late final GeneratedColumn<String> company = GeneratedColumn<String>(
    'company',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _leadTypeMeta = const VerificationMeta(
    'leadType',
  );
  @override
  late final GeneratedColumn<String> leadType = GeneratedColumn<String>(
    'lead_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _interestLevelMeta = const VerificationMeta(
    'interestLevel',
  );
  @override
  late final GeneratedColumn<String> interestLevel = GeneratedColumn<String>(
    'interest_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _placeMeta = const VerificationMeta('place');
  @override
  late final GeneratedColumn<String> place = GeneratedColumn<String>(
    'place',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentFileIdsJsonMeta =
      const VerificationMeta('contentFileIdsJson');
  @override
  late final GeneratedColumn<String> contentFileIdsJson =
      GeneratedColumn<String>(
        'content_file_ids_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _contentNamesJsonMeta = const VerificationMeta(
    'contentNamesJson',
  );
  @override
  late final GeneratedColumn<String> contentNamesJson = GeneratedColumn<String>(
    'content_names_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _transcriptionMeta = const VerificationMeta(
    'transcription',
  );
  @override
  late final GeneratedColumn<String> transcription = GeneratedColumn<String>(
    'transcription',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _remoteRevisionMeta = const VerificationMeta(
    'remoteRevision',
  );
  @override
  late final GeneratedColumn<int> remoteRevision = GeneratedColumn<int>(
    'remote_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    localId,
    ownerUserId,
    commercialFolio,
    capturedAt,
    capturedBy,
    originKind,
    eventLocalId,
    eventNameSnapshot,
    name,
    lastName,
    role,
    company,
    email,
    phone,
    leadType,
    interestLevel,
    note,
    place,
    contentFileIdsJson,
    contentNamesJson,
    transcription,
    syncState,
    remoteRevision,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_leads';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredLead> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    }
    if (data.containsKey('commercial_folio')) {
      context.handle(
        _commercialFolioMeta,
        commercialFolio.isAcceptableOrUnknown(
          data['commercial_folio']!,
          _commercialFolioMeta,
        ),
      );
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_capturedAtMeta);
    }
    if (data.containsKey('captured_by')) {
      context.handle(
        _capturedByMeta,
        capturedBy.isAcceptableOrUnknown(data['captured_by']!, _capturedByMeta),
      );
    } else if (isInserting) {
      context.missing(_capturedByMeta);
    }
    if (data.containsKey('origin_kind')) {
      context.handle(
        _originKindMeta,
        originKind.isAcceptableOrUnknown(data['origin_kind']!, _originKindMeta),
      );
    } else if (isInserting) {
      context.missing(_originKindMeta);
    }
    if (data.containsKey('event_local_id')) {
      context.handle(
        _eventLocalIdMeta,
        eventLocalId.isAcceptableOrUnknown(
          data['event_local_id']!,
          _eventLocalIdMeta,
        ),
      );
    }
    if (data.containsKey('event_name_snapshot')) {
      context.handle(
        _eventNameSnapshotMeta,
        eventNameSnapshot.isAcceptableOrUnknown(
          data['event_name_snapshot']!,
          _eventNameSnapshotMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('last_name')) {
      context.handle(
        _lastNameMeta,
        lastName.isAcceptableOrUnknown(data['last_name']!, _lastNameMeta),
      );
    } else if (isInserting) {
      context.missing(_lastNameMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('company')) {
      context.handle(
        _companyMeta,
        company.isAcceptableOrUnknown(data['company']!, _companyMeta),
      );
    } else if (isInserting) {
      context.missing(_companyMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    } else if (isInserting) {
      context.missing(_phoneMeta);
    }
    if (data.containsKey('lead_type')) {
      context.handle(
        _leadTypeMeta,
        leadType.isAcceptableOrUnknown(data['lead_type']!, _leadTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_leadTypeMeta);
    }
    if (data.containsKey('interest_level')) {
      context.handle(
        _interestLevelMeta,
        interestLevel.isAcceptableOrUnknown(
          data['interest_level']!,
          _interestLevelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_interestLevelMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    } else if (isInserting) {
      context.missing(_noteMeta);
    }
    if (data.containsKey('place')) {
      context.handle(
        _placeMeta,
        place.isAcceptableOrUnknown(data['place']!, _placeMeta),
      );
    }
    if (data.containsKey('content_file_ids_json')) {
      context.handle(
        _contentFileIdsJsonMeta,
        contentFileIdsJson.isAcceptableOrUnknown(
          data['content_file_ids_json']!,
          _contentFileIdsJsonMeta,
        ),
      );
    }
    if (data.containsKey('content_names_json')) {
      context.handle(
        _contentNamesJsonMeta,
        contentNamesJson.isAcceptableOrUnknown(
          data['content_names_json']!,
          _contentNamesJsonMeta,
        ),
      );
    }
    if (data.containsKey('transcription')) {
      context.handle(
        _transcriptionMeta,
        transcription.isAcceptableOrUnknown(
          data['transcription']!,
          _transcriptionMeta,
        ),
      );
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('remote_revision')) {
      context.handle(
        _remoteRevisionMeta,
        remoteRevision.isAcceptableOrUnknown(
          data['remote_revision']!,
          _remoteRevisionMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  StoredLead map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredLead(
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_id'],
      )!,
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      ),
      commercialFolio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commercial_folio'],
      ),
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}captured_at'],
      )!,
      capturedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}captured_by'],
      )!,
      originKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_kind'],
      )!,
      eventLocalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_local_id'],
      ),
      eventNameSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_name_snapshot'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      lastName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_name'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      company: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      )!,
      leadType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lead_type'],
      )!,
      interestLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}interest_level'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      place: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}place'],
      ),
      contentFileIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_file_ids_json'],
      )!,
      contentNamesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_names_json'],
      )!,
      transcription: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcription'],
      ),
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      remoteRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_revision'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalLeadsTable createAlias(String alias) {
    return $LocalLeadsTable(attachedDatabase, alias);
  }
}

class StoredLead extends DataClass implements Insertable<StoredLead> {
  final String localId;
  final String? ownerUserId;
  final String? commercialFolio;
  final DateTime capturedAt;
  final String capturedBy;
  final String originKind;
  final String? eventLocalId;
  final String? eventNameSnapshot;
  final String name;
  final String lastName;
  final String role;
  final String company;
  final String email;
  final String phone;
  final String leadType;
  final String interestLevel;
  final String note;
  final String? place;
  final String contentFileIdsJson;
  final String contentNamesJson;
  final String? transcription;
  final String syncState;
  final int? remoteRevision;
  final DateTime createdAt;
  final DateTime updatedAt;
  const StoredLead({
    required this.localId,
    this.ownerUserId,
    this.commercialFolio,
    required this.capturedAt,
    required this.capturedBy,
    required this.originKind,
    this.eventLocalId,
    this.eventNameSnapshot,
    required this.name,
    required this.lastName,
    required this.role,
    required this.company,
    required this.email,
    required this.phone,
    required this.leadType,
    required this.interestLevel,
    required this.note,
    this.place,
    required this.contentFileIdsJson,
    required this.contentNamesJson,
    this.transcription,
    required this.syncState,
    this.remoteRevision,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<String>(localId);
    if (!nullToAbsent || ownerUserId != null) {
      map['owner_user_id'] = Variable<String>(ownerUserId);
    }
    if (!nullToAbsent || commercialFolio != null) {
      map['commercial_folio'] = Variable<String>(commercialFolio);
    }
    map['captured_at'] = Variable<DateTime>(capturedAt);
    map['captured_by'] = Variable<String>(capturedBy);
    map['origin_kind'] = Variable<String>(originKind);
    if (!nullToAbsent || eventLocalId != null) {
      map['event_local_id'] = Variable<String>(eventLocalId);
    }
    if (!nullToAbsent || eventNameSnapshot != null) {
      map['event_name_snapshot'] = Variable<String>(eventNameSnapshot);
    }
    map['name'] = Variable<String>(name);
    map['last_name'] = Variable<String>(lastName);
    map['role'] = Variable<String>(role);
    map['company'] = Variable<String>(company);
    map['email'] = Variable<String>(email);
    map['phone'] = Variable<String>(phone);
    map['lead_type'] = Variable<String>(leadType);
    map['interest_level'] = Variable<String>(interestLevel);
    map['note'] = Variable<String>(note);
    if (!nullToAbsent || place != null) {
      map['place'] = Variable<String>(place);
    }
    map['content_file_ids_json'] = Variable<String>(contentFileIdsJson);
    map['content_names_json'] = Variable<String>(contentNamesJson);
    if (!nullToAbsent || transcription != null) {
      map['transcription'] = Variable<String>(transcription);
    }
    map['sync_state'] = Variable<String>(syncState);
    if (!nullToAbsent || remoteRevision != null) {
      map['remote_revision'] = Variable<int>(remoteRevision);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalLeadsCompanion toCompanion(bool nullToAbsent) {
    return LocalLeadsCompanion(
      localId: Value(localId),
      ownerUserId: ownerUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerUserId),
      commercialFolio: commercialFolio == null && nullToAbsent
          ? const Value.absent()
          : Value(commercialFolio),
      capturedAt: Value(capturedAt),
      capturedBy: Value(capturedBy),
      originKind: Value(originKind),
      eventLocalId: eventLocalId == null && nullToAbsent
          ? const Value.absent()
          : Value(eventLocalId),
      eventNameSnapshot: eventNameSnapshot == null && nullToAbsent
          ? const Value.absent()
          : Value(eventNameSnapshot),
      name: Value(name),
      lastName: Value(lastName),
      role: Value(role),
      company: Value(company),
      email: Value(email),
      phone: Value(phone),
      leadType: Value(leadType),
      interestLevel: Value(interestLevel),
      note: Value(note),
      place: place == null && nullToAbsent
          ? const Value.absent()
          : Value(place),
      contentFileIdsJson: Value(contentFileIdsJson),
      contentNamesJson: Value(contentNamesJson),
      transcription: transcription == null && nullToAbsent
          ? const Value.absent()
          : Value(transcription),
      syncState: Value(syncState),
      remoteRevision: remoteRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteRevision),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredLead.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredLead(
      localId: serializer.fromJson<String>(json['localId']),
      ownerUserId: serializer.fromJson<String?>(json['ownerUserId']),
      commercialFolio: serializer.fromJson<String?>(json['commercialFolio']),
      capturedAt: serializer.fromJson<DateTime>(json['capturedAt']),
      capturedBy: serializer.fromJson<String>(json['capturedBy']),
      originKind: serializer.fromJson<String>(json['originKind']),
      eventLocalId: serializer.fromJson<String?>(json['eventLocalId']),
      eventNameSnapshot: serializer.fromJson<String?>(
        json['eventNameSnapshot'],
      ),
      name: serializer.fromJson<String>(json['name']),
      lastName: serializer.fromJson<String>(json['lastName']),
      role: serializer.fromJson<String>(json['role']),
      company: serializer.fromJson<String>(json['company']),
      email: serializer.fromJson<String>(json['email']),
      phone: serializer.fromJson<String>(json['phone']),
      leadType: serializer.fromJson<String>(json['leadType']),
      interestLevel: serializer.fromJson<String>(json['interestLevel']),
      note: serializer.fromJson<String>(json['note']),
      place: serializer.fromJson<String?>(json['place']),
      contentFileIdsJson: serializer.fromJson<String>(
        json['contentFileIdsJson'],
      ),
      contentNamesJson: serializer.fromJson<String>(json['contentNamesJson']),
      transcription: serializer.fromJson<String?>(json['transcription']),
      syncState: serializer.fromJson<String>(json['syncState']),
      remoteRevision: serializer.fromJson<int?>(json['remoteRevision']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<String>(localId),
      'ownerUserId': serializer.toJson<String?>(ownerUserId),
      'commercialFolio': serializer.toJson<String?>(commercialFolio),
      'capturedAt': serializer.toJson<DateTime>(capturedAt),
      'capturedBy': serializer.toJson<String>(capturedBy),
      'originKind': serializer.toJson<String>(originKind),
      'eventLocalId': serializer.toJson<String?>(eventLocalId),
      'eventNameSnapshot': serializer.toJson<String?>(eventNameSnapshot),
      'name': serializer.toJson<String>(name),
      'lastName': serializer.toJson<String>(lastName),
      'role': serializer.toJson<String>(role),
      'company': serializer.toJson<String>(company),
      'email': serializer.toJson<String>(email),
      'phone': serializer.toJson<String>(phone),
      'leadType': serializer.toJson<String>(leadType),
      'interestLevel': serializer.toJson<String>(interestLevel),
      'note': serializer.toJson<String>(note),
      'place': serializer.toJson<String?>(place),
      'contentFileIdsJson': serializer.toJson<String>(contentFileIdsJson),
      'contentNamesJson': serializer.toJson<String>(contentNamesJson),
      'transcription': serializer.toJson<String?>(transcription),
      'syncState': serializer.toJson<String>(syncState),
      'remoteRevision': serializer.toJson<int?>(remoteRevision),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredLead copyWith({
    String? localId,
    Value<String?> ownerUserId = const Value.absent(),
    Value<String?> commercialFolio = const Value.absent(),
    DateTime? capturedAt,
    String? capturedBy,
    String? originKind,
    Value<String?> eventLocalId = const Value.absent(),
    Value<String?> eventNameSnapshot = const Value.absent(),
    String? name,
    String? lastName,
    String? role,
    String? company,
    String? email,
    String? phone,
    String? leadType,
    String? interestLevel,
    String? note,
    Value<String?> place = const Value.absent(),
    String? contentFileIdsJson,
    String? contentNamesJson,
    Value<String?> transcription = const Value.absent(),
    String? syncState,
    Value<int?> remoteRevision = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StoredLead(
    localId: localId ?? this.localId,
    ownerUserId: ownerUserId.present ? ownerUserId.value : this.ownerUserId,
    commercialFolio: commercialFolio.present
        ? commercialFolio.value
        : this.commercialFolio,
    capturedAt: capturedAt ?? this.capturedAt,
    capturedBy: capturedBy ?? this.capturedBy,
    originKind: originKind ?? this.originKind,
    eventLocalId: eventLocalId.present ? eventLocalId.value : this.eventLocalId,
    eventNameSnapshot: eventNameSnapshot.present
        ? eventNameSnapshot.value
        : this.eventNameSnapshot,
    name: name ?? this.name,
    lastName: lastName ?? this.lastName,
    role: role ?? this.role,
    company: company ?? this.company,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    leadType: leadType ?? this.leadType,
    interestLevel: interestLevel ?? this.interestLevel,
    note: note ?? this.note,
    place: place.present ? place.value : this.place,
    contentFileIdsJson: contentFileIdsJson ?? this.contentFileIdsJson,
    contentNamesJson: contentNamesJson ?? this.contentNamesJson,
    transcription: transcription.present
        ? transcription.value
        : this.transcription,
    syncState: syncState ?? this.syncState,
    remoteRevision: remoteRevision.present
        ? remoteRevision.value
        : this.remoteRevision,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredLead copyWithCompanion(LocalLeadsCompanion data) {
    return StoredLead(
      localId: data.localId.present ? data.localId.value : this.localId,
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      commercialFolio: data.commercialFolio.present
          ? data.commercialFolio.value
          : this.commercialFolio,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      capturedBy: data.capturedBy.present
          ? data.capturedBy.value
          : this.capturedBy,
      originKind: data.originKind.present
          ? data.originKind.value
          : this.originKind,
      eventLocalId: data.eventLocalId.present
          ? data.eventLocalId.value
          : this.eventLocalId,
      eventNameSnapshot: data.eventNameSnapshot.present
          ? data.eventNameSnapshot.value
          : this.eventNameSnapshot,
      name: data.name.present ? data.name.value : this.name,
      lastName: data.lastName.present ? data.lastName.value : this.lastName,
      role: data.role.present ? data.role.value : this.role,
      company: data.company.present ? data.company.value : this.company,
      email: data.email.present ? data.email.value : this.email,
      phone: data.phone.present ? data.phone.value : this.phone,
      leadType: data.leadType.present ? data.leadType.value : this.leadType,
      interestLevel: data.interestLevel.present
          ? data.interestLevel.value
          : this.interestLevel,
      note: data.note.present ? data.note.value : this.note,
      place: data.place.present ? data.place.value : this.place,
      contentFileIdsJson: data.contentFileIdsJson.present
          ? data.contentFileIdsJson.value
          : this.contentFileIdsJson,
      contentNamesJson: data.contentNamesJson.present
          ? data.contentNamesJson.value
          : this.contentNamesJson,
      transcription: data.transcription.present
          ? data.transcription.value
          : this.transcription,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      remoteRevision: data.remoteRevision.present
          ? data.remoteRevision.value
          : this.remoteRevision,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredLead(')
          ..write('localId: $localId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('commercialFolio: $commercialFolio, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('capturedBy: $capturedBy, ')
          ..write('originKind: $originKind, ')
          ..write('eventLocalId: $eventLocalId, ')
          ..write('eventNameSnapshot: $eventNameSnapshot, ')
          ..write('name: $name, ')
          ..write('lastName: $lastName, ')
          ..write('role: $role, ')
          ..write('company: $company, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('leadType: $leadType, ')
          ..write('interestLevel: $interestLevel, ')
          ..write('note: $note, ')
          ..write('place: $place, ')
          ..write('contentFileIdsJson: $contentFileIdsJson, ')
          ..write('contentNamesJson: $contentNamesJson, ')
          ..write('transcription: $transcription, ')
          ..write('syncState: $syncState, ')
          ..write('remoteRevision: $remoteRevision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    localId,
    ownerUserId,
    commercialFolio,
    capturedAt,
    capturedBy,
    originKind,
    eventLocalId,
    eventNameSnapshot,
    name,
    lastName,
    role,
    company,
    email,
    phone,
    leadType,
    interestLevel,
    note,
    place,
    contentFileIdsJson,
    contentNamesJson,
    transcription,
    syncState,
    remoteRevision,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredLead &&
          other.localId == this.localId &&
          other.ownerUserId == this.ownerUserId &&
          other.commercialFolio == this.commercialFolio &&
          other.capturedAt == this.capturedAt &&
          other.capturedBy == this.capturedBy &&
          other.originKind == this.originKind &&
          other.eventLocalId == this.eventLocalId &&
          other.eventNameSnapshot == this.eventNameSnapshot &&
          other.name == this.name &&
          other.lastName == this.lastName &&
          other.role == this.role &&
          other.company == this.company &&
          other.email == this.email &&
          other.phone == this.phone &&
          other.leadType == this.leadType &&
          other.interestLevel == this.interestLevel &&
          other.note == this.note &&
          other.place == this.place &&
          other.contentFileIdsJson == this.contentFileIdsJson &&
          other.contentNamesJson == this.contentNamesJson &&
          other.transcription == this.transcription &&
          other.syncState == this.syncState &&
          other.remoteRevision == this.remoteRevision &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalLeadsCompanion extends UpdateCompanion<StoredLead> {
  final Value<String> localId;
  final Value<String?> ownerUserId;
  final Value<String?> commercialFolio;
  final Value<DateTime> capturedAt;
  final Value<String> capturedBy;
  final Value<String> originKind;
  final Value<String?> eventLocalId;
  final Value<String?> eventNameSnapshot;
  final Value<String> name;
  final Value<String> lastName;
  final Value<String> role;
  final Value<String> company;
  final Value<String> email;
  final Value<String> phone;
  final Value<String> leadType;
  final Value<String> interestLevel;
  final Value<String> note;
  final Value<String?> place;
  final Value<String> contentFileIdsJson;
  final Value<String> contentNamesJson;
  final Value<String?> transcription;
  final Value<String> syncState;
  final Value<int?> remoteRevision;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalLeadsCompanion({
    this.localId = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.commercialFolio = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.capturedBy = const Value.absent(),
    this.originKind = const Value.absent(),
    this.eventLocalId = const Value.absent(),
    this.eventNameSnapshot = const Value.absent(),
    this.name = const Value.absent(),
    this.lastName = const Value.absent(),
    this.role = const Value.absent(),
    this.company = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.leadType = const Value.absent(),
    this.interestLevel = const Value.absent(),
    this.note = const Value.absent(),
    this.place = const Value.absent(),
    this.contentFileIdsJson = const Value.absent(),
    this.contentNamesJson = const Value.absent(),
    this.transcription = const Value.absent(),
    this.syncState = const Value.absent(),
    this.remoteRevision = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalLeadsCompanion.insert({
    required String localId,
    this.ownerUserId = const Value.absent(),
    this.commercialFolio = const Value.absent(),
    required DateTime capturedAt,
    required String capturedBy,
    required String originKind,
    this.eventLocalId = const Value.absent(),
    this.eventNameSnapshot = const Value.absent(),
    required String name,
    required String lastName,
    required String role,
    required String company,
    required String email,
    required String phone,
    required String leadType,
    required String interestLevel,
    required String note,
    this.place = const Value.absent(),
    this.contentFileIdsJson = const Value.absent(),
    this.contentNamesJson = const Value.absent(),
    this.transcription = const Value.absent(),
    this.syncState = const Value.absent(),
    this.remoteRevision = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : localId = Value(localId),
       capturedAt = Value(capturedAt),
       capturedBy = Value(capturedBy),
       originKind = Value(originKind),
       name = Value(name),
       lastName = Value(lastName),
       role = Value(role),
       company = Value(company),
       email = Value(email),
       phone = Value(phone),
       leadType = Value(leadType),
       interestLevel = Value(interestLevel),
       note = Value(note),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<StoredLead> custom({
    Expression<String>? localId,
    Expression<String>? ownerUserId,
    Expression<String>? commercialFolio,
    Expression<DateTime>? capturedAt,
    Expression<String>? capturedBy,
    Expression<String>? originKind,
    Expression<String>? eventLocalId,
    Expression<String>? eventNameSnapshot,
    Expression<String>? name,
    Expression<String>? lastName,
    Expression<String>? role,
    Expression<String>? company,
    Expression<String>? email,
    Expression<String>? phone,
    Expression<String>? leadType,
    Expression<String>? interestLevel,
    Expression<String>? note,
    Expression<String>? place,
    Expression<String>? contentFileIdsJson,
    Expression<String>? contentNamesJson,
    Expression<String>? transcription,
    Expression<String>? syncState,
    Expression<int>? remoteRevision,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (commercialFolio != null) 'commercial_folio': commercialFolio,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (capturedBy != null) 'captured_by': capturedBy,
      if (originKind != null) 'origin_kind': originKind,
      if (eventLocalId != null) 'event_local_id': eventLocalId,
      if (eventNameSnapshot != null) 'event_name_snapshot': eventNameSnapshot,
      if (name != null) 'name': name,
      if (lastName != null) 'last_name': lastName,
      if (role != null) 'role': role,
      if (company != null) 'company': company,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (leadType != null) 'lead_type': leadType,
      if (interestLevel != null) 'interest_level': interestLevel,
      if (note != null) 'note': note,
      if (place != null) 'place': place,
      if (contentFileIdsJson != null)
        'content_file_ids_json': contentFileIdsJson,
      if (contentNamesJson != null) 'content_names_json': contentNamesJson,
      if (transcription != null) 'transcription': transcription,
      if (syncState != null) 'sync_state': syncState,
      if (remoteRevision != null) 'remote_revision': remoteRevision,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalLeadsCompanion copyWith({
    Value<String>? localId,
    Value<String?>? ownerUserId,
    Value<String?>? commercialFolio,
    Value<DateTime>? capturedAt,
    Value<String>? capturedBy,
    Value<String>? originKind,
    Value<String?>? eventLocalId,
    Value<String?>? eventNameSnapshot,
    Value<String>? name,
    Value<String>? lastName,
    Value<String>? role,
    Value<String>? company,
    Value<String>? email,
    Value<String>? phone,
    Value<String>? leadType,
    Value<String>? interestLevel,
    Value<String>? note,
    Value<String?>? place,
    Value<String>? contentFileIdsJson,
    Value<String>? contentNamesJson,
    Value<String?>? transcription,
    Value<String>? syncState,
    Value<int?>? remoteRevision,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalLeadsCompanion(
      localId: localId ?? this.localId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      commercialFolio: commercialFolio ?? this.commercialFolio,
      capturedAt: capturedAt ?? this.capturedAt,
      capturedBy: capturedBy ?? this.capturedBy,
      originKind: originKind ?? this.originKind,
      eventLocalId: eventLocalId ?? this.eventLocalId,
      eventNameSnapshot: eventNameSnapshot ?? this.eventNameSnapshot,
      name: name ?? this.name,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      company: company ?? this.company,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      leadType: leadType ?? this.leadType,
      interestLevel: interestLevel ?? this.interestLevel,
      note: note ?? this.note,
      place: place ?? this.place,
      contentFileIdsJson: contentFileIdsJson ?? this.contentFileIdsJson,
      contentNamesJson: contentNamesJson ?? this.contentNamesJson,
      transcription: transcription ?? this.transcription,
      syncState: syncState ?? this.syncState,
      remoteRevision: remoteRevision ?? this.remoteRevision,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (commercialFolio.present) {
      map['commercial_folio'] = Variable<String>(commercialFolio.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    if (capturedBy.present) {
      map['captured_by'] = Variable<String>(capturedBy.value);
    }
    if (originKind.present) {
      map['origin_kind'] = Variable<String>(originKind.value);
    }
    if (eventLocalId.present) {
      map['event_local_id'] = Variable<String>(eventLocalId.value);
    }
    if (eventNameSnapshot.present) {
      map['event_name_snapshot'] = Variable<String>(eventNameSnapshot.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (lastName.present) {
      map['last_name'] = Variable<String>(lastName.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (company.present) {
      map['company'] = Variable<String>(company.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (leadType.present) {
      map['lead_type'] = Variable<String>(leadType.value);
    }
    if (interestLevel.present) {
      map['interest_level'] = Variable<String>(interestLevel.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (place.present) {
      map['place'] = Variable<String>(place.value);
    }
    if (contentFileIdsJson.present) {
      map['content_file_ids_json'] = Variable<String>(contentFileIdsJson.value);
    }
    if (contentNamesJson.present) {
      map['content_names_json'] = Variable<String>(contentNamesJson.value);
    }
    if (transcription.present) {
      map['transcription'] = Variable<String>(transcription.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (remoteRevision.present) {
      map['remote_revision'] = Variable<int>(remoteRevision.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalLeadsCompanion(')
          ..write('localId: $localId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('commercialFolio: $commercialFolio, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('capturedBy: $capturedBy, ')
          ..write('originKind: $originKind, ')
          ..write('eventLocalId: $eventLocalId, ')
          ..write('eventNameSnapshot: $eventNameSnapshot, ')
          ..write('name: $name, ')
          ..write('lastName: $lastName, ')
          ..write('role: $role, ')
          ..write('company: $company, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('leadType: $leadType, ')
          ..write('interestLevel: $interestLevel, ')
          ..write('note: $note, ')
          ..write('place: $place, ')
          ..write('contentFileIdsJson: $contentFileIdsJson, ')
          ..write('contentNamesJson: $contentNamesJson, ')
          ..write('transcription: $transcription, ')
          ..write('syncState: $syncState, ')
          ..write('remoteRevision: $remoteRevision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalEmailFollowUpsTable extends LocalEmailFollowUps
    with TableInfo<$LocalEmailFollowUpsTable, StoredEmailFollowUp> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalEmailFollowUpsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
    'local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _leadLocalIdMeta = const VerificationMeta(
    'leadLocalId',
  );
  @override
  late final GeneratedColumn<String> leadLocalId = GeneratedColumn<String>(
    'lead_local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_leads (local_id)',
    ),
  );
  static const VerificationMeta _recipientAddressMeta = const VerificationMeta(
    'recipientAddress',
  );
  @override
  late final GeneratedColumn<String> recipientAddress = GeneratedColumn<String>(
    'recipient_address',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plainBodyMeta = const VerificationMeta(
    'plainBody',
  );
  @override
  late final GeneratedColumn<String> plainBody = GeneratedColumn<String>(
    'plain_body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _htmlBodyMeta = const VerificationMeta(
    'htmlBody',
  );
  @override
  late final GeneratedColumn<String> htmlBody = GeneratedColumn<String>(
    'html_body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentFileIdsJsonMeta =
      const VerificationMeta('contentFileIdsJson');
  @override
  late final GeneratedColumn<String> contentFileIdsJson =
      GeneratedColumn<String>(
        'content_file_ids_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _contentNamesJsonMeta = const VerificationMeta(
    'contentNamesJson',
  );
  @override
  late final GeneratedColumn<String> contentNamesJson = GeneratedColumn<String>(
    'content_names_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _languageCodeMeta = const VerificationMeta(
    'languageCode',
  );
  @override
  late final GeneratedColumn<String> languageCode = GeneratedColumn<String>(
    'language_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _preparedAtMeta = const VerificationMeta(
    'preparedAt',
  );
  @override
  late final GeneratedColumn<DateTime> preparedAt = GeneratedColumn<DateTime>(
    'prepared_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    localId,
    ownerUserId,
    leadLocalId,
    recipientAddress,
    subject,
    plainBody,
    htmlBody,
    contentFileIdsJson,
    contentNamesJson,
    languageCode,
    preparedAt,
    syncState,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_email_follow_ups';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredEmailFollowUp> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerUserIdMeta);
    }
    if (data.containsKey('lead_local_id')) {
      context.handle(
        _leadLocalIdMeta,
        leadLocalId.isAcceptableOrUnknown(
          data['lead_local_id']!,
          _leadLocalIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_leadLocalIdMeta);
    }
    if (data.containsKey('recipient_address')) {
      context.handle(
        _recipientAddressMeta,
        recipientAddress.isAcceptableOrUnknown(
          data['recipient_address']!,
          _recipientAddressMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recipientAddressMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('plain_body')) {
      context.handle(
        _plainBodyMeta,
        plainBody.isAcceptableOrUnknown(data['plain_body']!, _plainBodyMeta),
      );
    } else if (isInserting) {
      context.missing(_plainBodyMeta);
    }
    if (data.containsKey('html_body')) {
      context.handle(
        _htmlBodyMeta,
        htmlBody.isAcceptableOrUnknown(data['html_body']!, _htmlBodyMeta),
      );
    } else if (isInserting) {
      context.missing(_htmlBodyMeta);
    }
    if (data.containsKey('content_file_ids_json')) {
      context.handle(
        _contentFileIdsJsonMeta,
        contentFileIdsJson.isAcceptableOrUnknown(
          data['content_file_ids_json']!,
          _contentFileIdsJsonMeta,
        ),
      );
    }
    if (data.containsKey('content_names_json')) {
      context.handle(
        _contentNamesJsonMeta,
        contentNamesJson.isAcceptableOrUnknown(
          data['content_names_json']!,
          _contentNamesJsonMeta,
        ),
      );
    }
    if (data.containsKey('language_code')) {
      context.handle(
        _languageCodeMeta,
        languageCode.isAcceptableOrUnknown(
          data['language_code']!,
          _languageCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_languageCodeMeta);
    }
    if (data.containsKey('prepared_at')) {
      context.handle(
        _preparedAtMeta,
        preparedAt.isAcceptableOrUnknown(data['prepared_at']!, _preparedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_preparedAtMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  StoredEmailFollowUp map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredEmailFollowUp(
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_id'],
      )!,
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      )!,
      leadLocalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lead_local_id'],
      )!,
      recipientAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipient_address'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      plainBody: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plain_body'],
      )!,
      htmlBody: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}html_body'],
      )!,
      contentFileIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_file_ids_json'],
      )!,
      contentNamesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_names_json'],
      )!,
      languageCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language_code'],
      )!,
      preparedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}prepared_at'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
    );
  }

  @override
  $LocalEmailFollowUpsTable createAlias(String alias) {
    return $LocalEmailFollowUpsTable(attachedDatabase, alias);
  }
}

class StoredEmailFollowUp extends DataClass
    implements Insertable<StoredEmailFollowUp> {
  final String localId;
  final String ownerUserId;
  final String leadLocalId;
  final String recipientAddress;
  final String subject;
  final String plainBody;
  final String htmlBody;
  final String contentFileIdsJson;
  final String contentNamesJson;
  final String languageCode;
  final DateTime preparedAt;
  final String syncState;
  const StoredEmailFollowUp({
    required this.localId,
    required this.ownerUserId,
    required this.leadLocalId,
    required this.recipientAddress,
    required this.subject,
    required this.plainBody,
    required this.htmlBody,
    required this.contentFileIdsJson,
    required this.contentNamesJson,
    required this.languageCode,
    required this.preparedAt,
    required this.syncState,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<String>(localId);
    map['owner_user_id'] = Variable<String>(ownerUserId);
    map['lead_local_id'] = Variable<String>(leadLocalId);
    map['recipient_address'] = Variable<String>(recipientAddress);
    map['subject'] = Variable<String>(subject);
    map['plain_body'] = Variable<String>(plainBody);
    map['html_body'] = Variable<String>(htmlBody);
    map['content_file_ids_json'] = Variable<String>(contentFileIdsJson);
    map['content_names_json'] = Variable<String>(contentNamesJson);
    map['language_code'] = Variable<String>(languageCode);
    map['prepared_at'] = Variable<DateTime>(preparedAt);
    map['sync_state'] = Variable<String>(syncState);
    return map;
  }

  LocalEmailFollowUpsCompanion toCompanion(bool nullToAbsent) {
    return LocalEmailFollowUpsCompanion(
      localId: Value(localId),
      ownerUserId: Value(ownerUserId),
      leadLocalId: Value(leadLocalId),
      recipientAddress: Value(recipientAddress),
      subject: Value(subject),
      plainBody: Value(plainBody),
      htmlBody: Value(htmlBody),
      contentFileIdsJson: Value(contentFileIdsJson),
      contentNamesJson: Value(contentNamesJson),
      languageCode: Value(languageCode),
      preparedAt: Value(preparedAt),
      syncState: Value(syncState),
    );
  }

  factory StoredEmailFollowUp.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredEmailFollowUp(
      localId: serializer.fromJson<String>(json['localId']),
      ownerUserId: serializer.fromJson<String>(json['ownerUserId']),
      leadLocalId: serializer.fromJson<String>(json['leadLocalId']),
      recipientAddress: serializer.fromJson<String>(json['recipientAddress']),
      subject: serializer.fromJson<String>(json['subject']),
      plainBody: serializer.fromJson<String>(json['plainBody']),
      htmlBody: serializer.fromJson<String>(json['htmlBody']),
      contentFileIdsJson: serializer.fromJson<String>(
        json['contentFileIdsJson'],
      ),
      contentNamesJson: serializer.fromJson<String>(json['contentNamesJson']),
      languageCode: serializer.fromJson<String>(json['languageCode']),
      preparedAt: serializer.fromJson<DateTime>(json['preparedAt']),
      syncState: serializer.fromJson<String>(json['syncState']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<String>(localId),
      'ownerUserId': serializer.toJson<String>(ownerUserId),
      'leadLocalId': serializer.toJson<String>(leadLocalId),
      'recipientAddress': serializer.toJson<String>(recipientAddress),
      'subject': serializer.toJson<String>(subject),
      'plainBody': serializer.toJson<String>(plainBody),
      'htmlBody': serializer.toJson<String>(htmlBody),
      'contentFileIdsJson': serializer.toJson<String>(contentFileIdsJson),
      'contentNamesJson': serializer.toJson<String>(contentNamesJson),
      'languageCode': serializer.toJson<String>(languageCode),
      'preparedAt': serializer.toJson<DateTime>(preparedAt),
      'syncState': serializer.toJson<String>(syncState),
    };
  }

  StoredEmailFollowUp copyWith({
    String? localId,
    String? ownerUserId,
    String? leadLocalId,
    String? recipientAddress,
    String? subject,
    String? plainBody,
    String? htmlBody,
    String? contentFileIdsJson,
    String? contentNamesJson,
    String? languageCode,
    DateTime? preparedAt,
    String? syncState,
  }) => StoredEmailFollowUp(
    localId: localId ?? this.localId,
    ownerUserId: ownerUserId ?? this.ownerUserId,
    leadLocalId: leadLocalId ?? this.leadLocalId,
    recipientAddress: recipientAddress ?? this.recipientAddress,
    subject: subject ?? this.subject,
    plainBody: plainBody ?? this.plainBody,
    htmlBody: htmlBody ?? this.htmlBody,
    contentFileIdsJson: contentFileIdsJson ?? this.contentFileIdsJson,
    contentNamesJson: contentNamesJson ?? this.contentNamesJson,
    languageCode: languageCode ?? this.languageCode,
    preparedAt: preparedAt ?? this.preparedAt,
    syncState: syncState ?? this.syncState,
  );
  StoredEmailFollowUp copyWithCompanion(LocalEmailFollowUpsCompanion data) {
    return StoredEmailFollowUp(
      localId: data.localId.present ? data.localId.value : this.localId,
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      leadLocalId: data.leadLocalId.present
          ? data.leadLocalId.value
          : this.leadLocalId,
      recipientAddress: data.recipientAddress.present
          ? data.recipientAddress.value
          : this.recipientAddress,
      subject: data.subject.present ? data.subject.value : this.subject,
      plainBody: data.plainBody.present ? data.plainBody.value : this.plainBody,
      htmlBody: data.htmlBody.present ? data.htmlBody.value : this.htmlBody,
      contentFileIdsJson: data.contentFileIdsJson.present
          ? data.contentFileIdsJson.value
          : this.contentFileIdsJson,
      contentNamesJson: data.contentNamesJson.present
          ? data.contentNamesJson.value
          : this.contentNamesJson,
      languageCode: data.languageCode.present
          ? data.languageCode.value
          : this.languageCode,
      preparedAt: data.preparedAt.present
          ? data.preparedAt.value
          : this.preparedAt,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredEmailFollowUp(')
          ..write('localId: $localId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('leadLocalId: $leadLocalId, ')
          ..write('recipientAddress: $recipientAddress, ')
          ..write('subject: $subject, ')
          ..write('plainBody: $plainBody, ')
          ..write('htmlBody: $htmlBody, ')
          ..write('contentFileIdsJson: $contentFileIdsJson, ')
          ..write('contentNamesJson: $contentNamesJson, ')
          ..write('languageCode: $languageCode, ')
          ..write('preparedAt: $preparedAt, ')
          ..write('syncState: $syncState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localId,
    ownerUserId,
    leadLocalId,
    recipientAddress,
    subject,
    plainBody,
    htmlBody,
    contentFileIdsJson,
    contentNamesJson,
    languageCode,
    preparedAt,
    syncState,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredEmailFollowUp &&
          other.localId == this.localId &&
          other.ownerUserId == this.ownerUserId &&
          other.leadLocalId == this.leadLocalId &&
          other.recipientAddress == this.recipientAddress &&
          other.subject == this.subject &&
          other.plainBody == this.plainBody &&
          other.htmlBody == this.htmlBody &&
          other.contentFileIdsJson == this.contentFileIdsJson &&
          other.contentNamesJson == this.contentNamesJson &&
          other.languageCode == this.languageCode &&
          other.preparedAt == this.preparedAt &&
          other.syncState == this.syncState);
}

class LocalEmailFollowUpsCompanion
    extends UpdateCompanion<StoredEmailFollowUp> {
  final Value<String> localId;
  final Value<String> ownerUserId;
  final Value<String> leadLocalId;
  final Value<String> recipientAddress;
  final Value<String> subject;
  final Value<String> plainBody;
  final Value<String> htmlBody;
  final Value<String> contentFileIdsJson;
  final Value<String> contentNamesJson;
  final Value<String> languageCode;
  final Value<DateTime> preparedAt;
  final Value<String> syncState;
  final Value<int> rowid;
  const LocalEmailFollowUpsCompanion({
    this.localId = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.leadLocalId = const Value.absent(),
    this.recipientAddress = const Value.absent(),
    this.subject = const Value.absent(),
    this.plainBody = const Value.absent(),
    this.htmlBody = const Value.absent(),
    this.contentFileIdsJson = const Value.absent(),
    this.contentNamesJson = const Value.absent(),
    this.languageCode = const Value.absent(),
    this.preparedAt = const Value.absent(),
    this.syncState = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalEmailFollowUpsCompanion.insert({
    required String localId,
    required String ownerUserId,
    required String leadLocalId,
    required String recipientAddress,
    required String subject,
    required String plainBody,
    required String htmlBody,
    this.contentFileIdsJson = const Value.absent(),
    this.contentNamesJson = const Value.absent(),
    required String languageCode,
    required DateTime preparedAt,
    this.syncState = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : localId = Value(localId),
       ownerUserId = Value(ownerUserId),
       leadLocalId = Value(leadLocalId),
       recipientAddress = Value(recipientAddress),
       subject = Value(subject),
       plainBody = Value(plainBody),
       htmlBody = Value(htmlBody),
       languageCode = Value(languageCode),
       preparedAt = Value(preparedAt);
  static Insertable<StoredEmailFollowUp> custom({
    Expression<String>? localId,
    Expression<String>? ownerUserId,
    Expression<String>? leadLocalId,
    Expression<String>? recipientAddress,
    Expression<String>? subject,
    Expression<String>? plainBody,
    Expression<String>? htmlBody,
    Expression<String>? contentFileIdsJson,
    Expression<String>? contentNamesJson,
    Expression<String>? languageCode,
    Expression<DateTime>? preparedAt,
    Expression<String>? syncState,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (leadLocalId != null) 'lead_local_id': leadLocalId,
      if (recipientAddress != null) 'recipient_address': recipientAddress,
      if (subject != null) 'subject': subject,
      if (plainBody != null) 'plain_body': plainBody,
      if (htmlBody != null) 'html_body': htmlBody,
      if (contentFileIdsJson != null)
        'content_file_ids_json': contentFileIdsJson,
      if (contentNamesJson != null) 'content_names_json': contentNamesJson,
      if (languageCode != null) 'language_code': languageCode,
      if (preparedAt != null) 'prepared_at': preparedAt,
      if (syncState != null) 'sync_state': syncState,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalEmailFollowUpsCompanion copyWith({
    Value<String>? localId,
    Value<String>? ownerUserId,
    Value<String>? leadLocalId,
    Value<String>? recipientAddress,
    Value<String>? subject,
    Value<String>? plainBody,
    Value<String>? htmlBody,
    Value<String>? contentFileIdsJson,
    Value<String>? contentNamesJson,
    Value<String>? languageCode,
    Value<DateTime>? preparedAt,
    Value<String>? syncState,
    Value<int>? rowid,
  }) {
    return LocalEmailFollowUpsCompanion(
      localId: localId ?? this.localId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      leadLocalId: leadLocalId ?? this.leadLocalId,
      recipientAddress: recipientAddress ?? this.recipientAddress,
      subject: subject ?? this.subject,
      plainBody: plainBody ?? this.plainBody,
      htmlBody: htmlBody ?? this.htmlBody,
      contentFileIdsJson: contentFileIdsJson ?? this.contentFileIdsJson,
      contentNamesJson: contentNamesJson ?? this.contentNamesJson,
      languageCode: languageCode ?? this.languageCode,
      preparedAt: preparedAt ?? this.preparedAt,
      syncState: syncState ?? this.syncState,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (leadLocalId.present) {
      map['lead_local_id'] = Variable<String>(leadLocalId.value);
    }
    if (recipientAddress.present) {
      map['recipient_address'] = Variable<String>(recipientAddress.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (plainBody.present) {
      map['plain_body'] = Variable<String>(plainBody.value);
    }
    if (htmlBody.present) {
      map['html_body'] = Variable<String>(htmlBody.value);
    }
    if (contentFileIdsJson.present) {
      map['content_file_ids_json'] = Variable<String>(contentFileIdsJson.value);
    }
    if (contentNamesJson.present) {
      map['content_names_json'] = Variable<String>(contentNamesJson.value);
    }
    if (languageCode.present) {
      map['language_code'] = Variable<String>(languageCode.value);
    }
    if (preparedAt.present) {
      map['prepared_at'] = Variable<DateTime>(preparedAt.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalEmailFollowUpsCompanion(')
          ..write('localId: $localId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('leadLocalId: $leadLocalId, ')
          ..write('recipientAddress: $recipientAddress, ')
          ..write('subject: $subject, ')
          ..write('plainBody: $plainBody, ')
          ..write('htmlBody: $htmlBody, ')
          ..write('contentFileIdsJson: $contentFileIdsJson, ')
          ..write('contentNamesJson: $contentNamesJson, ')
          ..write('languageCode: $languageCode, ')
          ..write('preparedAt: $preparedAt, ')
          ..write('syncState: $syncState, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalEmailSendIntentsTable extends LocalEmailSendIntents
    with TableInfo<$LocalEmailSendIntentsTable, StoredEmailSendIntent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalEmailSendIntentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
    'local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _followUpLocalIdMeta = const VerificationMeta(
    'followUpLocalId',
  );
  @override
  late final GeneratedColumn<String> followUpLocalId = GeneratedColumn<String>(
    'follow_up_local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_email_follow_ups (local_id)',
    ),
  );
  static const VerificationMeta _connectionIdMeta = const VerificationMeta(
    'connectionId',
  );
  @override
  late final GeneratedColumn<String> connectionId = GeneratedColumn<String>(
    'connection_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _senderAddressMeta = const VerificationMeta(
    'senderAddress',
  );
  @override
  late final GeneratedColumn<String> senderAddress = GeneratedColumn<String>(
    'sender_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _omittedContentIdsJsonMeta =
      const VerificationMeta('omittedContentIdsJson');
  @override
  late final GeneratedColumn<String> omittedContentIdsJson =
      GeneratedColumn<String>(
        'omitted_content_ids_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _parentIntentIdMeta = const VerificationMeta(
    'parentIntentId',
  );
  @override
  late final GeneratedColumn<String> parentIntentId = GeneratedColumn<String>(
    'parent_intent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    localId,
    ownerUserId,
    followUpLocalId,
    connectionId,
    senderAddress,
    status,
    omittedContentIdsJson,
    parentIntentId,
    attemptCount,
    errorCode,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_email_send_intents';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredEmailSendIntent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerUserIdMeta);
    }
    if (data.containsKey('follow_up_local_id')) {
      context.handle(
        _followUpLocalIdMeta,
        followUpLocalId.isAcceptableOrUnknown(
          data['follow_up_local_id']!,
          _followUpLocalIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_followUpLocalIdMeta);
    }
    if (data.containsKey('connection_id')) {
      context.handle(
        _connectionIdMeta,
        connectionId.isAcceptableOrUnknown(
          data['connection_id']!,
          _connectionIdMeta,
        ),
      );
    }
    if (data.containsKey('sender_address')) {
      context.handle(
        _senderAddressMeta,
        senderAddress.isAcceptableOrUnknown(
          data['sender_address']!,
          _senderAddressMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('omitted_content_ids_json')) {
      context.handle(
        _omittedContentIdsJsonMeta,
        omittedContentIdsJson.isAcceptableOrUnknown(
          data['omitted_content_ids_json']!,
          _omittedContentIdsJsonMeta,
        ),
      );
    }
    if (data.containsKey('parent_intent_id')) {
      context.handle(
        _parentIntentIdMeta,
        parentIntentId.isAcceptableOrUnknown(
          data['parent_intent_id']!,
          _parentIntentIdMeta,
        ),
      );
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  StoredEmailSendIntent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredEmailSendIntent(
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_id'],
      )!,
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      )!,
      followUpLocalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}follow_up_local_id'],
      )!,
      connectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}connection_id'],
      ),
      senderAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_address'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      omittedContentIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}omitted_content_ids_json'],
      )!,
      parentIntentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_intent_id'],
      ),
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalEmailSendIntentsTable createAlias(String alias) {
    return $LocalEmailSendIntentsTable(attachedDatabase, alias);
  }
}

class StoredEmailSendIntent extends DataClass
    implements Insertable<StoredEmailSendIntent> {
  final String localId;
  final String ownerUserId;
  final String followUpLocalId;
  final String? connectionId;
  final String? senderAddress;
  final String status;
  final String omittedContentIdsJson;
  final String? parentIntentId;
  final int attemptCount;
  final String? errorCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  const StoredEmailSendIntent({
    required this.localId,
    required this.ownerUserId,
    required this.followUpLocalId,
    this.connectionId,
    this.senderAddress,
    required this.status,
    required this.omittedContentIdsJson,
    this.parentIntentId,
    required this.attemptCount,
    this.errorCode,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<String>(localId);
    map['owner_user_id'] = Variable<String>(ownerUserId);
    map['follow_up_local_id'] = Variable<String>(followUpLocalId);
    if (!nullToAbsent || connectionId != null) {
      map['connection_id'] = Variable<String>(connectionId);
    }
    if (!nullToAbsent || senderAddress != null) {
      map['sender_address'] = Variable<String>(senderAddress);
    }
    map['status'] = Variable<String>(status);
    map['omitted_content_ids_json'] = Variable<String>(omittedContentIdsJson);
    if (!nullToAbsent || parentIntentId != null) {
      map['parent_intent_id'] = Variable<String>(parentIntentId);
    }
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalEmailSendIntentsCompanion toCompanion(bool nullToAbsent) {
    return LocalEmailSendIntentsCompanion(
      localId: Value(localId),
      ownerUserId: Value(ownerUserId),
      followUpLocalId: Value(followUpLocalId),
      connectionId: connectionId == null && nullToAbsent
          ? const Value.absent()
          : Value(connectionId),
      senderAddress: senderAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(senderAddress),
      status: Value(status),
      omittedContentIdsJson: Value(omittedContentIdsJson),
      parentIntentId: parentIntentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentIntentId),
      attemptCount: Value(attemptCount),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredEmailSendIntent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredEmailSendIntent(
      localId: serializer.fromJson<String>(json['localId']),
      ownerUserId: serializer.fromJson<String>(json['ownerUserId']),
      followUpLocalId: serializer.fromJson<String>(json['followUpLocalId']),
      connectionId: serializer.fromJson<String?>(json['connectionId']),
      senderAddress: serializer.fromJson<String?>(json['senderAddress']),
      status: serializer.fromJson<String>(json['status']),
      omittedContentIdsJson: serializer.fromJson<String>(
        json['omittedContentIdsJson'],
      ),
      parentIntentId: serializer.fromJson<String?>(json['parentIntentId']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<String>(localId),
      'ownerUserId': serializer.toJson<String>(ownerUserId),
      'followUpLocalId': serializer.toJson<String>(followUpLocalId),
      'connectionId': serializer.toJson<String?>(connectionId),
      'senderAddress': serializer.toJson<String?>(senderAddress),
      'status': serializer.toJson<String>(status),
      'omittedContentIdsJson': serializer.toJson<String>(omittedContentIdsJson),
      'parentIntentId': serializer.toJson<String?>(parentIntentId),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'errorCode': serializer.toJson<String?>(errorCode),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredEmailSendIntent copyWith({
    String? localId,
    String? ownerUserId,
    String? followUpLocalId,
    Value<String?> connectionId = const Value.absent(),
    Value<String?> senderAddress = const Value.absent(),
    String? status,
    String? omittedContentIdsJson,
    Value<String?> parentIntentId = const Value.absent(),
    int? attemptCount,
    Value<String?> errorCode = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StoredEmailSendIntent(
    localId: localId ?? this.localId,
    ownerUserId: ownerUserId ?? this.ownerUserId,
    followUpLocalId: followUpLocalId ?? this.followUpLocalId,
    connectionId: connectionId.present ? connectionId.value : this.connectionId,
    senderAddress: senderAddress.present
        ? senderAddress.value
        : this.senderAddress,
    status: status ?? this.status,
    omittedContentIdsJson: omittedContentIdsJson ?? this.omittedContentIdsJson,
    parentIntentId: parentIntentId.present
        ? parentIntentId.value
        : this.parentIntentId,
    attemptCount: attemptCount ?? this.attemptCount,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredEmailSendIntent copyWithCompanion(LocalEmailSendIntentsCompanion data) {
    return StoredEmailSendIntent(
      localId: data.localId.present ? data.localId.value : this.localId,
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      followUpLocalId: data.followUpLocalId.present
          ? data.followUpLocalId.value
          : this.followUpLocalId,
      connectionId: data.connectionId.present
          ? data.connectionId.value
          : this.connectionId,
      senderAddress: data.senderAddress.present
          ? data.senderAddress.value
          : this.senderAddress,
      status: data.status.present ? data.status.value : this.status,
      omittedContentIdsJson: data.omittedContentIdsJson.present
          ? data.omittedContentIdsJson.value
          : this.omittedContentIdsJson,
      parentIntentId: data.parentIntentId.present
          ? data.parentIntentId.value
          : this.parentIntentId,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredEmailSendIntent(')
          ..write('localId: $localId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('followUpLocalId: $followUpLocalId, ')
          ..write('connectionId: $connectionId, ')
          ..write('senderAddress: $senderAddress, ')
          ..write('status: $status, ')
          ..write('omittedContentIdsJson: $omittedContentIdsJson, ')
          ..write('parentIntentId: $parentIntentId, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('errorCode: $errorCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localId,
    ownerUserId,
    followUpLocalId,
    connectionId,
    senderAddress,
    status,
    omittedContentIdsJson,
    parentIntentId,
    attemptCount,
    errorCode,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredEmailSendIntent &&
          other.localId == this.localId &&
          other.ownerUserId == this.ownerUserId &&
          other.followUpLocalId == this.followUpLocalId &&
          other.connectionId == this.connectionId &&
          other.senderAddress == this.senderAddress &&
          other.status == this.status &&
          other.omittedContentIdsJson == this.omittedContentIdsJson &&
          other.parentIntentId == this.parentIntentId &&
          other.attemptCount == this.attemptCount &&
          other.errorCode == this.errorCode &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalEmailSendIntentsCompanion
    extends UpdateCompanion<StoredEmailSendIntent> {
  final Value<String> localId;
  final Value<String> ownerUserId;
  final Value<String> followUpLocalId;
  final Value<String?> connectionId;
  final Value<String?> senderAddress;
  final Value<String> status;
  final Value<String> omittedContentIdsJson;
  final Value<String?> parentIntentId;
  final Value<int> attemptCount;
  final Value<String?> errorCode;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalEmailSendIntentsCompanion({
    this.localId = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.followUpLocalId = const Value.absent(),
    this.connectionId = const Value.absent(),
    this.senderAddress = const Value.absent(),
    this.status = const Value.absent(),
    this.omittedContentIdsJson = const Value.absent(),
    this.parentIntentId = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalEmailSendIntentsCompanion.insert({
    required String localId,
    required String ownerUserId,
    required String followUpLocalId,
    this.connectionId = const Value.absent(),
    this.senderAddress = const Value.absent(),
    this.status = const Value.absent(),
    this.omittedContentIdsJson = const Value.absent(),
    this.parentIntentId = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.errorCode = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : localId = Value(localId),
       ownerUserId = Value(ownerUserId),
       followUpLocalId = Value(followUpLocalId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<StoredEmailSendIntent> custom({
    Expression<String>? localId,
    Expression<String>? ownerUserId,
    Expression<String>? followUpLocalId,
    Expression<String>? connectionId,
    Expression<String>? senderAddress,
    Expression<String>? status,
    Expression<String>? omittedContentIdsJson,
    Expression<String>? parentIntentId,
    Expression<int>? attemptCount,
    Expression<String>? errorCode,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (followUpLocalId != null) 'follow_up_local_id': followUpLocalId,
      if (connectionId != null) 'connection_id': connectionId,
      if (senderAddress != null) 'sender_address': senderAddress,
      if (status != null) 'status': status,
      if (omittedContentIdsJson != null)
        'omitted_content_ids_json': omittedContentIdsJson,
      if (parentIntentId != null) 'parent_intent_id': parentIntentId,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (errorCode != null) 'error_code': errorCode,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalEmailSendIntentsCompanion copyWith({
    Value<String>? localId,
    Value<String>? ownerUserId,
    Value<String>? followUpLocalId,
    Value<String?>? connectionId,
    Value<String?>? senderAddress,
    Value<String>? status,
    Value<String>? omittedContentIdsJson,
    Value<String?>? parentIntentId,
    Value<int>? attemptCount,
    Value<String?>? errorCode,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalEmailSendIntentsCompanion(
      localId: localId ?? this.localId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      followUpLocalId: followUpLocalId ?? this.followUpLocalId,
      connectionId: connectionId ?? this.connectionId,
      senderAddress: senderAddress ?? this.senderAddress,
      status: status ?? this.status,
      omittedContentIdsJson:
          omittedContentIdsJson ?? this.omittedContentIdsJson,
      parentIntentId: parentIntentId ?? this.parentIntentId,
      attemptCount: attemptCount ?? this.attemptCount,
      errorCode: errorCode ?? this.errorCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (followUpLocalId.present) {
      map['follow_up_local_id'] = Variable<String>(followUpLocalId.value);
    }
    if (connectionId.present) {
      map['connection_id'] = Variable<String>(connectionId.value);
    }
    if (senderAddress.present) {
      map['sender_address'] = Variable<String>(senderAddress.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (omittedContentIdsJson.present) {
      map['omitted_content_ids_json'] = Variable<String>(
        omittedContentIdsJson.value,
      );
    }
    if (parentIntentId.present) {
      map['parent_intent_id'] = Variable<String>(parentIntentId.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalEmailSendIntentsCompanion(')
          ..write('localId: $localId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('followUpLocalId: $followUpLocalId, ')
          ..write('connectionId: $connectionId, ')
          ..write('senderAddress: $senderAddress, ')
          ..write('status: $status, ')
          ..write('omittedContentIdsJson: $omittedContentIdsJson, ')
          ..write('parentIntentId: $parentIntentId, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('errorCode: $errorCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalLeadMediaTable extends LocalLeadMedia
    with TableInfo<$LocalLeadMediaTable, StoredLeadMedia> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalLeadMediaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
    'local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _leadLocalIdMeta = const VerificationMeta(
    'leadLocalId',
  );
  @override
  late final GeneratedColumn<String> leadLocalId = GeneratedColumn<String>(
    'lead_local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_leads (local_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _mediaTypeMeta = const VerificationMeta(
    'mediaType',
  );
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
    'media_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uploadStateMeta = const VerificationMeta(
    'uploadState',
  );
  @override
  late final GeneratedColumn<String> uploadState = GeneratedColumn<String>(
    'upload_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    localId,
    leadLocalId,
    mediaType,
    localPath,
    durationSeconds,
    uploadState,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_lead_media';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredLeadMedia> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('lead_local_id')) {
      context.handle(
        _leadLocalIdMeta,
        leadLocalId.isAcceptableOrUnknown(
          data['lead_local_id']!,
          _leadLocalIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_leadLocalIdMeta);
    }
    if (data.containsKey('media_type')) {
      context.handle(
        _mediaTypeMeta,
        mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('upload_state')) {
      context.handle(
        _uploadStateMeta,
        uploadState.isAcceptableOrUnknown(
          data['upload_state']!,
          _uploadStateMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  StoredLeadMedia map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredLeadMedia(
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_id'],
      )!,
      leadLocalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lead_local_id'],
      )!,
      mediaType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_type'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      ),
      uploadState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}upload_state'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LocalLeadMediaTable createAlias(String alias) {
    return $LocalLeadMediaTable(attachedDatabase, alias);
  }
}

class StoredLeadMedia extends DataClass implements Insertable<StoredLeadMedia> {
  final String localId;
  final String leadLocalId;
  final String mediaType;
  final String localPath;
  final int? durationSeconds;
  final String uploadState;
  final DateTime createdAt;
  const StoredLeadMedia({
    required this.localId,
    required this.leadLocalId,
    required this.mediaType,
    required this.localPath,
    this.durationSeconds,
    required this.uploadState,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<String>(localId);
    map['lead_local_id'] = Variable<String>(leadLocalId);
    map['media_type'] = Variable<String>(mediaType);
    map['local_path'] = Variable<String>(localPath);
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    map['upload_state'] = Variable<String>(uploadState);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalLeadMediaCompanion toCompanion(bool nullToAbsent) {
    return LocalLeadMediaCompanion(
      localId: Value(localId),
      leadLocalId: Value(leadLocalId),
      mediaType: Value(mediaType),
      localPath: Value(localPath),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      uploadState: Value(uploadState),
      createdAt: Value(createdAt),
    );
  }

  factory StoredLeadMedia.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredLeadMedia(
      localId: serializer.fromJson<String>(json['localId']),
      leadLocalId: serializer.fromJson<String>(json['leadLocalId']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      localPath: serializer.fromJson<String>(json['localPath']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      uploadState: serializer.fromJson<String>(json['uploadState']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<String>(localId),
      'leadLocalId': serializer.toJson<String>(leadLocalId),
      'mediaType': serializer.toJson<String>(mediaType),
      'localPath': serializer.toJson<String>(localPath),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'uploadState': serializer.toJson<String>(uploadState),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  StoredLeadMedia copyWith({
    String? localId,
    String? leadLocalId,
    String? mediaType,
    String? localPath,
    Value<int?> durationSeconds = const Value.absent(),
    String? uploadState,
    DateTime? createdAt,
  }) => StoredLeadMedia(
    localId: localId ?? this.localId,
    leadLocalId: leadLocalId ?? this.leadLocalId,
    mediaType: mediaType ?? this.mediaType,
    localPath: localPath ?? this.localPath,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    uploadState: uploadState ?? this.uploadState,
    createdAt: createdAt ?? this.createdAt,
  );
  StoredLeadMedia copyWithCompanion(LocalLeadMediaCompanion data) {
    return StoredLeadMedia(
      localId: data.localId.present ? data.localId.value : this.localId,
      leadLocalId: data.leadLocalId.present
          ? data.leadLocalId.value
          : this.leadLocalId,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      uploadState: data.uploadState.present
          ? data.uploadState.value
          : this.uploadState,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredLeadMedia(')
          ..write('localId: $localId, ')
          ..write('leadLocalId: $leadLocalId, ')
          ..write('mediaType: $mediaType, ')
          ..write('localPath: $localPath, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('uploadState: $uploadState, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localId,
    leadLocalId,
    mediaType,
    localPath,
    durationSeconds,
    uploadState,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredLeadMedia &&
          other.localId == this.localId &&
          other.leadLocalId == this.leadLocalId &&
          other.mediaType == this.mediaType &&
          other.localPath == this.localPath &&
          other.durationSeconds == this.durationSeconds &&
          other.uploadState == this.uploadState &&
          other.createdAt == this.createdAt);
}

class LocalLeadMediaCompanion extends UpdateCompanion<StoredLeadMedia> {
  final Value<String> localId;
  final Value<String> leadLocalId;
  final Value<String> mediaType;
  final Value<String> localPath;
  final Value<int?> durationSeconds;
  final Value<String> uploadState;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalLeadMediaCompanion({
    this.localId = const Value.absent(),
    this.leadLocalId = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.localPath = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.uploadState = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalLeadMediaCompanion.insert({
    required String localId,
    required String leadLocalId,
    required String mediaType,
    required String localPath,
    this.durationSeconds = const Value.absent(),
    this.uploadState = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : localId = Value(localId),
       leadLocalId = Value(leadLocalId),
       mediaType = Value(mediaType),
       localPath = Value(localPath),
       createdAt = Value(createdAt);
  static Insertable<StoredLeadMedia> custom({
    Expression<String>? localId,
    Expression<String>? leadLocalId,
    Expression<String>? mediaType,
    Expression<String>? localPath,
    Expression<int>? durationSeconds,
    Expression<String>? uploadState,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (leadLocalId != null) 'lead_local_id': leadLocalId,
      if (mediaType != null) 'media_type': mediaType,
      if (localPath != null) 'local_path': localPath,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (uploadState != null) 'upload_state': uploadState,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalLeadMediaCompanion copyWith({
    Value<String>? localId,
    Value<String>? leadLocalId,
    Value<String>? mediaType,
    Value<String>? localPath,
    Value<int?>? durationSeconds,
    Value<String>? uploadState,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalLeadMediaCompanion(
      localId: localId ?? this.localId,
      leadLocalId: leadLocalId ?? this.leadLocalId,
      mediaType: mediaType ?? this.mediaType,
      localPath: localPath ?? this.localPath,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      uploadState: uploadState ?? this.uploadState,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (leadLocalId.present) {
      map['lead_local_id'] = Variable<String>(leadLocalId.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (uploadState.present) {
      map['upload_state'] = Variable<String>(uploadState.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalLeadMediaCompanion(')
          ..write('localId: $localId, ')
          ..write('leadLocalId: $leadLocalId, ')
          ..write('mediaType: $mediaType, ')
          ..write('localPath: $localPath, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('uploadState: $uploadState, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalPreferencesTable extends LocalPreferences
    with TableInfo<$LocalPreferencesTable, StoredPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  StoredPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredPreference(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalPreferencesTable createAlias(String alias) {
    return $LocalPreferencesTable(attachedDatabase, alias);
  }
}

class StoredPreference extends DataClass
    implements Insertable<StoredPreference> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const StoredPreference({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalPreferencesCompanion toCompanion(bool nullToAbsent) {
    return LocalPreferencesCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredPreference(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredPreference copyWith({
    String? key,
    String? value,
    DateTime? updatedAt,
  }) => StoredPreference(
    key: key ?? this.key,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredPreference copyWithCompanion(LocalPreferencesCompanion data) {
    return StoredPreference(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredPreference(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredPreference &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class LocalPreferencesCompanion extends UpdateCompanion<StoredPreference> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalPreferencesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalPreferencesCompanion.insert({
    required String key,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<StoredPreference> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalPreferencesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalPreferencesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalPreferencesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalUserPreferencesTable extends LocalUserPreferences
    with TableInfo<$LocalUserPreferencesTable, StoredUserPreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalUserPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [ownerUserId, key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_user_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredUserPreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerUserIdMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerUserId, key};
  @override
  StoredUserPreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredUserPreference(
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalUserPreferencesTable createAlias(String alias) {
    return $LocalUserPreferencesTable(attachedDatabase, alias);
  }
}

class StoredUserPreference extends DataClass
    implements Insertable<StoredUserPreference> {
  final String ownerUserId;
  final String key;
  final String value;
  final DateTime updatedAt;
  const StoredUserPreference({
    required this.ownerUserId,
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_user_id'] = Variable<String>(ownerUserId);
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalUserPreferencesCompanion toCompanion(bool nullToAbsent) {
    return LocalUserPreferencesCompanion(
      ownerUserId: Value(ownerUserId),
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredUserPreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredUserPreference(
      ownerUserId: serializer.fromJson<String>(json['ownerUserId']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerUserId': serializer.toJson<String>(ownerUserId),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredUserPreference copyWith({
    String? ownerUserId,
    String? key,
    String? value,
    DateTime? updatedAt,
  }) => StoredUserPreference(
    ownerUserId: ownerUserId ?? this.ownerUserId,
    key: key ?? this.key,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredUserPreference copyWithCompanion(LocalUserPreferencesCompanion data) {
    return StoredUserPreference(
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredUserPreference(')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(ownerUserId, key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredUserPreference &&
          other.ownerUserId == this.ownerUserId &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class LocalUserPreferencesCompanion
    extends UpdateCompanion<StoredUserPreference> {
  final Value<String> ownerUserId;
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalUserPreferencesCompanion({
    this.ownerUserId = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalUserPreferencesCompanion.insert({
    required String ownerUserId,
    required String key,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : ownerUserId = Value(ownerUserId),
       key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<StoredUserPreference> custom({
    Expression<String>? ownerUserId,
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalUserPreferencesCompanion copyWith({
    Value<String>? ownerUserId,
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalUserPreferencesCompanion(
      ownerUserId: ownerUserId ?? this.ownerUserId,
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalUserPreferencesCompanion(')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOperationsTable extends SyncOperations
    with TableInfo<$SyncOperationsTable, StoredSyncOperation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOperationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    operationId,
    ownerUserId,
    entityType,
    entityId,
    action,
    payloadJson,
    idempotencyKey,
    status,
    attemptCount,
    nextAttemptAt,
    lastError,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_operations';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredSyncOperation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerUserIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {operationId};
  @override
  StoredSyncOperation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredSyncOperation(
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SyncOperationsTable createAlias(String alias) {
    return $SyncOperationsTable(attachedDatabase, alias);
  }
}

class StoredSyncOperation extends DataClass
    implements Insertable<StoredSyncOperation> {
  final String operationId;
  final String ownerUserId;
  final String entityType;
  final String entityId;
  final String action;
  final String payloadJson;
  final String idempotencyKey;
  final String status;
  final int attemptCount;
  final DateTime? nextAttemptAt;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  const StoredSyncOperation({
    required this.operationId,
    required this.ownerUserId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.payloadJson,
    required this.idempotencyKey,
    required this.status,
    required this.attemptCount,
    this.nextAttemptAt,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['owner_user_id'] = Variable<String>(ownerUserId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['action'] = Variable<String>(action);
    map['payload_json'] = Variable<String>(payloadJson);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['status'] = Variable<String>(status);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SyncOperationsCompanion toCompanion(bool nullToAbsent) {
    return SyncOperationsCompanion(
      operationId: Value(operationId),
      ownerUserId: Value(ownerUserId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      action: Value(action),
      payloadJson: Value(payloadJson),
      idempotencyKey: Value(idempotencyKey),
      status: Value(status),
      attemptCount: Value(attemptCount),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredSyncOperation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredSyncOperation(
      operationId: serializer.fromJson<String>(json['operationId']),
      ownerUserId: serializer.fromJson<String>(json['ownerUserId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      action: serializer.fromJson<String>(json['action']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      status: serializer.fromJson<String>(json['status']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'ownerUserId': serializer.toJson<String>(ownerUserId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'action': serializer.toJson<String>(action),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'status': serializer.toJson<String>(status),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredSyncOperation copyWith({
    String? operationId,
    String? ownerUserId,
    String? entityType,
    String? entityId,
    String? action,
    String? payloadJson,
    String? idempotencyKey,
    String? status,
    int? attemptCount,
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StoredSyncOperation(
    operationId: operationId ?? this.operationId,
    ownerUserId: ownerUserId ?? this.ownerUserId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    action: action ?? this.action,
    payloadJson: payloadJson ?? this.payloadJson,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    status: status ?? this.status,
    attemptCount: attemptCount ?? this.attemptCount,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredSyncOperation copyWithCompanion(SyncOperationsCompanion data) {
    return StoredSyncOperation(
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      action: data.action.present ? data.action.value : this.action,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      status: data.status.present ? data.status.value : this.status,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredSyncOperation(')
          ..write('operationId: $operationId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('action: $action, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    operationId,
    ownerUserId,
    entityType,
    entityId,
    action,
    payloadJson,
    idempotencyKey,
    status,
    attemptCount,
    nextAttemptAt,
    lastError,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredSyncOperation &&
          other.operationId == this.operationId &&
          other.ownerUserId == this.ownerUserId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.action == this.action &&
          other.payloadJson == this.payloadJson &&
          other.idempotencyKey == this.idempotencyKey &&
          other.status == this.status &&
          other.attemptCount == this.attemptCount &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SyncOperationsCompanion extends UpdateCompanion<StoredSyncOperation> {
  final Value<String> operationId;
  final Value<String> ownerUserId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> action;
  final Value<String> payloadJson;
  final Value<String> idempotencyKey;
  final Value<String> status;
  final Value<int> attemptCount;
  final Value<DateTime?> nextAttemptAt;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SyncOperationsCompanion({
    this.operationId = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.action = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOperationsCompanion.insert({
    required String operationId,
    required String ownerUserId,
    required String entityType,
    required String entityId,
    required String action,
    required String payloadJson,
    required String idempotencyKey,
    this.status = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : operationId = Value(operationId),
       ownerUserId = Value(ownerUserId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       action = Value(action),
       payloadJson = Value(payloadJson),
       idempotencyKey = Value(idempotencyKey),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<StoredSyncOperation> custom({
    Expression<String>? operationId,
    Expression<String>? ownerUserId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? action,
    Expression<String>? payloadJson,
    Expression<String>? idempotencyKey,
    Expression<String>? status,
    Expression<int>? attemptCount,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (action != null) 'action': action,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (status != null) 'status': status,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOperationsCompanion copyWith({
    Value<String>? operationId,
    Value<String>? ownerUserId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? action,
    Value<String>? payloadJson,
    Value<String>? idempotencyKey,
    Value<String>? status,
    Value<int>? attemptCount,
    Value<DateTime?>? nextAttemptAt,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SyncOperationsCompanion(
      operationId: operationId ?? this.operationId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      action: action ?? this.action,
      payloadJson: payloadJson ?? this.payloadJson,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOperationsCompanion(')
          ..write('operationId: $operationId, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('action: $action, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('status: $status, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalProfilesTable localProfiles = $LocalProfilesTable(this);
  late final $LocalEventsTable localEvents = $LocalEventsTable(this);
  late final $LocalContentFilesTable localContentFiles =
      $LocalContentFilesTable(this);
  late final $LocalEmailTemplatesTable localEmailTemplates =
      $LocalEmailTemplatesTable(this);
  late final $LocalEmailConnectionsTable localEmailConnections =
      $LocalEmailConnectionsTable(this);
  late final $LocalLeadsTable localLeads = $LocalLeadsTable(this);
  late final $LocalEmailFollowUpsTable localEmailFollowUps =
      $LocalEmailFollowUpsTable(this);
  late final $LocalEmailSendIntentsTable localEmailSendIntents =
      $LocalEmailSendIntentsTable(this);
  late final $LocalLeadMediaTable localLeadMedia = $LocalLeadMediaTable(this);
  late final $LocalPreferencesTable localPreferences = $LocalPreferencesTable(
    this,
  );
  late final $LocalUserPreferencesTable localUserPreferences =
      $LocalUserPreferencesTable(this);
  late final $SyncOperationsTable syncOperations = $SyncOperationsTable(this);
  late final Index profileOwnerIdx = Index(
    'profile_owner_idx',
    'CREATE UNIQUE INDEX profile_owner_idx ON local_profiles (owner_user_id)',
  );
  late final Index eventOwnerIdx = Index(
    'event_owner_idx',
    'CREATE INDEX event_owner_idx ON local_events (owner_user_id)',
  );
  late final Index contentOwnerIdx = Index(
    'content_owner_idx',
    'CREATE INDEX content_owner_idx ON local_content_files (owner_user_id)',
  );
  late final Index emailFollowUpOwnerIdx = Index(
    'email_follow_up_owner_idx',
    'CREATE INDEX email_follow_up_owner_idx ON local_email_follow_ups (owner_user_id, prepared_at)',
  );
  late final Index emailIntentOwnerStatusIdx = Index(
    'email_intent_owner_status_idx',
    'CREATE INDEX email_intent_owner_status_idx ON local_email_send_intents (owner_user_id, status)',
  );
  late final Index leadEventIdx = Index(
    'lead_event_idx',
    'CREATE INDEX lead_event_idx ON local_leads (event_local_id)',
  );
  late final Index leadCapturedIdx = Index(
    'lead_captured_idx',
    'CREATE INDEX lead_captured_idx ON local_leads (captured_at)',
  );
  late final Index leadOwnerIdx = Index(
    'lead_owner_idx',
    'CREATE INDEX lead_owner_idx ON local_leads (owner_user_id)',
  );
  late final Index mediaLeadIdx = Index(
    'media_lead_idx',
    'CREATE INDEX media_lead_idx ON local_lead_media (lead_local_id)',
  );
  late final Index syncOwnerStatusIdx = Index(
    'sync_owner_status_idx',
    'CREATE INDEX sync_owner_status_idx ON sync_operations (owner_user_id, status)',
  );
  late final ProfilePreferencesDao profilePreferencesDao =
      ProfilePreferencesDao(this as AppDatabase);
  late final EventDao eventDao = EventDao(this as AppDatabase);
  late final ContentDao contentDao = ContentDao(this as AppDatabase);
  late final EmailTemplateDao emailTemplateDao = EmailTemplateDao(
    this as AppDatabase,
  );
  late final EmailDeliveryDao emailDeliveryDao = EmailDeliveryDao(
    this as AppDatabase,
  );
  late final LeadDao leadDao = LeadDao(this as AppDatabase);
  late final SyncDao syncDao = SyncDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localProfiles,
    localEvents,
    localContentFiles,
    localEmailTemplates,
    localEmailConnections,
    localLeads,
    localEmailFollowUps,
    localEmailSendIntents,
    localLeadMedia,
    localPreferences,
    localUserPreferences,
    syncOperations,
    profileOwnerIdx,
    eventOwnerIdx,
    contentOwnerIdx,
    emailFollowUpOwnerIdx,
    emailIntentOwnerStatusIdx,
    leadEventIdx,
    leadCapturedIdx,
    leadOwnerIdx,
    mediaLeadIdx,
    syncOwnerStatusIdx,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_events',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_leads', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_leads',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_lead_media', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$LocalProfilesTableCreateCompanionBuilder =
    LocalProfilesCompanion Function({
      required String localId,
      Value<String?> ownerUserId,
      required String name,
      required String company,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<String> syncState,
      Value<int> rowid,
    });
typedef $$LocalProfilesTableUpdateCompanionBuilder =
    LocalProfilesCompanion Function({
      Value<String> localId,
      Value<String?> ownerUserId,
      Value<String> name,
      Value<String> company,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String> syncState,
      Value<int> rowid,
    });

class $$LocalProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalProfilesTable> {
  $$LocalProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get company => $composableBuilder(
    column: $table.company,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalProfilesTable> {
  $$LocalProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get company => $composableBuilder(
    column: $table.company,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalProfilesTable> {
  $$LocalProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get company =>
      $composableBuilder(column: $table.company, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);
}

class $$LocalProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalProfilesTable,
          StoredProfile,
          $$LocalProfilesTableFilterComposer,
          $$LocalProfilesTableOrderingComposer,
          $$LocalProfilesTableAnnotationComposer,
          $$LocalProfilesTableCreateCompanionBuilder,
          $$LocalProfilesTableUpdateCompanionBuilder,
          (
            StoredProfile,
            BaseReferences<_$AppDatabase, $LocalProfilesTable, StoredProfile>,
          ),
          StoredProfile,
          PrefetchHooks Function()
        > {
  $$LocalProfilesTableTableManager(_$AppDatabase db, $LocalProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> localId = const Value.absent(),
                Value<String?> ownerUserId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> company = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProfilesCompanion(
                localId: localId,
                ownerUserId: ownerUserId,
                name: name,
                company: company,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncState: syncState,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localId,
                Value<String?> ownerUserId = const Value.absent(),
                required String name,
                required String company,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<String> syncState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProfilesCompanion.insert(
                localId: localId,
                ownerUserId: ownerUserId,
                name: name,
                company: company,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncState: syncState,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalProfilesTable, StoredProfile>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalProfilesTable,
                    StoredProfile
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalProfilesTable,
      StoredProfile,
      $$LocalProfilesTableFilterComposer,
      $$LocalProfilesTableOrderingComposer,
      $$LocalProfilesTableAnnotationComposer,
      $$LocalProfilesTableCreateCompanionBuilder,
      $$LocalProfilesTableUpdateCompanionBuilder,
      (
        StoredProfile,
        BaseReferences<_$AppDatabase, $LocalProfilesTable, StoredProfile>,
      ),
      StoredProfile,
      PrefetchHooks Function()
    >;
typedef $$LocalEventsTableCreateCompanionBuilder =
    LocalEventsCompanion Function({
      required String localId,
      Value<String?> ownerUserId,
      Value<String?> commercialCode,
      required String name,
      required DateTime startsOn,
      required DateTime endsOn,
      Value<bool> active,
      Value<bool> deleted,
      Value<String> contentFileIdsJson,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<String> syncState,
      Value<int?> remoteRevision,
      Value<int> rowid,
    });
typedef $$LocalEventsTableUpdateCompanionBuilder =
    LocalEventsCompanion Function({
      Value<String> localId,
      Value<String?> ownerUserId,
      Value<String?> commercialCode,
      Value<String> name,
      Value<DateTime> startsOn,
      Value<DateTime> endsOn,
      Value<bool> active,
      Value<bool> deleted,
      Value<String> contentFileIdsJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String> syncState,
      Value<int?> remoteRevision,
      Value<int> rowid,
    });

final class $$LocalEventsTableReferences
    extends BaseReferences<_$AppDatabase, $LocalEventsTable, StoredEvent> {
  $$LocalEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LocalLeadsTable, List<StoredLead>>
  _localLeadsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.localLeads,
    aliasName: 'local_events__local_id__local_leads__event_local_id',
  );

  $$LocalLeadsTableProcessedTableManager get localLeadsRefs {
    final manager = $$LocalLeadsTableTableManager($_db, $_db.localLeads).filter(
      (f) =>
          f.eventLocalId.localId.sqlEquals($_itemColumn<String>('local_id')!),
    );

    final cache = $_typedResult.readTableOrNull(_localLeadsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalEventsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalEventsTable> {
  $$LocalEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commercialCode => $composableBuilder(
    column: $table.commercialCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startsOn => $composableBuilder(
    column: $table.startsOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endsOn => $composableBuilder(
    column: $table.endsOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentFileIdsJson => $composableBuilder(
    column: $table.contentFileIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteRevision => $composableBuilder(
    column: $table.remoteRevision,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> localLeadsRefs(
    Expression<bool> Function($$LocalLeadsTableFilterComposer f) f,
  ) {
    final $$LocalLeadsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.localId,
      referencedTable: $db.localLeads,
      getReferencedColumn: (t) => t.eventLocalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalLeadsTableFilterComposer(
            $db: $db,
            $table: $db.localLeads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalEventsTable> {
  $$LocalEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commercialCode => $composableBuilder(
    column: $table.commercialCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startsOn => $composableBuilder(
    column: $table.startsOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endsOn => $composableBuilder(
    column: $table.endsOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentFileIdsJson => $composableBuilder(
    column: $table.contentFileIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteRevision => $composableBuilder(
    column: $table.remoteRevision,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalEventsTable> {
  $$LocalEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get commercialCode => $composableBuilder(
    column: $table.commercialCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get startsOn =>
      $composableBuilder(column: $table.startsOn, builder: (column) => column);

  GeneratedColumn<DateTime> get endsOn =>
      $composableBuilder(column: $table.endsOn, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get contentFileIdsJson => $composableBuilder(
    column: $table.contentFileIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<int> get remoteRevision => $composableBuilder(
    column: $table.remoteRevision,
    builder: (column) => column,
  );

  Expression<T> localLeadsRefs<T extends Object>(
    Expression<T> Function($$LocalLeadsTableAnnotationComposer a) f,
  ) {
    final $$LocalLeadsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.localId,
      referencedTable: $db.localLeads,
      getReferencedColumn: (t) => t.eventLocalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalLeadsTableAnnotationComposer(
            $db: $db,
            $table: $db.localLeads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalEventsTable,
          StoredEvent,
          $$LocalEventsTableFilterComposer,
          $$LocalEventsTableOrderingComposer,
          $$LocalEventsTableAnnotationComposer,
          $$LocalEventsTableCreateCompanionBuilder,
          $$LocalEventsTableUpdateCompanionBuilder,
          (StoredEvent, $$LocalEventsTableReferences),
          StoredEvent,
          PrefetchHooks Function({bool localLeadsRefs})
        > {
  $$LocalEventsTableTableManager(_$AppDatabase db, $LocalEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> localId = const Value.absent(),
                Value<String?> ownerUserId = const Value.absent(),
                Value<String?> commercialCode = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> startsOn = const Value.absent(),
                Value<DateTime> endsOn = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String> contentFileIdsJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int?> remoteRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalEventsCompanion(
                localId: localId,
                ownerUserId: ownerUserId,
                commercialCode: commercialCode,
                name: name,
                startsOn: startsOn,
                endsOn: endsOn,
                active: active,
                deleted: deleted,
                contentFileIdsJson: contentFileIdsJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncState: syncState,
                remoteRevision: remoteRevision,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localId,
                Value<String?> ownerUserId = const Value.absent(),
                Value<String?> commercialCode = const Value.absent(),
                required String name,
                required DateTime startsOn,
                required DateTime endsOn,
                Value<bool> active = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String> contentFileIdsJson = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<String> syncState = const Value.absent(),
                Value<int?> remoteRevision = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalEventsCompanion.insert(
                localId: localId,
                ownerUserId: ownerUserId,
                commercialCode: commercialCode,
                name: name,
                startsOn: startsOn,
                endsOn: endsOn,
                active: active,
                deleted: deleted,
                contentFileIdsJson: contentFileIdsJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                syncState: syncState,
                remoteRevision: remoteRevision,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalEventsTable, StoredEvent>(table),
                  $$LocalEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({localLeadsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (localLeadsRefs) db.localLeads],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (localLeadsRefs)
                    await $_getPrefetchedData<
                      StoredEvent,
                      $LocalEventsTable,
                      StoredLead
                    >(
                      currentTable: table,
                      referencedTable: $$LocalEventsTableReferences
                          ._localLeadsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LocalEventsTableReferences(
                            db,
                            table,
                            p0,
                          ).localLeadsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.eventLocalId == item.localId,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LocalEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalEventsTable,
      StoredEvent,
      $$LocalEventsTableFilterComposer,
      $$LocalEventsTableOrderingComposer,
      $$LocalEventsTableAnnotationComposer,
      $$LocalEventsTableCreateCompanionBuilder,
      $$LocalEventsTableUpdateCompanionBuilder,
      (StoredEvent, $$LocalEventsTableReferences),
      StoredEvent,
      PrefetchHooks Function({bool localLeadsRefs})
    >;
typedef $$LocalContentFilesTableCreateCompanionBuilder =
    LocalContentFilesCompanion Function({
      required String localId,
      required String ownerUserId,
      required String displayName,
      required String fileName,
      required int byteSize,
      Value<String?> localPath,
      Value<bool> allEvents,
      Value<String> eventIdsJson,
      Value<bool> deleted,
      Value<String> uploadState,
      Value<String> syncState,
      Value<int?> remoteRevision,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LocalContentFilesTableUpdateCompanionBuilder =
    LocalContentFilesCompanion Function({
      Value<String> localId,
      Value<String> ownerUserId,
      Value<String> displayName,
      Value<String> fileName,
      Value<int> byteSize,
      Value<String?> localPath,
      Value<bool> allEvents,
      Value<String> eventIdsJson,
      Value<bool> deleted,
      Value<String> uploadState,
      Value<String> syncState,
      Value<int?> remoteRevision,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LocalContentFilesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalContentFilesTable> {
  $$LocalContentFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allEvents => $composableBuilder(
    column: $table.allEvents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventIdsJson => $composableBuilder(
    column: $table.eventIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteRevision => $composableBuilder(
    column: $table.remoteRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalContentFilesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalContentFilesTable> {
  $$LocalContentFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allEvents => $composableBuilder(
    column: $table.allEvents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventIdsJson => $composableBuilder(
    column: $table.eventIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteRevision => $composableBuilder(
    column: $table.remoteRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalContentFilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalContentFilesTable> {
  $$LocalContentFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<bool> get allEvents =>
      $composableBuilder(column: $table.allEvents, builder: (column) => column);

  GeneratedColumn<String> get eventIdsJson => $composableBuilder(
    column: $table.eventIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<int> get remoteRevision => $composableBuilder(
    column: $table.remoteRevision,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalContentFilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalContentFilesTable,
          StoredContentFile,
          $$LocalContentFilesTableFilterComposer,
          $$LocalContentFilesTableOrderingComposer,
          $$LocalContentFilesTableAnnotationComposer,
          $$LocalContentFilesTableCreateCompanionBuilder,
          $$LocalContentFilesTableUpdateCompanionBuilder,
          (
            StoredContentFile,
            BaseReferences<
              _$AppDatabase,
              $LocalContentFilesTable,
              StoredContentFile
            >,
          ),
          StoredContentFile,
          PrefetchHooks Function()
        > {
  $$LocalContentFilesTableTableManager(
    _$AppDatabase db,
    $LocalContentFilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalContentFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalContentFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalContentFilesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> localId = const Value.absent(),
                Value<String> ownerUserId = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<bool> allEvents = const Value.absent(),
                Value<String> eventIdsJson = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String> uploadState = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int?> remoteRevision = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalContentFilesCompanion(
                localId: localId,
                ownerUserId: ownerUserId,
                displayName: displayName,
                fileName: fileName,
                byteSize: byteSize,
                localPath: localPath,
                allEvents: allEvents,
                eventIdsJson: eventIdsJson,
                deleted: deleted,
                uploadState: uploadState,
                syncState: syncState,
                remoteRevision: remoteRevision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localId,
                required String ownerUserId,
                required String displayName,
                required String fileName,
                required int byteSize,
                Value<String?> localPath = const Value.absent(),
                Value<bool> allEvents = const Value.absent(),
                Value<String> eventIdsJson = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String> uploadState = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int?> remoteRevision = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalContentFilesCompanion.insert(
                localId: localId,
                ownerUserId: ownerUserId,
                displayName: displayName,
                fileName: fileName,
                byteSize: byteSize,
                localPath: localPath,
                allEvents: allEvents,
                eventIdsJson: eventIdsJson,
                deleted: deleted,
                uploadState: uploadState,
                syncState: syncState,
                remoteRevision: remoteRevision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalContentFilesTable, StoredContentFile>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalContentFilesTable,
                    StoredContentFile
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalContentFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalContentFilesTable,
      StoredContentFile,
      $$LocalContentFilesTableFilterComposer,
      $$LocalContentFilesTableOrderingComposer,
      $$LocalContentFilesTableAnnotationComposer,
      $$LocalContentFilesTableCreateCompanionBuilder,
      $$LocalContentFilesTableUpdateCompanionBuilder,
      (
        StoredContentFile,
        BaseReferences<
          _$AppDatabase,
          $LocalContentFilesTable,
          StoredContentFile
        >,
      ),
      StoredContentFile,
      PrefetchHooks Function()
    >;
typedef $$LocalEmailTemplatesTableCreateCompanionBuilder =
    LocalEmailTemplatesCompanion Function({
      required String ownerUserId,
      required String originKind,
      required String languageCode,
      required String subject,
      required String body,
      required String signature,
      required DateTime updatedAt,
      Value<String> syncState,
      Value<int> rowid,
    });
typedef $$LocalEmailTemplatesTableUpdateCompanionBuilder =
    LocalEmailTemplatesCompanion Function({
      Value<String> ownerUserId,
      Value<String> originKind,
      Value<String> languageCode,
      Value<String> subject,
      Value<String> body,
      Value<String> signature,
      Value<DateTime> updatedAt,
      Value<String> syncState,
      Value<int> rowid,
    });

class $$LocalEmailTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalEmailTemplatesTable> {
  $$LocalEmailTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originKind => $composableBuilder(
    column: $table.originKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalEmailTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalEmailTemplatesTable> {
  $$LocalEmailTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originKind => $composableBuilder(
    column: $table.originKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalEmailTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalEmailTemplatesTable> {
  $$LocalEmailTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originKind => $composableBuilder(
    column: $table.originKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get signature =>
      $composableBuilder(column: $table.signature, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);
}

class $$LocalEmailTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalEmailTemplatesTable,
          StoredEmailTemplate,
          $$LocalEmailTemplatesTableFilterComposer,
          $$LocalEmailTemplatesTableOrderingComposer,
          $$LocalEmailTemplatesTableAnnotationComposer,
          $$LocalEmailTemplatesTableCreateCompanionBuilder,
          $$LocalEmailTemplatesTableUpdateCompanionBuilder,
          (
            StoredEmailTemplate,
            BaseReferences<
              _$AppDatabase,
              $LocalEmailTemplatesTable,
              StoredEmailTemplate
            >,
          ),
          StoredEmailTemplate,
          PrefetchHooks Function()
        > {
  $$LocalEmailTemplatesTableTableManager(
    _$AppDatabase db,
    $LocalEmailTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalEmailTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalEmailTemplatesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalEmailTemplatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> ownerUserId = const Value.absent(),
                Value<String> originKind = const Value.absent(),
                Value<String> languageCode = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> signature = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalEmailTemplatesCompanion(
                ownerUserId: ownerUserId,
                originKind: originKind,
                languageCode: languageCode,
                subject: subject,
                body: body,
                signature: signature,
                updatedAt: updatedAt,
                syncState: syncState,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerUserId,
                required String originKind,
                required String languageCode,
                required String subject,
                required String body,
                required String signature,
                required DateTime updatedAt,
                Value<String> syncState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalEmailTemplatesCompanion.insert(
                ownerUserId: ownerUserId,
                originKind: originKind,
                languageCode: languageCode,
                subject: subject,
                body: body,
                signature: signature,
                updatedAt: updatedAt,
                syncState: syncState,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalEmailTemplatesTable, StoredEmailTemplate>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalEmailTemplatesTable,
                    StoredEmailTemplate
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalEmailTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalEmailTemplatesTable,
      StoredEmailTemplate,
      $$LocalEmailTemplatesTableFilterComposer,
      $$LocalEmailTemplatesTableOrderingComposer,
      $$LocalEmailTemplatesTableAnnotationComposer,
      $$LocalEmailTemplatesTableCreateCompanionBuilder,
      $$LocalEmailTemplatesTableUpdateCompanionBuilder,
      (
        StoredEmailTemplate,
        BaseReferences<
          _$AppDatabase,
          $LocalEmailTemplatesTable,
          StoredEmailTemplate
        >,
      ),
      StoredEmailTemplate,
      PrefetchHooks Function()
    >;
typedef $$LocalEmailConnectionsTableCreateCompanionBuilder =
    LocalEmailConnectionsCompanion Function({
      required String ownerUserId,
      required String connectionId,
      required String provider,
      required String senderAddress,
      required String status,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LocalEmailConnectionsTableUpdateCompanionBuilder =
    LocalEmailConnectionsCompanion Function({
      Value<String> ownerUserId,
      Value<String> connectionId,
      Value<String> provider,
      Value<String> senderAddress,
      Value<String> status,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LocalEmailConnectionsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalEmailConnectionsTable> {
  $$LocalEmailConnectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get connectionId => $composableBuilder(
    column: $table.connectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderAddress => $composableBuilder(
    column: $table.senderAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalEmailConnectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalEmailConnectionsTable> {
  $$LocalEmailConnectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get connectionId => $composableBuilder(
    column: $table.connectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderAddress => $composableBuilder(
    column: $table.senderAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalEmailConnectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalEmailConnectionsTable> {
  $$LocalEmailConnectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get connectionId => $composableBuilder(
    column: $table.connectionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get senderAddress => $composableBuilder(
    column: $table.senderAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalEmailConnectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalEmailConnectionsTable,
          StoredEmailConnection,
          $$LocalEmailConnectionsTableFilterComposer,
          $$LocalEmailConnectionsTableOrderingComposer,
          $$LocalEmailConnectionsTableAnnotationComposer,
          $$LocalEmailConnectionsTableCreateCompanionBuilder,
          $$LocalEmailConnectionsTableUpdateCompanionBuilder,
          (
            StoredEmailConnection,
            BaseReferences<
              _$AppDatabase,
              $LocalEmailConnectionsTable,
              StoredEmailConnection
            >,
          ),
          StoredEmailConnection,
          PrefetchHooks Function()
        > {
  $$LocalEmailConnectionsTableTableManager(
    _$AppDatabase db,
    $LocalEmailConnectionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalEmailConnectionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalEmailConnectionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalEmailConnectionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> ownerUserId = const Value.absent(),
                Value<String> connectionId = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> senderAddress = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalEmailConnectionsCompanion(
                ownerUserId: ownerUserId,
                connectionId: connectionId,
                provider: provider,
                senderAddress: senderAddress,
                status: status,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerUserId,
                required String connectionId,
                required String provider,
                required String senderAddress,
                required String status,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalEmailConnectionsCompanion.insert(
                ownerUserId: ownerUserId,
                connectionId: connectionId,
                provider: provider,
                senderAddress: senderAddress,
                status: status,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LocalEmailConnectionsTable,
                    StoredEmailConnection
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalEmailConnectionsTable,
                    StoredEmailConnection
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalEmailConnectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalEmailConnectionsTable,
      StoredEmailConnection,
      $$LocalEmailConnectionsTableFilterComposer,
      $$LocalEmailConnectionsTableOrderingComposer,
      $$LocalEmailConnectionsTableAnnotationComposer,
      $$LocalEmailConnectionsTableCreateCompanionBuilder,
      $$LocalEmailConnectionsTableUpdateCompanionBuilder,
      (
        StoredEmailConnection,
        BaseReferences<
          _$AppDatabase,
          $LocalEmailConnectionsTable,
          StoredEmailConnection
        >,
      ),
      StoredEmailConnection,
      PrefetchHooks Function()
    >;
typedef $$LocalLeadsTableCreateCompanionBuilder = LocalLeadsCompanion Function({
  required String localId,
  Value<String?> ownerUserId,
  Value<String?> commercialFolio,
  required DateTime capturedAt,
  required String capturedBy,
  required String originKind,
  Value<String?> eventLocalId,
  Value<String?> eventNameSnapshot,
  required String name,
  required String lastName,
  required String role,
  required String company,
  required String email,
  required String phone,
  required String leadType,
  required String interestLevel,
  required String note,
  Value<String?> place,
  Value<String> contentFileIdsJson,
  Value<String> contentNamesJson,
  Value<String?> transcription,
  Value<String> syncState,
  Value<int?> remoteRevision,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$LocalLeadsTableUpdateCompanionBuilder = LocalLeadsCompanion Function({
  Value<String> localId,
  Value<String?> ownerUserId,
  Value<String?> commercialFolio,
  Value<DateTime> capturedAt,
  Value<String> capturedBy,
  Value<String> originKind,
  Value<String?> eventLocalId,
  Value<String?> eventNameSnapshot,
  Value<String> name,
  Value<String> lastName,
  Value<String> role,
  Value<String> company,
  Value<String> email,
  Value<String> phone,
  Value<String> leadType,
  Value<String> interestLevel,
  Value<String> note,
  Value<String?> place,
  Value<String> contentFileIdsJson,
  Value<String> contentNamesJson,
  Value<String?> transcription,
  Value<String> syncState,
  Value<int?> remoteRevision,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$LocalLeadsTableReferences
    extends BaseReferences<_$AppDatabase, $LocalLeadsTable, StoredLead> {
  $$LocalLeadsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LocalEventsTable _eventLocalIdTable(_$AppDatabase db) => db
      .localEvents
      .createAlias('local_leads__event_local_id__local_events__local_id');

  $$LocalEventsTableProcessedTableManager? get eventLocalId {
    final $_column = $_itemColumn<String>('event_local_id');
    if ($_column == null) return null;
    final manager = $$LocalEventsTableTableManager(
      $_db,
      $_db.localEvents,
    ).filter((f) => f.localId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_eventLocalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $LocalEmailFollowUpsTable,
    List<StoredEmailFollowUp>
  >
  _localEmailFollowUpsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.localEmailFollowUps,
        aliasName:
            'local_leads__local_id__local_email_follow_ups__lead_local_id',
      );

  $$LocalEmailFollowUpsTableProcessedTableManager get localEmailFollowUpsRefs {
    final manager =
        $$LocalEmailFollowUpsTableTableManager(
          $_db,
          $_db.localEmailFollowUps,
        ).filter(
          (f) => f.leadLocalId.localId.sqlEquals(
            $_itemColumn<String>('local_id')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _localEmailFollowUpsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LocalLeadMediaTable, List<StoredLeadMedia>>
  _localLeadMediaRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.localLeadMedia,
    aliasName: 'local_leads__local_id__local_lead_media__lead_local_id',
  );

  $$LocalLeadMediaTableProcessedTableManager get localLeadMediaRefs {
    final manager = $$LocalLeadMediaTableTableManager($_db, $_db.localLeadMedia)
        .filter(
          (f) => f.leadLocalId.localId.sqlEquals(
            $_itemColumn<String>('local_id')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(_localLeadMediaRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalLeadsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalLeadsTable> {
  $$LocalLeadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commercialFolio => $composableBuilder(
    column: $table.commercialFolio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capturedBy => $composableBuilder(
    column: $table.capturedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originKind => $composableBuilder(
    column: $table.originKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventNameSnapshot => $composableBuilder(
    column: $table.eventNameSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastName => $composableBuilder(
    column: $table.lastName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get company => $composableBuilder(
    column: $table.company,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get leadType => $composableBuilder(
    column: $table.leadType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get interestLevel => $composableBuilder(
    column: $table.interestLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get place => $composableBuilder(
    column: $table.place,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentFileIdsJson => $composableBuilder(
    column: $table.contentFileIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentNamesJson => $composableBuilder(
    column: $table.contentNamesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcription => $composableBuilder(
    column: $table.transcription,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteRevision => $composableBuilder(
    column: $table.remoteRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalEventsTableFilterComposer get eventLocalId {
    final $$LocalEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventLocalId,
      referencedTable: $db.localEvents,
      getReferencedColumn: (t) => t.localId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalEventsTableFilterComposer(
            $db: $db,
            $table: $db.localEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> localEmailFollowUpsRefs(
    Expression<bool> Function($$LocalEmailFollowUpsTableFilterComposer f) f,
  ) {
    final $$LocalEmailFollowUpsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.localId,
      referencedTable: $db.localEmailFollowUps,
      getReferencedColumn: (t) => t.leadLocalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalEmailFollowUpsTableFilterComposer(
            $db: $db,
            $table: $db.localEmailFollowUps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> localLeadMediaRefs(
    Expression<bool> Function($$LocalLeadMediaTableFilterComposer f) f,
  ) {
    final $$LocalLeadMediaTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.localId,
      referencedTable: $db.localLeadMedia,
      getReferencedColumn: (t) => t.leadLocalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalLeadMediaTableFilterComposer(
            $db: $db,
            $table: $db.localLeadMedia,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalLeadsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalLeadsTable> {
  $$LocalLeadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commercialFolio => $composableBuilder(
    column: $table.commercialFolio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capturedBy => $composableBuilder(
    column: $table.capturedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originKind => $composableBuilder(
    column: $table.originKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventNameSnapshot => $composableBuilder(
    column: $table.eventNameSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastName => $composableBuilder(
    column: $table.lastName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get company => $composableBuilder(
    column: $table.company,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leadType => $composableBuilder(
    column: $table.leadType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get interestLevel => $composableBuilder(
    column: $table.interestLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get place => $composableBuilder(
    column: $table.place,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentFileIdsJson => $composableBuilder(
    column: $table.contentFileIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentNamesJson => $composableBuilder(
    column: $table.contentNamesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcription => $composableBuilder(
    column: $table.transcription,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteRevision => $composableBuilder(
    column: $table.remoteRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalEventsTableOrderingComposer get eventLocalId {
    final $$LocalEventsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventLocalId,
      referencedTable: $db.localEvents,
      getReferencedColumn: (t) => t.localId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalEventsTableOrderingComposer(
            $db: $db,
            $table: $db.localEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalLeadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalLeadsTable> {
  $$LocalLeadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get commercialFolio => $composableBuilder(
    column: $table.commercialFolio,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get capturedBy => $composableBuilder(
    column: $table.capturedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originKind => $composableBuilder(
    column: $table.originKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get eventNameSnapshot => $composableBuilder(
    column: $table.eventNameSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get lastName =>
      $composableBuilder(column: $table.lastName, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get company =>
      $composableBuilder(column: $table.company, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get leadType =>
      $composableBuilder(column: $table.leadType, builder: (column) => column);

  GeneratedColumn<String> get interestLevel => $composableBuilder(
    column: $table.interestLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get place =>
      $composableBuilder(column: $table.place, builder: (column) => column);

  GeneratedColumn<String> get contentFileIdsJson => $composableBuilder(
    column: $table.contentFileIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentNamesJson => $composableBuilder(
    column: $table.contentNamesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transcription => $composableBuilder(
    column: $table.transcription,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<int> get remoteRevision => $composableBuilder(
    column: $table.remoteRevision,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$LocalEventsTableAnnotationComposer get eventLocalId {
    final $$LocalEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventLocalId,
      referencedTable: $db.localEvents,
      getReferencedColumn: (t) => t.localId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.localEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> localEmailFollowUpsRefs<T extends Object>(
    Expression<T> Function($$LocalEmailFollowUpsTableAnnotationComposer a) f,
  ) {
    final $$LocalEmailFollowUpsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.localId,
          referencedTable: $db.localEmailFollowUps,
          getReferencedColumn: (t) => t.leadLocalId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalEmailFollowUpsTableAnnotationComposer(
                $db: $db,
                $table: $db.localEmailFollowUps,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> localLeadMediaRefs<T extends Object>(
    Expression<T> Function($$LocalLeadMediaTableAnnotationComposer a) f,
  ) {
    final $$LocalLeadMediaTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.localId,
      referencedTable: $db.localLeadMedia,
      getReferencedColumn: (t) => t.leadLocalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalLeadMediaTableAnnotationComposer(
            $db: $db,
            $table: $db.localLeadMedia,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalLeadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalLeadsTable,
          StoredLead,
          $$LocalLeadsTableFilterComposer,
          $$LocalLeadsTableOrderingComposer,
          $$LocalLeadsTableAnnotationComposer,
          $$LocalLeadsTableCreateCompanionBuilder,
          $$LocalLeadsTableUpdateCompanionBuilder,
          (StoredLead, $$LocalLeadsTableReferences),
          StoredLead,
          PrefetchHooks Function({
            bool eventLocalId,
            bool localEmailFollowUpsRefs,
            bool localLeadMediaRefs,
          })
        > {
  $$LocalLeadsTableTableManager(_$AppDatabase db, $LocalLeadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalLeadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalLeadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalLeadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> localId = const Value.absent(),
                Value<String?> ownerUserId = const Value.absent(),
                Value<String?> commercialFolio = const Value.absent(),
                Value<DateTime> capturedAt = const Value.absent(),
                Value<String> capturedBy = const Value.absent(),
                Value<String> originKind = const Value.absent(),
                Value<String?> eventLocalId = const Value.absent(),
                Value<String?> eventNameSnapshot = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> lastName = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> company = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String> leadType = const Value.absent(),
                Value<String> interestLevel = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String?> place = const Value.absent(),
                Value<String> contentFileIdsJson = const Value.absent(),
                Value<String> contentNamesJson = const Value.absent(),
                Value<String?> transcription = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int?> remoteRevision = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalLeadsCompanion(
                localId: localId,
                ownerUserId: ownerUserId,
                commercialFolio: commercialFolio,
                capturedAt: capturedAt,
                capturedBy: capturedBy,
                originKind: originKind,
                eventLocalId: eventLocalId,
                eventNameSnapshot: eventNameSnapshot,
                name: name,
                lastName: lastName,
                role: role,
                company: company,
                email: email,
                phone: phone,
                leadType: leadType,
                interestLevel: interestLevel,
                note: note,
                place: place,
                contentFileIdsJson: contentFileIdsJson,
                contentNamesJson: contentNamesJson,
                transcription: transcription,
                syncState: syncState,
                remoteRevision: remoteRevision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localId,
                Value<String?> ownerUserId = const Value.absent(),
                Value<String?> commercialFolio = const Value.absent(),
                required DateTime capturedAt,
                required String capturedBy,
                required String originKind,
                Value<String?> eventLocalId = const Value.absent(),
                Value<String?> eventNameSnapshot = const Value.absent(),
                required String name,
                required String lastName,
                required String role,
                required String company,
                required String email,
                required String phone,
                required String leadType,
                required String interestLevel,
                required String note,
                Value<String?> place = const Value.absent(),
                Value<String> contentFileIdsJson = const Value.absent(),
                Value<String> contentNamesJson = const Value.absent(),
                Value<String?> transcription = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int?> remoteRevision = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalLeadsCompanion.insert(
                localId: localId,
                ownerUserId: ownerUserId,
                commercialFolio: commercialFolio,
                capturedAt: capturedAt,
                capturedBy: capturedBy,
                originKind: originKind,
                eventLocalId: eventLocalId,
                eventNameSnapshot: eventNameSnapshot,
                name: name,
                lastName: lastName,
                role: role,
                company: company,
                email: email,
                phone: phone,
                leadType: leadType,
                interestLevel: interestLevel,
                note: note,
                place: place,
                contentFileIdsJson: contentFileIdsJson,
                contentNamesJson: contentNamesJson,
                transcription: transcription,
                syncState: syncState,
                remoteRevision: remoteRevision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalLeadsTable, StoredLead>(table),
                  $$LocalLeadsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                eventLocalId = false,
                localEmailFollowUpsRefs = false,
                localLeadMediaRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (localEmailFollowUpsRefs) db.localEmailFollowUps,
                    if (localLeadMediaRefs) db.localLeadMedia,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (eventLocalId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.eventLocalId,
                            referencedTable: $$LocalLeadsTableReferences
                                ._eventLocalIdTable(db),
                            referencedColumn: $$LocalLeadsTableReferences
                                ._eventLocalIdTable(db)
                                .localId,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (localEmailFollowUpsRefs)
                        await $_getPrefetchedData<
                          StoredLead,
                          $LocalLeadsTable,
                          StoredEmailFollowUp
                        >(
                          currentTable: table,
                          referencedTable: $$LocalLeadsTableReferences
                              ._localEmailFollowUpsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalLeadsTableReferences(
                                db,
                                table,
                                p0,
                              ).localEmailFollowUpsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.leadLocalId == item.localId,
                              ),
                          typedResults: items,
                        ),
                      if (localLeadMediaRefs)
                        await $_getPrefetchedData<
                          StoredLead,
                          $LocalLeadsTable,
                          StoredLeadMedia
                        >(
                          currentTable: table,
                          referencedTable: $$LocalLeadsTableReferences
                              ._localLeadMediaRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalLeadsTableReferences(
                                db,
                                table,
                                p0,
                              ).localLeadMediaRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.leadLocalId == item.localId,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LocalLeadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalLeadsTable,
      StoredLead,
      $$LocalLeadsTableFilterComposer,
      $$LocalLeadsTableOrderingComposer,
      $$LocalLeadsTableAnnotationComposer,
      $$LocalLeadsTableCreateCompanionBuilder,
      $$LocalLeadsTableUpdateCompanionBuilder,
      (StoredLead, $$LocalLeadsTableReferences),
      StoredLead,
      PrefetchHooks Function({
        bool eventLocalId,
        bool localEmailFollowUpsRefs,
        bool localLeadMediaRefs,
      })
    >;
typedef $$LocalEmailFollowUpsTableCreateCompanionBuilder =
    LocalEmailFollowUpsCompanion Function({
      required String localId,
      required String ownerUserId,
      required String leadLocalId,
      required String recipientAddress,
      required String subject,
      required String plainBody,
      required String htmlBody,
      Value<String> contentFileIdsJson,
      Value<String> contentNamesJson,
      required String languageCode,
      required DateTime preparedAt,
      Value<String> syncState,
      Value<int> rowid,
    });
typedef $$LocalEmailFollowUpsTableUpdateCompanionBuilder =
    LocalEmailFollowUpsCompanion Function({
      Value<String> localId,
      Value<String> ownerUserId,
      Value<String> leadLocalId,
      Value<String> recipientAddress,
      Value<String> subject,
      Value<String> plainBody,
      Value<String> htmlBody,
      Value<String> contentFileIdsJson,
      Value<String> contentNamesJson,
      Value<String> languageCode,
      Value<DateTime> preparedAt,
      Value<String> syncState,
      Value<int> rowid,
    });

final class $$LocalEmailFollowUpsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LocalEmailFollowUpsTable,
          StoredEmailFollowUp
        > {
  $$LocalEmailFollowUpsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalLeadsTable _leadLocalIdTable(_$AppDatabase db) =>
      db.localLeads.createAlias(
        'local_email_follow_ups__lead_local_id__local_leads__local_id',
      );

  $$LocalLeadsTableProcessedTableManager get leadLocalId {
    final $_column = $_itemColumn<String>('lead_local_id')!;

    final manager = $$LocalLeadsTableTableManager(
      $_db,
      $_db.localLeads,
    ).filter((f) => f.localId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_leadLocalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $LocalEmailSendIntentsTable,
    List<StoredEmailSendIntent>
  >
  _localEmailSendIntentsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.localEmailSendIntents,
        aliasName: 'local_email_follow_ups__local_id__local_email_send_intents__follow_up_local_id',
      );

  $$LocalEmailSendIntentsTableProcessedTableManager
  get localEmailSendIntentsRefs {
    final manager =
        $$LocalEmailSendIntentsTableTableManager(
          $_db,
          $_db.localEmailSendIntents,
        ).filter(
          (f) => f.followUpLocalId.localId.sqlEquals(
            $_itemColumn<String>('local_id')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _localEmailSendIntentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalEmailFollowUpsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalEmailFollowUpsTable> {
  $$LocalEmailFollowUpsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipientAddress => $composableBuilder(
    column: $table.recipientAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plainBody => $composableBuilder(
    column: $table.plainBody,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get htmlBody => $composableBuilder(
    column: $table.htmlBody,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentFileIdsJson => $composableBuilder(
    column: $table.contentFileIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentNamesJson => $composableBuilder(
    column: $table.contentNamesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get preparedAt => $composableBuilder(
    column: $table.preparedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalLeadsTableFilterComposer get leadLocalId {
    final $$LocalLeadsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.leadLocalId,
      referencedTable: $db.localLeads,
      getReferencedColumn: (t) => t.localId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalLeadsTableFilterComposer(
            $db: $db,
            $table: $db.localLeads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> localEmailSendIntentsRefs(
    Expression<bool> Function($$LocalEmailSendIntentsTableFilterComposer f) f,
  ) {
    final $$LocalEmailSendIntentsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.localId,
          referencedTable: $db.localEmailSendIntents,
          getReferencedColumn: (t) => t.followUpLocalId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalEmailSendIntentsTableFilterComposer(
                $db: $db,
                $table: $db.localEmailSendIntents,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LocalEmailFollowUpsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalEmailFollowUpsTable> {
  $$LocalEmailFollowUpsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipientAddress => $composableBuilder(
    column: $table.recipientAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subject => $composableBuilder(
    column: $table.subject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plainBody => $composableBuilder(
    column: $table.plainBody,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get htmlBody => $composableBuilder(
    column: $table.htmlBody,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentFileIdsJson => $composableBuilder(
    column: $table.contentFileIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentNamesJson => $composableBuilder(
    column: $table.contentNamesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get preparedAt => $composableBuilder(
    column: $table.preparedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalLeadsTableOrderingComposer get leadLocalId {
    final $$LocalLeadsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.leadLocalId,
      referencedTable: $db.localLeads,
      getReferencedColumn: (t) => t.localId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalLeadsTableOrderingComposer(
            $db: $db,
            $table: $db.localLeads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalEmailFollowUpsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalEmailFollowUpsTable> {
  $$LocalEmailFollowUpsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recipientAddress => $composableBuilder(
    column: $table.recipientAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get plainBody =>
      $composableBuilder(column: $table.plainBody, builder: (column) => column);

  GeneratedColumn<String> get htmlBody =>
      $composableBuilder(column: $table.htmlBody, builder: (column) => column);

  GeneratedColumn<String> get contentFileIdsJson => $composableBuilder(
    column: $table.contentFileIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentNamesJson => $composableBuilder(
    column: $table.contentNamesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get languageCode => $composableBuilder(
    column: $table.languageCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get preparedAt => $composableBuilder(
    column: $table.preparedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  $$LocalLeadsTableAnnotationComposer get leadLocalId {
    final $$LocalLeadsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.leadLocalId,
      referencedTable: $db.localLeads,
      getReferencedColumn: (t) => t.localId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalLeadsTableAnnotationComposer(
            $db: $db,
            $table: $db.localLeads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> localEmailSendIntentsRefs<T extends Object>(
    Expression<T> Function($$LocalEmailSendIntentsTableAnnotationComposer a) f,
  ) {
    final $$LocalEmailSendIntentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.localId,
          referencedTable: $db.localEmailSendIntents,
          getReferencedColumn: (t) => t.followUpLocalId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalEmailSendIntentsTableAnnotationComposer(
                $db: $db,
                $table: $db.localEmailSendIntents,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LocalEmailFollowUpsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalEmailFollowUpsTable,
          StoredEmailFollowUp,
          $$LocalEmailFollowUpsTableFilterComposer,
          $$LocalEmailFollowUpsTableOrderingComposer,
          $$LocalEmailFollowUpsTableAnnotationComposer,
          $$LocalEmailFollowUpsTableCreateCompanionBuilder,
          $$LocalEmailFollowUpsTableUpdateCompanionBuilder,
          (StoredEmailFollowUp, $$LocalEmailFollowUpsTableReferences),
          StoredEmailFollowUp,
          PrefetchHooks Function({
            bool leadLocalId,
            bool localEmailSendIntentsRefs,
          })
        > {
  $$LocalEmailFollowUpsTableTableManager(
    _$AppDatabase db,
    $LocalEmailFollowUpsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalEmailFollowUpsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalEmailFollowUpsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalEmailFollowUpsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> localId = const Value.absent(),
                Value<String> ownerUserId = const Value.absent(),
                Value<String> leadLocalId = const Value.absent(),
                Value<String> recipientAddress = const Value.absent(),
                Value<String> subject = const Value.absent(),
                Value<String> plainBody = const Value.absent(),
                Value<String> htmlBody = const Value.absent(),
                Value<String> contentFileIdsJson = const Value.absent(),
                Value<String> contentNamesJson = const Value.absent(),
                Value<String> languageCode = const Value.absent(),
                Value<DateTime> preparedAt = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalEmailFollowUpsCompanion(
                localId: localId,
                ownerUserId: ownerUserId,
                leadLocalId: leadLocalId,
                recipientAddress: recipientAddress,
                subject: subject,
                plainBody: plainBody,
                htmlBody: htmlBody,
                contentFileIdsJson: contentFileIdsJson,
                contentNamesJson: contentNamesJson,
                languageCode: languageCode,
                preparedAt: preparedAt,
                syncState: syncState,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localId,
                required String ownerUserId,
                required String leadLocalId,
                required String recipientAddress,
                required String subject,
                required String plainBody,
                required String htmlBody,
                Value<String> contentFileIdsJson = const Value.absent(),
                Value<String> contentNamesJson = const Value.absent(),
                required String languageCode,
                required DateTime preparedAt,
                Value<String> syncState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalEmailFollowUpsCompanion.insert(
                localId: localId,
                ownerUserId: ownerUserId,
                leadLocalId: leadLocalId,
                recipientAddress: recipientAddress,
                subject: subject,
                plainBody: plainBody,
                htmlBody: htmlBody,
                contentFileIdsJson: contentFileIdsJson,
                contentNamesJson: contentNamesJson,
                languageCode: languageCode,
                preparedAt: preparedAt,
                syncState: syncState,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalEmailFollowUpsTable, StoredEmailFollowUp>(
                    table,
                  ),
                  $$LocalEmailFollowUpsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({leadLocalId = false, localEmailSendIntentsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (localEmailSendIntentsRefs) db.localEmailSendIntents,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (leadLocalId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.leadLocalId,
                            referencedTable:
                                $$LocalEmailFollowUpsTableReferences
                                    ._leadLocalIdTable(db),
                            referencedColumn:
                                $$LocalEmailFollowUpsTableReferences
                                    ._leadLocalIdTable(db)
                                    .localId,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (localEmailSendIntentsRefs)
                        await $_getPrefetchedData<
                          StoredEmailFollowUp,
                          $LocalEmailFollowUpsTable,
                          StoredEmailSendIntent
                        >(
                          currentTable: table,
                          referencedTable: $$LocalEmailFollowUpsTableReferences
                              ._localEmailSendIntentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalEmailFollowUpsTableReferences(
                                db,
                                table,
                                p0,
                              ).localEmailSendIntentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.followUpLocalId == item.localId,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LocalEmailFollowUpsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalEmailFollowUpsTable,
      StoredEmailFollowUp,
      $$LocalEmailFollowUpsTableFilterComposer,
      $$LocalEmailFollowUpsTableOrderingComposer,
      $$LocalEmailFollowUpsTableAnnotationComposer,
      $$LocalEmailFollowUpsTableCreateCompanionBuilder,
      $$LocalEmailFollowUpsTableUpdateCompanionBuilder,
      (StoredEmailFollowUp, $$LocalEmailFollowUpsTableReferences),
      StoredEmailFollowUp,
      PrefetchHooks Function({bool leadLocalId, bool localEmailSendIntentsRefs})
    >;
typedef $$LocalEmailSendIntentsTableCreateCompanionBuilder =
    LocalEmailSendIntentsCompanion Function({
      required String localId,
      required String ownerUserId,
      required String followUpLocalId,
      Value<String?> connectionId,
      Value<String?> senderAddress,
      Value<String> status,
      Value<String> omittedContentIdsJson,
      Value<String?> parentIntentId,
      Value<int> attemptCount,
      Value<String?> errorCode,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LocalEmailSendIntentsTableUpdateCompanionBuilder =
    LocalEmailSendIntentsCompanion Function({
      Value<String> localId,
      Value<String> ownerUserId,
      Value<String> followUpLocalId,
      Value<String?> connectionId,
      Value<String?> senderAddress,
      Value<String> status,
      Value<String> omittedContentIdsJson,
      Value<String?> parentIntentId,
      Value<int> attemptCount,
      Value<String?> errorCode,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$LocalEmailSendIntentsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LocalEmailSendIntentsTable,
          StoredEmailSendIntent
        > {
  $$LocalEmailSendIntentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalEmailFollowUpsTable _followUpLocalIdTable(_$AppDatabase db) =>
      db.localEmailFollowUps.createAlias(
        'local_email_send_intents__follow_up_local_id__local_email_follow_ups__local_id',
      );

  $$LocalEmailFollowUpsTableProcessedTableManager get followUpLocalId {
    final $_column = $_itemColumn<String>('follow_up_local_id')!;

    final manager = $$LocalEmailFollowUpsTableTableManager(
      $_db,
      $_db.localEmailFollowUps,
    ).filter((f) => f.localId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_followUpLocalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocalEmailSendIntentsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalEmailSendIntentsTable> {
  $$LocalEmailSendIntentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get connectionId => $composableBuilder(
    column: $table.connectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderAddress => $composableBuilder(
    column: $table.senderAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get omittedContentIdsJson => $composableBuilder(
    column: $table.omittedContentIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentIntentId => $composableBuilder(
    column: $table.parentIntentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalEmailFollowUpsTableFilterComposer get followUpLocalId {
    final $$LocalEmailFollowUpsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.followUpLocalId,
      referencedTable: $db.localEmailFollowUps,
      getReferencedColumn: (t) => t.localId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalEmailFollowUpsTableFilterComposer(
            $db: $db,
            $table: $db.localEmailFollowUps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalEmailSendIntentsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalEmailSendIntentsTable> {
  $$LocalEmailSendIntentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get connectionId => $composableBuilder(
    column: $table.connectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderAddress => $composableBuilder(
    column: $table.senderAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get omittedContentIdsJson => $composableBuilder(
    column: $table.omittedContentIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentIntentId => $composableBuilder(
    column: $table.parentIntentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalEmailFollowUpsTableOrderingComposer get followUpLocalId {
    final $$LocalEmailFollowUpsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.followUpLocalId,
          referencedTable: $db.localEmailFollowUps,
          getReferencedColumn: (t) => t.localId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalEmailFollowUpsTableOrderingComposer(
                $db: $db,
                $table: $db.localEmailFollowUps,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$LocalEmailSendIntentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalEmailSendIntentsTable> {
  $$LocalEmailSendIntentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get connectionId => $composableBuilder(
    column: $table.connectionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get senderAddress => $composableBuilder(
    column: $table.senderAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get omittedContentIdsJson => $composableBuilder(
    column: $table.omittedContentIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentIntentId => $composableBuilder(
    column: $table.parentIntentId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$LocalEmailFollowUpsTableAnnotationComposer get followUpLocalId {
    final $$LocalEmailFollowUpsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.followUpLocalId,
          referencedTable: $db.localEmailFollowUps,
          getReferencedColumn: (t) => t.localId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LocalEmailFollowUpsTableAnnotationComposer(
                $db: $db,
                $table: $db.localEmailFollowUps,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$LocalEmailSendIntentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalEmailSendIntentsTable,
          StoredEmailSendIntent,
          $$LocalEmailSendIntentsTableFilterComposer,
          $$LocalEmailSendIntentsTableOrderingComposer,
          $$LocalEmailSendIntentsTableAnnotationComposer,
          $$LocalEmailSendIntentsTableCreateCompanionBuilder,
          $$LocalEmailSendIntentsTableUpdateCompanionBuilder,
          (StoredEmailSendIntent, $$LocalEmailSendIntentsTableReferences),
          StoredEmailSendIntent,
          PrefetchHooks Function({bool followUpLocalId})
        > {
  $$LocalEmailSendIntentsTableTableManager(
    _$AppDatabase db,
    $LocalEmailSendIntentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalEmailSendIntentsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalEmailSendIntentsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalEmailSendIntentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> localId = const Value.absent(),
                Value<String> ownerUserId = const Value.absent(),
                Value<String> followUpLocalId = const Value.absent(),
                Value<String?> connectionId = const Value.absent(),
                Value<String?> senderAddress = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> omittedContentIdsJson = const Value.absent(),
                Value<String?> parentIntentId = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalEmailSendIntentsCompanion(
                localId: localId,
                ownerUserId: ownerUserId,
                followUpLocalId: followUpLocalId,
                connectionId: connectionId,
                senderAddress: senderAddress,
                status: status,
                omittedContentIdsJson: omittedContentIdsJson,
                parentIntentId: parentIntentId,
                attemptCount: attemptCount,
                errorCode: errorCode,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localId,
                required String ownerUserId,
                required String followUpLocalId,
                Value<String?> connectionId = const Value.absent(),
                Value<String?> senderAddress = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> omittedContentIdsJson = const Value.absent(),
                Value<String?> parentIntentId = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalEmailSendIntentsCompanion.insert(
                localId: localId,
                ownerUserId: ownerUserId,
                followUpLocalId: followUpLocalId,
                connectionId: connectionId,
                senderAddress: senderAddress,
                status: status,
                omittedContentIdsJson: omittedContentIdsJson,
                parentIntentId: parentIntentId,
                attemptCount: attemptCount,
                errorCode: errorCode,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LocalEmailSendIntentsTable,
                    StoredEmailSendIntent
                  >(table),
                  $$LocalEmailSendIntentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({followUpLocalId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (followUpLocalId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.followUpLocalId,
                        referencedTable: $$LocalEmailSendIntentsTableReferences
                            ._followUpLocalIdTable(db),
                        referencedColumn: $$LocalEmailSendIntentsTableReferences
                            ._followUpLocalIdTable(db)
                            .localId,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LocalEmailSendIntentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalEmailSendIntentsTable,
      StoredEmailSendIntent,
      $$LocalEmailSendIntentsTableFilterComposer,
      $$LocalEmailSendIntentsTableOrderingComposer,
      $$LocalEmailSendIntentsTableAnnotationComposer,
      $$LocalEmailSendIntentsTableCreateCompanionBuilder,
      $$LocalEmailSendIntentsTableUpdateCompanionBuilder,
      (StoredEmailSendIntent, $$LocalEmailSendIntentsTableReferences),
      StoredEmailSendIntent,
      PrefetchHooks Function({bool followUpLocalId})
    >;
typedef $$LocalLeadMediaTableCreateCompanionBuilder =
    LocalLeadMediaCompanion Function({
      required String localId,
      required String leadLocalId,
      required String mediaType,
      required String localPath,
      Value<int?> durationSeconds,
      Value<String> uploadState,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$LocalLeadMediaTableUpdateCompanionBuilder =
    LocalLeadMediaCompanion Function({
      Value<String> localId,
      Value<String> leadLocalId,
      Value<String> mediaType,
      Value<String> localPath,
      Value<int?> durationSeconds,
      Value<String> uploadState,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$LocalLeadMediaTableReferences
    extends
        BaseReferences<_$AppDatabase, $LocalLeadMediaTable, StoredLeadMedia> {
  $$LocalLeadMediaTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalLeadsTable _leadLocalIdTable(_$AppDatabase db) => db.localLeads
      .createAlias('local_lead_media__lead_local_id__local_leads__local_id');

  $$LocalLeadsTableProcessedTableManager get leadLocalId {
    final $_column = $_itemColumn<String>('lead_local_id')!;

    final manager = $$LocalLeadsTableTableManager(
      $_db,
      $_db.localLeads,
    ).filter((f) => f.localId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_leadLocalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocalLeadMediaTableFilterComposer
    extends Composer<_$AppDatabase, $LocalLeadMediaTable> {
  $$LocalLeadMediaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalLeadsTableFilterComposer get leadLocalId {
    final $$LocalLeadsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.leadLocalId,
      referencedTable: $db.localLeads,
      getReferencedColumn: (t) => t.localId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalLeadsTableFilterComposer(
            $db: $db,
            $table: $db.localLeads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalLeadMediaTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalLeadMediaTable> {
  $$LocalLeadMediaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalLeadsTableOrderingComposer get leadLocalId {
    final $$LocalLeadsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.leadLocalId,
      referencedTable: $db.localLeads,
      getReferencedColumn: (t) => t.localId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalLeadsTableOrderingComposer(
            $db: $db,
            $table: $db.localLeads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalLeadMediaTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalLeadMediaTable> {
  $$LocalLeadMediaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$LocalLeadsTableAnnotationComposer get leadLocalId {
    final $$LocalLeadsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.leadLocalId,
      referencedTable: $db.localLeads,
      getReferencedColumn: (t) => t.localId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalLeadsTableAnnotationComposer(
            $db: $db,
            $table: $db.localLeads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalLeadMediaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalLeadMediaTable,
          StoredLeadMedia,
          $$LocalLeadMediaTableFilterComposer,
          $$LocalLeadMediaTableOrderingComposer,
          $$LocalLeadMediaTableAnnotationComposer,
          $$LocalLeadMediaTableCreateCompanionBuilder,
          $$LocalLeadMediaTableUpdateCompanionBuilder,
          (StoredLeadMedia, $$LocalLeadMediaTableReferences),
          StoredLeadMedia,
          PrefetchHooks Function({bool leadLocalId})
        > {
  $$LocalLeadMediaTableTableManager(
    _$AppDatabase db,
    $LocalLeadMediaTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalLeadMediaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalLeadMediaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalLeadMediaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> localId = const Value.absent(),
                Value<String> leadLocalId = const Value.absent(),
                Value<String> mediaType = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<String> uploadState = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalLeadMediaCompanion(
                localId: localId,
                leadLocalId: leadLocalId,
                mediaType: mediaType,
                localPath: localPath,
                durationSeconds: durationSeconds,
                uploadState: uploadState,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localId,
                required String leadLocalId,
                required String mediaType,
                required String localPath,
                Value<int?> durationSeconds = const Value.absent(),
                Value<String> uploadState = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalLeadMediaCompanion.insert(
                localId: localId,
                leadLocalId: leadLocalId,
                mediaType: mediaType,
                localPath: localPath,
                durationSeconds: durationSeconds,
                uploadState: uploadState,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalLeadMediaTable, StoredLeadMedia>(table),
                  $$LocalLeadMediaTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({leadLocalId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (leadLocalId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.leadLocalId,
                        referencedTable: $$LocalLeadMediaTableReferences
                            ._leadLocalIdTable(db),
                        referencedColumn: $$LocalLeadMediaTableReferences
                            ._leadLocalIdTable(db)
                            .localId,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LocalLeadMediaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalLeadMediaTable,
      StoredLeadMedia,
      $$LocalLeadMediaTableFilterComposer,
      $$LocalLeadMediaTableOrderingComposer,
      $$LocalLeadMediaTableAnnotationComposer,
      $$LocalLeadMediaTableCreateCompanionBuilder,
      $$LocalLeadMediaTableUpdateCompanionBuilder,
      (StoredLeadMedia, $$LocalLeadMediaTableReferences),
      StoredLeadMedia,
      PrefetchHooks Function({bool leadLocalId})
    >;
typedef $$LocalPreferencesTableCreateCompanionBuilder =
    LocalPreferencesCompanion Function({
      required String key,
      required String value,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LocalPreferencesTableUpdateCompanionBuilder =
    LocalPreferencesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LocalPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalPreferencesTable> {
  $$LocalPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalPreferencesTable> {
  $$LocalPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalPreferencesTable> {
  $$LocalPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalPreferencesTable,
          StoredPreference,
          $$LocalPreferencesTableFilterComposer,
          $$LocalPreferencesTableOrderingComposer,
          $$LocalPreferencesTableAnnotationComposer,
          $$LocalPreferencesTableCreateCompanionBuilder,
          $$LocalPreferencesTableUpdateCompanionBuilder,
          (
            StoredPreference,
            BaseReferences<
              _$AppDatabase,
              $LocalPreferencesTable,
              StoredPreference
            >,
          ),
          StoredPreference,
          PrefetchHooks Function()
        > {
  $$LocalPreferencesTableTableManager(
    _$AppDatabase db,
    $LocalPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalPreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalPreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalPreferencesCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalPreferencesCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalPreferencesTable, StoredPreference>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalPreferencesTable,
                    StoredPreference
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalPreferencesTable,
      StoredPreference,
      $$LocalPreferencesTableFilterComposer,
      $$LocalPreferencesTableOrderingComposer,
      $$LocalPreferencesTableAnnotationComposer,
      $$LocalPreferencesTableCreateCompanionBuilder,
      $$LocalPreferencesTableUpdateCompanionBuilder,
      (
        StoredPreference,
        BaseReferences<_$AppDatabase, $LocalPreferencesTable, StoredPreference>,
      ),
      StoredPreference,
      PrefetchHooks Function()
    >;
typedef $$LocalUserPreferencesTableCreateCompanionBuilder =
    LocalUserPreferencesCompanion Function({
      required String ownerUserId,
      required String key,
      required String value,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LocalUserPreferencesTableUpdateCompanionBuilder =
    LocalUserPreferencesCompanion Function({
      Value<String> ownerUserId,
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LocalUserPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalUserPreferencesTable> {
  $$LocalUserPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalUserPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalUserPreferencesTable> {
  $$LocalUserPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalUserPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalUserPreferencesTable> {
  $$LocalUserPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalUserPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalUserPreferencesTable,
          StoredUserPreference,
          $$LocalUserPreferencesTableFilterComposer,
          $$LocalUserPreferencesTableOrderingComposer,
          $$LocalUserPreferencesTableAnnotationComposer,
          $$LocalUserPreferencesTableCreateCompanionBuilder,
          $$LocalUserPreferencesTableUpdateCompanionBuilder,
          (
            StoredUserPreference,
            BaseReferences<
              _$AppDatabase,
              $LocalUserPreferencesTable,
              StoredUserPreference
            >,
          ),
          StoredUserPreference,
          PrefetchHooks Function()
        > {
  $$LocalUserPreferencesTableTableManager(
    _$AppDatabase db,
    $LocalUserPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalUserPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalUserPreferencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalUserPreferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> ownerUserId = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalUserPreferencesCompanion(
                ownerUserId: ownerUserId,
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerUserId,
                required String key,
                required String value,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalUserPreferencesCompanion.insert(
                ownerUserId: ownerUserId,
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalUserPreferencesTable, StoredUserPreference>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalUserPreferencesTable,
                    StoredUserPreference
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalUserPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalUserPreferencesTable,
      StoredUserPreference,
      $$LocalUserPreferencesTableFilterComposer,
      $$LocalUserPreferencesTableOrderingComposer,
      $$LocalUserPreferencesTableAnnotationComposer,
      $$LocalUserPreferencesTableCreateCompanionBuilder,
      $$LocalUserPreferencesTableUpdateCompanionBuilder,
      (
        StoredUserPreference,
        BaseReferences<
          _$AppDatabase,
          $LocalUserPreferencesTable,
          StoredUserPreference
        >,
      ),
      StoredUserPreference,
      PrefetchHooks Function()
    >;
typedef $$SyncOperationsTableCreateCompanionBuilder =
    SyncOperationsCompanion Function({
      required String operationId,
      required String ownerUserId,
      required String entityType,
      required String entityId,
      required String action,
      required String payloadJson,
      required String idempotencyKey,
      Value<String> status,
      Value<int> attemptCount,
      Value<DateTime?> nextAttemptAt,
      Value<String?> lastError,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SyncOperationsTableUpdateCompanionBuilder =
    SyncOperationsCompanion Function({
      Value<String> operationId,
      Value<String> ownerUserId,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> action,
      Value<String> payloadJson,
      Value<String> idempotencyKey,
      Value<String> status,
      Value<int> attemptCount,
      Value<DateTime?> nextAttemptAt,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SyncOperationsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOperationsTable> {
  $$SyncOperationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOperationsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOperationsTable> {
  $$SyncOperationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOperationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOperationsTable> {
  $$SyncOperationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SyncOperationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncOperationsTable,
          StoredSyncOperation,
          $$SyncOperationsTableFilterComposer,
          $$SyncOperationsTableOrderingComposer,
          $$SyncOperationsTableAnnotationComposer,
          $$SyncOperationsTableCreateCompanionBuilder,
          $$SyncOperationsTableUpdateCompanionBuilder,
          (
            StoredSyncOperation,
            BaseReferences<
              _$AppDatabase,
              $SyncOperationsTable,
              StoredSyncOperation
            >,
          ),
          StoredSyncOperation,
          PrefetchHooks Function()
        > {
  $$SyncOperationsTableTableManager(
    _$AppDatabase db,
    $SyncOperationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOperationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOperationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOperationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> operationId = const Value.absent(),
                Value<String> ownerUserId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOperationsCompanion(
                operationId: operationId,
                ownerUserId: ownerUserId,
                entityType: entityType,
                entityId: entityId,
                action: action,
                payloadJson: payloadJson,
                idempotencyKey: idempotencyKey,
                status: status,
                attemptCount: attemptCount,
                nextAttemptAt: nextAttemptAt,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String operationId,
                required String ownerUserId,
                required String entityType,
                required String entityId,
                required String action,
                required String payloadJson,
                required String idempotencyKey,
                Value<String> status = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncOperationsCompanion.insert(
                operationId: operationId,
                ownerUserId: ownerUserId,
                entityType: entityType,
                entityId: entityId,
                action: action,
                payloadJson: payloadJson,
                idempotencyKey: idempotencyKey,
                status: status,
                attemptCount: attemptCount,
                nextAttemptAt: nextAttemptAt,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncOperationsTable, StoredSyncOperation>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncOperationsTable,
                    StoredSyncOperation
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOperationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncOperationsTable,
      StoredSyncOperation,
      $$SyncOperationsTableFilterComposer,
      $$SyncOperationsTableOrderingComposer,
      $$SyncOperationsTableAnnotationComposer,
      $$SyncOperationsTableCreateCompanionBuilder,
      $$SyncOperationsTableUpdateCompanionBuilder,
      (
        StoredSyncOperation,
        BaseReferences<
          _$AppDatabase,
          $SyncOperationsTable,
          StoredSyncOperation
        >,
      ),
      StoredSyncOperation,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalProfilesTableTableManager get localProfiles =>
      $$LocalProfilesTableTableManager(_db, _db.localProfiles);
  $$LocalEventsTableTableManager get localEvents =>
      $$LocalEventsTableTableManager(_db, _db.localEvents);
  $$LocalContentFilesTableTableManager get localContentFiles =>
      $$LocalContentFilesTableTableManager(_db, _db.localContentFiles);
  $$LocalEmailTemplatesTableTableManager get localEmailTemplates =>
      $$LocalEmailTemplatesTableTableManager(_db, _db.localEmailTemplates);
  $$LocalEmailConnectionsTableTableManager get localEmailConnections =>
      $$LocalEmailConnectionsTableTableManager(_db, _db.localEmailConnections);
  $$LocalLeadsTableTableManager get localLeads =>
      $$LocalLeadsTableTableManager(_db, _db.localLeads);
  $$LocalEmailFollowUpsTableTableManager get localEmailFollowUps =>
      $$LocalEmailFollowUpsTableTableManager(_db, _db.localEmailFollowUps);
  $$LocalEmailSendIntentsTableTableManager get localEmailSendIntents =>
      $$LocalEmailSendIntentsTableTableManager(_db, _db.localEmailSendIntents);
  $$LocalLeadMediaTableTableManager get localLeadMedia =>
      $$LocalLeadMediaTableTableManager(_db, _db.localLeadMedia);
  $$LocalPreferencesTableTableManager get localPreferences =>
      $$LocalPreferencesTableTableManager(_db, _db.localPreferences);
  $$LocalUserPreferencesTableTableManager get localUserPreferences =>
      $$LocalUserPreferencesTableTableManager(_db, _db.localUserPreferences);
  $$SyncOperationsTableTableManager get syncOperations =>
      $$SyncOperationsTableTableManager(_db, _db.syncOperations);
}
