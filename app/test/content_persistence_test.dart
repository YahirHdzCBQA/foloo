/// Exercises FL-018 private PDF persistence and owner-scoped tombstones.
///
/// These tests use temporary SQLite/files only; no S3 or real account is used.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/data/local/app_database.dart';
import 'package:foloo/data/local/private_media_storage.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/models/content_file.dart';

void main() {
  const contentId = '06309df4-1645-4b1b-94bc-ade52ca2668f';
  const eventId = '31495fa2-b707-49c7-89be-2fd8c4e63dc0';
  late Directory temp;
  late AppDatabase database;
  late ContentRepository content;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('foloo_content_test_');
    database = AppDatabase(NativeDatabase(File('${temp.path}/db.sqlite')));
    content = ContentRepository(
      database,
      PrivateMediaStorage(Directory('${temp.path}/private')),
    );
    await EventRepository(database).save(
      'user-a',
      AppEvent(
        id: eventId,
        name: 'Feria 文档',
        startsOn: DateTime(2026, 9, 17),
        endsOn: DateTime(2026, 9, 18),
      ),
    );
  });

  tearDown(() async {
    await database.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test(
    'copies to private storage, survives reopen, isolates and tombstones',
    () async {
      final source = File('${temp.path}/source.pdf');
      await source.writeAsBytes('%PDF-1.7\nUnicode'.codeUnits);
      final saved = await content.import(
        'user-a',
        ContentFile(
          id: contentId,
          displayName: 'Catálogo 漢字',
          fileName: '资料.pdf',
          sizeLabel: '1 KB',
          localPath: source.path,
          eventIds: {eventId},
        ),
      );
      expect(saved.displayName, 'Catálogo 漢字');
      expect(await File(saved.localPath!).exists(), isTrue);
      expect(await content.list('user-b'), isEmpty);
      await source.delete();
      await database.close();
      database = AppDatabase(NativeDatabase(File('${temp.path}/db.sqlite')));
      content = ContentRepository(
        database,
        PrivateMediaStorage(Directory('${temp.path}/private')),
      );
      expect((await content.list('user-a')).single.eventIds, {eventId});
      await content.delete('user-a', saved);
      expect(await content.list('user-a'), isEmpty);
      expect(
        (await database.contentDao.byId('user-a', contentId))?.deleted,
        isTrue,
      );
      expect(await File(saved.localPath!).exists(), isTrue);
      expect(
        (await database.syncDao.allForOwner('user-a'))
            .where((item) => item.entityType == 'content')
            .map((item) => item.action),
        containsAll(['create', 'delete']),
      );
    },
  );

  test(
    'rejects PDF larger than 25 million bytes before private copy',
    () async {
      final source = File('${temp.path}/large.pdf');
      final handle = await source.open(mode: FileMode.write);
      await handle.truncate(25000001);
      await handle.close();
      await expectLater(
        content.import(
          'user-a',
          ContentFile(
            id: contentId,
            displayName: 'Large',
            fileName: 'large.pdf',
            sizeLabel: '25 MB',
            localPath: source.path,
          ),
        ),
        throwsFormatException,
      );
      expect(await database.contentDao.byId('user-a', contentId), isNull);
    },
  );

  test('rejects a non-PDF renamed with a PDF extension', () async {
    final source = File('${temp.path}/fake.pdf');
    await source.writeAsString('not actually a PDF');
    await expectLater(
      content.import(
        'user-a',
        ContentFile(
          id: contentId,
          displayName: 'Fake',
          fileName: 'fake.pdf',
          sizeLabel: '1 KB',
          localPath: source.path,
        ),
      ),
      throwsFormatException,
    );
    expect(await database.contentDao.byId('user-a', contentId), isNull);
  });

  test('soft-deleting an Event does not delete associated Content', () async {
    final source = File('${temp.path}/associated.pdf');
    await source.writeAsString('%PDF-1.7');
    await content.import(
      'user-a',
      ContentFile(
        id: contentId,
        displayName: 'Feria',
        fileName: 'feria.pdf',
        sizeLabel: '1 KB',
        localPath: source.path,
        eventIds: {eventId},
      ),
    );
    final event = (await EventRepository(database).list('user-a')).single;
    await EventRepository(database).delete('user-a', event);
    expect((await content.list('user-a')).single.eventIds, {eventId});
  });
}
