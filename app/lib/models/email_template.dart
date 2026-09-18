/// User-owned follow-up template draft for Event or Direct origin.
///
/// This model contains editable text only; the privacy footer and provider
/// credentials are never stored in a mobile template (PLT-01–PLT-07).
library;

/// Durable editable variant keyed by owner, origin and language.
class EmailTemplateData {
  const EmailTemplateData({
    required this.origin,
    required this.language,
    required this.subject,
    required this.body,
    required this.signature,
  });

  final String origin;
  final String language;
  final String subject;
  final String body;
  final String signature;

  String get key => '$origin:$language';

  Map<String, Object?> toSyncPayload() => {
    'origin': origin,
    'language': language,
    'subject': subject,
    'body': body,
    'signature': signature,
  };
}
