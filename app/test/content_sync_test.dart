/// Verifies FL-018 Content metadata, binary transfer and tombstone outbox flow.
///
/// Network and S3 are fakes; the repository still uses real temporary SQLite.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/data/local/app_database.dart';
import 'package:foloo/data/local/private_media_storage.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/models/content_file.dart';
import 'package:foloo/sync/media_binary_transfer.dart';
import 'package:foloo/sync/sync_engine.dart';
import 'package:foloo/sync/sync_models.dart';
import 'package:foloo/sync/sync_store.dart';

class _Session implements SyncSessionProvider {
  @override
  Future<String?> accessTokenFor(String ownerSub) async => 'fake-token';
}

class _Transfer implements MediaBinaryTransfer {
  String? uploadedPath;
  bool failOnce = false;
  int uploadCalls = 0;
  @override
  Future<void> upload({
    required Uri url,
    required Map<String, String> headers,
    required String localPath,
  }) async {
    uploadCalls++;
    if (failOnce) {
      failOnce = false;
      throw const MediaTransferException(code: 'authorization_expired');
    }
    expect(headers['content-type'], 'application/pdf');
    expect(await File(localPath).readAsString(), startsWith('%PDF-'));
    uploadedPath = localPath;
  }

  @override
  Future<String> download({
    required Uri url,
    required String contentType,
  }) async => throw UnimplementedError();
}

class _Api implements SyncApi {
  final calls = <String>[];
  bool deleted = false;
  bool available = false;
  @override
  Future<SyncResponse> send(String token, SyncRequest request) async {
    calls.add('${request.method} ${request.path}');
    if (request.method == 'POST' && request.path == '/v1/content') {
      return const SyncResponse(
        statusCode: 201,
        data: {
          'data': {'revision': 1},
        },
      );
    }
    if (request.path.endsWith('/uploads')) {
      return const SyncResponse(
        statusCode: 201,
        data: {
          'data': {
            'upload': {
              'url': 'https://example.invalid/put',
              'headers': {'content-type': 'application/pdf'},
            },
          },
        },
      );
    }
    if (request.path.endsWith('/confirm')) {
      available = true;
      return const SyncResponse(
        statusCode: 200,
        data: {
          'data': {'revision': 2},
        },
      );
    }
    if (request.method == 'DELETE') {
      deleted = true;
      return const SyncResponse(
        statusCode: 200,
        data: {
          'data': {'revision': 3},
        },
      );
    }
    if (request.path == '/v1/content') {
      return SyncResponse(
        statusCode: 200,
        data: {
          'data': [
            {
              'id': '06309df4-1645-4b1b-94bc-ade52ca2668f',
              'displayName': 'Catálogo',
              'fileName': 'catalogo.pdf',
              'byteSize': 8,
              'allEvents': true,
              'eventIds': <String>[],
              'revision': deleted ? 3 : 2,
              'deletedAt': deleted ? '2026-09-17T12:00:00Z' : null,
              'uploadStatus': available ? 'available' : 'pending',
              'download': null,
            },
          ],
        },
      );
    }
    if (request.path == '/v1/profile') {
      return const SyncResponse(statusCode: 200, data: {'data': null});
    }
    return const SyncResponse(statusCode: 200, data: {'data': []});
  }
}

class _StagedApi extends _Api {
  bool unavailableOnce = true;
  @override
  Future<SyncResponse> send(String token, SyncRequest request) {
    if (unavailableOnce &&
        request.method == 'POST' &&
        request.path == '/v1/content') {
      unavailableOnce = false;
      throw const SyncHttpException(404);
    }
    return super.send(token, request);
  }
}

void main() {
  test(
    'Content uploads once, then deletion syncs a tombstone without S3 delete',
    () async {
      final temp = await Directory.systemTemp.createTemp('foloo_content_sync_');
      addTearDown(() => temp.delete(recursive: true));
      final database = AppDatabase(
        NativeDatabase(File('${temp.path}/db.sqlite')),
      );
      addTearDown(database.close);
      final storage = PrivateMediaStorage(Directory('${temp.path}/private'));
      final content = ContentRepository(database, storage);
      final source = File('${temp.path}/catalogo.pdf');
      await source.writeAsString('%PDF-1.7');
      final saved = await content.import(
        'owner-a',
        ContentFile(
          id: '06309df4-1645-4b1b-94bc-ade52ca2668f',
          displayName: 'Catálogo',
          fileName: 'catalogo.pdf',
          sizeLabel: '1 KB',
          localPath: source.path,
          allEvents: true,
        ),
      );
      final api = _Api();
      final transfer = _Transfer();
      final engine = SyncEngine(
        SyncStore(database, mediaStorage: storage),
        api,
        _Session(),
        mediaTransfer: transfer,
        logger: (_) {},
      );
      await engine.synchronize('owner-a');
      expect(
        api.calls.indexOf('POST /v1/content'),
        lessThan(api.calls.indexOf('POST /v1/content/${saved.id}/uploads')),
      );
      expect(transfer.uploadedPath, saved.localPath);
      expect(
        (await database.contentDao.byId('owner-a', saved.id))?.uploadState,
        'available',
      );
      await content.delete('owner-a', saved);
      await engine.synchronize('owner-a');
      expect(await content.list('owner-a'), isEmpty);
      expect(await File(saved.localPath!).exists(), isTrue);
      expect(api.calls.where((call) => call.contains('DeleteObject')), isEmpty);
    },
  );

  test(
    'expired authorization retries with a fresh URL and no duplicate Content',
    () async {
      final temp = await Directory.systemTemp.createTemp('foloo_pdf_retry_');
      addTearDown(() => temp.delete(recursive: true));
      final database = AppDatabase(
        NativeDatabase(File('${temp.path}/db.sqlite')),
      );
      addTearDown(database.close);
      final storage = PrivateMediaStorage(Directory('${temp.path}/private'));
      final source = File('${temp.path}/source.pdf');
      await source.writeAsString('%PDF-1.7');
      await ContentRepository(database, storage).import(
        'owner-a',
        ContentFile(
          id: '06309df4-1645-4b1b-94bc-ade52ca2668f',
          displayName: 'Prueba',
          fileName: 'prueba.pdf',
          sizeLabel: '1 KB',
          localPath: source.path,
          allEvents: true,
        ),
      );
      final api = _Api();
      final transfer = _Transfer()..failOnce = true;
      final engine = SyncEngine(
        SyncStore(database, mediaStorage: storage),
        api,
        _Session(),
        mediaTransfer: transfer,
        logger: (_) {},
      );
      await engine.synchronize('owner-a');
      expect(transfer.uploadCalls, 1);
      expect(api.available, isFalse);
      await engine.synchronize('owner-a', trigger: SyncTrigger.manual);
      expect(transfer.uploadCalls, 2);
      expect(
        api.calls.where((call) => call == 'POST /v1/content'),
        hasLength(1),
      );
      expect(
        api.calls.where((call) => call.endsWith('/uploads')),
        hasLength(2),
      );
      expect(api.available, isTrue);
    },
  );

  test(
    'older DEV API 404 leaves PDF retryable until FL-018 is deployed',
    () async {
      final temp = await Directory.systemTemp.createTemp('foloo_pdf_rollout_');
      addTearDown(() => temp.delete(recursive: true));
      final database = AppDatabase(
        NativeDatabase(File('${temp.path}/db.sqlite')),
      );
      addTearDown(database.close);
      final storage = PrivateMediaStorage(Directory('${temp.path}/private'));
      final source = File('${temp.path}/source.pdf');
      await source.writeAsString('%PDF-1.7');
      final saved = await ContentRepository(database, storage).import(
        'owner-a',
        ContentFile(
          id: '06309df4-1645-4b1b-94bc-ade52ca2668f',
          displayName: 'Prueba',
          fileName: 'prueba.pdf',
          sizeLabel: '1 KB',
          localPath: source.path,
          allEvents: true,
        ),
      );
      final api = _StagedApi();
      final engine = SyncEngine(
        SyncStore(database, mediaStorage: storage),
        api,
        _Session(),
        mediaTransfer: _Transfer(),
        logger: (_) {},
      );
      await engine.synchronize('owner-a');
      expect(
        (await database.syncDao.allForOwner('owner-a'))
            .where((item) => item.entityType == 'content')
            .single
            .status,
        'retryable',
      );
      expect(await File(saved.localPath!).exists(), isTrue);
      await engine.synchronize('owner-a', trigger: SyncTrigger.manual);
      expect(await database.syncDao.allForOwner('owner-a'), isEmpty);
    },
  );

  test(
    'remote PDF downloads once into private storage and keeps tombstone',
    () async {
      final temp = await Directory.systemTemp.createTemp('foloo_pdf_pull_');
      addTearDown(() => temp.delete(recursive: true));
      final database = AppDatabase(
        NativeDatabase(File('${temp.path}/db.sqlite')),
      );
      addTearDown(database.close);
      final storage = PrivateMediaStorage(Directory('${temp.path}/private'));
      final store = SyncStore(database, mediaStorage: storage);
      final source = File('${temp.path}/remote.pdf');
      await source.writeAsString('%PDF-1.7');
      final row = <String, Object?>{
        'id': '06309df4-1645-4b1b-94bc-ade52ca2668f',
        'displayName': 'Información León',
        'fileName': 'Niñez y pingüino.pdf',
        'byteSize': 8,
        'allEvents': true,
        'eventIds': <String>[],
        'revision': '1',
        'deletedAt': null,
        'uploadStatus': 'available',
        'download': {'url': 'https://example.invalid/get'},
      };
      var downloads = 0;
      Future<String> download(Uri _, String type) async {
        expect(type, 'application/pdf');
        downloads++;
        return source.path;
      }

      await store.applyRemoteContent('owner-a', [row], download: download);
      expect(downloads, 1);
      final saved = (await ContentRepository(database, storage).list('owner-a'))
          .single;
      expect(saved.fileName, 'Niñez y pingüino.pdf');
      expect(await File(saved.localPath!).exists(), isTrue);
      expect(
        await ContentRepository(database, storage).list('owner-b'),
        isEmpty,
      );
      await store.applyRemoteContent('owner-a', [row], download: download);
      expect(downloads, 1);
      await store.applyRemoteContent('owner-a', [
        {
          ...row,
          'revision': 2,
          'deletedAt': '2026-09-17T12:00:00Z',
          'download': null,
        },
      ], download: download);
      expect(
        await ContentRepository(database, storage).list('owner-a'),
        isEmpty,
      );
      expect(await File(saved.localPath!).exists(), isTrue);
    },
  );
}
