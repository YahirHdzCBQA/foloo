import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/data/local/app_database.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'v1 to v10 preserves rows and adds email metadata without data loss',
    () async {
      final directory = await Directory.systemTemp.createTemp('foloo_v1_v2_');
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final path = '${directory.path}/foloo.sqlite';
      final legacy = sqlite3.open(path);
      legacy.execute('''
      CREATE TABLE local_profiles (
        local_id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        company TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE TABLE local_events (
        local_id TEXT NOT NULL PRIMARY KEY,
        commercial_code TEXT,
        name TEXT NOT NULL,
        starts_on INTEGER NOT NULL,
        ends_on INTEGER NOT NULL,
        active INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0,
        content_file_ids_json TEXT NOT NULL DEFAULT '[]',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE TABLE local_leads (
        local_id TEXT NOT NULL PRIMARY KEY,
        commercial_folio TEXT,
        captured_at INTEGER NOT NULL,
        captured_by TEXT NOT NULL,
        origin_kind TEXT NOT NULL,
        event_local_id TEXT,
        event_name_snapshot TEXT,
        name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        role TEXT NOT NULL,
        company TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT NOT NULL,
        lead_type TEXT NOT NULL,
        interest_level TEXT NOT NULL,
        note TEXT NOT NULL,
        place TEXT,
        content_file_ids_json TEXT NOT NULL DEFAULT '[]',
        content_names_json TEXT NOT NULL DEFAULT '[]',
        transcription TEXT,
        sync_state TEXT NOT NULL DEFAULT 'local',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      CREATE TABLE local_lead_media (
        local_id TEXT NOT NULL PRIMARY KEY,
        lead_local_id TEXT NOT NULL,
        media_type TEXT NOT NULL,
        local_path TEXT NOT NULL UNIQUE,
        duration_seconds INTEGER,
        upload_state TEXT NOT NULL DEFAULT 'local',
        created_at INTEGER NOT NULL
      );
      CREATE TABLE local_preferences (
        key TEXT NOT NULL PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );
      PRAGMA user_version = 1;
    ''');
      final now = DateTime(2026, 8, 26).millisecondsSinceEpoch;
      legacy.execute('INSERT INTO local_profiles VALUES (?, ?, ?, ?, ?)', [
        'profile-v1',
        'Legacy Seller',
        'Legacy Company',
        now,
        now,
      ]);
      legacy.execute(
        'INSERT INTO local_events VALUES (?, NULL, ?, ?, ?, 1, 0, ?, ?, ?)',
        ['event-v1', 'Legacy Event', now, now, '[]', now, now],
      );
      legacy.execute(
        '''INSERT INTO local_leads VALUES (
        ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, NULL,
        ?, ?, ?
      )''',
        [
          'lead-v1',
          now,
          'Legacy Seller',
          'event',
          'event-v1',
          'Legacy Event',
          'Legacy Lead',
          '',
          '',
          'Legacy Company',
          'lead@example.com',
          '',
          'customer',
          'medium',
          '',
          '[]',
          '[]',
          'local',
          now,
          now,
        ],
      );
      legacy.execute(
        'INSERT INTO local_lead_media VALUES (?, ?, ?, ?, NULL, ?, ?)',
        ['media-v1', 'lead-v1', 'cardImage', '/legacy/card.jpg', 'local', now],
      );
      legacy.execute('INSERT INTO local_preferences VALUES (?, ?, ?)', [
        'locale',
        'en',
        now,
      ]);
      legacy.close();

      final database = AppDatabase(NativeDatabase(File(path)));
      final version = await database
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 10);
      expect(await database.select(database.syncOperations).get(), isEmpty);
      expect(
        await database.select(database.localEmailFollowUps).get(),
        isEmpty,
      );
      expect(
        await database.select(database.localEmailSendIntents).get(),
        isEmpty,
      );
      expect(
        await database.select(database.localEventEmailTemplates).get(),
        isEmpty,
      );

      final profiles = await database.select(database.localProfiles).get();
      final events = await database.select(database.localEvents).get();
      final leads = await database.select(database.localLeads).get();
      final media = await database.select(database.localLeadMedia).get();
      expect(profiles.single.ownerUserId, isNull);
      expect(events.single.ownerUserId, isNull);
      expect(events.single.remoteRevision, isNull);
      expect(leads.single.ownerUserId, isNull);
      expect(leads.single.remoteRevision, isNull);
      expect(media.single.leadLocalId, 'lead-v1');

      const userId = 'fake-user-a';
      expect(await ProfileRepository(database).load(userId), isNull);
      expect(await EventRepository(database).list(userId), isEmpty);
      expect(
        await PreferencesRepository(database).read(userId, 'locale'),
        isNull,
      );
      expect(await GlobalPreferencesRepository(database).read('locale'), 'en');
      await database.close();
    },
  );

  test('v9 to v10 preserves pending email preparation', () async {
    final directory = await Directory.systemTemp.createTemp('foloo_v9_v10_');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final path = '${directory.path}/foloo.sqlite';
    final now = DateTime.utc(2026, 9, 22);
    var database = AppDatabase(NativeDatabase(File(path)));
    await database.leadDao.insertLead(
      LocalLeadsCompanion.insert(
        localId: 'lead-v9',
        ownerUserId: const Value('seller-a'),
        capturedAt: now,
        capturedBy: 'Ana',
        originKind: 'direct',
        name: 'Pedro',
        lastName: '',
        role: '',
        company: 'Empresa',
        email: 'pedro@example.com',
        phone: '',
        leadType: 'customer',
        interestLevel: 'medium',
        note: '',
        place: const Value('Monterrey'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await database.emailDeliveryDao.saveFollowUp(
      LocalEmailFollowUpsCompanion.insert(
        localId: 'follow-up-v9',
        ownerUserId: 'seller-a',
        leadLocalId: 'lead-v9',
        recipientAddress: 'pedro@example.com',
        subject: 'Damos seguimiento, Pedro',
        plainBody: 'Hola Pedro ❤️',
        htmlBody: '<p>Hola Pedro ❤️</p>',
        languageCode: 'es',
        preparedAt: now,
      ),
    );
    await database.close();

    final legacy = sqlite3.open(path);
    legacy.execute('''
      ALTER TABLE local_email_follow_ups DROP COLUMN subject_semantic_json;
      ALTER TABLE local_email_follow_ups DROP COLUMN body_semantic_json;
      ALTER TABLE local_email_follow_ups DROP COLUMN subject_manually_edited;
      ALTER TABLE local_email_follow_ups DROP COLUMN body_manually_edited;
      PRAGMA user_version = 9;
    ''');
    legacy.close();

    database = AppDatabase(NativeDatabase(File(path)));
    addTearDown(database.close);
    final version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 10);
    final pending = await database.emailDeliveryDao.followUpById(
      'seller-a',
      'follow-up-v9',
    );
    expect(pending, isNotNull);
    expect(pending!.plainBody, 'Hola Pedro ❤️');
    expect(pending.subjectSemanticJson, isNull);
    expect(pending.bodySemanticJson, isNull);
    expect(pending.subjectManuallyEdited, isFalse);
    expect(pending.bodyManuallyEdited, isFalse);
  });
}
