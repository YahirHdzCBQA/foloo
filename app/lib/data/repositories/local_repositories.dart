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
import 'package:path/path.dart' as p;

import '../../models/app_event.dart';
import '../../models/content_file.dart';
import '../../models/email_template.dart';
import '../../models/email_delivery_error.dart';
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

/// Owner-scoped local-first template persistence (PLT-06, SYN-01).
class EmailTemplateRepository {
  EmailTemplateRepository(this._database, {SyncStore? syncStore})
    : _syncStore = syncStore ?? SyncStore(_database);

  final AppDatabase _database;
  final SyncStore _syncStore;

  Future<List<EmailTemplateData>> list(String ownerSub) async =>
      (await _database.emailTemplateDao.listForOwner(ownerSub))
          .map(
            (row) => EmailTemplateData(
              origin: row.originKind,
              language: row.languageCode,
              subject: row.subject,
              body: row.body,
              signature: row.signature,
            ),
          )
          .toList();

  Future<void> save(String ownerSub, EmailTemplateData template) async {
    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      await _database.emailTemplateDao.upsert(
        LocalEmailTemplatesCompanion.insert(
          ownerUserId: ownerSub,
          originKind: template.origin,
          languageCode: template.language,
          subject: template.subject,
          body: template.body,
          signature: template.signature,
          updatedAt: now,
          syncState: const Value('local'),
        ),
      );
      await _syncStore.enqueue(
        ownerSub: ownerSub,
        entityType: SyncEntityType.emailTemplate,
        entityId: template.key,
        action: 'upsert',
        payload: template.toSyncPayload(),
        now: now,
      );
    });
  }
}

/// Persists immutable local follow-ups and explicit send intentions (SAL-*).
class EmailDeliveryRepository {
  EmailDeliveryRepository(this._database, {SyncStore? syncStore})
    : _syncStore = syncStore ?? SyncStore(_database);

  final AppDatabase _database;
  final SyncStore _syncStore;

  Future<List<StoredEmailFollowUp>> list(String owner) =>
      _database.emailDeliveryDao.followUps(owner);

  Future<List<StoredEmailSendIntent>> intents(String owner) =>
      _database.emailDeliveryDao.intents(owner);

  Future<void> saveConnection({
    required String owner,
    required String connectionId,
    required String provider,
    required String senderAddress,
    required String status,
  }) => _database.emailDeliveryDao.saveConnection(
    LocalEmailConnectionsCompanion.insert(
      ownerUserId: owner,
      connectionId: connectionId,
      provider: provider,
      senderAddress: senderAddress,
      status: status,
      updatedAt: DateTime.now().toUtc(),
    ),
  );

  Future<StoredEmailFollowUp?> prepareForLead({
    required String owner,
    required String leadId,
    required LeadDraft lead,
    required DemoProfile seller,
    required String language,
  }) async {
    if (lead.email.trim().isEmpty) return null;
    final templates = await _database.emailTemplateDao.listForOwner(owner);
    final origin = lead.originKind.name;
    final stored = templates.where(
      (item) => item.originKind == origin && item.languageCode == language,
    );
    final isEnglish = language == 'en';
    final subjectTemplate = stored.isNotEmpty
        ? stored.first.subject
        : (isEnglish
              ? 'Following up, {nombre}'
              : 'Damos seguimiento, {nombre}');
    final bodyTemplate = stored.isNotEmpty
        ? stored.first.body
        : (isEnglish
              ? 'Hi {nombre},\n\nIt was great meeting you at ${origin == 'event' ? '{evento}' : '{lugar}'} and having the opportunity to talk.\n\nI\'m sharing {contenido} as a follow-up to our conversation.\n\nFeel free to reach out if you have any questions. I hope we can stay in touch.'
              : 'Hola {nombre},\n\nFue un gusto conocerte en ${origin == 'event' ? '{evento}' : '{lugar}'} y poder platicar contigo.\n\nTe comparto {contenido}, como seguimiento a nuestra conversación.\n\nQuedo pendiente y espero que podamos seguir en contacto.');
    final signatureTemplate = stored.isNotEmpty
        ? stored.first.signature
        : (isEnglish
              ? 'Best,\n{nombreVendedor}\n{empresaVendedor}'
              : 'Saludos,\n{nombreVendedor}\n{empresaVendedor}');
    String render(String source) => source
        .replaceAll('{nombre}', lead.name)
        .replaceAll('{apellido}', lead.lastName)
        .replaceAll('{empresa}', lead.company)
        .replaceAll('{puesto}', lead.role)
        .replaceAll('{evento}', lead.eventName ?? '')
        .replaceAll('{lugar}', lead.place ?? '')
        .replaceAll('{contenido}', lead.contentNames.join(', '))
        .replaceAll('{nombreVendedor}', seller.name)
        .replaceAll('{empresaVendedor}', seller.company);
    var renderedBody = render(bodyTemplate);
    final context = lead.originKind == LeadOriginKind.event
        ? lead.eventName
        : lead.place;
    if (context?.trim().isEmpty ?? true) {
      renderedBody = renderedBody
          .split('\n')
          .where(
            (line) => isEnglish
                ? !line.startsWith('It was great meeting you at ')
                : !line.startsWith('Fue un gusto conocerte en '),
          )
          .join('\n');
    }
    if (lead.contentNames.isEmpty) {
      renderedBody = renderedBody
          .split('\n')
          .where(
            (line) => isEnglish
                ? !line.startsWith("I'm sharing ")
                : !line.startsWith('Te comparto '),
          )
          .join('\n');
    }
    final renderedSubject = render(subjectTemplate)
        .replaceAll(RegExp(r'[\r\n]+'), ' ')
        .replaceFirst(RegExp(r',\s*$'), '')
        .trim();
    final id = _defaultLocalId();
    final now = DateTime.now().toUtc();
    final plain =
        '${renderedBody.trim()}\n\n${render(signatureTemplate).trim()}';
    await _database.transaction(() async {
      await _database.emailDeliveryDao.saveFollowUp(
        LocalEmailFollowUpsCompanion.insert(
          localId: id,
          ownerUserId: owner,
          leadLocalId: leadId,
          recipientAddress: lead.email.trim(),
          subject: renderedSubject,
          plainBody: plain,
          htmlBody: plain
              .split('\n')
              .map(
                (line) => line.isEmpty
                    ? '<br>'
                    : '<p>${const HtmlEscape().convert(line)}</p>',
              )
              .join(),
          contentFileIdsJson: Value(jsonEncode(lead.contentFileIds)),
          contentNamesJson: Value(jsonEncode(lead.contentNames)),
          languageCode: language,
          preparedAt: now,
        ),
      );
    });
    return _database.emailDeliveryDao.followUpById(owner, id);
  }

  Future<StoredEmailFollowUp?> forLead(String owner, String leadId) =>
      _database.emailDeliveryDao.followUpForLead(owner, leadId);

  Future<String> confirm({
    required String owner,
    required String followUpId,
    List<String> omittedContentIds = const [],
    String? parentIntentId,
    String? intentId,
    String? subject,
    String? plainBody,
  }) async {
    final id = intentId ?? _defaultLocalId();
    final now = DateTime.now().toUtc();
    final connection = await _database.emailDeliveryDao.connectionForOwner(
      owner,
    );
    final followUp = await _database.emailDeliveryDao.followUpById(
      owner,
      followUpId,
    );
    if (followUp == null) throw StateError('Email follow-up not found.');
    final finalSubject = (subject ?? followUp.subject).trim();
    final finalPlainBody = (plainBody ?? followUp.plainBody).trim();
    final finalHtmlBody = finalPlainBody
        .split('\n')
        .map(
          (line) => line.isEmpty
              ? '<br>'
              : '<p>${const HtmlEscape().convert(line)}</p>',
        )
        .join();
    await _database.transaction(() async {
      await _database.emailDeliveryDao.updatePreparedFollowUp(
        owner,
        followUpId,
        subject: finalSubject,
        plainBody: finalPlainBody,
        htmlBody: finalHtmlBody,
      );
      if (followUp.syncState != 'synced' &&
          !await _syncStore.hasPending(
            owner,
            SyncEntityType.emailFollowUp,
            followUpId,
          )) {
        await _syncStore.enqueue(
          ownerSub: owner,
          entityType: SyncEntityType.emailFollowUp,
          entityId: followUpId,
          action: 'create',
          payload: {
            'id': followUpId,
            'leadId': followUp.leadLocalId,
            'language': followUp.languageCode,
            'subject': finalSubject,
            'plainBody': finalPlainBody,
            'htmlBody': finalHtmlBody,
          },
          now: now,
        );
      }
      await _database.emailDeliveryDao.saveIntent(
        LocalEmailSendIntentsCompanion.insert(
          localId: id,
          ownerUserId: owner,
          followUpLocalId: followUpId,
          connectionId: Value(connection?.connectionId),
          senderAddress: Value(connection?.senderAddress),
          omittedContentIdsJson: Value(jsonEncode(omittedContentIds)),
          parentIntentId: Value(parentIntentId),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await _syncStore.enqueue(
        ownerSub: owner,
        entityType: SyncEntityType.emailSendIntent,
        entityId: id,
        action: parentIntentId == null ? 'confirm' : 'resend',
        payload: {
          'intentId': id,
          'followUpId': followUpId,
          'omittedContentIds': omittedContentIds,
          'parentIntentId': ?parentIntentId,
        },
        now: now,
      );
    });
    return id;
  }

  Future<void> retry({
    required String owner,
    required StoredEmailSendIntent intent,
  }) async {
    if (isTerminalEmailDeliveryError(intent.errorCode)) return;
    final now = DateTime.now().toUtc();
    await _database.emailDeliveryDao.updateIntentState(
      owner,
      intent.localId,
      'pending',
      intent.attemptCount,
      null,
      now,
    );
    await _syncStore.enqueue(
      ownerSub: owner,
      entityType: SyncEntityType.emailSendIntent,
      entityId: intent.localId,
      action: 'retry',
      payload: {'intentId': intent.localId},
      now: now,
    );
  }

  Future<void> cancelAttachmentDecision({
    required String owner,
    required StoredEmailSendIntent intent,
  }) async {
    final now = DateTime.now().toUtc();
    await _database.emailDeliveryDao.updateIntentState(
      owner,
      intent.localId,
      'pending',
      intent.attemptCount,
      'cancellation_pending',
      now,
    );
    await _syncStore.enqueue(
      ownerSub: owner,
      entityType: SyncEntityType.emailSendIntent,
      entityId: intent.localId,
      action: 'cancel',
      payload: {'intentId': intent.localId},
      now: now,
    );
  }
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

  /// Resolves the current owner-scoped name, including a soft-deleted event.
  /// REG-05: Lead snapshots are fallback text, not the relation's authority.
  Future<String?> nameForId(String userId, String eventId) async =>
      (await _database.eventDao.byId(userId, eventId))?.name;

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
      if (previous != null && previous.deleted) {
        throw StateError('Cannot edit a deleted event.');
      }
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
          remoteRevision: Value(previous?.remoteRevision),
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
      } else if (previous.name != event.name ||
          previous.startsOn != event.startsOn.toUtc() ||
          previous.endsOn != event.endsOn.toUtc()) {
        final payload = <String, Object?>{
          'revision': previous.remoteRevision ?? 1,
          'name': event.name,
          'startsAt': event.startsOn.toUtc().toIso8601String(),
          'endsAt': event.endsOn.toUtc().toIso8601String(),
        };
        final operations = await _database.syncDao.forEntity(
          userId,
          SyncEntityType.event.name,
          event.id,
        );
        final creates = operations.where((item) => item.action == 'create');
        if (creates.isNotEmpty) {
          final create = creates.first;
          final original = (jsonDecode(create.payloadJson) as Map)
              .cast<String, Object?>();
          original.addAll(payload);
          original.remove('revision');
          await _database.syncDao.repairFailedPayload(
            create.operationId,
            jsonEncode(original),
            now,
          );
        } else {
          final updates = operations.where(
            (item) => item.action == 'update' && item.status != 'syncing',
          );
          if (updates.isNotEmpty) {
            await _database.syncDao.repairFailedPayload(
              updates.first.operationId,
              jsonEncode(payload),
              now,
            );
          } else {
            await _syncStore.enqueue(
              ownerSub: userId,
              entityType: SyncEntityType.event,
              entityId: event.id,
              action: 'update',
              payload: payload,
              now: now,
            );
          }
        }
        await _database.eventDao.upsert(
          LocalEventsCompanion.insert(
            localId: event.id,
            ownerUserId: Value(userId),
            commercialCode: Value(previous.commercialCode),
            name: event.name,
            startsOn: event.startsOn.toUtc(),
            endsOn: event.endsOn.toUtc(),
            active: Value(makeActive || event.active),
            deleted: const Value(false),
            contentFileIdsJson: Value(
              jsonEncode(event.contentFileIds.toList()),
            ),
            createdAt: previous.createdAt,
            updatedAt: now,
            syncState: const Value('pending'),
            remoteRevision: Value(previous.remoteRevision),
          ),
        );
      }
    });
  }

  Future<void> delete(String userId, AppEvent event) async {
    await _database.transaction(() async {
      final stored = await _database.eventDao.byId(userId, event.id);
      if (stored == null || stored.deleted) return;
      final now = DateTime.now().toUtc();
      await _database.eventDao.softDelete(userId, event.id, now);
      await _syncStore.enqueue(
        ownerSub: userId,
        entityType: SyncEntityType.event,
        entityId: event.id,
        action: 'delete',
        payload: {'revision': stored.remoteRevision ?? 1},
        now: now,
      );
    });
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

/// Owns private PDF copies and owner-scoped metadata/outbox (CON-01–CON-10).
class ContentRepository {
  ContentRepository(this._database, this._storage, {SyncStore? syncStore})
    : _syncStore = syncStore ?? SyncStore(_database);

  static const maxPdfBytes = 25000000;
  final AppDatabase _database;
  final PrivateMediaStorage _storage;
  final SyncStore _syncStore;

  Future<List<ContentFile>> list(String owner) async {
    final rows = await _database.contentDao.list(owner);
    return Future.wait(rows.map(_fromStored));
  }

  Future<ContentFile> _fromStored(StoredContentFile row) async {
    final path = row.localPath == null
        ? null
        : await _storage.resolveExistingPath(row.localPath!);
    return ContentFile(
      id: row.localId,
      displayName: row.displayName,
      fileName: row.fileName,
      byteSize: row.byteSize,
      sizeLabel: _sizeLabel(row.byteSize),
      localPath: path,
      allEvents: row.allEvents,
      eventIds: (jsonDecode(row.eventIdsJson) as List).cast<String>().toSet(),
    );
  }

  String _sizeLabel(int bytes) => bytes >= 1000000
      ? '${(bytes / 1000000).toStringAsFixed(1)} MB'
      : '${(bytes / 1000).ceil()} KB';

  Future<ContentFile> import(String owner, ContentFile draft) async {
    if (!Uuid.isValidUUID(fromString: draft.id)) {
      throw const FormatException('Invalid content ID.');
    }
    if (draft.displayName.trim().isEmpty ||
        draft.displayName.length > 160 ||
        draft.fileName.length > 255) {
      throw const FormatException('Invalid content metadata.');
    }
    if (!draft.fileName.toLowerCase().endsWith('.pdf') ||
        draft.localPath == null) {
      throw const FormatException('A PDF file is required.');
    }
    final source = File(draft.localPath!);
    final bytes = await source.length();
    if (bytes == 0 || bytes > maxPdfBytes) {
      throw const FormatException('PDF exceeds the 25 MB limit.');
    }
    final handle = await source.open();
    try {
      final signature = await handle.read(5);
      if (signature.length != 5 || String.fromCharCodes(signature) != '%PDF-') {
        throw const FormatException('Invalid PDF signature.');
      }
    } finally {
      await handle.close();
    }
    await _validateEvents(owner, draft.eventIds);
    if (await _database.contentDao.byAnyId(draft.id) != null) {
      throw StateError('Content ID already exists.');
    }
    final directory = Directory(p.join(_storage.root.path, 'content'));
    await directory.create(recursive: true);
    final destination = File(p.join(directory.path, '${draft.id}.pdf'));
    final staging = File('${destination.path}.partial');
    try {
      await source.copy(staging.path);
      if (await staging.length() != bytes) {
        throw const FileSystemException('Incomplete PDF copy.');
      }
      await staging.rename(destination.path);
      final now = DateTime.now().toUtc();
      await _database.transaction(() async {
        await _database.contentDao.upsert(
          LocalContentFilesCompanion.insert(
            localId: draft.id,
            ownerUserId: owner,
            displayName: draft.displayName,
            fileName: draft.fileName,
            byteSize: bytes,
            localPath: Value(destination.path),
            allEvents: Value(draft.allEvents),
            eventIdsJson: Value(jsonEncode(draft.eventIds.toList())),
            createdAt: now,
            updatedAt: now,
          ),
        );
        await _syncStore.enqueue(
          ownerSub: owner,
          entityType: SyncEntityType.content,
          entityId: draft.id,
          action: 'create',
          payload: _payload(draft, bytes),
          now: now,
        );
        await _syncStore.enqueue(
          ownerSub: owner,
          entityType: SyncEntityType.contentBinary,
          entityId: draft.id,
          action: 'upload',
          payload: {
            'contentId': draft.id,
            'byteSize': bytes,
            'contentType': 'application/pdf',
          },
          now: now,
        );
      });
      return (await _fromStored(
        (await _database.contentDao.byId(owner, draft.id))!,
      ));
    } catch (_) {
      if (await staging.exists()) await staging.delete();
      if (await destination.exists() &&
          await _database.contentDao.byId(owner, draft.id) == null) {
        await destination.delete();
      }
      rethrow;
    }
  }

  Map<String, Object?> _payload(ContentFile file, int size, {int? revision}) =>
      {
        if (revision == null) 'id': file.id else 'revision': revision,
        'displayName': file.displayName,
        'fileName': file.fileName,
        'byteSize': size,
        'allEvents': file.allEvents,
        'eventIds': file.eventIds.toList(),
      };

  Future<void> _validateEvents(String owner, Set<String> ids) async {
    for (final id in ids) {
      final event = await _database.eventDao.byId(owner, id);
      if (event == null || event.deleted) {
        throw const FormatException('Unavailable event.');
      }
    }
  }

  Future<ContentFile> update(String owner, ContentFile file) async {
    if (file.displayName.trim().isEmpty || file.displayName.length > 160) {
      throw const FormatException('Invalid display name.');
    }
    final previous = await _database.contentDao.byId(owner, file.id);
    if (previous == null || previous.deleted) {
      throw StateError('Content is unavailable.');
    }
    await _validateEvents(
      owner,
      file.eventIds.difference(
        (jsonDecode(previous.eventIdsJson) as List).cast<String>().toSet(),
      ),
    );
    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      await _database.contentDao.upsert(
        LocalContentFilesCompanion.insert(
          localId: file.id,
          ownerUserId: owner,
          displayName: file.displayName,
          fileName: previous.fileName,
          byteSize: previous.byteSize,
          localPath: Value(previous.localPath),
          allEvents: Value(file.allEvents),
          eventIdsJson: Value(jsonEncode(file.eventIds.toList())),
          createdAt: previous.createdAt,
          updatedAt: now,
          remoteRevision: Value(previous.remoteRevision),
          uploadState: Value(previous.uploadState),
          syncState: const Value('pending'),
        ),
      );
      await _syncStore.enqueue(
        ownerSub: owner,
        entityType: SyncEntityType.content,
        entityId: file.id,
        action: 'update',
        payload: _payload(
          file,
          previous.byteSize,
          revision: previous.remoteRevision ?? 1,
        ),
        now: now,
      );
    });
    return _fromStored((await _database.contentDao.byId(owner, file.id))!);
  }

  Future<void> delete(String owner, ContentFile file) async {
    final previous = await _database.contentDao.byId(owner, file.id);
    if (previous == null || previous.deleted) return;
    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      await _database.contentDao.upsert(
        LocalContentFilesCompanion.insert(
          localId: file.id,
          ownerUserId: owner,
          displayName: previous.displayName,
          fileName: previous.fileName,
          byteSize: previous.byteSize,
          localPath: Value(previous.localPath),
          allEvents: Value(previous.allEvents),
          eventIdsJson: Value(previous.eventIdsJson),
          deleted: const Value(true),
          uploadState: Value(previous.uploadState),
          syncState: const Value('pending'),
          remoteRevision: Value(previous.remoteRevision),
          createdAt: previous.createdAt,
          updatedAt: now,
        ),
      );
      await _syncStore.enqueue(
        ownerSub: owner,
        entityType: SyncEntityType.content,
        entityId: file.id,
        action: 'delete',
        payload: {'revision': previous.remoteRevision ?? 1},
        now: now,
      );
    });
  }
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
            'contentFileIds': draft.contentFileIds,
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
              'capturedAt': item.createdAt.toUtc().toIso8601String(),
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

  /// Persists REG-07 fields first and queues an owner-scoped optimistic update.
  Future<void> updateDraft(
    String userId,
    SessionLead session,
    LeadDraft draft,
  ) async {
    final name = draft.name.trim();
    final company = draft.company.trim();
    final email = draft.email.trim();
    final phone = draft.phone.trim();
    if (name.isEmpty || company.isEmpty || (email.isEmpty && phone.isEmpty)) {
      throw ArgumentError('Lead name, company and contact are required.');
    }
    if (email.isNotEmpty &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      throw ArgumentError('Lead email is invalid.');
    }
    if (draft.originKind == LeadOriginKind.direct &&
        (draft.place?.trim().isEmpty ?? true)) {
      throw ArgumentError('Place is required for a direct lead.');
    }
    final stored = await _database.leadDao.byId(userId, session.localId);
    if (stored == null || stored.ownerUserId != userId) {
      throw StateError('Cannot update an unavailable lead.');
    }
    if (draft.originKind != LeadOriginKind.values.byName(stored.originKind) ||
        draft.eventLocalId != stored.eventLocalId) {
      throw StateError('Immutable lead identity fields cannot be changed.');
    }
    final now = DateTime.now().toUtc();
    final payload = <String, Object?>{
      'revision': stored.remoteRevision ?? 1,
      'firstName': draft.name,
      'lastName': draft.lastName.isEmpty ? null : draft.lastName,
      'position': draft.role.isEmpty ? null : draft.role,
      'company': draft.company,
      'email': draft.email.isEmpty ? null : draft.email,
      'phone': draft.phone.isEmpty ? null : draft.phone,
      'leadType': draft.type.name,
      'interest': draft.interest.name,
      'writtenNote': draft.note.isEmpty ? null : draft.note,
      'place': stored.originKind == LeadOriginKind.direct.name
          ? draft.place
          : null,
    };
    await _database.transaction(() async {
      await _database.leadDao.updateLead(
        stored.copyWith(
          name: draft.name,
          lastName: draft.lastName,
          role: draft.role,
          company: draft.company,
          email: draft.email,
          phone: draft.phone,
          leadType: draft.type.name,
          interestLevel: draft.interest.name,
          note: draft.note,
          place: Value(
            stored.originKind == LeadOriginKind.direct.name
                ? draft.place
                : stored.place,
          ),
          syncState: 'pending',
          updatedAt: now,
        ),
      );
      final operations = await _database.syncDao.forEntity(
        userId,
        SyncEntityType.lead.name,
        stored.localId,
      );
      final creates = operations.where(
        (operation) => operation.action == 'create',
      );
      if (creates.isNotEmpty) {
        final create = creates.first;
        final createPayload = (jsonDecode(create.payloadJson) as Map)
            .cast<String, Object?>();
        createPayload
          ..addAll(payload)
          ..remove('revision');
        await _database.syncDao.repairFailedPayload(
          create.operationId,
          jsonEncode(createPayload),
          now,
        );
        return;
      }
      final replaceable = operations.where(
        (operation) =>
            operation.action == 'update' && operation.status != 'syncing',
      );
      if (replaceable.isNotEmpty) {
        await _database.syncDao.repairFailedPayload(
          replaceable.first.operationId,
          jsonEncode(payload),
          now,
        );
        return;
      }
      await _syncStore.enqueue(
        ownerSub: userId,
        entityType: SyncEntityType.lead,
        entityId: stored.localId,
        action: 'update',
        payload: payload,
        now: now,
      );
    });
  }

  Future<void> reconcileMediaReferences() async {
    for (final media in await _database.leadDao.allMedia()) {
      final resolvedPath = await _mediaStorage.resolveExistingPath(
        media.localPath,
      );
      if (resolvedPath != null && resolvedPath != media.localPath) {
        await _database.leadDao.updateMediaLocalPath(
          media.localId,
          resolvedPath,
        );
      }
    }
  }

  Future<List<StoredLeadBundle>> _visibleBundles(
    String userId,
    List<StoredLeadBundle> bundles,
  ) async => bundles;

  Future<List<StoredLead>> _visibleRows(
    String userId,
    List<StoredLead> rows,
  ) async => rows;

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
    final leadState = switch (stored.syncState) {
      'enHoja' || 'synced' => SessionUploadState.synced,
      'retryable' => SessionUploadState.retryable,
      'syncing' => SessionUploadState.syncing,
      'failed' => SessionUploadState.failed,
      'conflict' => SessionUploadState.conflict,
      'pendiente' || 'pending' => SessionUploadState.pending,
      _ => SessionUploadState.local,
    };
    final visibleSyncState = leadState != SessionUploadState.synced
        ? leadState
        : mediaStates.contains('failed')
        ? SessionUploadState.syncedWithMediaError
        : mediaStates.contains('syncing')
        ? SessionUploadState.syncing
        : mediaStates.contains('retryable')
        ? SessionUploadState.retryable
        : mediaStates.any((state) => state != 'synced')
        ? SessionUploadState.syncedWithMediaPending
        : SessionUploadState.synced;
    return SessionLead(
      localId: stored.localId,
      folio: stored.commercialFolio,
      capturedAt: stored.capturedAt.toLocal(),
      uploadState: visibleSyncState,
      remoteRevision: stored.remoteRevision,
      capturedBy: stored.capturedBy,
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
       templates = EmailTemplateRepository(database),
       emailDelivery = EmailDeliveryRepository(database),
       globalPreferences = GlobalPreferencesRepository(database),
       events = EventRepository(database),
       content = ContentRepository(database, mediaStorage),
       leads = LeadRepository(database, mediaStorage),
       syncStore = SyncStore(database, mediaStorage: mediaStorage);

  final AppDatabase database;
  final PrivateMediaStorage mediaStorage;
  final bool deleteMediaOnClose;
  final ProfileRepository profiles;
  final PreferencesRepository preferences;
  final EmailTemplateRepository templates;
  final EmailDeliveryRepository emailDelivery;
  final GlobalPreferencesRepository globalPreferences;
  final EventRepository events;
  final ContentRepository content;
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
