import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/models/lead_draft.dart';
import 'package:foloo/models/session_lead.dart';
import 'package:foloo/screens/lead_capture_screen.dart';
import 'package:foloo/theme/foloo_theme.dart';

import 'support/fake_voice_note_service.dart';

Widget voiceNoteApp(
  FakeVoiceNoteService service, {
  ValueChanged<LeadDraft>? onSaved,
}) => MaterialApp(
  theme: FolooTheme.light,
  home: LeadCaptureScreen(
    originKind: LeadOriginKind.event,
    eventName: DemoEventData.eventName,
    events: DemoBasicData.events,
    recordsCount: 0,
    darkMode: false,
    voiceNoteService: service,
    onLeadSaved: (lead) {
      onSaved?.call(lead);
      return DemoEventData.createSessionLead(lead: lead, sequence: 1);
    },
    onOriginChanged: (_, _) {},
    onCreateEvent: (_) {},
    onDestinationSelected: (_) {},
    onAppearanceChanged: (_) {},
    onLogout: () {},
  ),
);

Future<void> showRecorder(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('recordButton')),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> createVoiceNote(WidgetTester tester) async {
  await showRecorder(tester);
  await tester.tap(find.byKey(const Key('recordButton')));
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.tap(find.byKey(const Key('recordButton')));
  await tester.pumpAndSettle();
}

Future<void> completeRequiredFields(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('nameField')), 'Ana López');
  await tester.enterText(find.byKey(const Key('companyField')), 'Estudio Uno');
  await tester.enterText(
    find.byKey(const Key('emailField')),
    'ana@example.com',
  );

  final partner = find.byKey(const Key('leadType-partner'));
  await tester.scrollUntilVisible(
    partner,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(partner);
}

void main() {
  testWidgets(
    'records plays pauses rerecords and deletes one local voice note',
    (tester) async {
      final service = FakeVoiceNoteService();
      await tester.pumpWidget(voiceNoteApp(service));
      await showRecorder(tester);

      expect(find.text('Listo para grabar'), findsOneWidget);

      await tester.tap(find.byKey(const Key('recordButton')));
      await tester.pump();
      expect(find.text('● GRABANDO'), findsOneWidget);
      expect(find.text('Micrófono activo'), findsOneWidget);
      expect(service.startCount, 1);

      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byKey(const Key('recordButton')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nota de voz · 00:02'), findsOneWidget);
      expect(service.stopCount, 1);

      await tester.tap(find.byKey(const Key('playPauseButton')));
      await tester.pump();
      expect(find.text('PAUSAR'), findsOneWidget);
      expect(service.playCount, 1);

      await tester.tap(find.byKey(const Key('playPauseButton')));
      await tester.pump();
      expect(find.text('REPRODUCIR'), findsOneWidget);
      expect(service.pauseCount, 1);

      await tester.tap(find.byKey(const Key('rerecordButton')));
      await tester.pump();
      expect(find.text('● GRABANDO'), findsOneWidget);
      expect(service.startCount, 2);
      expect(service.deletedPaths, contains('/tmp/foloo_voice_1.m4a'));

      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const Key('recordButton')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nota de voz · 00:01'), findsOneWidget);

      await tester.tap(find.byKey(const Key('deleteVoiceNoteButton')));
      await tester.pumpAndSettle();
      expect(find.text('Listo para grabar'), findsOneWidget);
      expect(find.byKey(const Key('playPauseButton')), findsNothing);
      expect(service.deletedPaths, contains('/tmp/foloo_voice_2.m4a'));
    },
  );

  testWidgets('permission denial preserves the written note fallback', (
    tester,
  ) async {
    final service = FakeVoiceNoteService(permissionDenied: true);
    await tester.pumpWidget(voiceNoteApp(service));
    await showRecorder(tester);

    await tester.tap(find.byKey(const Key('recordButton')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Permiso de micrófono rechazado'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('noteField')), findsOneWidget);
    expect(find.text('Listo para grabar'), findsOneWidget);
  });

  testWidgets('form saves normally without a voice note', (tester) async {
    final service = FakeVoiceNoteService();
    LeadDraft? savedLead;
    await tester.pumpWidget(
      voiceNoteApp(service, onSaved: (lead) => savedLead = lead),
    );

    await completeRequiredFields(tester);
    await tester.tap(find.byKey(const Key('saveLeadButton')));
    await tester.pumpAndSettle();

    expect(savedLead?.hasVoiceNote, isFalse);
    expect(savedLead?.audioSeconds, 0);
    expect(find.text('Lead guardado'), findsOneWidget);
  });

  testWidgets(
    'saved lead keeps the local reference and capture another resets UI',
    (tester) async {
      final service = FakeVoiceNoteService();
      LeadDraft? savedLead;
      await tester.pumpWidget(
        voiceNoteApp(service, onSaved: (lead) => savedLead = lead),
      );

      await completeRequiredFields(tester);
      await createVoiceNote(tester);
      await tester.tap(find.byKey(const Key('saveLeadButton')));
      await tester.pumpAndSettle();

      expect(savedLead?.audioLocalPath, '/tmp/foloo_voice_1.m4a');
      expect(savedLead?.audioSeconds, 2);
      expect(find.text('Lead guardado'), findsOneWidget);

      await tester.tap(find.byKey(const Key('captureAnotherButton')));
      await tester.pumpAndSettle();
      await showRecorder(tester);
      expect(find.text('Listo para grabar'), findsOneWidget);
      expect(find.byKey(const Key('playPauseButton')), findsNothing);
    },
  );
}
