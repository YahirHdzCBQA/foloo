/// Client boundary and models for the STORE-02 Account Deletion contract.
///
/// The production UI remains disabled until backend security dependencies are
/// approved. Tests may inject a synthetic implementation (AUT-18–AUT-21).
library;

import '../sync/sync_models.dart';

enum AccountDeletionStatus {
  awaitingConfirmation,
  requested,
  inProgress,
  blocked,
  completed,
}

class AccountDeletionPreflight {
  const AccountDeletionPreflight({
    required this.requestId,
    required this.pendingSyncCount,
    required this.exportAvailable,
    required this.subscriptionCancellationRequired,
  });

  final String requestId;
  final int pendingSyncCount;
  final bool exportAvailable;
  final bool subscriptionCancellationRequired;
}

class AccountDeletionAccepted {
  const AccountDeletionAccepted({
    required this.requestId,
    required this.receipt,
    required this.status,
  });

  final String requestId;
  final String receipt;
  final AccountDeletionStatus status;
}

/// Public receipt status that remains queryable after Cognito logout.
class AccountDeletionProgress {
  const AccountDeletionProgress({
    required this.requestId,
    required this.status,
    required this.updatedAt,
    this.completedAt,
    this.supportCode,
  });

  final String requestId;
  final AccountDeletionStatus status;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final String? supportCode;
}

abstract interface class AccountDeletionService {
  Future<bool> hasRecentAuthentication(String ownerSub);
  Future<AccountDeletionPreflight> createPreflight({
    required String ownerSub,
    required String locale,
    required bool requestedExport,
    required String idempotencyKey,
  });
  Future<AccountDeletionAccepted> confirm({
    required String ownerSub,
    required String requestId,
    required bool discardUnsyncedAccepted,
    required bool cancelRenewalAccepted,
    required String idempotencyKey,
  });

  /// Queries the receipt-only public route without requiring a user session.
  Future<AccountDeletionProgress> statusByReceipt(String receipt);
}

class ApiAccountDeletionService implements AccountDeletionService {
  const ApiAccountDeletionService(this._api, this._sessions);

  final SyncApi _api;
  final SyncSessionProvider _sessions;

  @override
  Future<bool> hasRecentAuthentication(String ownerSub) async {
    final data = await _request(
      ownerSub,
      const SyncRequest(
        method: 'POST',
        path: '/v1/account-deletion-reauthentication/verify',
      ),
    );
    return (data['recent'] as bool?) ?? false;
  }

  @override
  Future<AccountDeletionPreflight> createPreflight({
    required String ownerSub,
    required String locale,
    required bool requestedExport,
    required String idempotencyKey,
  }) async {
    final data = await _request(
      ownerSub,
      SyncRequest(
        method: 'POST',
        path: '/v1/account-deletion-requests',
        idempotencyKey: idempotencyKey,
        body: {'locale': locale, 'requestedExport': requestedExport},
      ),
    );
    final subscription = data['subscription'];
    return AccountDeletionPreflight(
      requestId: data['requestId'] as String,
      pendingSyncCount: data['pendingSyncCount'] as int? ?? 0,
      exportAvailable: data['exportAvailable'] as bool? ?? false,
      subscriptionCancellationRequired:
          subscription is Map && subscription['cancellationRequired'] == true,
    );
  }

  @override
  Future<AccountDeletionAccepted> confirm({
    required String ownerSub,
    required String requestId,
    required bool discardUnsyncedAccepted,
    required bool cancelRenewalAccepted,
    required String idempotencyKey,
  }) async {
    final data = await _request(
      ownerSub,
      SyncRequest(
        method: 'POST',
        path: '/v1/account-deletion-requests/$requestId/confirm',
        idempotencyKey: idempotencyKey,
        body: {
          'acknowledgementVersion': 'store-02-v1',
          'irreversibleAccepted': true,
          'discardUnsyncedAccepted': discardUnsyncedAccepted,
          'cancelRenewalAccepted': cancelRenewalAccepted,
        },
      ),
    );
    return AccountDeletionAccepted(
      requestId: data['requestId'] as String,
      receipt: data['receipt'] as String,
      status: _status(data['status'] as String),
    );
  }

  @override
  Future<AccountDeletionProgress> statusByReceipt(String receipt) async {
    final response = await _api.send(
      '',
      SyncRequest(
        method: 'POST',
        path: '/v1/account-deletion-status',
        body: {'receipt': receipt},
      ),
    );
    final envelope = response.data;
    if (envelope is! Map || envelope['data'] is! Map) {
      throw const AccountDeletionServiceException('invalid_response');
    }
    final data = Map<String, Object?>.from(envelope['data'] as Map);
    return AccountDeletionProgress(
      requestId: data['requestId'] as String,
      status: _status(data['status'] as String),
      updatedAt: DateTime.parse(data['updatedAt'] as String),
      completedAt: data['completedAt'] is String
          ? DateTime.parse(data['completedAt'] as String)
          : null,
      supportCode: data['supportCode'] as String?,
    );
  }

  Future<Map<String, Object?>> _request(
    String ownerSub,
    SyncRequest request,
  ) async {
    final token = await _sessions.accessTokenFor(ownerSub);
    if (token == null) throw const AccountDeletionServiceException('session');
    late final SyncResponse response;
    try {
      response = await _api.send(token, request);
    } on SyncHttpException catch (error) {
      throw AccountDeletionServiceException(
        error.errorCode ?? 'http_${error.statusCode}',
      );
    }
    final envelope = response.data;
    if (envelope is! Map || envelope['data'] is! Map) {
      throw const AccountDeletionServiceException('invalid_response');
    }
    return Map<String, Object?>.from(envelope['data'] as Map);
  }
}

class AccountDeletionServiceException implements Exception {
  const AccountDeletionServiceException(this.code);
  final String code;
}

AccountDeletionStatus _status(String value) => switch (value) {
  'awaiting_confirmation' => AccountDeletionStatus.awaitingConfirmation,
  'requested' => AccountDeletionStatus.requested,
  'in_progress' => AccountDeletionStatus.inProgress,
  'blocked' => AccountDeletionStatus.blocked,
  'completed' => AccountDeletionStatus.completed,
  _ => throw const AccountDeletionServiceException('invalid_status'),
};
