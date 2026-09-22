import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/models/lead_draft.dart';
import 'package:foloo/models/session_lead.dart';
import 'package:foloo/models/email_review.dart';
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
    events: DemoAppData.events,
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

class _VoiceNavigationHost extends StatefulWidget {
  const _VoiceNavigationHost(this.service);

  final FakeVoiceNoteService service;

  @override
  State<_VoiceNavigationHost> createState() => _VoiceNavigationHostState();
}

class _VoiceNavigationHostState extends State<_VoiceNavigationHost> {
  var _outsideCapture = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: FolooTheme.light,
    home: Scaffold(
      body: IndexedStack(
        index: _outsideCapture ? 1 : 0,
        children: [
          LeadCaptureScreen(
            originKind: LeadOriginKind.event,
            eventName: DemoEventData.eventName,
            events: DemoAppData.events,
            recordsCount: 0,
            darkMode: false,
            voiceNoteService: widget.service,
            onLeadSaved: (lead) =>
                DemoEventData.createSessionLead(lead: lead, sequence: 1),
            onOriginChanged: (_, _) {},
            onCreateEvent: (_) {},
            onDestinationSelected: (_) {},
            onAppearanceChanged: (_) {},
            onLogout: () {},
          ),
          const Center(child: Text('Provider connection placeholder')),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('temporaryProviderNavigation'),
        onPressed: () => setState(() => _outsideCapture = !_outsideCapture),
        child: const Icon(Icons.swap_horiz),
      ),
    ),
  );
}

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
    'Save Review Back adopts definitive voice path and reuses the same Lead',
    (tester) async {
      final service = FakeVoiceNoteService();
      var saves = 0;
      var revisions = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: FolooTheme.light,
          home: LeadCaptureScreen(
            originKind: LeadOriginKind.event,
            eventName: DemoEventData.eventName,
            events: DemoAppData.events,
            recordsCount: 0,
            darkMode: false,
            voiceNoteService: service,
            onLeadSaved: (lead) {
              saves++;
              return SessionLead(
                localId: 'lead-one',
                folio: null,
                capturedAt: DateTime(2026, 9, 21),
                lead: lead.copyWith(audioLocalPath: '/support/lead-one.m4a'),
              );
            },
            onLeadRevised: (record, lead) {
              revisions++;
              return record;
            },
            onEmailReviewRequested: (record) => const EmailReviewDraft(
              followUpId: 'follow-up-one',
              leadName: 'Ana López',
              recipientAddress: 'ana@example.com',
              subject: 'Seguimiento',
              message: 'Hola Ana',
              attachmentNames: [],
            ),
            onEmailReviewConfirmed: (_) async => EmailReviewOutcome.pending,
            onOriginChanged: (_, _) {},
            onCreateEvent: (_) {},
            onDestinationSelected: (_) {},
            onAppearanceChanged: (_) {},
            onLogout: () {},
          ),
        ),
      );
      await completeRequiredFields(tester);
      await createVoiceNote(tester);
      await tester.tap(find.byKey(const Key('saveLeadButton')));
      await tester.pumpAndSettle();
      expect(find.text('Revisar'), findsOneWidget);
      await tester.tap(find.byKey(const Key('emailReviewBack')));
      await tester.pumpAndSettle();
      await showRecorder(tester);
      expect(find.byKey(const Key('playPauseButton')), findsOneWidget);
      await tester.tap(find.byKey(const Key('playPauseButton')));
      await tester.pump();
      expect(service.playedPaths.last, '/support/lead-one.m4a');
      await tester.tap(find.byKey(const Key('playPauseButton')));
      await tester.pump();
      for (var visit = 0; visit < 5; visit++) {
        await tester.scrollUntilVisible(
          find.byKey(const Key('saveLeadButton')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(const Key('saveLeadButton')));
        await tester.pumpAndSettle();
        expect(find.text('Revisar'), findsOneWidget);
        if (visit < 4) {
          await tester.tap(find.byKey(const Key('emailReviewBack')));
          await tester.pumpAndSettle();
        }
      }
      expect(saves, 1);
      expect(revisions, 5);
    },
  );

  testWidgets(
    'VOZ-04 stopped voice survives temporary provider navigation and remains playable',
    (tester) async {
      final service = FakeVoiceNoteService();
      await tester.pumpWidget(_VoiceNavigationHost(service));
      await createVoiceNote(tester);

      await tester.tap(find.byKey(const Key('temporaryProviderNavigation')));
      await tester.pumpAndSettle();
      expect(find.text('Provider connection placeholder'), findsOneWidget);
      expect(service.deletedPaths, isEmpty);

      await tester.tap(find.byKey(const Key('temporaryProviderNavigation')));
      await tester.pumpAndSettle();
      await showRecorder(tester);
      expect(find.byKey(const Key('playPauseButton')), findsOneWidget);
      await tester.tap(find.byKey(const Key('playPauseButton')));
      await tester.pump();
      expect(service.playCount, 1);
    },
  );

  testWidgets(
    'records plays pauses rerecords and deletes one local voice note',
    (tester) async {
      final service = FakeVoiceNoteService();
      await tester.pumpWidget(voiceNoteApp(service));
      await showRecorder(tester);

      expect(find.byKey(const Key('recordButton')), findsOneWidget);

      await tester.tap(find.byKey(const Key('recordButton')));
      await tester.pump();
      expect(find.text('● GRABANDO'), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(service.startCount, 1);

      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byKey(const Key('recordButton')));
      await tester.pumpAndSettle();
      expect(find.text('00:02'), findsOneWidget);
      expect(service.stopCount, 1);

      await tester.tap(find.byKey(const Key('playPauseButton')));
      await tester.pump();
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(service.playCount, 1);

      await tester.tap(find.byKey(const Key('playPauseButton')));
      await tester.pump();
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(service.pauseCount, 1);

      await tester.tap(find.byKey(const Key('rerecordButton')));
      await tester.pump();
      expect(find.text('● GRABANDO'), findsOneWidget);
      expect(service.startCount, 2);
      expect(service.deletedPaths, contains('/tmp/foloo_voice_1.m4a'));

      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const Key('recordButton')));
      await tester.pumpAndSettle();
      expect(find.text('00:01'), findsOneWidget);

      await tester.tap(find.byKey(const Key('deleteVoiceNoteButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recordButton')), findsOneWidget);
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
    expect(find.byKey(const Key('recordButton')), findsOneWidget);
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
      expect(find.byKey(const Key('recordButton')), findsOneWidget);
      expect(find.byKey(const Key('playPauseButton')), findsNothing);
    },
  );
}
