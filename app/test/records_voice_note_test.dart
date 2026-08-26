import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/models/app_destination.dart';
import 'package:foloo/models/lead_draft.dart';
import 'package:foloo/models/session_lead.dart';
import 'package:foloo/screens/records_screen.dart';
import 'package:foloo/theme/foloo_theme.dart';

import 'support/fake_voice_note_service.dart';

LeadDraft lead({String? audioPath, int audioSeconds = 0}) => LeadDraft(
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
);

Widget recordsApp(
  FakeVoiceNoteService service, {
  required List<SessionLead> records,
  ValueChanged<AppDestination>? onDestinationSelected,
}) => MaterialApp(
  theme: FolooTheme.light,
  home: RecordsScreen(
    records: records,
    darkMode: false,
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
