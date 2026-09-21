/// Serial offline-first synchronizer for Foloo's persistent Drift outbox.
///
/// It obtains authentication at execution time, preserves idempotency keys,
/// schedules bounded retries and reconciles safe server snapshots (SYN-04–10).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/local/app_database.dart';
import 'media_binary_transfer.dart';
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
    this.mediaTransfer,
  }) : _now = now ?? DateTime.now;

  final SyncStore _store;
  final SyncApi _api;
  final SyncSessionProvider _sessions;
  final DateTime Function() _now;
  final MediaBinaryTransfer? mediaTransfer;
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
    final repairedEmailFailures = await _store.reconcileTerminalEmailFailures(
      ownerSub,
    );
    if (repairedEmailFailures > 0) {
      logger({
        'scope': 'sync_repair',
        'entityType': SyncEntityType.emailSendIntent.name,
        'result': 'terminal_state_restored',
        'count': repairedEmailFailures,
      });
    }
    if (trigger == SyncTrigger.manual) {
      final leadRepairs = await _store.repairFailedLeadContracts(ownerSub);
      for (final repair in leadRepairs) {
        logger({
          'scope': 'sync_repair',
          'entityType': SyncEntityType.lead.name,
          'operationId': repair.operationId,
          'entityId': repair.leadId,
          'result': repair.result,
        });
      }
      final repairs = [
        ...await _store.repairFailedMediaTimestamps(ownerSub),
        ...await _store.repairFailedImageContent(ownerSub),
      ];
      for (final repair in repairs) {
        logger({
          'scope': 'sync_repair',
          'entityType': SyncEntityType.leadMedia.name,
          'operationId': repair.operationId,
          'mediaId': repair.mediaId,
          'result': repair.result,
        });
      }
    }
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
    if (trigger == SyncTrigger.manual) {
      await _rebaseRevisionConflicts(ownerSub, token);
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
        final response = await _sendOperation(token, operation);
        final data = _data(response);
        await _store.complete(
          operation,
          remoteData: data is Map<String, Object?> ? data : null,
        );
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
        if (error.statusCode == 404 &&
            (operation.entityType == SyncEntityType.content.name ||
                operation.entityType == SyncEntityType.contentBinary.name)) {
          // DEV can briefly run an older API during FL-018 rollout. Keep the
          // local PDF/outbox retryable instead of stranding it as failed.
          await _retry(
            operation,
            error.retryAfter,
            _httpError(error),
            httpStatus: error.statusCode,
          );
          continue;
        }
        if (error.errorCode == 'revision_conflict') {
          await _store.markRevisionConflict(
            operation,
            _httpError(error),
            _now(),
          );
          _log(
            operation,
            'conflict',
            httpStatus: error.statusCode,
            error: error.errorCode,
            requestId: error.requestId,
          );
        } else if (error.retryable) {
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
      } on MediaTransferException catch (error) {
        if (error.code == 'local_metadata_missing') {
          await _store.markFailed(
            operation,
            'media_upload_${error.code}',
            _now(),
          );
          _logMedia(
            operation,
            'failed',
            error: error.code,
            storageCode: error.storageCode,
          );
          continue;
        }
        _logMedia(
          operation,
          'retry',
          httpStatus: error.statusCode,
          error: error.code,
          storageCode: error.storageCode,
        );
        await _retry(
          operation,
          null,
          'media_upload_${error.statusCode ?? error.code}',
          httpStatus: error.statusCode,
        );
      } on Object catch (error) {
        // A request adapter must not leave a durable row stuck in `syncing`.
        await _retry(operation, null, 'unexpected_${error.runtimeType}');
      }
    }
    return hadBlockedChildren;
  }

  Future<SyncResponse> _sendOperation(
    String token,
    StoredSyncOperation operation,
  ) async {
    if (operation.entityType == SyncEntityType.contentBinary.name) {
      if (mediaTransfer == null) {
        throw const MediaTransferException(code: 'transport');
      }
      final content = await _store.database.contentDao.byId(
        operation.ownerUserId,
        operation.entityId,
      );
      if (content?.deleted == true) {
        // A local tombstone supersedes an upload that has not yet started.
        return const SyncResponse(statusCode: 200);
      }
      if (content == null || content.localPath == null) {
        throw const MediaTransferException(code: 'local_metadata_missing');
      }
      final localPath = await _store.mediaStorage?.resolveExistingPath(
        content.localPath!,
      );
      if (localPath == null) {
        throw const MediaTransferException(code: 'local_file_missing');
      }
      final authorization = await _api.send(
        token,
        SyncRequest(
          method: 'POST',
          path: '/v1/content/${operation.entityId}/uploads',
        ),
      );
      final upload = _uploadTarget(authorization);
      await mediaTransfer!.upload(
        url: upload.url,
        headers: upload.headers,
        localPath: localPath,
      );
      return _api.send(token, _request(operation));
    }
    if (operation.entityType != SyncEntityType.leadMedia.name ||
        mediaTransfer == null) {
      return _api.send(token, _request(operation));
    }
    final payload = _payload(operation);
    final leadId = payload.remove('leadId');
    if (leadId is! String) {
      throw const FormatException('Media operation has no leadId.');
    }
    final media = await _store.mediaById(operation.entityId);
    if (media == null) {
      throw const MediaTransferException(code: 'local_metadata_missing');
    }
    _logMedia(operation, 'upload_start');
    final authorization = await _api.send(
      token,
      SyncRequest(
        method: 'POST',
        path: '/v1/leads/$leadId/media/uploads',
        body: payload,
      ),
    );
    final upload = _uploadTarget(authorization);
    _logMediaAuthorization(operation, payload, upload.headers);
    await mediaTransfer!.upload(
      url: upload.url,
      headers: upload.headers,
      localPath: media.localPath,
    );
    _logMedia(operation, 'upload_success');
    final confirmation = await _api.send(token, _request(operation));
    _logMedia(operation, 'confirm_success');
    return confirmation;
  }

  Future<void> _rebaseRevisionConflicts(String ownerSub, String token) async {
    try {
      final events = _list(
        _data(
          await _api.send(
            token,
            const SyncRequest(method: 'GET', path: '/v1/events'),
          ),
        ),
      );
      final leads = _list(
        _data(
          await _api.send(
            token,
            const SyncRequest(method: 'GET', path: '/v1/leads'),
          ),
        ),
      );
      var content = <Map<String, Object?>>[];
      try {
        content = _list(
          _data(
            await _api.send(
              token,
              const SyncRequest(method: 'GET', path: '/v1/content'),
            ),
          ),
        );
      } on SyncHttpException {
        // FL-017 conflicts remain recoverable during a staged FL-018 deploy.
      }
      final repaired = await _store.rebaseRevisionConflicts(
        ownerSub,
        leads,
        remoteEvents: events,
        remoteContent: content,
      );
      if (repaired > 0) {
        logger({
          'scope': 'sync_conflict',
          'result': 'rearmed',
          'count': repaired,
        });
      }
    } on SyncHttpException {
      // The local edit and conflict state remain durable for a later retry.
    } on SyncTransportException {
      // The local edit and conflict state remain durable for a later retry.
    } on FormatException {
      // Invalid remote data must never replace the local edit.
    }
  }

  ({Uri url, Map<String, String> headers}) _uploadTarget(
    SyncResponse response,
  ) {
    final data = _data(response);
    if (data is! Map) throw const FormatException('Missing upload data.');
    final upload = data['upload'];
    if (upload is! Map || upload['url'] is! String) {
      throw const FormatException('Missing upload target.');
    }
    final rawHeaders = upload['headers'];
    final headers = rawHeaders is Map
        ? rawHeaders.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : <String, String>{};
    return (url: Uri.parse(upload['url'] as String), headers: headers);
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

  void _logMedia(
    StoredSyncOperation operation,
    String result, {
    int? httpStatus,
    String? error,
    String? storageCode,
  }) {
    final event = <String, Object?>{
      'scope': 'media_upload',
      'mediaId': operation.entityId,
      'operationId': operation.operationId,
      'result': result,
    };
    if (httpStatus != null) event['httpStatus'] = httpStatus;
    if (error != null) event['errorClass'] = error;
    if (storageCode != null) event['storageErrorCode'] = storageCode;
    logger(event);
  }

  void _logMediaAuthorization(
    StoredSyncOperation operation,
    Map<String, Object?> payload,
    Map<String, String> headers,
  ) {
    final normalized = headers.map(
      (key, value) => MapEntry(key.toLowerCase(), value),
    );
    logger({
      'scope': 'media_upload',
      'mediaId': operation.entityId,
      'operationId': operation.operationId,
      'result': 'authorization_received',
      'requiredHeaders': normalized.keys.toList()..sort(),
      'contentTypeMatches':
          normalized['content-type'] == payload['contentType'],
      'mediaMetadataPresent':
          normalized['x-amz-meta-foloo-media-id'] == operation.entityId,
    });
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
      SyncEntityType.lead => await _hasPendingLeadParent(
        operation.ownerUserId,
        payload,
      ),
      SyncEntityType.leadMedia => switch (payload['leadId']) {
        final String leadId => _store.hasPending(
          operation.ownerUserId,
          SyncEntityType.lead,
          leadId,
        ),
        _ => false,
      },
      SyncEntityType.content => _hasPendingContentEvent(
        operation.ownerUserId,
        payload,
      ),
      SyncEntityType.contentBinary => _store.hasPending(
        operation.ownerUserId,
        SyncEntityType.content,
        operation.entityId,
      ),
      SyncEntityType.event =>
        operation.action == 'delete' && await _hasPendingLeadCreate(operation),
      SyncEntityType.profile => false,
      SyncEntityType.emailTemplate => false,
      SyncEntityType.emailFollowUp => switch (payload['leadId']) {
        final String leadId => _store.hasPending(
          operation.ownerUserId,
          SyncEntityType.lead,
          leadId,
        ),
        _ => false,
      },
      SyncEntityType.emailSendIntent => switch (payload['followUpId']) {
        final String followUpId => _store.hasPending(
          operation.ownerUserId,
          SyncEntityType.emailFollowUp,
          followUpId,
        ),
        _ => false,
      },
    };
  }

  Future<bool> _hasPendingLeadCreate(StoredSyncOperation event) async {
    for (final lead in await _store.database.leadDao.byEvent(
      event.ownerUserId,
      event.entityId,
    )) {
      final operations = await _store.database.syncDao.forEntity(
        event.ownerUserId,
        SyncEntityType.lead.name,
        lead.localId,
      );
      if (operations.any(
        (item) =>
            item.action == 'create' &&
            (item.status == 'pending' ||
                item.status == 'retryable' ||
                item.status == 'syncing'),
      )) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _hasPendingContentEvent(
    String ownerSub,
    Map<String, Object?> payload,
  ) async {
    final ids = payload['eventIds'];
    if (ids is! List) return false;
    for (final id in ids.whereType<String>()) {
      final operations = await _store.database.syncDao.forEntity(
        ownerSub,
        SyncEntityType.event.name,
        id,
      );
      if (operations.any(
        (item) => item.action == 'create' && item.status != 'completed',
      )) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _hasPendingLeadParent(
    String ownerSub,
    Map<String, Object?> payload,
  ) async {
    final eventId = payload['eventId'];
    if (eventId is String) {
      final events = await _store.database.syncDao.forEntity(
        ownerSub,
        SyncEntityType.event.name,
        eventId,
      );
      if (events.any(
        (item) => item.action == 'create' && item.status != 'completed',
      )) {
        return true;
      }
    }
    final ids = payload['contentFileIds'];
    if (ids is List) {
      for (final id in ids.whereType<String>()) {
        final operations = await _store.database.syncDao.forEntity(
          ownerSub,
          SyncEntityType.content.name,
          id,
        );
        if (operations.any(
          (item) => item.action == 'create' && item.status != 'completed',
        )) {
          return true;
        }
      }
    }
    return false;
  }

  String _httpError(SyncHttpException error) => error.errorCode == null
      ? 'http_${error.statusCode}'
      : 'http_${error.statusCode}_${error.errorCode}';

  Map<String, Object?> _payload(StoredSyncOperation operation) =>
      (jsonDecode(operation.payloadJson) as Map).cast<String, Object?>();

  String _endpoint(StoredSyncOperation operation) => switch (SyncEntityType
      .values
      .byName(operation.entityType)) {
    SyncEntityType.profile => '/v1/profile',
    SyncEntityType.emailTemplate => '/v1/email/templates',
    SyncEntityType.emailFollowUp => '/v1/email/follow-ups',
    SyncEntityType.emailSendIntent =>
      operation.action == 'retry' || operation.action == 'cancel'
          ? '/v1/email/send-intents/${operation.entityId}/${operation.action}'
          : '/v1/email/follow-ups/${_payload(operation)['followUpId']}/${operation.action == 'resend' ? 'resend' : 'confirm'}',
    SyncEntityType.event =>
      operation.action == 'create'
          ? '/v1/events'
          : '/v1/events/${operation.entityId}',
    SyncEntityType.lead =>
      operation.action == 'update'
          ? '/v1/leads/${operation.entityId}'
          : '/v1/leads',
    SyncEntityType.leadMedia =>
      '/v1/leads/${_payload(operation)['leadId']}/media',
    SyncEntityType.content =>
      operation.action == 'create'
          ? '/v1/content'
          : '/v1/content/${operation.entityId}',
    SyncEntityType.contentBinary => '/v1/content/${operation.entityId}/confirm',
  };

  SyncRequest _request(StoredSyncOperation operation) {
    final payload = _payload(operation);
    return switch (SyncEntityType.values.byName(operation.entityType)) {
      SyncEntityType.profile => SyncRequest(
        method: 'PUT',
        path: '/v1/profile',
        body: payload,
      ),
      SyncEntityType.emailTemplate => SyncRequest(
        method: 'PUT',
        path: '/v1/email/templates',
        body: payload,
        idempotencyKey: operation.idempotencyKey,
      ),
      SyncEntityType.emailFollowUp => SyncRequest(
        method: 'POST',
        path: '/v1/email/follow-ups',
        body: payload,
        idempotencyKey: operation.idempotencyKey,
      ),
      SyncEntityType.emailSendIntent =>
        operation.action == 'retry' || operation.action == 'cancel'
            ? SyncRequest(
                method: 'POST',
                path:
                    '/v1/email/send-intents/${operation.entityId}/${operation.action}',
                idempotencyKey: operation.idempotencyKey,
              )
            : SyncRequest(
                method: 'POST',
                path:
                    '/v1/email/follow-ups/${payload.remove('followUpId')}/${operation.action == 'resend' ? 'resend' : 'confirm'}',
                body: payload,
                idempotencyKey: operation.idempotencyKey,
              ),
      SyncEntityType.event => SyncRequest(
        method: operation.action == 'create'
            ? 'POST'
            : operation.action == 'delete'
            ? 'DELETE'
            : 'PUT',
        path: operation.action == 'create'
            ? '/v1/events'
            : '/v1/events/${operation.entityId}',
        body: payload,
        idempotencyKey: operation.idempotencyKey,
      ),
      SyncEntityType.lead => SyncRequest(
        method: operation.action == 'update' ? 'PUT' : 'POST',
        path: operation.action == 'update'
            ? '/v1/leads/${operation.entityId}'
            : '/v1/leads',
        body: payload,
        idempotencyKey: operation.idempotencyKey,
      ),
      SyncEntityType.leadMedia => SyncRequest(
        method: 'POST',
        path: '/v1/leads/${payload.remove('leadId')}/media',
        body: payload,
        idempotencyKey: operation.idempotencyKey,
      ),
      SyncEntityType.content => SyncRequest(
        method: operation.action == 'create'
            ? 'POST'
            : operation.action == 'delete'
            ? 'DELETE'
            : 'PUT',
        path: operation.action == 'create'
            ? '/v1/content'
            : '/v1/content/${operation.entityId}',
        body: payload,
        idempotencyKey: operation.idempotencyKey,
      ),
      SyncEntityType.contentBinary => SyncRequest(
        method: 'POST',
        path: '/v1/content/${operation.entityId}/confirm',
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
      try {
        final templates = _list(
          _data(
            await _api.send(
              token,
              const SyncRequest(method: 'GET', path: '/v1/email/templates'),
            ),
          ),
        );
        await _store.applyRemoteEmailTemplates(ownerSub, templates);
      } on SyncHttpException {
        // A DEV backend without FL-019 must not block existing sync flows.
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
      try {
        final content = _list(
          _data(
            await _api.send(
              token,
              const SyncRequest(method: 'GET', path: '/v1/content'),
            ),
          ),
        );
        await _store.applyRemoteContent(
          ownerSub,
          content,
          download: mediaTransfer == null
              ? null
              : (url, contentType) =>
                    mediaTransfer!.download(url: url, contentType: contentType),
        );
      } on SyncHttpException {
        // Older DEV deployments may not expose FL-018 yet. Other entities
        // must continue to reconcile while deployment catches up.
      } on MediaTransferException {
        // A later pull obtains a fresh temporary download authorization.
      } on FormatException {
        // Invalid Content metadata never blocks Lead reconciliation.
      } on FileSystemException {
        // Local storage pressure is surfaced on open; other entities continue.
      }
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
        await _store.applyRemoteMedia(
          ownerSub,
          id,
          media,
          download: mediaTransfer == null
              ? null
              : (url, contentType) async {
                  try {
                    return await mediaTransfer!.download(
                      url: url,
                      contentType: contentType,
                    );
                  } on MediaTransferException {
                    rethrow;
                  }
                },
        );
      }
      try {
        final followUps = _list(
          _data(
            await _api.send(
              token,
              const SyncRequest(method: 'GET', path: '/v1/email/follow-ups'),
            ),
          ),
        );
        await _store.applyRemoteEmailFollowUps(ownerSub, followUps);
      } on SyncHttpException {
        // A pre-FL-019 DEV backend must not block existing entity pull.
      }
    } on SyncHttpException {
      // Pull is opportunistic; queued local writes remain the source of truth.
    } on SyncTransportException {
      // A later trigger retries the complete reconciliation safely.
    } on FormatException {
      // Invalid remote snapshots never overwrite valid local state.
    } on MediaTransferException {
      // Remote recovery is opportunistic; a later pull obtains a fresh URL.
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
