/// Session models and fixtures for Foloo V1 content and email-template surfaces.
///
/// The fixtures support local UI validation only. CON-* and PLT-* require
/// durable local/server-owned data in later delivery work.
library;

import 'app_event.dart';

/// Metadata for a PDF assigned to one or more events.
class ContentFile {
  const ContentFile({
    required this.id,
    required this.displayName,
    required this.fileName,
    required this.sizeLabel,
    this.byteSize = 0,
    this.localPath,
    this.allEvents = false,
    this.eventIds = const <String>{},
  });

  final String id;
  final String displayName;
  final String fileName;
  final String sizeLabel;
  final int byteSize;
  final String? localPath;
  final bool allEvents;
  final Set<String> eventIds;

  ContentFile copyWith({
    String? displayName,
    bool? allEvents,
    Set<String>? eventIds,
  }) => ContentFile(
    id: id,
    displayName: displayName ?? this.displayName,
    fileName: fileName,
    sizeLabel: sizeLabel,
    byteSize: byteSize,
    localPath: localPath,
    allEvents: allEvents ?? this.allEvents,
    eventIds: eventIds ?? this.eventIds,
  );

  bool appliesTo(AppEvent event) => allEvents || eventIds.contains(event.id);
}

/// Local fixtures used while the V1 content repository remains pending.
abstract final class DemoContentData {
  static const files = <ContentFile>[
    ContentFile(
      id: 'scanley-ims',
      displayName: 'Scanley IMS · Ficha técnica',
      fileName: 'scanley-ims.pdf',
      sizeLabel: '1.2 MB',
      byteSize: 1258291,
      eventIds: {'expo-alimentaria', 'foro-lacteo'},
    ),
    ContentFile(
      id: 'portafolio',
      displayName: 'CBQA General · Portafolio',
      fileName: 'cbqa-general.pdf',
      sizeLabel: '2.8 MB',
      byteSize: 2936013,
      allEvents: true,
    ),
    ContentFile(
      id: 'vision-ai',
      displayName: 'Vision AI · Casos de uso',
      fileName: 'vision-ai-casos.pdf',
      sizeLabel: '940 KB',
      byteSize: 962560,
      eventIds: {'expo-alimentaria'},
    ),
  ];
}

/// Editable in-memory representation of one V1 follow-up template.
class DemoEmailTemplate {
  const DemoEmailTemplate({required this.subject, required this.body});
  final String subject;
  final String body;
}
