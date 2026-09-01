import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/data/local/app_database.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'v1 to v2 preserves historical rows without assigning ownership',
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
      expect(version.read<int>('user_version'), 2);

      final profiles = await database.select(database.localProfiles).get();
      final events = await database.select(database.localEvents).get();
      final leads = await database.select(database.localLeads).get();
      final media = await database.select(database.localLeadMedia).get();
      expect(profiles.single.ownerUserId, isNull);
      expect(events.single.ownerUserId, isNull);
      expect(leads.single.ownerUserId, isNull);
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
}
