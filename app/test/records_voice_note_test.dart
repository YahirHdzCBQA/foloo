import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/models/app_destination.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/models/app_plan.dart';
import 'package:foloo/models/lead_draft.dart';
import 'package:foloo/models/session_lead.dart';
import 'package:foloo/screens/records_screen.dart';
import 'package:foloo/theme/foloo_theme.dart';
import 'package:image/image.dart' as image_codec;

import 'support/fake_voice_note_service.dart';

LeadDraft lead({
  String? audioPath,
  int audioSeconds = 0,
  String? cardImagePath,
  String eventId = 'expo-alimentaria',
  String eventName = DemoEventData.eventName,
  String name = 'Mariana',
  List<String> referenceImagePaths = const [],
}) => LeadDraft(
  name: name,
  lastName: 'Sandoval Ruiz',
  role: 'Gerente de calidad',
  company: 'Grupo Lácteo del Norte',
  email: 'mariana@example.com',
  phone: '',
  type: LeadType.customer,
  interest: InterestLevel.high,
  note: '',
  originKind: LeadOriginKind.event,
  eventLocalId: eventId,
  eventName: eventName,
  audioLocalPath: audioPath,
  audioSeconds: audioSeconds,
  cardImageLocalPath: cardImagePath,
  referenceImageLocalPaths: referenceImagePaths,
);

Widget recordsApp(
  FakeVoiceNoteService service, {
  required List<SessionLead> records,
  ValueChanged<AppDestination>? onDestinationSelected,
  bool darkMode = false,
  List<AppEvent> events = const [],
  AppPlan plan = AppPlan.basic,
}) => MaterialApp(
  theme: FolooTheme.light,
  darkTheme: FolooTheme.dark,
  themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
  home: RecordsScreen(
    records: records,
    darkMode: darkMode,
    events: events,
    voiceNoteService: service,
    plan: plan,
    onDestinationSelected: onDestinationSelected ?? (_) {},
    onAppearanceChanged: (_) {},
    onLogout: () {},
  ),
);

void main() {
  testWidgets('record with local audio can play pause resume and replay', (
    tester,
  ) async {
    final service = FakeVoiceNoteService();
    AppDestination? selectedDestination;
    final record = SessionLead(
      localId: 'EXP-260812-001',
      folio: 'EXP-260812-001',
      capturedAt: DateTime(2026, 8, 20, 12, 45),
      lead: lead(audioPath: '/tmp/foloo_voice_1.m4a', audioSeconds: 32),
    );
    await tester.pumpWidget(
      recordsApp(
        service,
        records: [record],
        onDestinationSelected: (value) => selectedDestination = value,
      ),
    );

    final audioButton = find.byKey(const Key('recordAudio-EXP-260812-001'));
    expect(audioButton, findsOneWidget);
    expect(find.byKey(const Key('recordAudio-EXP-260812-001')), findsOneWidget);

    await tester.tap(audioButton);
    await tester.pump();
    expect(service.playCount, 1);
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await tester.tap(audioButton);
    await tester.pump();
    expect(service.pauseCount, 1);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await tester.tap(audioButton);
    await tester.pump();
    expect(service.resumeCount, 1);

    service.completePlayback();
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await tester.tap(audioButton);
    await tester.pump();
    expect(service.playCount, 2);

    await tester.tap(find.byKey(const Key('hamburgerMenuButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drawerHome')));
    await tester.pumpAndSettle();
    expect(selectedDestination, AppDestination.home);
    expect(service.stopPlaybackCount, greaterThanOrEqualTo(3));
  });

  testWidgets('record without audio does not show a playback control', (
    tester,
  ) async {
    final service = FakeVoiceNoteService();
    final record = SessionLead(
      localId: 'EXP-260812-002',
      folio: 'EXP-260812-002',
      capturedAt: DateTime(2026, 8, 20, 12, 46),
      lead: lead(),
    );
    await tester.pumpWidget(recordsApp(service, records: [record]));

    expect(find.byKey(const Key('recordAudio-EXP-260812-002')), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
    for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
      expect(chip.showCheckmark, isFalse);
    }
  });

  testWidgets('REG-02 event dropdown filters records and updates results', (
    tester,
  ) async {
    final service = FakeVoiceNoteService();
    final events = [
      AppEvent(
        id: 'event-a',
        name: 'Evento A',
        startsOn: DateTime(2026, 8, 20),
        endsOn: DateTime(2026, 8, 21),
        active: true,
      ),
      AppEvent(
        id: 'event-b',
        name: 'Evento B',
        startsOn: DateTime(2026, 8, 22),
        endsOn: DateTime(2026, 8, 23),
      ),
    ];
    final records = [
      SessionLead(
        localId: 'lead-a',
        folio: 'lead-a',
        capturedAt: DateTime(2026, 8, 20),
        lead: lead(eventId: 'event-a', eventName: 'Evento A', name: 'Ana'),
      ),
      SessionLead(
        localId: 'lead-b',
        folio: 'lead-b',
        capturedAt: DateTime(2026, 8, 22),
        lead: lead(eventId: 'event-b', eventName: 'Evento B', name: 'Beatriz'),
      ),
    ];
    await tester.pumpWidget(
      recordsApp(service, records: records, events: events),
    );

    expect(find.text('Ana Sandoval Ruiz'), findsOneWidget);
    expect(find.text('Beatriz Sandoval Ruiz'), findsNothing);

    await tester.tap(find.byKey(const Key('recordsEventFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Evento B').last);
    await tester.pumpAndSettle();

    expect(find.text('Ana Sandoval Ruiz'), findsNothing);
    expect(find.text('Beatriz Sandoval Ruiz'), findsOneWidget);
    expect(find.text('1 lead · 1 por subir'), findsOneWidget);

    await tester.tap(find.byKey(const Key('recordsEventFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todos los eventos').last);
    await tester.pumpAndSettle();

    expect(find.text('Ana Sandoval Ruiz'), findsOneWidget);
    expect(find.text('Beatriz Sandoval Ruiz'), findsOneWidget);
    expect(find.text('2 leads · 2 por subir'), findsOneWidget);
  });

  testWidgets(
    'detail pills stay legible in dark mode and card opens a viewer',
    (tester) async {
      final service = FakeVoiceNoteService();
      final record = SessionLead(
        localId: 'EXP-260812-003',
        folio: 'EXP-260812-003',
        capturedAt: DateTime(2026, 8, 20, 12, 47),
        lead: lead(cardImagePath: '/tmp/foloo_missing_card.jpg'),
      );
      await tester.pumpWidget(
        recordsApp(service, records: [record], darkMode: true),
      );

      await tester.tap(find.text('Mariana Sandoval Ruiz'));
      await tester.pumpAndSettle();

      for (final key in const [
        Key('detailInterestPill'),
        Key('detailUploadStatePill'),
      ]) {
        final pillFinder = find.descendant(
          of: find.byKey(key),
          matching: find.byType(Container),
        );
        final pill = tester.widget<Container>(pillFinder.first);
        final background = (pill.decoration! as BoxDecoration).color;
        final label = tester.widget<Text>(
          find
              .descendant(of: find.byKey(key), matching: find.byType(Text))
              .last,
        );
        expect(label.style!.color, isNot(background));
      }

      await tester.tap(find.byKey(const Key('detailCardImageButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detailCardImageDialog')), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detailCardImageDialog')), findsNothing);
    },
  );

  testWidgets('REG-13 Pro detail shows and opens reference images', (
    tester,
  ) async {
    final temporary = Directory.systemTemp.createTempSync(
      'foloo_reference_detail_',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final image = File('${temporary.path}/reference.png');
    image.writeAsBytesSync(
      image_codec.encodePng(image_codec.Image(width: 2, height: 2)),
    );
    final service = FakeVoiceNoteService();
    final record = SessionLead(
      localId: 'lead-reference',
      folio: null,
      capturedAt: DateTime(2026, 9, 1),
      lead: lead(referenceImagePaths: [image.path]),
    );
    await tester.pumpWidget(
      recordsApp(service, records: [record], plan: AppPlan.pro),
    );

    await tester.tap(find.text('Mariana Sandoval Ruiz'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.byKey(const Key('detailReferenceImages')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Imágenes de referencia'), findsOneWidget);
    await tester.tap(find.byKey(const Key('detailReferenceImage-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('detailReferenceImageDialog')), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('detailReferenceImageDialog')), findsNothing);
  });

  testWidgets('export dialog opens and switches format without layout errors', (
    tester,
  ) async {
    final service = FakeVoiceNoteService();
    await tester.pumpWidget(recordsApp(service, records: const []));

    await tester.tap(find.byKey(const Key('exportButton')));
    await tester.pumpAndSettle();

    expect(find.text('Exportar registros'), findsOneWidget);
    expect(find.byKey(const Key('exportXlsOption')), findsOneWidget);
    expect(find.byKey(const Key('exportCsvOption')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('exportCsvOption')));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('confirmExportButton')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Exportación CSV'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
