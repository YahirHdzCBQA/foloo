/// Classifies durable email failures returned by the Foloo API.
///
/// Sync stores HTTP context in its diagnostic value, while remote pull stores
/// the domain code directly. Both forms must lead to the same terminal UI.
library;

const _httpConflictPrefix = 'http_409_';

/// Returns the stable backend code regardless of the sync diagnostic wrapper.
String? emailDeliveryErrorCode(String? value) {
  if (value == null) return null;
  return value.startsWith(_httpConflictPrefix)
      ? value.substring(_httpConflictPrefix.length)
      : value;
}

/// True when the recipient has explicitly been recorded as opted out.
bool isRecipientOptedOutError(String? value) =>
    emailDeliveryErrorCode(value) == 'recipient_opted_out';

/// Failures for which another send attempt is prohibited by the backend.
bool isTerminalEmailDeliveryError(String? value) {
  final code = emailDeliveryErrorCode(value);
  return code == 'recipient_opted_out' || code == 'email_retry_not_allowed';
}
