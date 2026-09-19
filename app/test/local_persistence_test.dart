import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/auth/auth_repository.dart';
import 'package:foloo/auth/development_auth_service.dart';
import 'package:foloo/auth/drift_development_auth_store.dart';
import 'package:foloo/data/local/app_database.dart';
import 'package:foloo/data/local/private_media_storage.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/models/lead_draft.dart';
import 'package:foloo/sync/sync_models.dart';
import 'package:image/image.dart' as image_codec;

List<int> testJpeg() =>
    image_codec.encodeJpg(image_codec.Image(width: 2, height: 2));

List<int> testPng() =>
    image_codec.encodePng(image_codec.Image(width: 2, height: 2));

LeadDraft draft({
  String name = 'Mariana',
  String company = 'Grupo Lácteo',
  String? eventId = 'event-1',
  String? cardPath,
  String? audioPath,
  List<String> referencePaths = const [],
  DateTime? ignoredCapturedAt,
}) => LeadDraft(
  name: name,
  lastName: 'Sandoval',
  role: 'Compras',
  company: company,
  email: 'mariana@example.com',
  phone: '+52 81 0000 0000',
  type: LeadType.customer,
  interest: InterestLevel.high,
  note: 'Solicita seguimiento.',
  originKind: LeadOriginKind.event,
  eventLocalId: eventId,
  eventName: 'Expo Uno',
  cardImageLocalPath: cardPath,
  audioLocalPath: audioPath,
  audioSeconds: audioPath == null ? 0 : 18,
  referenceImageLocalPaths: referencePaths,
);

AppEvent event({String name = 'Expo Uno'}) => AppEvent(
  id: 'event-1',
  name: name,
  startsOn: DateTime(2026, 8, 12),
  endsOn: DateTime(2026, 8, 14),
  active: true,
);

void main() {
  const userId = 'fake-user-a';
  late Directory temporary;
  late String databasePath;
  late Directory mediaRoot;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('foloo_persistence_');
    databasePath = '${temporary.path}/foloo.sqlite';
    mediaRoot = Directory('${temporary.path}/media');
  });

  tearDown(() async {
    if (await temporary.exists()) await temporary.delete(recursive: true);
  });

  AppDatabase openDatabase() => AppDatabase(NativeDatabase(File(databasePath)));

  test('lead saves, updates, queries and survives database reopen', () async {
    var database = openDatabase();
    final events = EventRepository(database);
    await events.save(userId, event(), makeActive: true);
    var sequence = 0;
    final leads = LeadRepository(
      database,
      PrivateMediaStorage(mediaRoot),
      idFactory: () => 'lead-${++sequence}',
    );

    await leads.saveDraft(
      userId,
      draft(name: 'Ana', company: 'Zeta'),
      capturedBy: const DemoProfile(name: 'Yahir', company: 'CBQA'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await leads.saveDraft(
      userId,
      draft(name: 'Beatriz', company: 'Alfa'),
      capturedBy: const DemoProfile(name: 'Yahir', company: 'CBQA'),
    );

    final listed = await leads.listAll(userId);
    expect(
      listed.map((item) => item.localId),
      unorderedEquals(['lead-2', 'lead-1']),
    );
    expect(listed.every((item) => item.folio == null), isTrue);
    expect(await leads.byEvent(userId, 'event-1'), hasLength(2));
    expect(await leads.byType(userId, LeadType.customer), hasLength(2));
    expect((await leads.search(userId, 'zeta')).single.name, 'Ana');

    final stored = (await leads.search(userId, 'Ana')).single;
    await leads.updateStructured(
      userId,
      stored.copyWith(phone: '+52 81 1111 1111'),
    );
    await database.close();

    database = openDatabase();
    final reopened = LeadRepository(database, PrivateMediaStorage(mediaRoot));
    final afterReopen = await reopened.listAll(userId);
    expect(afterReopen, hasLength(2));
    expect(
      afterReopen.singleWhere((item) => item.localId == 'lead-1').lead.phone,
      '+52 81 1111 1111',
    );
    await database.close();
  });

  test(
    'REG-07 edit updates create snapshot or queues optimistic PUT',
    () async {
      final database = openDatabase();
      await EventRepository(database).save(userId, event(), makeActive: true);
      final leads = LeadRepository(
        database,
        PrivateMediaStorage(mediaRoot),
        idFactory: () => '57d8ce9a-dcc4-4b78-8fd9-552c216a62a1',
      );
      final saved = await leads.saveDraft(
        userId,
        draft(),
        capturedBy: const DemoProfile(name: 'Yahir', company: 'CBQA'),
      );
      await leads.updateDraft(
        userId,
        saved,
        saved.lead.copyWith(phone: '+52 55 1111 2222'),
      );
      var operations = await database.syncDao.forEntity(
        userId,
        SyncEntityType.lead.name,
        saved.localId,
      );
      expect(operations.where((item) => item.action == 'update'), isEmpty);
      expect(
        jsonDecode(operations.single.payloadJson)['phone'],
        '+52 55 1111 2222',
      );

      await database.syncDao.completeCreatesForEntity(
        userId,
        SyncEntityType.lead.name,
        saved.localId,
      );
      await database.leadDao.markLeadSynced(userId, saved.localId, 7);
      final synced = (await leads.listAll(userId)).single;
      await leads.updateDraft(
        userId,
        synced,
        synced.lead.copyWith(note: 'Nota corregida'),
      );
      operations = await database.syncDao.forEntity(
        userId,
        SyncEntityType.lead.name,
        saved.localId,
      );
      final update = operations.single;
      expect(update.action, 'update');
      expect(jsonDecode(update.payloadJson)['revision'], 7);
      expect(jsonDecode(update.payloadJson)['writtenNote'], 'Nota corregida');
      expect((await leads.listAll(userId)).single.lead.note, 'Nota corregida');
      await database.close();
    },
  );

  test(
    'events and profile preferences survive reopen; delete is logical',
    () async {
      var database = openDatabase();
      var events = EventRepository(database);
      final profiles = ProfileRepository(
        database,
        idFactory: () => 'profile-1',
      );
      const preferences = <String, String>{'locale': 'en', 'themeMode': 'dark'};
      final settings = PreferencesRepository(database);

      await profiles.save(
        userId,
        const DemoProfile(name: 'Yahir Hernández', company: 'CBQA Solutions'),
      );
      for (final entry in preferences.entries) {
        await settings.write(userId, entry.key, entry.value);
      }
      await events.save(userId, event(), makeActive: true);
      await events.save(
        userId,
        event(name: 'Expo Renombrada').copyWith(
          startsOn: DateTime(2026, 9, 3),
          endsOn: DateTime(2026, 9, 6),
        ),
      );
      await database.close();

      database = openDatabase();
      events = EventRepository(database);
      final reopenedEvent = (await events.list(userId)).single;
      expect(reopenedEvent.name, 'Expo Renombrada');
      expect(reopenedEvent.startsOn, DateTime(2026, 9, 3));
      expect(reopenedEvent.endsOn, DateTime(2026, 9, 6));
      expect(
        (await ProfileRepository(database).load(userId))?.name,
        'Yahir Hernández',
      );
      expect(
        await PreferencesRepository(database).read(userId, 'locale'),
        'en',
      );

      await events.delete(userId, (await events.list(userId)).single);
      expect(await events.list(userId), isEmpty);
      expect(
        (await database.eventDao.byId(userId, 'event-1'))?.deleted,
        isTrue,
      );
      await database.close();
    },
  );

  test(
    'pending media metadata survives a temporarily unavailable local file',
    () async {
      final sourceCard = File('${temporary.path}/picker-card.jpg');
      final sourceAudio = File('${temporary.path}/recorder-note.m4a');
      await sourceCard.writeAsBytes(testJpeg());
      await sourceAudio.writeAsBytes([5, 6, 7, 8]);
      var database = openDatabase();
      await EventRepository(database).save(userId, event(), makeActive: true);
      var leads = LeadRepository(
        database,
        PrivateMediaStorage(mediaRoot),
        idFactory: () => 'lead-media',
      );

      final saved = await leads.saveDraft(
        userId,
        draft(cardPath: sourceCard.path, audioPath: sourceAudio.path),
        capturedBy: const DemoProfile(name: 'Yahir', company: 'CBQA'),
      );
      expect(saved.lead.cardImageLocalPath, isNot(sourceCard.path));
      expect(saved.lead.audioLocalPath, isNot(sourceAudio.path));
      expect(await File(saved.lead.cardImageLocalPath!).exists(), isTrue);
      expect(await File(saved.lead.audioLocalPath!).exists(), isTrue);
      await database.close();

      database = openDatabase();
      leads = LeadRepository(database, PrivateMediaStorage(mediaRoot));
      final recovered = (await leads.listAll(userId)).single;
      expect(await File(recovered.lead.cardImageLocalPath!).exists(), isTrue);
      expect(recovered.lead.audioSeconds, 18);

      await File(recovered.lead.audioLocalPath!).delete();
      await leads.reconcileMediaReferences();
      final coherent = (await leads.listAll(userId)).single;
      expect(coherent.lead.audioLocalPath, isNotNull);
      expect(coherent.lead.cardImageLocalPath, isNotNull);
      expect(await database.leadDao.mediaFor(saved.localId), hasLength(2));
      final managedOrphan = File('${mediaRoot.path}/voice_notes/orphan.m4a');
      await managedOrphan.parent.create(recursive: true);
      await managedOrphan.writeAsBytes([9]);
      final storage = PrivateMediaStorage(mediaRoot);
      await storage.deleteIfManaged(managedOrphan.path);
      await storage.deleteIfManaged(sourceCard.path);
      expect(await managedOrphan.exists(), isFalse);
      expect(await sourceCard.exists(), isTrue);
      await database.close();
    },
  );

  test(
    'CAP-22 reference images persist privately and survive reopen',
    () async {
      final sourceA = File('${temporary.path}/reference-a.jpg');
      final sourceB = File('${temporary.path}/reference-b.png');
      await sourceA.writeAsBytes(testJpeg());
      await sourceB.writeAsBytes(testPng());
      var database = openDatabase();
      await EventRepository(database).save(userId, event(), makeActive: true);
      var leads = LeadRepository(
        database,
        PrivateMediaStorage(mediaRoot),
        idFactory: () => 'lead-references',
      );

      final saved = await leads.saveDraft(
        userId,
        draft(referencePaths: [sourceA.path, sourceB.path]),
        capturedBy: const DemoProfile(name: 'Yahir', company: 'CBQA'),
      );
      expect(saved.lead.referenceImageLocalPaths, hasLength(2));
      expect(
        saved.lead.referenceImageLocalPaths.every(
          (path) => path.contains('reference_images'),
        ),
        isTrue,
      );
      expect(
        saved.lead.referenceImageLocalPaths.every(
          (path) => File(path).existsSync(),
        ),
        isTrue,
      );
      expect(
        saved.lead.referenceImageLocalPaths.every(
          (path) => path.endsWith('.jpg'),
        ),
        isTrue,
      );
      for (final path in saved.lead.referenceImageLocalPaths) {
        final bytes = await File(path).readAsBytes();
        expect(bytes.take(3), [0xff, 0xd8, 0xff]);
      }
      expect(await sourceB.exists(), isTrue);
      await database.close();

      database = openDatabase();
      leads = LeadRepository(database, PrivateMediaStorage(mediaRoot));
      final reopened = (await leads.listAll(userId)).single;
      expect(reopened.lead.referenceImageLocalPaths, hasLength(2));
      expect(
        reopened.lead.referenceImageLocalPaths.every(
          (path) => File(path).existsSync(),
        ),
        isTrue,
      );
      expect(
        (await database.leadDao.mediaFor(reopened.localId)).where(
          (media) => media.mediaType == LocalMediaType.referenceImage.name,
        ),
        hasLength(2),
      );
      await database.close();
    },
  );

  test('failed lead transaction removes newly copied media', () async {
    final source = File('${temporary.path}/picker-card.jpg');
    await source.writeAsBytes([1, 2, 3]);
    final database = openDatabase();
    final leads = LeadRepository(
      database,
      PrivateMediaStorage(mediaRoot),
      idFactory: () => 'lead-fails',
    );

    await expectLater(
      leads.saveDraft(
        userId,
        draft(eventId: 'missing-event', cardPath: source.path),
        capturedBy: const DemoProfile(name: 'Yahir', company: 'CBQA'),
      ),
      throwsA(anything),
    );
    expect(await leads.listAll(userId), isEmpty);
    final managedFiles = await mediaRoot.exists()
        ? await mediaRoot
              .list(recursive: true)
              .where((item) => item is File)
              .toList()
        : <FileSystemEntity>[];
    expect(managedFiles, isEmpty);
    await database.close();
  });

  test(
    'missing optional media does not discard an otherwise valid lead',
    () async {
      final database = openDatabase();
      await EventRepository(database).save(userId, event(), makeActive: true);
      final leads = LeadRepository(
        database,
        PrivateMediaStorage(mediaRoot),
        idFactory: () => 'lead-with-missing-media',
      );

      final saved = await leads.saveDraft(
        userId,
        draft(cardPath: '${temporary.path}/missing.jpg'),
        capturedBy: const DemoProfile(name: 'Yahir', company: 'CBQA'),
      );
      expect(saved.mediaIncomplete, isTrue);
      expect(saved.lead.cardImageLocalPath, isNull);
      expect(await leads.listAll(userId), hasLength(1));
      await database.close();
    },
  );

  test(
    'EVT-02 logical event deletion retains visible Leads without deleting rows',
    () async {
      final database = openDatabase();
      final events = EventRepository(database);
      final localEvent = event();
      await events.save(userId, localEvent, makeActive: true);
      final leads = LeadRepository(
        database,
        PrivateMediaStorage(mediaRoot),
        idFactory: () => 'lead-hidden',
      );
      await leads.saveDraft(
        userId,
        draft(),
        capturedBy: const DemoProfile(name: 'Yahir', company: 'CBQA'),
      );

      await events.delete(userId, localEvent);
      expect(await leads.listAll(userId), hasLength(1));
      expect(await leads.byEvent(userId, localEvent.id), isEmpty);
      expect(await database.leadDao.listAll(userId), hasLength(1));
      await database.close();
    },
  );

  test(
    'EVT-02 event update/delete survive restart with owner-scoped outbox',
    () async {
      var database = openDatabase();
      var events = EventRepository(database);
      final original = event();
      await events.save(userId, original);
      await database.syncDao.completeCreatesForEntity(
        userId,
        SyncEntityType.event.name,
        original.id,
      );
      await database.eventDao.markRemoteRevision(userId, original.id, 2);
      final corrected = original.copyWith(
        name: 'México · León · Exposición · Niñez · São Paulo',
      );
      await events.save(userId, corrected);
      var operation = (await database.syncDao.forEntity(
        userId,
        SyncEntityType.event.name,
        original.id,
      )).single;
      expect(operation.action, 'update');
      expect(jsonDecode(operation.payloadJson)['revision'], 2);
      await database.close();

      database = openDatabase();
      events = EventRepository(database);
      expect((await events.list(userId)).single.name, corrected.name);
      await events.delete(userId, corrected);
      expect(await events.list(userId), isEmpty);
      expect(
        (await database.syncDao.forEntity(
          userId,
          SyncEntityType.event.name,
          original.id,
        )).map((item) => item.action),
        containsAll(['update', 'delete']),
      );
      await database.close();

      database = openDatabase();
      events = EventRepository(database);
      expect(await events.list(userId), isEmpty);
      expect(
        (await database.eventDao.byId(userId, original.id))?.name,
        corrected.name,
      );
      expect(await events.list('another-owner'), isEmpty);
      await database.close();
    },
  );

  test('schema version is explicit and stable across reopen', () async {
    var database = openDatabase();
    expect(database.schemaVersion, 8);
    var version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 8);
    await database.close();

    database = openDatabase();
    version = await database.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 8);
    await database.close();
  });

  test(
    'AUT-08 ownership isolates and restores two users after reopen',
    () async {
      const userA = 'fake-user-a';
      const userB = 'fake-user-b';
      var database = openDatabase();
      var profiles = ProfileRepository(database);
      var events = EventRepository(database);
      var leads = LeadRepository(database, PrivateMediaStorage(mediaRoot));
      var preferences = PreferencesRepository(database);

      await profiles.save(
        userA,
        const DemoProfile(name: 'Seller A', company: 'Company A'),
      );
      await profiles.save(
        userB,
        const DemoProfile(name: 'Seller B', company: 'Company B'),
      );
      final eventA = event(name: 'Event A');
      final eventB = AppEvent(
        id: 'event-2',
        name: 'Event B',
        startsOn: DateTime(2026, 9, 1),
        endsOn: DateTime(2026, 9, 2),
        active: true,
      );
      await events.save(userA, eventA, makeActive: true);
      await events.save(userB, eventB, makeActive: true);
      await leads.saveDraft(
        userA,
        draft(name: 'Lead A'),
        capturedBy: const DemoProfile(name: 'Seller A', company: 'Company A'),
      );
      await leads.saveDraft(
        userB,
        draft(name: 'Lead B', eventId: 'event-2'),
        capturedBy: const DemoProfile(name: 'Seller B', company: 'Company B'),
      );
      await preferences.write(userA, 'themeMode', 'dark');
      await preferences.write(userB, 'themeMode', 'light');

      expect((await profiles.load(userA))?.name, 'Seller A');
      expect((await profiles.load(userB))?.name, 'Seller B');
      expect((await events.list(userA)).single.name, 'Event A');
      expect((await events.list(userB)).single.name, 'Event B');
      expect((await leads.listAll(userA)).single.lead.name, 'Lead A');
      expect((await leads.listAll(userB)).single.lead.name, 'Lead B');
      expect(await preferences.read(userA, 'themeMode'), 'dark');
      expect(await preferences.read(userB, 'themeMode'), 'light');
      await database.close();

      database = openDatabase();
      profiles = ProfileRepository(database);
      events = EventRepository(database);
      leads = LeadRepository(database, PrivateMediaStorage(mediaRoot));
      expect((await profiles.load(userA))?.name, 'Seller A');
      expect((await events.list(userA)).single.name, 'Event A');
      expect((await leads.listAll(userA)).single.lead.name, 'Lead A');
      expect((await leads.listAll(userA)).single.lead.name, isNot('Lead B'));
      await database.close();
    },
  );

  test(
    'development auth session survives database reopen without password',
    () async {
      var database = openDatabase();
      var auth = AuthRepository(
        DevelopmentAuthService(
          DriftDevelopmentAuthStore(GlobalPreferencesRepository(database)),
          userIdFactory: () => 'fake-user-a',
        ),
      );
      await auth.initialize();
      await auth.signIn(username: 'seller-a', password: 'temporary');
      expect(auth.state.user?.id, 'fake-user-a');
      await database.close();

      database = openDatabase();
      auth = AuthRepository(
        DevelopmentAuthService(
          DriftDevelopmentAuthStore(GlobalPreferencesRepository(database)),
        ),
      );
      await auth.initialize();
      expect(auth.state.user?.id, 'fake-user-a');
      await database.close();
    },
  );
}
