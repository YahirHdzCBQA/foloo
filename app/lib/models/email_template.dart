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

/// Optional Event-scoped override; absence means live inheritance.
class EventEmailTemplateData {
  const EventEmailTemplateData({
    required this.eventId,
    required this.language,
    required this.subject,
    required this.body,
    required this.signature,
  });

  final String eventId;
  final String language;
  final String subject;
  final String body;
  final String signature;

  String get key => '$eventId:$language';

  Map<String, Object?> toSyncPayload() => {
    'eventId': eventId,
    'language': language,
    'subject': subject,
    'body': body,
    'signature': signature,
  };
}

/// Canonical official defaults used by editor, preview and preparation.
abstract final class FolooEmailDefaults {
  static EmailTemplateData forContext(String origin, String language) {
    final english = language == 'en';
    final context = origin == 'event' ? '{evento}' : '{lugar}';
    return EmailTemplateData(
      origin: origin,
      language: language,
      subject: english
          ? 'Following up, {nombre}'
          : 'Damos seguimiento, {nombre}',
      body: english
          ? 'Hi {nombre},\n\nIt was great meeting you at $context and having the opportunity to talk.\n\nI\'m sharing {contenido} as a follow-up to our conversation.\n\nFeel free to reach out if you have any questions. I hope we can stay in touch.'
          : 'Hola {nombre},\n\nFue un gusto conocerte en $context y poder platicar contigo.\n\nTe comparto {contenido}, como seguimiento a nuestra conversación.\n\nQuedo pendiente y espero que podamos seguir en contacto.',
      signature: english
          ? 'Best,\n{nombreVendedor}\n{empresaVendedor}'
          : 'Saludos,\n{nombreVendedor}\n{empresaVendedor}',
    );
  }
}
