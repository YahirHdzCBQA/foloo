/// Serial offline-first synchronizer for Foloo's persistent Drift outbox.
///
/// It obtains authentication at execution time, preserves idempotency keys,
/// schedules bounded retries and reconciles safe server snapshots (SYN-04–10).
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/local/app_database.dart';
import 'sync_models.dart';
import 'sync_store.dart';

class SyncEngine extends ChangeNotifier {
  SyncEngine(
    this._store,
    this._api,
    this._sessions, {
    DateTime Function()? now,
    this.logger = _defaultLogger,
  }) : _now = now ?? DateTime.now;

  final SyncStore _store;
  final SyncApi _api;
  final SyncSessionProvider _sessions;
  final DateTime Function() _now;
  final void Function(Map<String, Object?> event) logger;
  bool _running = false;

  bool get running => _running;

  Future<void> synchronize(String ownerSub, {bool manual = false}) async {
    if (_running) return;
    _running = true;
    notifyListeners();
    try {
      if (manual) await _store.retryFailed(ownerSub, _now());
      final token = await _sessions.accessTokenFor(ownerSub);
      if (token == null) return;
      for (final operation in await _store.due(ownerSub, _now())) {
        _log(operation, 'attempt');
        await _store.markSyncing(operation, _now());
        notifyListeners();
        try {
          await _api.send(token, _request(operation));
          await _store.complete(operation);
          _log(operation, 'synced');
        } on SyncHttpException catch (error) {
          if (error.statusCode == 401 || error.statusCode == 403) {
            await _store.pause(operation, _now());
            return;
          }
          if (error.retryable) {
            await _retry(
              operation,
              error.retryAfter,
              'http_${error.statusCode}',
            );
          } else {
            await _store.markFailed(
              operation,
              'http_${error.statusCode}',
              _now(),
            );
            _log(operation, 'failed', error: 'http_${error.statusCode}');
          }
        } on SyncTransportException {
          await _retry(operation, null, 'transport');
        }
      }
      await _pull(ownerSub, token);
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  void _log(StoredSyncOperation operation, String result, {String? error}) =>
      logger({
        'operationId': operation.operationId,
        'entityType': operation.entityType,
        'entityId': operation.entityId,
        'attempt': operation.attemptCount + 1,
        'result': result,
        'error': error,
      });

  static void _defaultLogger(Map<String, Object?> event) {
    debugPrint(jsonEncode(event));
  }

  Future<void> _retry(
    StoredSyncOperation operation,
    Duration? retryAfter,
    String error,
  ) async {
    final attempt = operation.attemptCount + 1;
    final seconds = math.min(3600, math.pow(2, attempt).toInt());
    final delay = retryAfter != null && retryAfter > Duration(seconds: seconds)
        ? retryAfter
        : Duration(seconds: seconds);
    final now = _now();
    await _store.markRetryable(operation, now.add(delay), error, now);
  }

  SyncRequest _request(StoredSyncOperation operation) {
    final payload = (jsonDecode(operation.payloadJson) as Map)
        .cast<String, Object?>();
    return switch (SyncEntityType.values.byName(operation.entityType)) {
      SyncEntityType.profile => SyncRequest(
        method: 'PUT',
        path: '/v1/profile',
        body: payload,
      ),
      SyncEntityType.event => SyncRequest(
        method: 'POST',
        path: '/v1/events',
        body: payload,
        idempotencyKey: operation.idempotencyKey,
      ),
      SyncEntityType.lead => SyncRequest(
        method: 'POST',
        path: '/v1/leads',
        body: payload,
        idempotencyKey: operation.idempotencyKey,
      ),
      SyncEntityType.leadMedia => SyncRequest(
        method: 'POST',
        path: '/v1/leads/${payload.remove('leadId')}/media',
        body: payload,
        idempotencyKey: operation.idempotencyKey,
      ),
    };
  }

  Future<void> _pull(String ownerSub, String token) async {
    try {
      final profile = _data(
        await _api.send(
          token,
          const SyncRequest(method: 'GET', path: '/v1/profile'),
        ),
      );
      if (profile is Map<String, Object?>) {
        await _store.applyRemoteProfile(ownerSub, profile);
      }
      final events = _list(
        _data(
          await _api.send(
            token,
            const SyncRequest(method: 'GET', path: '/v1/events'),
          ),
        ),
      );
      await _store.applyRemoteEvents(ownerSub, events);
      final leads = _list(
        _data(
          await _api.send(
            token,
            const SyncRequest(method: 'GET', path: '/v1/leads'),
          ),
        ),
      );
      await _store.applyRemoteLeads(ownerSub, leads);
      for (final lead in leads) {
        final id = lead['id'];
        if (id is! String) continue;
        final media = _list(
          _data(
            await _api.send(
              token,
              SyncRequest(method: 'GET', path: '/v1/leads/$id/media'),
            ),
          ),
        );
        await _store.applyRemoteMedia(ownerSub, id, media);
      }
    } on SyncHttpException {
      // Pull is opportunistic; queued local writes remain the source of truth.
    } on SyncTransportException {
      // A later trigger retries the complete reconciliation safely.
    } on FormatException {
      // Invalid remote snapshots never overwrite valid local state.
    }
  }

  Object? _data(SyncResponse response) {
    final body = response.data;
    if (body is! Map) return null;
    return body['data'];
  }

  List<Map<String, Object?>> _list(Object? value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => item.cast<String, Object?>())
            .toList()
      : const [];
}
