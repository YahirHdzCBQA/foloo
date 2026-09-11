/// Domain contracts for Foloo's persistent, owner-scoped sync queue.
///
/// These values contain no credentials or binary media and remain independent
/// from widgets and the concrete HTTP implementation (SYN-04–SYN-10).
library;

enum SyncEntityType { profile, event, lead, leadMedia }

enum SyncOperationStatus { pending, syncing, retryable, failed }

/// Identifies why an outbox drain started so retry timing remains explicit.
enum SyncTrigger {
  automatic,
  startup,
  postSave,
  appResume,
  scheduledRetry,
  connectivityRestored,
  manual;

  bool get ignoresRetryBackoff =>
      this == connectivityRestored || this == manual;

  int get priority => ignoresRetryBackoff ? 1 : 0;

  String get logName => switch (this) {
    automatic => 'automatic',
    startup => 'startup',
    postSave => 'post_save',
    appResume => 'app_resume',
    scheduledRetry => 'scheduled_retry',
    connectivityRestored => 'connectivity_restored',
    manual => 'manual',
  };
}

class SyncRequest {
  const SyncRequest({
    required this.method,
    required this.path,
    this.body,
    this.idempotencyKey,
  });

  final String method;
  final String path;
  final Map<String, Object?>? body;
  final String? idempotencyKey;
}

class SyncResponse {
  const SyncResponse({required this.statusCode, this.data, this.retryAfter});

  final int statusCode;
  final Object? data;
  final Duration? retryAfter;
}

class SyncTransportException implements Exception {
  const SyncTransportException([this.message = 'transport']);

  final String message;
}

class SyncHttpException implements Exception {
  const SyncHttpException(
    this.statusCode, {
    this.retryAfter,
    this.errorCode,
    this.requestId,
  });

  final int statusCode;
  final Duration? retryAfter;
  final String? errorCode;
  final String? requestId;

  bool get retryable =>
      statusCode == 408 || statusCode == 429 || statusCode >= 500;
}

abstract interface class SyncApi {
  Future<SyncResponse> send(String accessToken, SyncRequest request);
}

abstract interface class SyncSessionProvider {
  /// Returns a current Cognito access token only for [ownerSub].
  Future<String?> accessTokenFor(String ownerSub);
}

class NoSyncSessionProvider implements SyncSessionProvider {
  const NoSyncSessionProvider();

  @override
  Future<String?> accessTokenFor(String ownerSub) async => null;
}
