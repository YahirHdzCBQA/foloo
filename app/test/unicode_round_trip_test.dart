// Verifies Unicode survives Foloo's local, JSON, HTTP and sync boundaries.
// These tests protect all business text carried by the shared persistence and
// transport layers rather than special-casing Spanish characters.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/data/local/app_database.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/sync/foloo_api_client.dart';
import 'package:foloo/sync/sync_engine.dart';
import 'package:foloo/sync/sync_models.dart';
import 'package:foloo/sync/sync_store.dart';

const _unicodeText =
    'MÉXICO · José Álvarez · León, Guanajuato · Niñez y pingüino · '
    '¿Información? · ¡Hola! · España · São Paulo';
const _owner = 'unicode-owner';
const _eventId = 'b9174606-f614-4f11-975b-d5a777427605';

class _Session implements SyncSessionProvider {
  @override
  Future<String?> accessTokenFor(String ownerSub) async => 'test-token';
}

class _RoundTripApi implements SyncApi {
  final remoteEvents = <Map<String, Object?>>[];

  @override
  Future<SyncResponse> send(String accessToken, SyncRequest request) async {
    if (request.method == 'POST' && request.path == '/v1/events') {
      final encoded = jsonEncode(request.body);
      final event = (jsonDecode(encoded) as Map).cast<String, Object?>();
      remoteEvents.add({...event, 'revision': 1});
      return SyncResponse(statusCode: 201, data: {'data': event});
    }
    if (request.path == '/v1/profile') {
      return const SyncResponse(statusCode: 200, data: {'data': null});
    }
    if (request.path == '/v1/events') {
      return SyncResponse(statusCode: 200, data: {'data': remoteEvents});
    }
    if (request.path == '/v1/leads') {
      return const SyncResponse(statusCode: 200, data: {'data': []});
    }
    if (request.path == '/v1/content') {
      return const SyncResponse(statusCode: 200, data: {'data': []});
    }
    throw StateError('Unexpected request: ${request.method} ${request.path}');
  }
}

void main() {
  test('RNF-06 Unicode survives Drift, outbox, API and pull', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final events = EventRepository(database);
    final store = SyncStore(database);

    await events.save(
      _owner,
      AppEvent(
        id: _eventId,
        name: _unicodeText,
        startsOn: DateTime.utc(2026, 9, 15),
        endsOn: DateTime.utc(2026, 9, 16),
      ),
    );

    expect((await events.list(_owner)).single.name, _unicodeText);
    final operation = (await store.all(_owner)).single;
    final payload = jsonDecode(operation.payloadJson) as Map<String, dynamic>;
    expect(payload['name'], _unicodeText);
    expect(jsonDecode(jsonEncode(payload))['name'], _unicodeText);

    final api = _RoundTripApi();
    await SyncEngine(store, api, _Session()).synchronize(_owner);

    expect(api.remoteEvents.single['name'], _unicodeText);
    expect((await events.list(_owner)).single.name, _unicodeText);
  });

  test('RNF-06 HTTP transport writes and decodes JSON as UTF-8', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final receivedBytes = Completer<List<int>>();
    server.listen((request) async {
      final bytes = await request.fold<List<int>>(
        <int>[],
        (all, chunk) => all..addAll(chunk),
      );
      receivedBytes.complete(bytes);
      request.response.headers.contentType = ContentType(
        'application',
        'json',
        charset: 'utf-8',
      );
      request.response.add(
        utf8.encode(
          jsonEncode({
            'data': {'name': _unicodeText},
          }),
        ),
      );
      await request.response.close();
    });

    final body = jsonEncode({'name': _unicodeText});
    final response = await IoSyncHttpTransport().send(
      uri: Uri.parse('http://127.0.0.1:${server.port}/unicode'),
      method: 'POST',
      headers: const {'content-type': 'application/json; charset=utf-8'},
      body: body,
      timeout: const Duration(seconds: 5),
    );

    expect(await receivedBytes.future, utf8.encode(body));
    expect((response.data as Map)['data']['name'], _unicodeText);
  });
}
