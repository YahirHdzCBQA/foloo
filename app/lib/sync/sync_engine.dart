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
    this.onRetryScheduled,
  }) : _now = now ?? DateTime.now;

  final SyncStore _store;
  final SyncApi _api;
  final SyncSessionProvider _sessions;
  final DateTime Function() _now;
  final void Function(Map<String, Object?> event) logger;
  final void Function(String ownerSub, DateTime nextAttemptAt)?
  onRetryScheduled;
  final Map<String, SyncTrigger> _queuedTriggers = {};
  bool _running = false;
  Future<void>? _activeRun;

  bool get running => _running;

  Future<void> synchronize(
    String ownerSub, {
    SyncTrigger trigger = SyncTrigger.automatic,
  }) async {
    if (_running) {
      _queue(ownerSub, trigger);
      await _activeRun;
      return;
    }
    final run = _drain(ownerSub, trigger);
    _activeRun = run;
    try {
      await run;
    } finally {
      if (identical(_activeRun, run)) _activeRun = null;
    }
  }

  Future<void> _drain(String ownerSub, SyncTrigger trigger) async {
    _running = true;
    notifyListeners();
    try {
      await _synchronizeOnce(ownerSub, trigger);
      while (_queuedTriggers.isNotEmpty) {
        final queued = _queuedTriggers.entries.first;
        _queuedTriggers.remove(queued.key);
        await _synchronizeOnce(queued.key, queued.value);
      }
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  Future<void> _synchronizeOnce(String ownerSub, SyncTrigger trigger) async {
    logger({'scope': 'sync_trigger', 'trigger': trigger.logName});
    await _logOutbox(ownerSub);
    String? token;
    try {
      token = await _sessions.accessTokenFor(ownerSub);
    } on Object catch (error) {
      logger({
        'scope': 'sync_trigger',
        'trigger': trigger.logName,
        'result': 'no_session',
        'errorClass': error.runtimeType.toString(),
      });
      return;
    }
    if (token == null) {
      logger({
        'scope': 'sync_trigger',
        'trigger': trigger.logName,
        'result': 'no_session',
      });
      return;
    }
    final hadBlockedChildren = await _pushDue(ownerSub, token, trigger);
    await _pull(ownerSub, token);
    if (hadBlockedChildren) {
      // Pull may confirm a parent whose create response was lost. A single
      // dependency pass lets children continue without another user trigger.
      await _pushDue(ownerSub, token, SyncTrigger.automatic);
    }
  }

  Future<bool> _pushDue(
    String ownerSub,
    String token,
    SyncTrigger trigger,
  ) async {
    var hadBlockedChildren = false;
    for (final operation in await _store.due(
      ownerSub,
      _now(),
      ignoreRetryBackoff: trigger.ignoresRetryBackoff,
    )) {
      if (await _blockedByParent(operation)) {
        hadBlockedChildren = true;
        _log(operation, 'blocked_by_parent');
        continue;
      }
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
          _log(
            operation,
            'paused',
            httpStatus: error.statusCode,
            error: error.errorCode ?? 'authentication',
            requestId: error.requestId,
          );
          return hadBlockedChildren;
        }
        if (error.retryable) {
          await _retry(
            operation,
            error.retryAfter,
            _httpError(error),
            httpStatus: error.statusCode,
          );
        } else {
          await _store.markFailed(operation, _httpError(error), _now());
          _log(
            operation,
            'failed',
            httpStatus: error.statusCode,
            error: error.errorCode ?? 'http_error',
            requestId: error.requestId,
          );
        }
      } on SyncTransportException {
        await _retry(operation, null, 'transport');
      } on Object catch (error) {
        // A request adapter must not leave a durable row stuck in `syncing`.
        await _retry(operation, null, 'unexpected_${error.runtimeType}');
      }
    }
    return hadBlockedChildren;
  }

  void _queue(String ownerSub, SyncTrigger trigger) {
    final current = _queuedTriggers[ownerSub];
    if (current == null || trigger.priority > current.priority) {
      _queuedTriggers[ownerSub] = trigger;
    }
  }

  Future<void> _logOutbox(String ownerSub) async {
    for (final operation in await _store.all(ownerSub)) {
      final event = <String, Object?>{
        'scope': 'sync_outbox',
        'operationId': operation.operationId,
        'entityType': operation.entityType,
        'entityId': operation.entityId,
        'action': operation.action,
        'endpoint': _endpoint(operation),
        'status': operation.status,
        'attempt': operation.attemptCount,
      };
      if (operation.nextAttemptAt != null) {
        event['nextAttemptAt'] = operation.nextAttemptAt!.toIso8601String();
      }
      if (operation.lastError != null) {
        event['lastError'] = operation.lastError;
      }
      logger(event);
    }
  }

  void _log(
    StoredSyncOperation operation,
    String result, {
    int? httpStatus,
    String? error,
    String? requestId,
  }) {
    final event = <String, Object?>{
      'scope': 'sync_operation',
      'operationId': operation.operationId,
      'entityType': operation.entityType,
      'entityId': operation.entityId,
      'action': operation.action,
      'endpoint': _endpoint(operation),
      'attempt': operation.attemptCount + 1,
      'result': result,
    };
    if (httpStatus != null) event['httpStatus'] = httpStatus;
    if (error != null) event['errorClass'] = error;
    if (requestId != null) event['requestId'] = requestId;
    logger(event);
  }

  static void _defaultLogger(Map<String, Object?> event) {
    if (kDebugMode) debugPrint(jsonEncode(event));
  }

  Future<void> _retry(
    StoredSyncOperation operation,
    Duration? retryAfter,
    String error, {
    int? httpStatus,
  }) async {
    final attempt = operation.attemptCount + 1;
    final seconds = math.min(3600, math.pow(2, attempt).toInt());
    final delay = retryAfter != null && retryAfter > Duration(seconds: seconds)
        ? retryAfter
        : Duration(seconds: seconds);
    final now = _now();
    final nextAttemptAt = now.add(delay);
    await _store.markRetryable(operation, nextAttemptAt, error, now);
    _log(operation, 'retryable', httpStatus: httpStatus, error: error);
    onRetryScheduled?.call(operation.ownerUserId, nextAttemptAt);
  }

  Future<bool> _blockedByParent(StoredSyncOperation operation) async {
    final payload = _payload(operation);
    return switch (SyncEntityType.values.byName(operation.entityType)) {
      SyncEntityType.lead => switch (payload['eventId']) {
        final String eventId => _store.hasPending(
          operation.ownerUserId,
          SyncEntityType.event,
          eventId,
        ),
        _ => false,
      },
      SyncEntityType.leadMedia => switch (payload['leadId']) {
        final String leadId => _store.hasPending(
          operation.ownerUserId,
          SyncEntityType.lead,
          leadId,
        ),
        _ => false,
      },
      SyncEntityType.profile || SyncEntityType.event => false,
    };
  }

  String _httpError(SyncHttpException error) => error.errorCode == null
      ? 'http_${error.statusCode}'
      : 'http_${error.statusCode}_${error.errorCode}';

  Map<String, Object?> _payload(StoredSyncOperation operation) =>
      (jsonDecode(operation.payloadJson) as Map).cast<String, Object?>();

  String _endpoint(StoredSyncOperation operation) =>
      switch (SyncEntityType.values.byName(operation.entityType)) {
        SyncEntityType.profile => '/v1/profile',
        SyncEntityType.event => '/v1/events',
        SyncEntityType.lead => '/v1/leads',
        SyncEntityType.leadMedia =>
          '/v1/leads/${_payload(operation)['leadId']}/media',
      };

  SyncRequest _request(StoredSyncOperation operation) {
    final payload = _payload(operation);
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
