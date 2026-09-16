import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/data/local/app_database.dart';
import 'package:foloo/data/local/private_media_storage.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/models/lead_draft.dart';
import 'package:foloo/models/session_lead.dart';
import 'package:foloo/sync/sync_engine.dart';
import 'package:foloo/sync/foloo_api_client.dart';
import 'package:foloo/sync/media_binary_transfer.dart';
import 'package:foloo/sync/sync_models.dart';
import 'package:foloo/sync/sync_store.dart';
import 'package:image/image.dart' as image_codec;

File _writeTestJpeg(String path) => File(path)
  ..writeAsBytesSync(
    image_codec.encodeJpg(image_codec.Image(width: 2, height: 2)),
  );

File _writeTestPng(String path) => File(path)
  ..writeAsBytesSync(
    image_codec.encodePng(image_codec.Image(width: 2, height: 2)),
  );

class _Session implements SyncSessionProvider {
  _Session(this.token);
  final String? token;

  @override
  Future<String?> accessTokenFor(String ownerSub) async => token;
}

class _RecoveringSession implements SyncSessionProvider {
  _RecoveringSession({this.error});

  String? token;
  Object? error;

  @override
  Future<String?> accessTokenFor(String ownerSub) async {
    final currentError = error;
    if (currentError != null) throw currentError;
    return token;
  }
}

class _Call {
  const _Call(this.token, this.request);
  final String token;
  final SyncRequest request;
}

class _Api implements SyncApi {
  final calls = <_Call>[];
  final failures = <Object>[];
  Map<String, Object?>? remoteProfile;
  List<Map<String, Object?>> remoteEvents = [];
  List<Map<String, Object?>> remoteLeads = [];

  @override
  Future<SyncResponse> send(String accessToken, SyncRequest request) async {
    calls.add(_Call(accessToken, request));
    if (request.method != 'GET' && failures.isNotEmpty) {
      throw failures.removeAt(0);
    }
    if (request.path == '/v1/profile') {
      return SyncResponse(statusCode: 200, data: {'data': remoteProfile});
    }
    if (request.path == '/v1/events') {
      return SyncResponse(statusCode: 200, data: {'data': remoteEvents});
    }
    if (request.path == '/v1/leads' && request.method == 'GET') {
      return SyncResponse(statusCode: 200, data: {'data': remoteLeads});
    }
    if (request.method == 'GET' && request.path.endsWith('/media')) {
      return const SyncResponse(statusCode: 200, data: {'data': []});
    }
    return const SyncResponse(statusCode: 201, data: {'data': {}});
  }
}

class _PathFailApi extends _Api {
  _PathFailApi({this.failurePath, this.failure = const SyncHttpException(400)});

  final String? failurePath;
  final Object failure;

  @override
  Future<SyncResponse> send(String accessToken, SyncRequest request) async {
    if (request.method != 'GET' && request.path == failurePath) {
      calls.add(_Call(accessToken, request));
      throw failure;
    }
    return super.send(accessToken, request);
  }
}

class _MediaApi extends _Api {
  int authorizationCount = 0;

  @override
  Future<SyncResponse> send(String accessToken, SyncRequest request) async {
    if (request.method == 'POST' && request.path.endsWith('/media/uploads')) {
      calls.add(_Call(accessToken, request));
      authorizationCount += 1;
      return SyncResponse(
        statusCode: 201,
        data: {
          'data': {
            'upload': {
              'url': 'https://s3.example.test/upload/$authorizationCount',
              'headers': {
                'content-type': request.body?['contentType'] as String,
                'x-amz-meta-foloo-media-id': request.body?['id'] as String,
              },
            },
          },
        },
      );
    }
    return super.send(accessToken, request);
  }
}

class _MediaTransfer implements MediaBinaryTransfer {
  final uploads = <({Uri url, String path, Map<String, String> headers})>[];
  final failures = <MediaTransferException>[];

  @override
  Future<void> upload({
    required Uri url,
    required Map<String, String> headers,
    required String localPath,
  }) async {
    uploads.add((url: url, path: localPath, headers: Map.of(headers)));
    if (failures.isNotEmpty) throw failures.removeAt(0);
  }

  @override
  Future<String> download({required Uri url, required String contentType}) {
    throw UnimplementedError();
  }
}

class _BlockingApi implements SyncApi {
  final calls = <_Call>[];
  final postStarted = Completer<void>();
  final releasePost = Completer<void>();

  @override
  Future<SyncResponse> send(String accessToken, SyncRequest request) async {
    calls.add(_Call(accessToken, request));
    if (request.method != 'GET') {
      if (!postStarted.isCompleted) postStarted.complete();
      await releasePost.future;
      return const SyncResponse(statusCode: 201, data: {'data': {}});
    }
    return const SyncResponse(statusCode: 200, data: {'data': []});
  }
}

class _Transport implements SyncHttpTransport {
  Uri? uri;
  String? method;
  Map<String, String>? headers;
  String? body;
  SyncResponse response = const SyncResponse(
    statusCode: 201,
    data: {'data': {}},
  );

  @override
  Future<SyncResponse> send({
    required Uri uri,
    required String method,
    required Map<String, String> headers,
    String? body,
    required Duration timeout,
  }) async {
    this.uri = uri;
    this.method = method;
    this.headers = headers;
    this.body = body;
    return response;
  }
}

LeadDraft _draft({
  String name = 'Local',
  String email = 'lead@example.com',
  String? cardPath,
  String? audioPath,
  List<String> referencePaths = const [],
  LeadOriginKind origin = LeadOriginKind.direct,
  String? eventId,
  String? eventName,
}) => LeadDraft(
  name: name,
  lastName: 'Lead',
  role: 'Buyer',
  company: 'Company',
  email: email,
  phone: '',
  type: LeadType.customer,
  interest: InterestLevel.medium,
  note: '',
  originKind: origin,
  eventLocalId: eventId,
  eventName: eventName,
  cardImageLocalPath: cardPath,
  audioLocalPath: audioPath,
  audioSeconds: audioPath == null ? 0 : 12,
  referenceImageLocalPaths: referencePaths,
  place: 'Monterrey',
);

Map<String, Object?> _remoteLead(
  String id, {
  String name = 'Remote',
  int revision = 1,
}) => {
  'id': id,
  'capturedAt': '2026-09-09T12:00:00.000Z',
  'origin': 'direct',
  'eventId': null,
  'place': 'CDMX',
  'firstName': name,
  'lastName': 'Lead',
  'position': 'Buyer',
  'company': 'Company',
  'email': 'lead@example.com',
  'phone': null,
  'leadType': 'customer',
  'interest': 'medium',
  'writtenNote': null,
  'commercialFolio': null,
  'revision': revision,
};

void main() {
  const owner = 'cognito-sub-a';
  const profile = DemoProfile(name: 'Seller', company: 'Foloo');

  test(
    'SYN-10 API client centralizes bearer, JSON and idempotency headers',
    () async {
      final transport = _Transport();
      final client = FolooApiClient(
        configuration: const FolooApiConfiguration(
          baseUrl: 'https://api.example.test',
        ),
        transport: transport,
      );

      await client.send(
        'secret-token',
        const SyncRequest(
          method: 'POST',
          path: '/v1/leads',
          body: {'id': 'local-id'},
          idempotencyKey: 'stable-operation',
        ),
      );

      expect(transport.uri, Uri.parse('https://api.example.test/v1/leads'));
      expect(transport.method, 'POST');
      expect(transport.headers?['authorization'], 'Bearer secret-token');
      expect(transport.headers?['Idempotency-Key'], 'stable-operation');
      expect(transport.body, contains('local-id'));
    },
  );

  test('SYN-08 API client preserves safe backend error diagnostics', () async {
    final transport = _Transport()
      ..response = const SyncResponse(
        statusCode: 400,
        data: {
          'error': {
            'code': 'invalid_resource',
            'message': 'private detail is not retained',
            'requestId': 'request-123',
          },
        },
      );
    final client = FolooApiClient(
      configuration: const FolooApiConfiguration(
        baseUrl: 'https://api.example.test',
      ),
      transport: transport,
    );

    await expectLater(
      client.send(
        'token',
        const SyncRequest(method: 'POST', path: '/v1/leads'),
      ),
      throwsA(
        isA<SyncHttpException>()
            .having((error) => error.statusCode, 'status', 400)
            .having((error) => error.errorCode, 'code', 'invalid_resource')
            .having((error) => error.requestId, 'request', 'request-123'),
      ),
    );
  });

  test('SYN-04 local lead and outbox survive database restart', () async {
    final root = await Directory.systemTemp.createTemp('foloo_sync_restart_');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/foloo.sqlite');
    var database = AppDatabase(NativeDatabase(file));
    var store = SyncStore(database, idFactory: () => 'operation-stable-1');
    var leads = LeadRepository(
      database,
      PrivateMediaStorage(root),
      idFactory: () => '11111111-1111-4111-8111-111111111111',
      syncStore: store,
    );

    await leads.saveDraft(owner, _draft(), capturedBy: profile);
    expect(await leads.listAll(owner), hasLength(1));
    expect(await store.all(owner), hasLength(1));
    await database.close();

    database = AppDatabase(NativeDatabase(file));
    store = SyncStore(database);
    leads = LeadRepository(
      database,
      PrivateMediaStorage(root),
      syncStore: store,
    );
    expect(await leads.listAll(owner), hasLength(1));
    expect(
      (await store.all(owner)).single.idempotencyKey,
      'operation-stable-1',
    );
    await database.close();
  });

  test('SYN-06 success sends bearer and stable idempotency key', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = SyncStore(database, idFactory: () => 'operation-stable-2');
    final leads = LeadRepository(
      database,
      PrivateMediaStorage(await Directory.systemTemp.createTemp()),
      idFactory: () => '22222222-2222-4222-8222-222222222222',
      syncStore: store,
    );
    await leads.saveDraft(owner, _draft(), capturedBy: profile);
    final api = _Api();

    await SyncEngine(store, api, _Session('access-token')).synchronize(owner);

    final post = api.calls.singleWhere((call) => call.request.method == 'POST');
    expect(post.token, 'access-token');
    expect(post.request.idempotencyKey, 'operation-stable-2');
    expect(await store.all(owner), isEmpty);
    expect((await leads.listAll(owner)).single.uploadState.name, 'synced');
  });

  test('SYN-04 event is pushed before its dependent lead', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = SyncStore(database);
    const eventId = '81818181-8181-4181-8181-818181818181';
    const leadId = '82828282-8282-4282-8282-828282828282';
    await store.enqueue(
      ownerSub: owner,
      entityType: SyncEntityType.lead,
      entityId: leadId,
      action: 'create',
      payload: {
        ..._remoteLead(leadId),
        'origin': 'event',
        'eventId': eventId,
        'place': null,
      },
    );
    await store.enqueue(
      ownerSub: owner,
      entityType: SyncEntityType.event,
      entityId: eventId,
      action: 'create',
      payload: const {
        'id': eventId,
        'name': 'EventoTest',
        'startsAt': '2026-09-10T12:00:00.000Z',
        'endsAt': '2026-09-11T12:00:00.000Z',
      },
    );
    final api = _Api();

    await SyncEngine(store, api, _Session('token')).synchronize(owner);

    expect(
      api.calls
          .where((call) => call.request.method == 'POST')
          .map((call) => call.request.path),
      ['/v1/events', '/v1/leads'],
    );
  });

  test('SYN-04 failed event blocks its dependent lead', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = SyncStore(database);
    const eventId = '83838383-8383-4383-8383-838383838383';
    const leadId = '84848484-8484-4484-8484-848484848484';
    await store.enqueue(
      ownerSub: owner,
      entityType: SyncEntityType.event,
      entityId: eventId,
      action: 'create',
      payload: const {
        'id': eventId,
        'name': 'EventoTest',
        'startsAt': '2026-09-10T12:00:00.000Z',
        'endsAt': '2026-09-11T12:00:00.000Z',
      },
    );
    await store.enqueue(
      ownerSub: owner,
      entityType: SyncEntityType.lead,
      entityId: leadId,
      action: 'create',
      payload: {
        ..._remoteLead(leadId),
        'origin': 'event',
        'eventId': eventId,
        'place': null,
      },
    );
    final api = _PathFailApi(failurePath: '/v1/events');

    await SyncEngine(store, api, _Session('token')).synchronize(owner);

    expect(
      api.calls
          .where((call) => call.request.method == 'POST')
          .map((call) => call.request.path),
      ['/v1/events'],
    );
    expect(
      (await store.all(owner))
          .singleWhere((item) => item.entityId == leadId)
          .status,
      'pending',
    );
  });

  test('SYN-04 lead is pushed before its dependent media', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = SyncStore(database);
    const leadId = '85858585-8585-4585-8585-858585858585';
    const mediaId = '86868686-8686-4686-8686-868686868686';
    await store.enqueue(
      ownerSub: owner,
      entityType: SyncEntityType.leadMedia,
      entityId: mediaId,
      action: 'create',
      payload: const {
        'leadId': leadId,
        'id': mediaId,
        'kind': 'business_card',
        'contentType': 'image/jpeg',
        'byteSize': 10,
        'capturedAt': '2026-09-10T12:00:00.000Z',
        'durationMs': null,
      },
    );
    await store.enqueue(
      ownerSub: owner,
      entityType: SyncEntityType.lead,
      entityId: leadId,
      action: 'create',
      payload: _remoteLead(leadId),
    );
    final api = _Api();

    await SyncEngine(store, api, _Session('token')).synchronize(owner);

    expect(
      api.calls
          .where((call) => call.request.method == 'POST')
          .map((call) => call.request.path),
      ['/v1/leads', '/v1/leads/$leadId/media'],
    );
  });

  test('SYN-04 failed lead blocks its dependent media', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = SyncStore(database);
    const leadId = '87878787-8787-4787-8787-878787878787';
    const mediaId = '88888888-8888-4888-8888-888888888889';
    await store.enqueue(
      ownerSub: owner,
      entityType: SyncEntityType.lead,
      entityId: leadId,
      action: 'create',
      payload: _remoteLead(leadId),
    );
    await store.enqueue(
      ownerSub: owner,
      entityType: SyncEntityType.leadMedia,
      entityId: mediaId,
      action: 'create',
      payload: const {
        'leadId': leadId,
        'id': mediaId,
        'kind': 'business_card',
        'contentType': 'image/jpeg',
        'byteSize': 10,
        'capturedAt': '2026-09-10T12:00:00.000Z',
        'durationMs': null,
      },
    );
    final api = _PathFailApi(failurePath: '/v1/leads');

    await SyncEngine(store, api, _Session('token')).synchronize(owner);

    expect(
      api.calls.where((call) => call.request.method == 'POST'),
      hasLength(1),
    );
    expect(
      (await store.all(owner))
          .singleWhere((item) => item.entityId == mediaId)
          .status,
      'pending',
    );
  });

  test('SYN-06 response loss retries with the same logical key', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    var now = DateTime.utc(2026, 9, 9, 12);
    final store = SyncStore(database, idFactory: () => 'operation-stable-3');
    final leads = LeadRepository(
      database,
      PrivateMediaStorage(await Directory.systemTemp.createTemp()),
      idFactory: () => '33333333-3333-4333-8333-333333333333',
      syncStore: store,
    );
    await leads.saveDraft(owner, _draft(), capturedBy: profile);
    final api = _Api()..failures.add(const SyncTransportException());
    final engine = SyncEngine(store, api, _Session('token'), now: () => now);

    await engine.synchronize(owner);
    expect((await store.all(owner)).single.status, 'retryable');
    expect(await leads.listAll(owner), hasLength(1));
    now = now.add(const Duration(minutes: 1));
    await engine.synchronize(owner);

    final keys = api.calls
        .where((call) => call.request.method == 'POST')
        .map((call) => call.request.idempotencyKey)
        .toList();
    expect(keys, ['operation-stable-3', 'operation-stable-3']);
    expect(await store.all(owner), isEmpty);
  });

  test(
    'SYN-05 connectivity recovery retries before backoff without restart',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final now = DateTime.utc(2026, 9, 10, 12);
      final store = SyncStore(database, idFactory: () => 'recovery-key');
      await store.enqueue(
        ownerSub: owner,
        entityType: SyncEntityType.lead,
        entityId: '10101010-1010-4010-8010-101010101010',
        action: 'create',
        payload: _remoteLead('10101010-1010-4010-8010-101010101010'),
        now: now,
      );
      final api = _Api()..failures.add(const SyncTransportException());
      final engine = SyncEngine(store, api, _Session('token'), now: () => now);

      await engine.synchronize(owner);
      final retryable = (await store.all(owner)).single;
      expect(retryable.status, 'retryable');
      expect(retryable.nextAttemptAt, isNotNull);
      expect(retryable.nextAttemptAt!.isAfter(now), isTrue);

      await engine.synchronize(
        owner,
        trigger: SyncTrigger.connectivityRestored,
      );

      expect(await store.all(owner), isEmpty);
      expect(
        api.calls.where((call) => call.request.method == 'POST'),
        hasLength(2),
      );
    },
  );

  test('SYN-05 manual retry processes deferred pending work now', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime.utc(2026, 9, 10, 12);
    final store = SyncStore(database, idFactory: () => 'manual-pending-key');
    await store.enqueue(
      ownerSub: owner,
      entityType: SyncEntityType.lead,
      entityId: '20202020-2020-4020-8020-202020202020',
      action: 'create',
      payload: _remoteLead('20202020-2020-4020-8020-202020202020'),
      now: now,
    );
    final operation = (await store.all(owner)).single;
    await store.markRetryable(
      operation,
      now.add(const Duration(hours: 1)),
      'transport',
      now,
    );
    final api = _Api();

    await SyncEngine(
      store,
      api,
      _Session('token'),
      now: () => now,
    ).synchronize(owner, trigger: SyncTrigger.manual);

    expect(await store.all(owner), isEmpty);
    expect(
      api.calls
          .singleWhere((call) => call.request.method == 'POST')
          .request
          .idempotencyKey,
      'manual-pending-key',
    );
  });

  test(
    'SYN-05 manual retry recovers a temporary failure with the same key',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final now = DateTime.utc(2026, 9, 10, 12);
      final store = SyncStore(database, idFactory: () => 'manual-retry-key');
      await store.enqueue(
        ownerSub: owner,
        entityType: SyncEntityType.lead,
        entityId: '30303030-3030-4030-8030-303030303030',
        action: 'create',
        payload: _remoteLead('30303030-3030-4030-8030-303030303030'),
        now: now,
      );
      final api = _Api()..failures.add(const SyncHttpException(503));
      final engine = SyncEngine(store, api, _Session('token'), now: () => now);

      await engine.synchronize(owner);
      expect((await store.all(owner)).single.status, 'retryable');
      await engine.synchronize(owner, trigger: SyncTrigger.manual);

      final keys = api.calls
          .where((call) => call.request.method == 'POST')
          .map((call) => call.request.idempotencyKey)
          .toList();
      expect(keys, ['manual-retry-key', 'manual-retry-key']);
      expect(await store.all(owner), isEmpty);
    },
  );

  test(
    'SYN-05 request exception releases lock and remains retryable',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final now = DateTime.utc(2026, 9, 10, 12);
      final store = SyncStore(database);
      await store.enqueue(
        ownerSub: owner,
        entityType: SyncEntityType.lead,
        entityId: '40404040-4040-4040-8040-404040404040',
        action: 'create',
        payload: _remoteLead('40404040-4040-4040-8040-404040404040'),
        now: now,
      );
      final api = _Api()..failures.add(StateError('adapter interrupted'));
      final engine = SyncEngine(store, api, _Session('token'), now: () => now);

      await engine.synchronize(owner);
      expect(engine.running, isFalse);
      expect((await store.all(owner)).single.status, 'retryable');
      await engine.synchronize(owner, trigger: SyncTrigger.manual);

      expect(engine.running, isFalse);
      expect(await store.all(owner), isEmpty);
    },
  );

  test(
    'SYN-06 rapid manual triggers coalesce without duplicate POST',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = SyncStore(database);
      await store.enqueue(
        ownerSub: owner,
        entityType: SyncEntityType.lead,
        entityId: '50505050-5050-4050-8050-505050505050',
        action: 'create',
        payload: _remoteLead('50505050-5050-4050-8050-505050505050'),
      );
      final api = _BlockingApi();
      final engine = SyncEngine(store, api, _Session('token'));

      final first = engine.synchronize(owner, trigger: SyncTrigger.manual);
      await api.postStarted.future;
      final repeated = List.generate(
        3,
        (_) => engine.synchronize(owner, trigger: SyncTrigger.manual),
      );
      api.releasePost.complete();
      await Future.wait([first, ...repeated]);

      expect(
        api.calls.where((call) => call.request.method == 'POST'),
        hasLength(1),
      );
      expect(await store.all(owner), isEmpty);
    },
  );

  test('SYN-09 token recovery continues without app restart', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = SyncStore(database);
    await store.enqueue(
      ownerSub: owner,
      entityType: SyncEntityType.profile,
      entityId: 'profile-a',
      action: 'upsert',
      payload: const {'name': 'A', 'company': 'A'},
    );
    final session = _RecoveringSession(error: StateError('temporarily stale'));
    final api = _Api();
    final engine = SyncEngine(store, api, session);

    await engine.synchronize(owner);
    expect(engine.running, isFalse);
    expect(await store.all(owner), hasLength(1));
    session
      ..error = null
      ..token = 'fresh-token';
    await engine.synchronize(owner, trigger: SyncTrigger.manual);

    expect(await store.all(owner), isEmpty);
    expect(
      api.calls.singleWhere((call) => call.request.method == 'PUT').token,
      'fresh-token',
    );
  });

  test(
    'SYN-08 manual retry does not revive permanent contract failures',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = SyncStore(database);
      await store.enqueue(
        ownerSub: owner,
        entityType: SyncEntityType.lead,
        entityId: '60606060-6060-4060-8060-606060606060',
        action: 'create',
        payload: _remoteLead('60606060-6060-4060-8060-606060606060'),
      );
      final api = _Api()..failures.add(const SyncHttpException(400));
      final engine = SyncEngine(store, api, _Session('token'));

      await engine.synchronize(owner);
      await engine.synchronize(owner, trigger: SyncTrigger.manual);

      expect((await store.all(owner)).single.status, 'failed');
      expect(
        api.calls.where((call) => call.request.method == 'POST'),
        hasLength(1),
      );
    },
  );

  test(
    'REG-07 revision conflict preserves local edit and manual retry rebases',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = SyncStore(database);
      const leadId = '70707070-7070-4070-8070-707070707070';
      final root = await Directory.systemTemp.createTemp('foloo_conflict_');
      addTearDown(() => root.delete(recursive: true));
      final leads = LeadRepository(
        database,
        PrivateMediaStorage(root),
        idFactory: () => leadId,
        syncStore: store,
      );
      final saved = await leads.saveDraft(owner, _draft(), capturedBy: profile);
      await database.syncDao.completeCreatesForEntity(
        owner,
        SyncEntityType.lead.name,
        leadId,
      );
      await database.leadDao.markLeadSynced(owner, leadId, 1);
      final synced = (await leads.listAll(owner)).single;
      await leads.updateDraft(
        owner,
        synced,
        synced.lead.copyWith(note: 'Local edit survives'),
      );
      final api = _Api()
        ..failures.add(
          const SyncHttpException(409, errorCode: 'revision_conflict'),
        )
        ..remoteLeads = [_remoteLead(leadId, revision: 4)];
      final engine = SyncEngine(store, api, _Session('token'));

      await engine.synchronize(owner);
      var local = (await leads.listAll(owner)).single;
      expect(local.lead.note, 'Local edit survives');
      expect(local.uploadState, SessionUploadState.conflict);
      expect((await store.all(owner)).single.status, 'failed');

      api.remoteLeads = [
        {
          ..._remoteLead(leadId, revision: 4),
          'writtenNote': 'Local edit survives',
        },
      ];
      await engine.synchronize(owner, trigger: SyncTrigger.manual);
      local = (await leads.listAll(owner)).single;
      expect(local.lead.note, 'Local edit survives');
      expect(local.uploadState, SessionUploadState.synced);
      expect(await store.all(owner), isEmpty);
      final puts = api.calls
          .where((call) => call.request.method == 'PUT')
          .toList();
      expect(puts, hasLength(2));
      expect(puts.first.request.body?['revision'], 1);
      expect(puts.last.request.body?['revision'], 4);
      expect(saved.localId, leadId);
    },
  );

  test(
    'SYN-07 synced lead with failed media reports a child-media error',
    () async {
      final root = await Directory.systemTemp.createTemp('foloo_media_state_');
      addTearDown(() => root.delete(recursive: true));
      final source = _writeTestJpeg('${root.path}/card.jpg');
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = SyncStore(database);
      const leadId = '89898989-8989-4989-8989-898989898989';
      final leads = LeadRepository(
        database,
        PrivateMediaStorage(Directory('${root.path}/private')),
        idFactory: () => leadId,
        syncStore: store,
      );
      await leads.saveDraft(
        owner,
        _draft(cardPath: source.path),
        capturedBy: profile,
      );
      final api = _PathFailApi(
        failurePath: '/v1/leads/$leadId/media',
        failure: const SyncHttpException(
          400,
          errorCode: 'validation_error',
          requestId: 'media-request',
        ),
      );

      await SyncEngine(store, api, _Session('token')).synchronize(owner);

      expect(
        (await leads.listAll(owner)).single.uploadState,
        SessionUploadState.syncedWithMediaError,
      );
      final mediaOperation = (await store.all(owner)).single;
      expect(mediaOperation.entityType, SyncEntityType.leadMedia.name);
      expect(mediaOperation.lastError, 'http_400_validation_error');
    },
  );

  test('SYN-10 pull reconciles a stale failed create found remotely', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = SyncStore(database);
    const leadId = '90909090-9090-4090-8090-909090909090';
    final leads = LeadRepository(
      database,
      PrivateMediaStorage(await Directory.systemTemp.createTemp()),
      idFactory: () => leadId,
      syncStore: store,
    );
    await leads.saveDraft(owner, _draft(), capturedBy: profile);
    final api = _Api()
      ..failures.add(
        const SyncHttpException(409, errorCode: 'resource_conflict'),
      )
      ..remoteLeads = [_remoteLead(leadId, name: 'Local')];

    await SyncEngine(store, api, _Session('token')).synchronize(owner);

    expect(await store.all(owner), isEmpty);
    expect(
      (await leads.listAll(owner)).single.uploadState,
      SessionUploadState.synced,
    );
  });

  test('SYN-05 emits safe trigger and operation diagnostics', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = SyncStore(database);
    await store.enqueue(
      ownerSub: owner,
      entityType: SyncEntityType.profile,
      entityId: 'profile-a',
      action: 'upsert',
      payload: const {'name': 'A', 'company': 'A'},
    );
    final logs = <Map<String, Object?>>[];

    await SyncEngine(
      store,
      _Api(),
      _Session('token'),
      logger: logs.add,
    ).synchronize(owner, trigger: SyncTrigger.postSave);

    expect(logs, contains(containsPair('trigger', 'post_save')));
    final operationLog = logs.firstWhere(
      (event) => event['scope'] == 'sync_operation',
    );
    expect(operationLog['entityType'], 'profile');
    expect(operationLog['action'], 'upsert');
    expect(operationLog, isNot(contains('payload')));
    expect(operationLog, isNot(contains('token')));
  });

  test('SYN-08 classifies 429/5xx retryable and 400 terminal', () async {
    Future<StoredSyncOperation> run(Object failure) async {
      final database = AppDatabase(NativeDatabase.memory());
      final store = SyncStore(database);
      await store.enqueue(
        ownerSub: owner,
        entityType: SyncEntityType.lead,
        entityId: '44444444-4444-4444-8444-444444444444',
        action: 'create',
        payload: _remoteLead('44444444-4444-4444-8444-444444444444'),
      );
      final api = _Api()..failures.add(failure);
      await SyncEngine(store, api, _Session('token')).synchronize(owner);
      final operation = (await store.all(owner)).single;
      await database.close();
      return operation;
    }

    final limited = await run(
      const SyncHttpException(429, retryAfter: Duration(minutes: 5)),
    );
    expect(limited.status, 'retryable');
    expect(limited.nextAttemptAt!.difference(limited.updatedAt).inMinutes, 5);
    expect((await run(const SyncHttpException(503))).status, 'retryable');
    expect((await run(const SyncHttpException(400))).status, 'failed');
  });

  test(
    'SYN-09 absent session and another owner never consume outbox',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = SyncStore(database);
      await store.enqueue(
        ownerSub: owner,
        entityType: SyncEntityType.profile,
        entityId: 'profile-a',
        action: 'upsert',
        payload: const {'name': 'A', 'company': 'A'},
      );
      await store.enqueue(
        ownerSub: 'cognito-sub-b',
        entityType: SyncEntityType.profile,
        entityId: 'profile-b',
        action: 'upsert',
        payload: const {'name': 'B', 'company': 'B'},
      );
      final api = _Api();

      await SyncEngine(store, api, _Session(null)).synchronize(owner);
      expect(api.calls, isEmpty);
      await SyncEngine(store, api, _Session('token')).synchronize(owner);

      expect(await store.all(owner), isEmpty);
      expect(await store.all('cognito-sub-b'), hasLength(1));
    },
  );

  test('SYN-09 manual sync for owner B never processes owner A', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = SyncStore(database);
    await store.enqueue(
      ownerSub: owner,
      entityType: SyncEntityType.profile,
      entityId: 'profile-a',
      action: 'upsert',
      payload: const {'name': 'A', 'company': 'A'},
    );
    final api = _Api();

    await SyncEngine(
      store,
      api,
      _Session('token-b'),
    ).synchronize('cognito-sub-b', trigger: SyncTrigger.manual);

    expect(await store.all(owner), hasLength(1));
    expect(api.calls.where((call) => call.request.method != 'GET'), isEmpty);
  });

  test(
    'SYN-09 expired session returns an in-flight operation to pending',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = SyncStore(database);
      await store.enqueue(
        ownerSub: owner,
        entityType: SyncEntityType.profile,
        entityId: 'profile-a',
        action: 'upsert',
        payload: const {'name': 'A', 'company': 'A'},
      );
      final api = _Api()..failures.add(const SyncHttpException(401));

      await SyncEngine(store, api, _Session('expired')).synchronize(owner);

      final operation = (await store.all(owner)).single;
      expect(operation.status, 'pending');
      expect(operation.attemptCount, 0);
    },
  );

  test(
    'SYN-10 pull adds remote rows but preserves a pending local row',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = SyncStore(database);
      final localId = '55555555-5555-4555-8555-555555555555';
      final leads = LeadRepository(
        database,
        PrivateMediaStorage(await Directory.systemTemp.createTemp()),
        idFactory: () => localId,
        syncStore: store,
      );
      await leads.saveDraft(owner, _draft(), capturedBy: profile);
      final remoteId = '66666666-6666-4666-8666-666666666666';
      final api = _Api()
        ..failures.add(const SyncTransportException())
        ..remoteLeads = [_remoteLead(localId), _remoteLead(remoteId)];

      await SyncEngine(store, api, _Session('token')).synchronize(owner);

      final rows = await leads.listAll(owner);
      expect(
        rows.singleWhere((row) => row.localId == localId).lead.name,
        'Local',
      );
      expect(
        rows.singleWhere((row) => row.localId == remoteId).lead.name,
        'Remote',
      );
    },
  );

  test(
    'SYN-10 pull persists remote profile and events for current owner',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final store = SyncStore(database);
      final eventId = '88888888-8888-4888-8888-888888888888';
      final api = _Api()
        ..remoteProfile = {
          'name': 'Remote Seller',
          'company': 'Remote Company',
          'updatedAt': '2026-09-09T12:00:00.000Z',
        }
        ..remoteEvents = [
          {
            'id': eventId,
            'name': 'Remote Event',
            'startsAt': '2026-10-01T00:00:00.000Z',
            'endsAt': '2026-10-02T00:00:00.000Z',
            'updatedAt': '2026-09-09T12:00:00.000Z',
          },
        ];

      await SyncEngine(store, api, _Session('token')).synchronize(owner);

      expect(
        (await ProfileRepository(database).load(owner))?.name,
        'Remote Seller',
      );
      expect((await EventRepository(database).list(owner)).single.id, eventId);
    },
  );

  test(
    'SYN-04 media sync sends metadata only, never the local binary',
    () async {
      final root = await Directory.systemTemp.createTemp('foloo_sync_media_');
      addTearDown(() => root.delete(recursive: true));
      final source = _writeTestJpeg('${root.path}/card.jpg');
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      var sequence = 0;
      final store = SyncStore(
        database,
        idFactory: () => 'operation-${sequence++}',
      );
      final leads = LeadRepository(
        database,
        PrivateMediaStorage(Directory('${root.path}/private')),
        idFactory: () => '77777777-7777-4777-8777-777777777777',
        syncStore: store,
      );
      final saved = await leads.saveDraft(
        owner,
        _draft(cardPath: source.path),
        capturedBy: profile,
      );
      final persistedMedia = (await database.leadDao.mediaFor(saved.localId))
          .single;
      final api = _Api();

      await SyncEngine(store, api, _Session('token')).synchronize(owner);

      final media = api.calls.singleWhere(
        (call) =>
            call.request.path.endsWith('/media') &&
            call.request.method == 'POST',
      );
      expect(media.request.body, isNot(contains('localPath')));
      expect(media.request.body, isNot(contains('base64')));
      expect(
        media.request.body?['byteSize'],
        await File(persistedMedia.localPath).length(),
      );
    },
  );

  test(
    'SYN-04 FL-016 uploads card, voice and reference media then confirms',
    () async {
      final root = await Directory.systemTemp.createTemp('foloo_media_s3_');
      addTearDown(() => root.delete(recursive: true));
      final card = _writeTestJpeg('${root.path}/card.jpg');
      final voice = File('${root.path}/voice.m4a')..writeAsBytesSync([4, 5, 6]);
      final reference = _writeTestJpeg('${root.path}/reference.jpg');
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      var sequence = 0;
      final storage = PrivateMediaStorage(Directory('${root.path}/private'));
      final store = SyncStore(
        database,
        mediaStorage: storage,
        idFactory: () => 'operation-${sequence++}',
      );
      final leads = LeadRepository(
        database,
        storage,
        idFactory: () => '99999999-9999-4999-8999-999999999999',
        syncStore: store,
      );
      final saved = await leads.saveDraft(
        owner,
        _draft(
          cardPath: card.path,
          audioPath: voice.path,
          referencePaths: [reference.path],
        ),
        capturedBy: profile,
      );
      final persistedMedia = await database.leadDao.mediaFor(saved.localId);
      final localPaths = persistedMedia.map((item) => item.localPath).toList();
      final durableOperations = await store.all(owner);
      expect(
        durableOperations.every(
          (operation) => !operation.payloadJson.contains('https://'),
        ),
        isTrue,
      );
      final api = _MediaApi();
      final transfer = _MediaTransfer();

      await SyncEngine(
        store,
        api,
        _Session('token'),
        mediaTransfer: transfer,
      ).synchronize(owner);

      expect(api.authorizationCount, 3);
      expect(transfer.uploads, hasLength(3));
      for (final upload in transfer.uploads) {
        expect(upload.headers.keys.toSet(), {
          'content-type',
          'x-amz-meta-foloo-media-id',
        });
      }
      final authorizations = api.calls
          .where((call) => call.request.path.endsWith('/media/uploads'))
          .map((call) => call.request.body!)
          .toList();
      expect(authorizations.map((body) => body['kind']).toSet(), {
        'business_card',
        'reference_image',
        'voice_note',
      });
      for (final body in authorizations) {
        expect(body['id'], isA<String>());
        expect(body['byteSize'], isA<int>());
        expect((body['byteSize'] as int) > 0, isTrue);
        expect(body['capturedAt'], endsWith('Z'));
        expect(
          body['contentType'],
          body['kind'] == 'voice_note' ? 'audio/m4a' : 'image/jpeg',
        );
      }
      expect(
        api.calls.where(
          (call) =>
              call.request.method == 'POST' &&
              call.request.path.endsWith('/media'),
        ),
        hasLength(3),
      );
      expect(await store.all(owner), isEmpty);
      for (final path in localPaths) {
        expect(await File(path).exists(), isTrue);
      }
    },
  );

  test(
    'SYN-06 expired media authorization retries same media with a fresh URL',
    () async {
      final root = await Directory.systemTemp.createTemp('foloo_media_retry_');
      addTearDown(() => root.delete(recursive: true));
      final source = _writeTestJpeg('${root.path}/card.jpg');
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      var operationSequence = 0;
      var now = DateTime.utc(2026, 9, 11, 12);
      final storage = PrivateMediaStorage(Directory('${root.path}/private'));
      final store = SyncStore(
        database,
        mediaStorage: storage,
        idFactory: () => 'operation-${operationSequence++}',
      );
      final leads = LeadRepository(
        database,
        storage,
        idFactory: () => 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        syncStore: store,
      );
      final saved = await leads.saveDraft(
        owner,
        _draft(cardPath: source.path),
        capturedBy: profile,
      );
      final persistedMedia = (await database.leadDao.mediaFor(saved.localId))
          .single;
      final mediaId = persistedMedia.localId;
      final api = _MediaApi();
      final transfer = _MediaTransfer()
        ..failures.add(
          const MediaTransferException(
            statusCode: 403,
            code: 'authorization_expired',
          ),
        );
      final engine = SyncEngine(
        store,
        api,
        _Session('token'),
        mediaTransfer: transfer,
        now: () => now,
      );

      await engine.synchronize(owner);
      expect((await store.all(owner)).single.entityId, mediaId);
      expect((await store.all(owner)).single.status, 'retryable');
      expect(
        (await leads.listAll(owner)).single.uploadState,
        SessionUploadState.retryable,
      );
      expect(await File(persistedMedia.localPath).exists(), isTrue);

      now = now.add(const Duration(minutes: 1));
      await engine.synchronize(owner);

      expect(api.authorizationCount, 2);
      expect(
        api.calls
            .where((call) => call.request.path.endsWith('/media/uploads'))
            .map((call) => call.request.body?['id'])
            .toSet(),
        {mediaId},
      );
      expect(transfer.uploads.map((item) => item.url.toString()), [
        'https://s3.example.test/upload/1',
        'https://s3.example.test/upload/2',
      ]);
      expect(await store.all(owner), isEmpty);
      expect(await File(persistedMedia.localPath).exists(), isTrue);
    },
  );

  test(
    'SYN-08 manual retry repairs relocated iOS legacy media without new IDs',
    () async {
      final root = await Directory.systemTemp.createTemp('foloo_media_repair_');
      addTearDown(() => root.delete(recursive: true));
      final source = _writeTestJpeg('${root.path}/card.jpg');
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      var sequence = 0;
      final storage = PrivateMediaStorage(
        Directory('${root.path}/new-container/foloo_media'),
      );
      final store = SyncStore(
        database,
        mediaStorage: storage,
        idFactory: () => 'repair-operation-${sequence++}',
      );
      final leads = LeadRepository(
        database,
        storage,
        idFactory: () => 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        syncStore: store,
      );
      final saved = await leads.saveDraft(
        owner,
        _draft(cardPath: source.path),
        capturedBy: profile,
      );
      final media = (await database.leadDao.mediaFor(saved.localId)).single;
      final initial = await store.all(owner);
      await store.complete(
        initial.singleWhere((item) => item.entityType == 'lead'),
      );
      final mediaOperation = initial.singleWhere(
        (item) => item.entityType == 'leadMedia',
      );
      final legacyPayload =
          (jsonDecode(mediaOperation.payloadJson) as Map)
              .cast<String, Object?>()
            ..['capturedAt'] = '2026-09-14T12:34:56.000';
      await database.syncDao.repairFailedMediaPayload(
        mediaOperation.operationId,
        jsonEncode(legacyPayload),
        DateTime.utc(2026, 9, 14, 18, 34),
      );
      final oldContainerPath = media.localPath.replaceFirst(
        '/new-container/',
        '/old-container/',
      );
      await database.leadDao.updateMediaLocalPath(
        media.localId,
        oldContainerPath,
      );
      final failed = (await store.all(
        owner,
      )).singleWhere((item) => item.operationId == mediaOperation.operationId);
      await store.markFailed(
        failed,
        'http_400_validation_error',
        DateTime.utc(2026, 9, 14, 18, 35),
      );
      final api = _MediaApi();
      final transfer = _MediaTransfer();
      final logs = <Map<String, Object?>>[];

      await SyncEngine(
        store,
        api,
        _Session('token'),
        mediaTransfer: transfer,
        logger: logs.add,
      ).synchronize(owner, trigger: SyncTrigger.manual);

      final authorization = api.calls.singleWhere(
        (call) => call.request.path.endsWith('/media/uploads'),
      );
      final confirmation = api.calls.singleWhere(
        (call) => call.request.path.endsWith('/media'),
      );
      expect(authorization.request.body?['id'], media.localId);
      expect(confirmation.request.body?['id'], media.localId);
      expect(authorization.request.body?['capturedAt'], endsWith('Z'));
      expect(
        confirmation.request.idempotencyKey,
        mediaOperation.idempotencyKey,
      );
      expect(api.authorizationCount, 1);
      expect(
        logs,
        contains(containsPair('result', 'repaired_legacy_captured_at')),
      );
      expect(
        logs,
        contains(
          allOf(
            containsPair('operationId', mediaOperation.operationId),
            containsPair('attempt', 2),
            containsPair('result', 'attempt'),
          ),
        ),
      );
      expect(await store.all(owner), isEmpty);
      expect(await database.leadDao.mediaFor(saved.localId), hasLength(1));
      expect(await File(media.localPath).exists(), isTrue);
      expect(
        (await database.leadDao.mediaById(media.localId))?.localPath,
        media.localPath,
      );
    },
  );

  test(
    'SYN-08 manual retry deterministically rebuilds orphaned legacy metadata',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'foloo_media_orphan_repair_',
      );
      addTearDown(() => root.delete(recursive: true));
      final source = _writeTestJpeg('${root.path}/card.jpg');
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      var sequence = 0;
      final storage = PrivateMediaStorage(
        Directory('${root.path}/foloo_media'),
      );
      final store = SyncStore(
        database,
        mediaStorage: storage,
        idFactory: () => 'orphan-operation-${sequence++}',
      );
      final leads = LeadRepository(
        database,
        storage,
        idFactory: () => 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        syncStore: store,
      );
      final saved = await leads.saveDraft(
        owner,
        _draft(cardPath: source.path),
        capturedBy: profile,
      );
      final media = (await database.leadDao.mediaFor(saved.localId)).single;
      final operations = await store.all(owner);
      await store.complete(
        operations.singleWhere((item) => item.entityType == 'lead'),
      );
      final mediaOperation = operations.singleWhere(
        (item) => item.entityType == 'leadMedia',
      );
      final legacyPayload =
          (jsonDecode(mediaOperation.payloadJson) as Map)
              .cast<String, Object?>()
            ..['capturedAt'] = '2026-09-14T12:34:56.000';
      await database.syncDao.repairFailedMediaPayload(
        mediaOperation.operationId,
        jsonEncode(legacyPayload),
        DateTime.utc(2026, 9, 14, 18, 34),
      );
      final pending = (await store.all(owner)).single;
      await store.markFailed(
        pending,
        'http_400_validation_error',
        DateTime.utc(2026, 9, 14, 18, 35),
      );
      await database.leadDao.deleteMediaMetadata(media.localId);
      expect(await database.leadDao.mediaById(media.localId), isNull);
      expect(await File(media.localPath).exists(), isTrue);
      final api = _MediaApi();
      final logs = <Map<String, Object?>>[];
      final engine = SyncEngine(
        store,
        api,
        _Session('token'),
        mediaTransfer: _MediaTransfer(),
        logger: logs.add,
      );

      await engine.synchronize(owner, trigger: SyncTrigger.manual);
      await engine.synchronize(owner, trigger: SyncTrigger.manual);

      expect(api.authorizationCount, 1);
      expect(await store.all(owner), isEmpty);
      final rebuilt = await database.leadDao.mediaById(media.localId);
      expect(rebuilt?.localId, media.localId);
      expect(rebuilt?.leadLocalId, saved.localId);
      expect(rebuilt?.localPath, media.localPath);
      expect(
        logs,
        contains(
          allOf(
            containsPair('operationId', mediaOperation.operationId),
            containsPair('mediaId', media.localId),
            containsPair(
              'result',
              'reconstructed_legacy_media_and_captured_at',
            ),
          ),
        ),
      );
      expect(
        logs,
        contains(
          allOf(
            containsPair('operationId', mediaOperation.operationId),
            containsPair('attempt', 2),
            containsPair('result', 'attempt'),
          ),
        ),
      );
      final confirmation = api.calls.singleWhere(
        (call) => call.request.path.endsWith('/media'),
      );
      expect(confirmation.request.body?['id'], media.localId);
      expect(confirmation.request.body?['capturedAt'], endsWith('Z'));
      expect(
        confirmation.request.idempotencyKey,
        mediaOperation.idempotencyKey,
      );
    },
  );

  test(
    'SYN-08 manual retry normalizes failed PNG under the same media operation',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'foloo_media_png_repair_',
      );
      addTearDown(() => root.delete(recursive: true));
      final source = _writeTestJpeg('${root.path}/reference.jpg');
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      var operationSequence = 0;
      const leadId = '6470b0c1-1ed2-43bf-9b57-9db9f2da7597';
      final storage = PrivateMediaStorage(
        Directory('${root.path}/foloo_media'),
      );
      final store = SyncStore(
        database,
        mediaStorage: storage,
        idFactory: () => 'stable-operation-${operationSequence++}',
      );
      final leads = LeadRepository(
        database,
        storage,
        idFactory: () => leadId,
        syncStore: store,
      );
      final saved = await leads.saveDraft(
        owner,
        _draft(referencePaths: [source.path]),
        capturedBy: profile,
      );
      final initialOperations = await store.all(owner);
      await store.complete(
        initialOperations.singleWhere((item) => item.entityType == 'lead'),
      );
      final operation = initialOperations.singleWhere(
        (item) => item.entityType == 'leadMedia',
      );
      final media = (await database.leadDao.mediaFor(saved.localId)).single;
      final mediaId = media.localId;
      final legacyPngPath = media.localPath.replaceFirst(
        RegExp(r'\.jpg$'),
        '.png',
      );
      final legacyPng = _writeTestPng(legacyPngPath);
      await database.leadDao.updateMediaLocalPath(mediaId, legacyPng.path);
      final payload =
          (jsonDecode(operation.payloadJson) as Map).cast<String, Object?>()
            ..['byteSize'] = await legacyPng.length();
      await database.syncDao.repairFailedMediaPayload(
        operation.operationId,
        jsonEncode(payload),
        DateTime.utc(2026, 9, 15, 12),
      );
      await store.markFailed(
        (await store.all(owner)).single,
        'http_400_invalid_media_content',
        DateTime.utc(2026, 9, 15, 12, 1),
      );
      final api = _MediaApi();
      final transfer = _MediaTransfer();
      final logs = <Map<String, Object?>>[];

      await SyncEngine(
        store,
        api,
        _Session('token'),
        mediaTransfer: transfer,
        logger: logs.add,
      ).synchronize(owner, trigger: SyncTrigger.manual);

      expect(await store.all(owner), isEmpty);
      expect(api.authorizationCount, 1);
      expect(transfer.uploads, hasLength(1));
      expect(transfer.uploads.single.path, endsWith('.jpg'));
      expect(await legacyPng.exists(), isTrue);
      final normalized = File(transfer.uploads.single.path);
      expect((await normalized.readAsBytes()).take(3), [0xff, 0xd8, 0xff]);
      final storedMedia = await database.leadDao.mediaById(mediaId);
      expect(storedMedia?.localId, mediaId);
      expect(storedMedia?.leadLocalId, leadId);
      expect(storedMedia?.localPath, normalized.path);
      expect(
        logs,
        contains(
          allOf(
            containsPair('operationId', operation.operationId),
            containsPair('mediaId', mediaId),
            containsPair('result', 'normalized_failed_png_to_jpeg'),
          ),
        ),
      );
      final confirmation = api.calls.singleWhere(
        (call) => call.request.path.endsWith('/media'),
      );
      expect(confirmation.request.body?['id'], mediaId);
      expect(confirmation.request.idempotencyKey, operation.idempotencyKey);
    },
  );

  test('SYN-08 manual retry leaves unrelated media HTTP 400 failed', () async {
    final root = await Directory.systemTemp.createTemp(
      'foloo_media_no_repair_',
    );
    addTearDown(() => root.delete(recursive: true));
    final source = _writeTestJpeg('${root.path}/card.jpg');
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final storage = PrivateMediaStorage(Directory('${root.path}/foloo_media'));
    final store = SyncStore(database, mediaStorage: storage);
    final leads = LeadRepository(
      database,
      storage,
      idFactory: () => 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      syncStore: store,
    );
    await leads.saveDraft(
      owner,
      _draft(cardPath: source.path),
      capturedBy: profile,
    );
    final operations = await store.all(owner);
    await store.complete(
      operations.singleWhere((item) => item.entityType == 'lead'),
    );
    final mediaOperation = operations.singleWhere(
      (item) => item.entityType == 'leadMedia',
    );
    await store.markFailed(
      mediaOperation,
      'http_400_validation_error',
      DateTime.utc(2026, 9, 14, 18, 35),
    );
    final api = _MediaApi();
    final logs = <Map<String, Object?>>[];

    await SyncEngine(
      store,
      api,
      _Session('token'),
      mediaTransfer: _MediaTransfer(),
      logger: logs.add,
    ).synchronize(owner, trigger: SyncTrigger.manual);

    final remaining = (await store.all(owner)).single;
    expect(remaining.operationId, mediaOperation.operationId);
    expect(remaining.status, 'failed');
    expect(remaining.attemptCount, 1);
    expect(api.authorizationCount, 0);
    expect(logs, contains(containsPair('result', 'skipped_contract_mismatch')));
  });

  test('SYN-08 missing local media metadata becomes terminal once', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final store = SyncStore(database);
    const mediaId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    await store.enqueue(
      ownerSub: owner,
      entityType: SyncEntityType.leadMedia,
      entityId: mediaId,
      action: 'create',
      payload: const {
        'leadId': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        'id': mediaId,
        'kind': 'reference_image',
        'contentType': 'image/jpeg',
        'byteSize': 42,
        'capturedAt': '2026-09-15T12:00:00.000Z',
        'durationMs': null,
      },
    );
    final engine = SyncEngine(
      store,
      _MediaApi(),
      _Session('token'),
      mediaTransfer: _MediaTransfer(),
    );

    await engine.synchronize(owner, trigger: SyncTrigger.manual);
    final failed = (await store.all(owner)).single;
    expect(failed.status, 'failed');
    expect(failed.attemptCount, 1);
    expect(failed.lastError, 'media_upload_local_metadata_missing');

    await engine.synchronize(owner, trigger: SyncTrigger.manual);
    expect((await store.all(owner)).single.attemptCount, 1);
  });

  test('SYN-06/SYN-09 remaps an owned legacy event and recovers the same lead media operations', () async {
    final root = await Directory.systemTemp.createTemp(
      'foloo_legacy_event_repair_',
    );
    addTearDown(() => root.delete(recursive: true));
    final sourceA = _writeTestJpeg('${root.path}/reference-a.jpg');
    final sourceB = _writeTestJpeg('${root.path}/reference-b.jpg');
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    var operationSequence = 0;
    const ownerB = 'cognito-sub-b';
    const ownerA = 'cognito-sub-a';
    const legacyEventId = 'legacy-event-owner-b';
    const cloudEventId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    const leadId = 'd3da86ba-3eab-4496-b4ef-15a1caa236e1';
    final storage = PrivateMediaStorage(Directory('${root.path}/foloo_media'));
    final store = SyncStore(
      database,
      mediaStorage: storage,
      idFactory: () => 'stable-operation-${operationSequence++}',
      legacyEventIdFactory: () => cloudEventId,
    );
    final events = EventRepository(database, syncStore: store);
    final leads = LeadRepository(
      database,
      storage,
      idFactory: () => leadId,
      syncStore: store,
    );
    final legacyEvent = AppEvent(
      id: legacyEventId,
      name: 'Historical event',
      startsOn: DateTime.utc(2026, 9, 14),
      endsOn: DateTime.utc(2026, 9, 16),
      active: true,
    );
    await events.save(ownerB, legacyEvent, makeActive: true);
    await store.complete((await store.all(ownerB)).single);
    await store.enqueue(
      ownerSub: ownerA,
      entityType: SyncEntityType.lead,
      entityId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      action: 'create',
      payload: const {'ownerSentinel': true},
    );

    await leads.saveDraft(
      ownerB,
      _draft(
        email: 'QA@b.c',
        origin: LeadOriginKind.event,
        eventId: legacyEventId,
        eventName: legacyEvent.name,
        referencePaths: [sourceA.path, sourceB.path],
      ),
      capturedBy: profile,
    );
    final initial = await store.all(ownerB);
    final leadOperation = initial.singleWhere(
      (operation) => operation.entityType == 'lead',
    );
    final mediaOperations = initial
        .where((operation) => operation.entityType == 'leadMedia')
        .toList();
    await store.markFailed(
      leadOperation,
      'http_400_validation_error',
      DateTime.utc(2026, 9, 15, 12),
    );
    final api = _MediaApi();
    final transfer = _MediaTransfer();

    await SyncEngine(
      store,
      api,
      _Session('token-b'),
      mediaTransfer: transfer,
    ).synchronize(ownerB, trigger: SyncTrigger.manual);

    expect(await store.all(ownerB), isEmpty);
    expect(await store.all(ownerA), hasLength(1));
    expect(await database.eventDao.byId(ownerB, legacyEventId), isNull);
    expect(await database.eventDao.byId(ownerB, cloudEventId), isNotNull);
    final storedLead = await database.leadDao.byId(ownerB, leadId);
    expect(storedLead?.eventLocalId, cloudEventId);
    expect((await leads.listAll(ownerB)).single.localId, leadId);
    expect(await database.leadDao.mediaFor(leadId), hasLength(2));
    expect(transfer.uploads, hasLength(2));

    final leadCall = api.calls.singleWhere(
      (call) =>
          call.request.method == 'POST' && call.request.path == '/v1/leads',
    );
    expect(leadCall.request.body?['id'], leadId);
    expect(leadCall.request.body?['eventId'], cloudEventId);
    expect(leadCall.request.idempotencyKey, leadOperation.idempotencyKey);
    final confirmations = api.calls
        .where(
          (call) =>
              call.request.method == 'POST' &&
              call.request.path == '/v1/leads/$leadId/media',
        )
        .toList();
    expect(
      confirmations.map((call) => call.request.body?['id']).toSet(),
      mediaOperations.map((operation) => operation.entityId).toSet(),
    );
    expect(
      confirmations.map((call) => call.request.idempotencyKey).toSet(),
      mediaOperations.map((operation) => operation.idempotencyKey).toSet(),
    );
  });
}
