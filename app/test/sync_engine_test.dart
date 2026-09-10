import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/data/local/app_database.dart';
import 'package:foloo/data/local/private_media_storage.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/models/lead_draft.dart';
import 'package:foloo/sync/sync_engine.dart';
import 'package:foloo/sync/foloo_api_client.dart';
import 'package:foloo/sync/sync_models.dart';
import 'package:foloo/sync/sync_store.dart';

class _Session implements SyncSessionProvider {
  _Session(this.token);
  final String? token;

  @override
  Future<String?> accessTokenFor(String ownerSub) async => token;
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

class _Transport implements SyncHttpTransport {
  Uri? uri;
  String? method;
  Map<String, String>? headers;
  String? body;

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
    return const SyncResponse(statusCode: 201, data: {'data': {}});
  }
}

LeadDraft _draft({String name = 'Local', String? cardPath}) => LeadDraft(
  name: name,
  lastName: 'Lead',
  role: 'Buyer',
  company: 'Company',
  email: 'lead@example.com',
  phone: '',
  type: LeadType.customer,
  interest: InterestLevel.medium,
  note: '',
  originKind: LeadOriginKind.direct,
  cardImageLocalPath: cardPath,
  audioSeconds: 0,
  place: 'Monterrey',
);

Map<String, Object?> _remoteLead(String id, {String name = 'Remote'}) => {
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
      final source = File('${root.path}/card.jpg')..writeAsBytesSync([1, 2, 3]);
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
      await leads.saveDraft(
        owner,
        _draft(cardPath: source.path),
        capturedBy: profile,
      );
      final api = _Api();

      await SyncEngine(store, api, _Session('token')).synchronize(owner);

      final media = api.calls.singleWhere(
        (call) =>
            call.request.path.endsWith('/media') &&
            call.request.method == 'POST',
      );
      expect(media.request.body, isNot(contains('localPath')));
      expect(media.request.body, isNot(contains('base64')));
      expect(media.request.body?['byteSize'], 3);
    },
  );
}
