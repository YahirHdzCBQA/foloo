import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/models/app_destination.dart';
import 'package:foloo/models/lead_draft.dart';
import 'package:foloo/models/session_lead.dart';
import 'package:foloo/screens/records_screen.dart';
import 'package:foloo/theme/foloo_theme.dart';

import 'support/fake_voice_note_service.dart';

LeadDraft lead({
  String? audioPath,
  int audioSeconds = 0,
  String? cardImagePath,
}) => LeadDraft(
  name: 'Mariana',
  lastName: 'Sandoval Ruiz',
  role: 'Gerente de calidad',
  company: 'Grupo Lácteo del Norte',
  email: 'mariana@example.com',
  phone: '',
  type: LeadType.customer,
  interest: InterestLevel.high,
  note: '',
  originKind: LeadOriginKind.event,
  eventName: DemoEventData.eventName,
  audioLocalPath: audioPath,
  audioSeconds: audioSeconds,
  cardImageLocalPath: cardImagePath,
);

Widget recordsApp(
  FakeVoiceNoteService service, {
  required List<SessionLead> records,
  ValueChanged<AppDestination>? onDestinationSelected,
  bool darkMode = false,
}) => MaterialApp(
  theme: FolooTheme.light,
  darkTheme: FolooTheme.dark,
  themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
  home: RecordsScreen(
    records: records,
    darkMode: darkMode,
    voiceNoteService: service,
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
