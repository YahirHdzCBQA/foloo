// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
mixin _$ProfilePreferencesDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalProfilesTable get localProfiles => attachedDatabase.localProfiles;
  $LocalPreferencesTable get localPreferences =>
      attachedDatabase.localPreferences;
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
  @override
  List<GeneratedColumn> get $columns => [
    localId,
    name,
    company,
    createdAt,
    updatedAt,
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
    );
  }

  @override
  $LocalProfilesTable createAlias(String alias) {
    return $LocalProfilesTable(attachedDatabase, alias);
  }
}

class StoredProfile extends DataClass implements Insertable<StoredProfile> {
  final String localId;
  final String name;
  final String company;
  final DateTime createdAt;
  final DateTime updatedAt;
  const StoredProfile({
    required this.localId,
    required this.name,
    required this.company,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<String>(localId);
    map['name'] = Variable<String>(name);
    map['company'] = Variable<String>(company);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalProfilesCompanion toCompanion(bool nullToAbsent) {
    return LocalProfilesCompanion(
      localId: Value(localId),
      name: Value(name),
      company: Value(company),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredProfile(
      localId: serializer.fromJson<String>(json['localId']),
      name: serializer.fromJson<String>(json['name']),
      company: serializer.fromJson<String>(json['company']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<String>(localId),
      'name': serializer.toJson<String>(name),
      'company': serializer.toJson<String>(company),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredProfile copyWith({
    String? localId,
    String? name,
    String? company,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StoredProfile(
    localId: localId ?? this.localId,
    name: name ?? this.name,
    company: company ?? this.company,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredProfile copyWithCompanion(LocalProfilesCompanion data) {
    return StoredProfile(
      localId: data.localId.present ? data.localId.value : this.localId,
      name: data.name.present ? data.name.value : this.name,
      company: data.company.present ? data.company.value : this.company,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredProfile(')
          ..write('localId: $localId, ')
          ..write('name: $name, ')
          ..write('company: $company, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(localId, name, company, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredProfile &&
          other.localId == this.localId &&
          other.name == this.name &&
          other.company == this.company &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalProfilesCompanion extends UpdateCompanion<StoredProfile> {
  final Value<String> localId;
  final Value<String> name;
  final Value<String> company;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalProfilesCompanion({
    this.localId = const Value.absent(),
    this.name = const Value.absent(),
    this.company = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalProfilesCompanion.insert({
    required String localId,
    required String name,
    required String company,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : localId = Value(localId),
       name = Value(name),
       company = Value(company),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<StoredProfile> custom({
    Expression<String>? localId,
    Expression<String>? name,
    Expression<String>? company,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (name != null) 'name': name,
      if (company != null) 'company': company,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalProfilesCompanion copyWith({
    Value<String>? localId,
    Value<String>? name,
    Value<String>? company,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalProfilesCompanion(
      localId: localId ?? this.localId,
      name: name ?? this.name,
      company: company ?? this.company,
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalProfilesCompanion(')
          ..write('localId: $localId, ')
          ..write('name: $name, ')
          ..write('company: $company, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
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
  @override
  List<GeneratedColumn> get $columns => [
    localId,
    commercialCode,
    name,
    startsOn,
    endsOn,
    active,
    deleted,
    contentFileIdsJson,
    createdAt,
    updatedAt,
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
    );
  }

  @override
  $LocalEventsTable createAlias(String alias) {
    return $LocalEventsTable(attachedDatabase, alias);
  }
}

class StoredEvent extends DataClass implements Insertable<StoredEvent> {
  final String localId;
  final String? commercialCode;
  final String name;
  final DateTime startsOn;
  final DateTime endsOn;
  final bool active;
  final bool deleted;
  final String contentFileIdsJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  const StoredEvent({
    required this.localId,
    this.commercialCode,
    required this.name,
    required this.startsOn,
    required this.endsOn,
    required this.active,
    required this.deleted,
    required this.contentFileIdsJson,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<String>(localId);
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
    return map;
  }

  LocalEventsCompanion toCompanion(bool nullToAbsent) {
    return LocalEventsCompanion(
      localId: Value(localId),
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
    );
  }

  factory StoredEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredEvent(
      localId: serializer.fromJson<String>(json['localId']),
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
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<String>(localId),
      'commercialCode': serializer.toJson<String?>(commercialCode),
      'name': serializer.toJson<String>(name),
      'startsOn': serializer.toJson<DateTime>(startsOn),
      'endsOn': serializer.toJson<DateTime>(endsOn),
      'active': serializer.toJson<bool>(active),
      'deleted': serializer.toJson<bool>(deleted),
      'contentFileIdsJson': serializer.toJson<String>(contentFileIdsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredEvent copyWith({
    String? localId,
    Value<String?> commercialCode = const Value.absent(),
    String? name,
    DateTime? startsOn,
    DateTime? endsOn,
    bool? active,
    bool? deleted,
    String? contentFileIdsJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StoredEvent(
    localId: localId ?? this.localId,
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
  );
  StoredEvent copyWithCompanion(LocalEventsCompanion data) {
    return StoredEvent(
      localId: data.localId.present ? data.localId.value : this.localId,
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
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredEvent(')
          ..write('localId: $localId, ')
          ..write('commercialCode: $commercialCode, ')
          ..write('name: $name, ')
          ..write('startsOn: $startsOn, ')
          ..write('endsOn: $endsOn, ')
          ..write('active: $active, ')
          ..write('deleted: $deleted, ')
          ..write('contentFileIdsJson: $contentFileIdsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localId,
    commercialCode,
    name,
    startsOn,
    endsOn,
    active,
    deleted,
    contentFileIdsJson,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredEvent &&
          other.localId == this.localId &&
          other.commercialCode == this.commercialCode &&
          other.name == this.name &&
          other.startsOn == this.startsOn &&
          other.endsOn == this.endsOn &&
          other.active == this.active &&
          other.deleted == this.deleted &&
          other.contentFileIdsJson == this.contentFileIdsJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalEventsCompanion extends UpdateCompanion<StoredEvent> {
  final Value<String> localId;
  final Value<String?> commercialCode;
  final Value<String> name;
  final Value<DateTime> startsOn;
  final Value<DateTime> endsOn;
  final Value<bool> active;
  final Value<bool> deleted;
  final Value<String> contentFileIdsJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalEventsCompanion({
    this.localId = const Value.absent(),
    this.commercialCode = const Value.absent(),
    this.name = const Value.absent(),
    this.startsOn = const Value.absent(),
    this.endsOn = const Value.absent(),
    this.active = const Value.absent(),
    this.deleted = const Value.absent(),
    this.contentFileIdsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalEventsCompanion.insert({
    required String localId,
    this.commercialCode = const Value.absent(),
    required String name,
    required DateTime startsOn,
    required DateTime endsOn,
    this.active = const Value.absent(),
    this.deleted = const Value.absent(),
    this.contentFileIdsJson = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : localId = Value(localId),
       name = Value(name),
       startsOn = Value(startsOn),
       endsOn = Value(endsOn),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<StoredEvent> custom({
    Expression<String>? localId,
    Expression<String>? commercialCode,
    Expression<String>? name,
    Expression<DateTime>? startsOn,
    Expression<DateTime>? endsOn,
    Expression<bool>? active,
    Expression<bool>? deleted,
    Expression<String>? contentFileIdsJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
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
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalEventsCompanion copyWith({
    Value<String>? localId,
    Value<String?>? commercialCode,
    Value<String>? name,
    Value<DateTime>? startsOn,
    Value<DateTime>? endsOn,
    Value<bool>? active,
    Value<bool>? deleted,
    Value<String>? contentFileIdsJson,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalEventsCompanion(
      localId: localId ?? this.localId,
      commercialCode: commercialCode ?? this.commercialCode,
      name: name ?? this.name,
      startsOn: startsOn ?? this.startsOn,
      endsOn: endsOn ?? this.endsOn,
      active: active ?? this.active,
      deleted: deleted ?? this.deleted,
      contentFileIdsJson: contentFileIdsJson ?? this.contentFileIdsJson,
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalEventsCompanion(')
          ..write('localId: $localId, ')
          ..write('commercialCode: $commercialCode, ')
          ..write('name: $name, ')
          ..write('startsOn: $startsOn, ')
          ..write('endsOn: $endsOn, ')
          ..write('active: $active, ')
          ..write('deleted: $deleted, ')
          ..write('contentFileIdsJson: $contentFileIdsJson, ')
          ..write('createdAt: $createdAt, ')
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
  final DateTime createdAt;
  final DateTime updatedAt;
  const StoredLead({
    required this.localId,
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
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<String>(localId);
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
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalLeadsCompanion toCompanion(bool nullToAbsent) {
    return LocalLeadsCompanion(
      localId: Value(localId),
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
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<String>(localId),
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
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredLead copyWith({
    String? localId,
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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StoredLead(
    localId: localId ?? this.localId,
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
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredLead copyWithCompanion(LocalLeadsCompanion data) {
    return StoredLead(
      localId: data.localId.present ? data.localId.value : this.localId,
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
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredLead(')
          ..write('localId: $localId, ')
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
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    localId,
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
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredLead &&
          other.localId == this.localId &&
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
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalLeadsCompanion extends UpdateCompanion<StoredLead> {
  final Value<String> localId;
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
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalLeadsCompanion({
    this.localId = const Value.absent(),
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
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalLeadsCompanion.insert({
    required String localId,
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
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
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
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalLeadsCompanion copyWith({
    Value<String>? localId,
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
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalLeadsCompanion(
      localId: localId ?? this.localId,
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalProfilesTable localProfiles = $LocalProfilesTable(this);
  late final $LocalEventsTable localEvents = $LocalEventsTable(this);
  late final $LocalLeadsTable localLeads = $LocalLeadsTable(this);
  late final $LocalLeadMediaTable localLeadMedia = $LocalLeadMediaTable(this);
  late final $LocalPreferencesTable localPreferences = $LocalPreferencesTable(
    this,
  );
  late final Index leadEventIdx = Index(
    'lead_event_idx',
    'CREATE INDEX lead_event_idx ON local_leads (event_local_id)',
  );
  late final Index leadCapturedIdx = Index(
    'lead_captured_idx',
    'CREATE INDEX lead_captured_idx ON local_leads (captured_at)',
  );
  late final Index mediaLeadIdx = Index(
    'media_lead_idx',
    'CREATE INDEX media_lead_idx ON local_lead_media (lead_local_id)',
  );
  late final ProfilePreferencesDao profilePreferencesDao =
      ProfilePreferencesDao(this as AppDatabase);
  late final EventDao eventDao = EventDao(this as AppDatabase);
  late final LeadDao leadDao = LeadDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localProfiles,
    localEvents,
    localLeads,
    localLeadMedia,
    localPreferences,
    leadEventIdx,
    leadCapturedIdx,
    mediaLeadIdx,
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
      required String name,
      required String company,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LocalProfilesTableUpdateCompanionBuilder =
    LocalProfilesCompanion Function({
      Value<String> localId,
      Value<String> name,
      Value<String> company,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
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

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get company =>
      $composableBuilder(column: $table.company, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
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
                Value<String> name = const Value.absent(),
                Value<String> company = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProfilesCompanion(
                localId: localId,
                name: name,
                company: company,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localId,
                required String name,
                required String company,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalProfilesCompanion.insert(
                localId: localId,
                name: name,
                company: company,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
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
      Value<String?> commercialCode,
      required String name,
      required DateTime startsOn,
      required DateTime endsOn,
      Value<bool> active,
      Value<bool> deleted,
      Value<String> contentFileIdsJson,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LocalEventsTableUpdateCompanionBuilder =
    LocalEventsCompanion Function({
      Value<String> localId,
      Value<String?> commercialCode,
      Value<String> name,
      Value<DateTime> startsOn,
      Value<DateTime> endsOn,
      Value<bool> active,
      Value<bool> deleted,
      Value<String> contentFileIdsJson,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
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
                Value<String?> commercialCode = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> startsOn = const Value.absent(),
                Value<DateTime> endsOn = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String> contentFileIdsJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalEventsCompanion(
                localId: localId,
                commercialCode: commercialCode,
                name: name,
                startsOn: startsOn,
                endsOn: endsOn,
                active: active,
                deleted: deleted,
                contentFileIdsJson: contentFileIdsJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localId,
                Value<String?> commercialCode = const Value.absent(),
                required String name,
                required DateTime startsOn,
                required DateTime endsOn,
                Value<bool> active = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String> contentFileIdsJson = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalEventsCompanion.insert(
                localId: localId,
                commercialCode: commercialCode,
                name: name,
                startsOn: startsOn,
                endsOn: endsOn,
                active: active,
                deleted: deleted,
                contentFileIdsJson: contentFileIdsJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
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
typedef $$LocalLeadsTableCreateCompanionBuilder = LocalLeadsCompanion Function({
  required String localId,
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
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$LocalLeadsTableUpdateCompanionBuilder = LocalLeadsCompanion Function({
  Value<String> localId,
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
          PrefetchHooks Function({bool eventLocalId, bool localLeadMediaRefs})
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
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalLeadsCompanion(
                localId: localId,
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
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localId,
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
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalLeadsCompanion.insert(
                localId: localId,
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
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LocalLeadsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({eventLocalId = false, localLeadMediaRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
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
      PrefetchHooks Function({bool eventLocalId, bool localLeadMediaRefs})
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
                  e.readTable(table),
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
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalProfilesTableTableManager get localProfiles =>
      $$LocalProfilesTableTableManager(_db, _db.localProfiles);
  $$LocalEventsTableTableManager get localEvents =>
      $$LocalEventsTableTableManager(_db, _db.localEvents);
  $$LocalLeadsTableTableManager get localLeads =>
      $$LocalLeadsTableTableManager(_db, _db.localLeads);
  $$LocalLeadMediaTableTableManager get localLeadMedia =>
      $$LocalLeadMediaTableTableManager(_db, _db.localLeadMedia);
  $$LocalPreferencesTableTableManager get localPreferences =>
      $$LocalPreferencesTableTableManager(_db, _db.localPreferences);
}
