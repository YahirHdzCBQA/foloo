import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/data/local/app_database.dart';
import 'package:foloo/data/local/private_media_storage.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/models/lead_draft.dart';

LeadDraft draft({
  String name = 'Mariana',
  String company = 'Grupo Lácteo',
  String? eventId = 'event-1',
  String? cardPath,
  String? audioPath,
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
);

AppEvent event({String name = 'Expo Uno'}) => AppEvent(
  id: 'event-1',
  name: name,
  startsOn: DateTime(2026, 8, 12),
  endsOn: DateTime(2026, 8, 14),
  active: true,
);

void main() {
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
    await events.save(event(), makeActive: true);
    var sequence = 0;
    final leads = LeadRepository(
      database,
      PrivateMediaStorage(mediaRoot),
      idFactory: () => 'lead-${++sequence}',
    );

    await leads.saveDraft(
      draft(name: 'Ana', company: 'Zeta'),
      capturedBy: const DemoProfile(name: 'Yahir', company: 'CBQA'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await leads.saveDraft(
      draft(name: 'Beatriz', company: 'Alfa'),
      capturedBy: const DemoProfile(name: 'Yahir', company: 'CBQA'),
    );

    final listed = await leads.listAll();
    expect(listed.map((item) => item.localId), ['lead-2', 'lead-1']);
    expect(listed.every((item) => item.folio == null), isTrue);
    expect(await leads.byEvent('event-1'), hasLength(2));
    expect(await leads.byType(LeadType.customer), hasLength(2));
    expect((await leads.search('zeta')).single.name, 'Ana');

    final stored = (await leads.search('Ana')).single;
    await leads.updateStructured(stored.copyWith(phone: '+52 81 1111 1111'));
    await database.close();

    database = openDatabase();
    final reopened = LeadRepository(database, PrivateMediaStorage(mediaRoot));
    final afterReopen = await reopened.listAll();
    expect(afterReopen, hasLength(2));
    expect(
      afterReopen.singleWhere((item) => item.localId == 'lead-1').lead.phone,
      '+52 81 1111 1111',
    );
    await database.close();
  });

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
        const DemoProfile(name: 'Yahir Hernández', company: 'CBQA Solutions'),
      );
      for (final entry in preferences.entries) {
        await settings.write(entry.key, entry.value);
      }
      await events.save(event(), makeActive: true);
      await events.save(
        event(name: 'Expo Renombrada').copyWith(
          startsOn: DateTime(2026, 9, 3),
          endsOn: DateTime(2026, 9, 6),
        ),
      );
      await database.close();

      database = openDatabase();
      events = EventRepository(database);
      final reopenedEvent = (await events.list()).single;
      expect(reopenedEvent.name, 'Expo Renombrada');
      expect(reopenedEvent.startsOn, DateTime(2026, 9, 3));
      expect(reopenedEvent.endsOn, DateTime(2026, 9, 6));
      expect(
        (await ProfileRepository(database).load())?.name,
        'Yahir Hernández',
      );
      expect(await PreferencesRepository(database).read('locale'), 'en');

      await events.delete((await events.list()).single);
      expect(await events.list(), isEmpty);
      expect((await database.eventDao.byId('event-1'))?.deleted, isTrue);
      await database.close();
    },
  );

  test(
    'card and voice files are copied privately and recovered after reopen',
    () async {
      final sourceCard = File('${temporary.path}/picker-card.jpg');
      final sourceAudio = File('${temporary.path}/recorder-note.m4a');
      await sourceCard.writeAsBytes([1, 2, 3, 4]);
      await sourceAudio.writeAsBytes([5, 6, 7, 8]);
      var database = openDatabase();
      await EventRepository(database).save(event(), makeActive: true);
      var leads = LeadRepository(
        database,
        PrivateMediaStorage(mediaRoot),
        idFactory: () => 'lead-media',
      );

      final saved = await leads.saveDraft(
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
      final recovered = (await leads.listAll()).single;
      expect(await File(recovered.lead.cardImageLocalPath!).exists(), isTrue);
      expect(recovered.lead.audioSeconds, 18);

      await File(recovered.lead.audioLocalPath!).delete();
      await leads.reconcileMediaReferences();
      final coherent = (await leads.listAll()).single;
      expect(coherent.lead.audioLocalPath, isNull);
      expect(coherent.lead.cardImageLocalPath, isNotNull);
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
        draft(eventId: 'missing-event', cardPath: source.path),
        capturedBy: const DemoProfile(name: 'Yahir', company: 'CBQA'),
      ),
      throwsA(anything),
    );
    expect(await leads.listAll(), isEmpty);
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
      await EventRepository(database).save(event(), makeActive: true);
      final leads = LeadRepository(
        database,
        PrivateMediaStorage(mediaRoot),
        idFactory: () => 'lead-with-missing-media',
      );

      final saved = await leads.saveDraft(
        draft(cardPath: '${temporary.path}/missing.jpg'),
        capturedBy: const DemoProfile(name: 'Yahir', company: 'CBQA'),
      );
      expect(saved.mediaIncomplete, isTrue);
      expect(saved.lead.cardImageLocalPath, isNull);
      expect(await leads.listAll(), hasLength(1));
      await database.close();
    },
  );

  test(
    'logical event deletion hides its local leads without deleting rows',
    () async {
      final database = openDatabase();
      final events = EventRepository(database);
      final localEvent = event();
      await events.save(localEvent, makeActive: true);
      final leads = LeadRepository(
        database,
        PrivateMediaStorage(mediaRoot),
        idFactory: () => 'lead-hidden',
      );
      await leads.saveDraft(
        draft(),
        capturedBy: const DemoProfile(name: 'Yahir', company: 'CBQA'),
      );

      await events.delete(localEvent);
      expect(await leads.listAll(), isEmpty);
      expect(await leads.byEvent(localEvent.id), isEmpty);
      expect(await database.leadDao.listAll(), hasLength(1));
      await database.close();
    },
  );

  test('schema version is explicit and stable across reopen', () async {
    var database = openDatabase();
    expect(database.schemaVersion, 1);
    var version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 1);
    await database.close();

    database = openDatabase();
    version = await database.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 1);
    await database.close();
  });
}
