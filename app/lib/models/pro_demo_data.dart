import 'app_event.dart';

class ContentFile {
  const ContentFile({
    required this.id,
    required this.displayName,
    required this.fileName,
    required this.sizeLabel,
    this.allEvents = false,
    this.eventIds = const <String>{},
  });

  final String id;
  final String displayName;
  final String fileName;
  final String sizeLabel;
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
    allEvents: allEvents ?? this.allEvents,
    eventIds: eventIds ?? this.eventIds,
  );

  bool appliesTo(AppEvent event) => allEvents || eventIds.contains(event.id);
}

abstract final class DemoProData {
  static const adminEmail = 'marketing@cbqasolutions.com';
  static const transcript =
      'Platicamos sobre automatizar la inspección de calidad. Solicita una demo con su equipo técnico.';

  static const files = <ContentFile>[
    ContentFile(
      id: 'scanley-ims',
      displayName: 'Scanley IMS · Ficha técnica',
      fileName: 'scanley-ims.pdf',
      sizeLabel: '1.2 MB',
      eventIds: {'expo-alimentaria', 'foro-lacteo'},
    ),
    ContentFile(
      id: 'vision-ai',
      displayName: 'Vision AI · Casos de uso',
      fileName: 'vision-ai-casos.pdf',
      sizeLabel: '940 KB',
      eventIds: {'expo-alimentaria'},
    ),
    ContentFile(
      id: 'portafolio',
      displayName: 'Portafolio CBQA Solutions',
      fileName: 'portafolio-2026.pdf',
      sizeLabel: '2.8 MB',
      allEvents: true,
    ),
  ];
}

class DemoEmailTemplate {
  const DemoEmailTemplate({required this.subject, required this.body});
  final String subject;
  final String body;
}
