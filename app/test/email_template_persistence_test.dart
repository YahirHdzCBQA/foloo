/// Verifies FL-019 templates survive restart and remain owner-scoped.
///
/// The test uses temporary SQLite and a fake sync boundary, never AWS.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/data/local/app_database.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/models/email_template.dart';
import 'package:foloo/sync/sync_engine.dart';
import 'package:foloo/sync/sync_models.dart';
import 'package:foloo/sync/sync_store.dart';

class _Session implements SyncSessionProvider {
  @override
  Future<String?> accessTokenFor(String ownerSub) async => 'test-token';
}

class _Api implements SyncApi {
  final calls = <SyncRequest>[];
  List<Map<String, Object?>> remoteTemplates = const [];

  @override
  Future<SyncResponse> send(String token, SyncRequest request) async {
    calls.add(request);
    if (request.path == '/v1/email/templates' && request.method == 'PUT') {
      return SyncResponse(statusCode: 200, data: {'data': request.body});
    }
    if (request.path == '/v1/email/templates' && request.method == 'GET') {
      return SyncResponse(statusCode: 200, data: {'data': remoteTemplates});
    }
    return const SyncResponse(statusCode: 200, data: {'data': []});
  }
}

void main() {
  late Directory temp;
  late AppDatabase db;
  late EmailTemplateRepository repository;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('foloo_email_template_');
    db = AppDatabase(NativeDatabase(File('${temp.path}/db.sqlite')));
    repository = EmailTemplateRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test(
    'local save survives restart, isolates A/B and queues one upload',
    () async {
      const template = EmailTemplateData(
        origin: 'event',
        language: 'es',
        subject: 'Hola {nombre}',
        body: 'Catálogo 漢字',
        signature: 'Sofía',
      );
      await repository.save('seller-a', template);
      expect(await repository.list('seller-b'), isEmpty);
      expect((await repository.list('seller-a')).single.body, 'Catálogo 漢字');
      await db.close();
      db = AppDatabase(NativeDatabase(File('${temp.path}/db.sqlite')));
      repository = EmailTemplateRepository(db);
      expect(
        (await repository.list('seller-a')).single.subject,
        template.subject,
      );
      final operations = await db.syncDao.allForOwner('seller-a');
      expect(
        operations.map((item) => item.entityType),
        contains('emailTemplate'),
      );
      expect(await db.syncDao.allForOwner('seller-b'), isEmpty);
    },
  );

  test(
    'existing outbox synchronizes template without cross-account replay',
    () async {
      await repository.save(
        'seller-a',
        const EmailTemplateData(
          origin: 'direct',
          language: 'en',
          subject: 'Nice meeting you, {nombre}',
          body: 'Hi {nombre}',
          signature: 'Best, {nombreVendedor}',
        ),
      );
      final api = _Api();
      final engine = SyncEngine(SyncStore(db), api, _Session());
      await engine.synchronize('seller-b');
      expect(api.calls.where((call) => call.method == 'PUT'), isEmpty);
      await engine.synchronize('seller-a');
      final put = api.calls.singleWhere((call) => call.method == 'PUT');
      expect(put.path, '/v1/email/templates');
      expect(put.idempotencyKey, isNotEmpty);
      expect(
        (await db.emailTemplateDao.listForOwner('seller-a')).single.syncState,
        'synced',
      );
    },
  );

  test('remote template pull restores only the active account', () async {
    final api = _Api()
      ..remoteTemplates = [
        {
          'origin': 'event',
          'language': 'en',
          'subject': 'Welcome {nombre}',
          'body': 'Hello',
          'signature': 'Best',
        },
      ];
    final engine = SyncEngine(SyncStore(db), api, _Session());
    await engine.synchronize('seller-a');
    expect(
      (await repository.list('seller-a')).single.subject,
      'Welcome {nombre}',
    );
    expect(await repository.list('seller-b'), isEmpty);
  });
}
