import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/l10n/app_localizations.dart';
import 'package:foloo/models/app_destination.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/models/content_file.dart';
import 'package:foloo/models/email_review.dart';
import 'package:foloo/models/lead_draft.dart';
import 'package:foloo/models/session_lead.dart';
import 'package:foloo/screens/records_screen.dart';
import 'package:foloo/services/records_export_service.dart';
import 'package:foloo/theme/foloo_theme.dart';
import 'package:foloo/widgets/voice_playback_waveform.dart';
import 'package:image/image.dart' as image_codec;

import 'support/fake_voice_note_service.dart';

LeadDraft lead({
  String? audioPath,
  int audioSeconds = 0,
  String? cardImagePath,
  String eventId = 'expo-alimentaria',
  String eventName = DemoEventData.eventName,
  String name = 'Mariana',
  String note = '',
  List<String> contentIds = const [],
  List<String> contentNames = const [],
  List<String> referenceImagePaths = const [],
  LeadOriginKind originKind = LeadOriginKind.event,
  String? place,
}) => LeadDraft(
  name: name,
  lastName: 'Sandoval Ruiz',
  role: 'Gerente de calidad',
  company: 'Grupo Lácteo del Norte',
  email: 'mariana@example.com',
  phone: '',
  type: LeadType.customer,
  interest: InterestLevel.high,
  note: note,
  originKind: originKind,
  eventLocalId: originKind == LeadOriginKind.event ? eventId : null,
  eventName: originKind == LeadOriginKind.event ? eventName : null,
  place: place,
  contentFileIds: contentIds,
  contentNames: contentNames,
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
  Future<void> Function()? onSync,
  bool syncing = false,
  RecordsFileSharer fileSharer = const _FakeRecordsFileSharer(),
  RecordsFileSaver fileSaver = const _FakeRecordsFileSaver(),
  bool? deviceSaveAvailable,
  Future<SessionLead> Function(SessionLead, LeadDraft)? onLeadUpdated,
  Future<String?> Function(String eventId)? eventNameForId,
  Locale locale = const Locale('es'),
  Future<void> Function(SessionLead)? onDelete,
  Future<SessionLead> Function(SessionLead, String, int)? onVoiceNoteAdded,
  Future<SessionLead> Function(SessionLead, LeadVoiceNote)? onVoiceNoteDeleted,
  Future<EmailReviewDraft?> Function(SessionLead)? onEmailReviewRequested,
  Future<EmailReviewOutcome> Function(EmailReviewDraft)? onEmailReviewConfirmed,
  Future<void> Function(EmailReviewDraft, LeadDraft)? onEmailReviewUpdated,
  List<ContentFile> contentFiles = const [],
  String? ownerSub,
  EmailDeliveryRepository? deliveryRepository,
}) => MaterialApp(
  theme: FolooTheme.light,
  darkTheme: FolooTheme.dark,
  themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: RecordsScreen(
    records: records,
    contentFiles: contentFiles,
    darkMode: darkMode,
    events: events,
    eventNameForId: eventNameForId,
    voiceNoteService: service,
    onDestinationSelected: onDestinationSelected ?? (_) {},
    onAppearanceChanged: (_) {},
    onLogout: () {},
    onSync: onSync,
    syncing: syncing,
    fileSharer: fileSharer,
    fileSaver: fileSaver,
    deviceSaveAvailable: deviceSaveAvailable,
    onLeadUpdated: onLeadUpdated,
    onDelete: onDelete,
    onVoiceNoteAdded: onVoiceNoteAdded,
    onVoiceNoteDeleted: onVoiceNoteDeleted,
    onEmailReviewRequested: onEmailReviewRequested,
    onEmailReviewConfirmed: onEmailReviewConfirmed,
    onEmailReviewUpdated: onEmailReviewUpdated,
    ownerSub: ownerSub,
    deliveryRepository: deliveryRepository,
  ),
);

class _FakeRecordsFileSharer implements RecordsFileSharer {
  const _FakeRecordsFileSharer();

  @override
  Future<void> share(RecordsExportFile file, {Rect? origin}) async {}
}

class _CapturingRecordsFileSharer implements RecordsFileSharer {
  RecordsExportFile? file;

  @override
  Future<void> share(RecordsExportFile file, {Rect? origin}) async {
    this.file = file;
  }
}

class _FakeRecordsFileSaver implements RecordsFileSaver {
  const _FakeRecordsFileSaver();

  @override
  Future<RecordsFileSaveOutcome> save(RecordsExportFile file) async =>
      RecordsFileSaveOutcome.saved;
}

class _CapturingRecordsFileSaver implements RecordsFileSaver {
  _CapturingRecordsFileSaver(this.outcome);

  final RecordsFileSaveOutcome outcome;
  RecordsExportFile? file;

  @override
  Future<RecordsFileSaveOutcome> save(RecordsExportFile file) async {
    this.file = file;
    return outcome;
  }
}

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
    expect(service.stopPlaybackCount, greaterThanOrEqualTo(2));
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
    'record detail mirrors play pause and disposes playback on exit',
    (tester) async {
      final service = FakeVoiceNoteService();
      final record = SessionLead(
        localId: 'voice-detail',
        folio: null,
        capturedAt: DateTime(2026, 11, 9),
        lead: lead(audioPath: '/tmp/detail.m4a', audioSeconds: 18),
      );
      await tester.pumpWidget(recordsApp(service, records: [record]));

      await tester.tap(find.byKey(const Key('record-voice-detail')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detailAudioWaveform')), findsOneWidget);
      expect(
        tester
            .widget<VoicePlaybackWaveform>(
              find.byKey(const Key('detailAudioWaveform')),
            )
            .active,
        isFalse,
      );

      await tester.ensureVisible(find.byKey(const Key('detailAudioButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('detailAudioButton')));
      await tester.pump();
      expect(service.playCount, 1);
      expect(
        tester
            .widget<VoicePlaybackWaveform>(
              find.byKey(const Key('detailAudioWaveform')),
            )
            .active,
        isTrue,
      );

      await tester.tap(find.byKey(const Key('detailAudioButton')));
      await tester.pump();
      expect(service.pauseCount, 1);
      expect(
        tester
            .widget<VoicePlaybackWaveform>(
              find.byKey(const Key('detailAudioWaveform')),
            )
            .active,
        isFalse,
      );

      await tester.tap(find.byKey(const Key('detailBackButton')));
      await tester.pumpAndSettle();
      expect(service.stopPlaybackCount, greaterThanOrEqualTo(1));
    },
  );

  testWidgets('REG-08 detail reports the three voice-note limit', (
    tester,
  ) async {
    var addCalls = 0;
    final record = SessionLead(
      localId: 'voice-limit',
      folio: null,
      capturedAt: DateTime(2026, 11, 18),
      lead: lead(audioPath: '/tmp/voice-1.m4a'),
      voiceNotes: const [
        LeadVoiceNote(
          id: 'voice-1',
          localPath: '/tmp/voice-1.m4a',
          durationSeconds: 1,
        ),
        LeadVoiceNote(
          id: 'voice-2',
          localPath: '/tmp/voice-2.m4a',
          durationSeconds: 2,
        ),
        LeadVoiceNote(
          id: 'voice-3',
          localPath: '/tmp/voice-3.m4a',
          durationSeconds: 3,
        ),
      ],
    );
    await tester.pumpWidget(
      recordsApp(
        FakeVoiceNoteService(),
        records: [record],
        onVoiceNoteAdded: (current, path, duration) async {
          addCalls += 1;
          return current;
        },
      ),
    );
    await tester.tap(find.byKey(const Key('record-voice-limit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detailAddVoiceNote')));
    await tester.pump();

    expect(addCalls, 0);
    expect(
      find.text('Este lead ya tiene el máximo de 3 notas de voz.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'VOZ-01–04 Records reviews, discards, rerecords and confirms audio',
    (tester) async {
      final service = FakeVoiceNoteService();
      String? savedPath;
      int? savedSeconds;
      final record = SessionLead(
        localId: 'voice-review',
        folio: null,
        capturedAt: DateTime(2026, 11, 18),
        lead: lead(),
      );
      await tester.pumpWidget(
        recordsApp(
          service,
          records: [record],
          onVoiceNoteAdded: (current, path, duration) async {
            savedPath = path;
            savedSeconds = duration;
            return current;
          },
        ),
      );

      await tester.tap(find.byKey(const Key('record-voice-review')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('detailAddVoiceNote')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('detailVoiceRecordButton')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byKey(const Key('detailVoiceRecordButton')));
      await tester.pump();

      expect(find.byKey(const Key('detailVoicePlayButton')), findsOneWidget);
      await tester.tap(find.byKey(const Key('detailVoicePlayButton')));
      await tester.pump();
      expect(service.playedPaths, ['/tmp/foloo_voice_1.m4a']);

      await tester.tap(find.byKey(const Key('detailVoiceDiscardButton')));
      await tester.pump();
      expect(service.deletedPaths, contains('/tmp/foloo_voice_1.m4a'));
      expect(find.byKey(const Key('detailVoiceRecordButton')), findsOneWidget);

      await tester.tap(find.byKey(const Key('detailVoiceRecordButton')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const Key('detailVoiceRecordButton')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('detailVoiceRerecordButton')));
      await tester.pump();
      expect(service.deletedPaths, contains('/tmp/foloo_voice_2.m4a'));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const Key('detailVoiceRecordButton')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('detailVoiceSaveButton')));
      await tester.pumpAndSettle();

      expect(savedPath, '/tmp/foloo_voice_3.m4a');
      expect(savedSeconds, 1);
      expect(service.deletedPaths, contains('/tmp/foloo_voice_3.m4a'));
    },
  );

  testWidgets('REG-17 uses global header and delete swipe confirms', (
    tester,
  ) async {
    var deleted = false;
    final record = SessionLead(
      localId: 'lead-delete',
      folio: null,
      capturedAt: DateTime(2026, 10, 2),
      lead: lead(),
    );
    await tester.pumpWidget(
      recordsApp(
        FakeVoiceNoteService(),
        records: [record],
        onDelete: (_) async => deleted = true,
      ),
    );

    expect(find.byKey(const Key('moduleBackButton')), findsNothing);
    expect(find.byKey(const Key('hamburgerMenuButton')), findsOneWidget);
    await tester.tap(find.byKey(const Key('hamburgerMenuButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('appDrawer')), findsOneWidget);
    await tester.tapAt(const Offset(4, 300));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recordSwipeDeleteAction')), findsNothing);
    await tester.drag(
      find.byKey(const Key('record-lead-delete')),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();
    expect(deleted, isFalse);
    final cardSize = tester.getSize(
      find.byKey(const Key('record-lead-delete')),
    );
    final actionSize = tester.getSize(
      find.byKey(const Key('recordSwipeDeleteAction')),
    );
    expect(actionSize.width, 92);
    expect(actionSize.height, cardSize.height);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('recordSwipeDeleteAction')));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar lead?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(deleted, isFalse);

    await tester.drag(
      find.byKey(const Key('record-lead-delete')),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recordSwipeDeleteAction')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDeleteLead')));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
  });

  testWidgets('REG-17 email swipe fills the card and only opens on tap', (
    tester,
  ) async {
    var reviewRequests = 0;
    final record = SessionLead(
      localId: 'lead-email',
      folio: null,
      capturedAt: DateTime(2026, 10, 2),
      lead: lead(),
    );
    await tester.pumpWidget(
      recordsApp(
        FakeVoiceNoteService(),
        records: [record],
        onEmailReviewRequested: (_) async {
          reviewRequests += 1;
          return const EmailReviewDraft(
            followUpId: 'follow-up-email',
            leadName: 'Mariana Sandoval Ruiz',
            recipientAddress: 'mariana@example.com',
            subject: 'Seguimiento',
            message: 'Hola Mariana',
            attachmentNames: [],
          );
        },
        onEmailReviewConfirmed: (_) async => EmailReviewOutcome.pending,
      ),
    );

    expect(find.byKey(const Key('recordSwipeEmailAction')), findsNothing);
    await tester.drag(
      find.byKey(const Key('record-lead-email')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();
    expect(reviewRequests, 0);
    final cardSize = tester.getSize(find.byKey(const Key('record-lead-email')));
    final actionSize = tester.getSize(
      find.byKey(const Key('recordSwipeEmailAction')),
    );
    expect(actionSize.width, 92);
    expect(actionSize.height, cardSize.height);
    expect(find.byIcon(Icons.outgoing_mail), findsOneWidget);
    expect(find.bySemanticsLabel('Enviar correo'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('recordSwipeEmailAction')));
    await tester.pumpAndSettle();
    expect(reviewRequests, 1);
    expect(find.text('Revisar'), findsOneWidget);
  });

  testWidgets('REG-17 prior email intent labels the action as resend', (
    tester,
  ) async {
    const owner = 'owner-email-history';
    final persistence = LocalPersistence.inMemory();
    addTearDown(persistence.close);
    final record = await persistence.leads.saveDraft(
      owner,
      lead(originKind: LeadOriginKind.direct, place: 'León'),
      capturedBy: const DemoProfile(name: 'Yahir', company: 'Foloo'),
    );
    final followUp = await persistence.emailDelivery.prepareForLead(
      owner: owner,
      leadId: record.localId,
      lead: record.lead,
      seller: const DemoProfile(name: 'Yahir', company: 'Foloo'),
      language: 'es',
    );
    await persistence.emailDelivery.confirm(
      owner: owner,
      followUpId: followUp!.localId,
    );

    await tester.pumpWidget(
      recordsApp(
        FakeVoiceNoteService(),
        records: [record],
        ownerSub: owner,
        deliveryRepository: persistence.emailDelivery,
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(Key('record-${record.uiKey}')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.outgoing_mail), findsOneWidget);
    expect(find.bySemanticsLabel('Reenviar correo'), findsOneWidget);
  });

  testWidgets(
    'QA-18 detail owns Content selection and Review remains read-only',
    (tester) async {
      const first = ContentFile(
        id: 'content-first',
        displayName: 'Ficha A',
        fileName: 'a.pdf',
        sizeLabel: '1 MB',
      );
      const second = ContentFile(
        id: 'content-second',
        displayName: 'Ficha B',
        fileName: 'b.pdf',
        sizeLabel: '1 MB',
      );
      final record = SessionLead(
        localId: 'lead-email-content',
        folio: null,
        capturedAt: DateTime(2026, 11, 18),
        lead: lead(
          originKind: LeadOriginKind.direct,
          place: 'León',
          contentNames: const ['Ficha A'],
        ).copyWith(contentFileIds: const ['content-first']),
      );
      LeadDraft? savedLead;
      await tester.pumpWidget(
        recordsApp(
          FakeVoiceNoteService(),
          records: [record],
          contentFiles: const [first, second],
          onLeadUpdated: (current, updated) async {
            savedLead = updated;
            return SessionLead(
              localId: current.localId,
              folio: current.folio,
              capturedAt: current.capturedAt,
              lead: updated,
            );
          },
          onEmailReviewRequested: (_) async => const EmailReviewDraft(
            followUpId: 'follow-up-1',
            leadName: 'Mariana',
            recipientAddress: 'qa@example.com',
            subject: 'Hola',
            message: 'Mensaje',
            attachmentIds: ['content-first'],
            attachmentNames: ['Ficha A'],
          ),
          onEmailReviewConfirmed: (_) async => EmailReviewOutcome.pending,
        ),
      );

      await tester.tap(find.byKey(const Key('record-lead-email-content')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('detailAddContent')));
      await tester.tap(find.byKey(const Key('detailAddContent')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('leadContentOption-content-first')),
      );
      await tester.tap(
        find.byKey(const Key('leadContentOption-content-second')),
      );
      await tester.tap(find.byKey(const Key('saveLeadContentSelection')));
      await tester.pumpAndSettle();

      expect(savedLead?.contentFileIds, ['content-second']);
      expect(savedLead?.contentNames, ['Ficha B']);

      final secondCard = find.byKey(
        const Key('leadContentCard-content-second'),
      );
      await tester.drag(secondCard, const Offset(500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar').last);
      await tester.pumpAndSettle();
      expect(savedLead?.contentFileIds, ['content-second']);

      await tester.drag(secondCard, const Offset(500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar').last);
      await tester.pumpAndSettle();
      expect(savedLead?.contentFileIds, isEmpty);

      await tester.tap(find.byKey(const Key('detailAddContent')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('leadContentOption-content-second')),
      );
      await tester.tap(find.byKey(const Key('saveLeadContentSelection')));
      await tester.pumpAndSettle();
      expect(savedLead?.contentFileIds, ['content-second']);

      await tester.ensureVisible(find.byKey(const Key('detailEmailAction')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('detailEmailAction')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('editEmailAttachments')), findsNothing);
      expect(find.text('Ficha A'), findsOneWidget);
    },
  );

  testWidgets('QA-20 unions selected events and direct leads', (tester) async {
    final event = SessionLead(
      localId: 'event-lead',
      folio: null,
      capturedAt: DateTime(2026, 10, 2),
      lead: lead(name: 'Evento'),
    );
    final direct = SessionLead(
      localId: 'direct-lead',
      folio: null,
      capturedAt: DateTime(2026, 10, 2),
      lead: lead(
        name: 'Directo',
        originKind: LeadOriginKind.direct,
        place: 'León',
      ),
    );
    await tester.pumpWidget(
      recordsApp(
        FakeVoiceNoteService(),
        records: [event, direct],
        events: [
          AppEvent(
            id: 'expo-alimentaria',
            name: DemoEventData.eventName,
            startsOn: DateTime(2026, 10, 1),
            endsOn: DateTime(2026, 10, 3),
          ),
        ],
      ),
    );
    expect(find.text('Evento Sandoval Ruiz'), findsOneWidget);
    expect(find.text('Directo Sandoval Ruiz'), findsOneWidget);

    await tester.tap(find.byKey(const Key('recordsEventsFilter')));
    await tester.pumpAndSettle();
    expect(find.text('Nivel de Interés'), findsOneWidget);
    expect(find.text('Nombre de lead'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('recordsFilterEvent-expo-alimentaria')),
    );
    await tester.tap(find.byKey(const Key('applyRecordsFilters')));
    await tester.pumpAndSettle();
    expect(find.text('Evento Sandoval Ruiz'), findsOneWidget);
    expect(find.text('Directo Sandoval Ruiz'), findsNothing);

    await tester.tap(find.byKey(const Key('recordsDirectFilter')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('recordsFilterDirectLead-direct-lead')),
    );
    await tester.tap(find.byKey(const Key('applyRecordsFilters')));
    await tester.pumpAndSettle();
    expect(find.text('Evento Sandoval Ruiz'), findsOneWidget);
    expect(find.text('Directo Sandoval Ruiz'), findsOneWidget);

    await tester.tap(find.byKey(const Key('recordsDirectFilter')));
    await tester.pumpAndSettle();
    expect(find.text('Solo leads directos'), findsOneWidget);
    expect(
      find.byKey(const Key('recordsFilterDirectLead-direct-lead')),
      findsOneWidget,
    );
  });

  testWidgets(
    'Records detail renders the complete persisted Content snapshot',
    (tester) async {
      final record = SessionLead(
        localId: 'lead-content',
        folio: null,
        capturedAt: DateTime(2026, 9, 22),
        lead: lead(
          contentIds: const ['content-a', 'content-b'],
          contentNames: const ['Ficha A.pdf', 'Ficha B.pdf'],
        ),
      );
      await tester.pumpWidget(
        recordsApp(FakeVoiceNoteService(), records: [record]),
      );

      await tester.tap(find.text('Mariana Sandoval Ruiz'));
      await tester.pumpAndSettle();

      expect(find.text('Ficha A.pdf'), findsOneWidget);
      expect(find.text('Ficha B.pdf'), findsOneWidget);
    },
  );

  testWidgets('QA-25 detail keeps the approved section order', (tester) async {
    final record = SessionLead(
      localId: 'lead-section-order',
      folio: null,
      capturedAt: DateTime(2026, 11, 22),
      lead: lead(
        audioPath: '/private/voice.m4a',
        audioSeconds: 2,
        referenceImagePaths: const ['/private/reference.jpg'],
        note: 'Nota QA',
        contentIds: const ['content-a'],
        contentNames: const ['Ficha A'],
      ),
    );
    await tester.pumpWidget(
      recordsApp(FakeVoiceNoteService(), records: [record]),
    );
    await tester.tap(find.text('Mariana Sandoval Ruiz'));
    await tester.pumpAndSettle();

    final sections = [
      'Contacto',
      'Nota de voz',
      'Imágenes de referencia',
      'Nota escrita',
      'Contenido',
      'Registro',
    ];
    final positions = sections
        .map((label) => tester.getTopLeft(find.text(label).first).dy)
        .toList();
    expect(positions, orderedEquals([...positions]..sort()));
    expect(find.text('Contenido adjunto'), findsNothing);
  });

  testWidgets('SYN-07 failed media is never described as waiting for signal', (
    tester,
  ) async {
    var syncCalls = 0;
    final failed = SessionLead(
      localId: 'failed-media',
      folio: null,
      capturedAt: DateTime(2026, 9, 15),
      lead: lead(),
      uploadState: SessionUploadState.syncedWithMediaError,
    );
    await tester.pumpWidget(
      recordsApp(
        FakeVoiceNoteService(),
        records: [failed],
        onSync: () async => syncCalls += 1,
      ),
    );

    expect(find.text('1 registro requiere atención'), findsOneWidget);
    expect(find.textContaining('espera señal'), findsNothing);
    await tester.tap(find.byKey(const Key('syncButton')));
    await tester.pump();
    expect(syncCalls, 1);
    expect(find.text('1 registro requiere atención'), findsOneWidget);

    await tester.tap(find.text('Mariana Sandoval Ruiz'));
    await tester.pumpAndSettle();
    expect(find.text('Lead guardado · error en medios'), findsOneWidget);
  });

  testWidgets('SYN-07 pending retryable syncing and synced summaries differ', (
    tester,
  ) async {
    Future<void> verify(SessionUploadState state, String expected) async {
      await tester.pumpWidget(
        recordsApp(
          FakeVoiceNoteService(),
          records: [
            SessionLead(
              localId: state.name,
              folio: null,
              capturedAt: DateTime(2026, 9, 15),
              lead: lead(),
              uploadState: state,
            ),
          ],
        ),
      );
      expect(find.text(expected), findsOneWidget);
    }

    await verify(
      SessionUploadState.pending,
      '1 registro pendiente de sincronizar',
    );
    await verify(SessionUploadState.retryable, '1 registro se reintentará');
    await verify(SessionUploadState.syncing, 'Sincronizando 1 registro');
    await verify(SessionUploadState.synced, 'Todo sincronizado');
  });

  testWidgets('QA-20 event filter updates the owner-scoped result set', (
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
    expect(find.text('Beatriz Sandoval Ruiz'), findsOneWidget);

    await tester.tap(find.byKey(const Key('recordsEventsFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recordsFilterEvent-event-a')));
    await tester.tap(find.byKey(const Key('applyRecordsFilters')));
    await tester.pumpAndSettle();
    expect(find.text('Ana Sandoval Ruiz'), findsOneWidget);
    expect(find.text('Beatriz Sandoval Ruiz'), findsNothing);

    await tester.tap(find.byKey(const Key('recordsEventsFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recordsFilterEvent-event-a')));
    await tester.tap(find.byKey(const Key('recordsFilterEvent-event-b')));
    await tester.tap(find.byKey(const Key('applyRecordsFilters')));
    await tester.pumpAndSettle();

    expect(find.text('Ana Sandoval Ruiz'), findsNothing);
    expect(find.text('Beatriz Sandoval Ruiz'), findsOneWidget);
    expect(find.text('1 lead · 1 por subir'), findsOneWidget);

    await tester.tap(find.byKey(const Key('recordsEventsFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('clearRecordsFilters')));
    await tester.tap(find.byKey(const Key('applyRecordsFilters')));
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

  testWidgets('REG-06 V1 detail shows and opens reference images', (
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
    await tester.pumpWidget(recordsApp(service, records: [record]));

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
    await tester.pumpWidget(
      recordsApp(
        service,
        records: [
          SessionLead(
            localId: 'export-a',
            folio: null,
            capturedAt: DateTime(2026, 9, 1),
            lead: lead(eventId: 'event-a', eventName: 'Evento A'),
          ),
        ],
        events: [
          AppEvent(
            id: 'event-a',
            name: 'Evento A',
            startsOn: DateTime(2026, 9, 1),
            endsOn: DateTime(2026, 9, 2),
            active: true,
          ),
        ],
      ),
    );

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
    expect(find.text('Exportar registros'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android export can save CSV without replacing Share', (
    tester,
  ) async {
    final sharer = _CapturingRecordsFileSharer();
    final saver = _CapturingRecordsFileSaver(RecordsFileSaveOutcome.saved);
    await tester.pumpWidget(
      recordsApp(
        FakeVoiceNoteService(),
        records: [
          SessionLead(
            localId: 'android-export',
            folio: null,
            capturedAt: DateTime(2026, 10, 14),
            lead: lead(),
          ),
        ],
        events: [
          AppEvent(
            id: 'expo-alimentaria',
            name: 'Evento Android',
            startsOn: DateTime(2026, 10, 14),
            endsOn: DateTime(2026, 10, 14),
            active: true,
          ),
        ],
        fileSharer: sharer,
        fileSaver: saver,
        deviceSaveAvailable: true,
      ),
    );

    await tester.tap(find.byKey(const Key('exportButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('saveExportToDeviceButton')), findsOneWidget);
    expect(find.byKey(const Key('confirmExportButton')), findsOneWidget);
    await tester.tap(find.byKey(const Key('exportCsvOption')));
    await tester.tap(find.byKey(const Key('saveExportToDeviceButton')));
    await tester.pumpAndSettle();

    expect(saver.file?.filename, endsWith('.csv'));
    expect(saver.file?.mimeType, 'text/csv');
    expect(saver.file?.bytes.take(3), [0xEF, 0xBB, 0xBF]);
    expect(sharer.file, isNull);
    expect(find.text('Archivo guardado en el dispositivo.'), findsOneWidget);
  });

  testWidgets('Android native save cancellation is not reported as failure', (
    tester,
  ) async {
    final saver = _CapturingRecordsFileSaver(RecordsFileSaveOutcome.cancelled);
    await tester.pumpWidget(
      recordsApp(
        FakeVoiceNoteService(),
        records: [
          SessionLead(
            localId: 'cancel-export',
            folio: null,
            capturedAt: DateTime(2026, 10, 14),
            lead: lead(eventId: 'event-cancel', eventName: 'Evento Cancelar'),
          ),
        ],
        events: [
          AppEvent(
            id: 'event-cancel',
            name: 'Evento Cancelar',
            startsOn: DateTime(2026, 10, 14),
            endsOn: DateTime(2026, 10, 14),
            active: true,
          ),
        ],
        fileSaver: saver,
        deviceSaveAvailable: true,
      ),
    );

    await tester.tap(find.byKey(const Key('exportButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveExportToDeviceButton')));
    await tester.pumpAndSettle();

    expect(find.text('Guardado cancelado.'), findsOneWidget);
    expect(find.text('No se pudo guardar el archivo.'), findsNothing);
  });

  testWidgets('REG-07 detail edits structured data and leaves media out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    LeadDraft? updated;
    final current = SessionLead(
      localId: 'lead-edit',
      folio: null,
      capturedAt: DateTime(2026, 9, 15),
      lead: lead(cardImagePath: '/private/card.jpg'),
    );
    await tester.pumpWidget(
      recordsApp(
        FakeVoiceNoteService(),
        records: [current],
        onLeadUpdated: (_, value) async {
          updated = value;
          return SessionLead(
            localId: current.localId,
            folio: current.folio,
            capturedAt: current.capturedAt,
            lead: value,
          );
        },
      ),
    );
    await tester.tap(find.text('Mariana Sandoval Ruiz'));
    await tester.pumpAndSettle();
    expect(find.text('Este lead no tiene contenido asociado.'), findsOneWidget);
    expect(find.textContaining('demo', findRichText: true), findsNothing);
    await tester.tap(find.byKey(const Key('editLeadButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'María José');
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    final save = find.byKey(const Key('saveLeadEditButton'));
    expect(tester.getRect(save).bottom, lessThanOrEqualTo(568 - 240));
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(updated?.name, 'María José');
    expect(updated?.cardImageLocalPath, '/private/card.jpg');
    expect(find.byKey(const Key('detailBackButton')), findsOneWidget);
    expect(find.text('María José Sandoval Ruiz'), findsWidgets);
  });

  testWidgets('QA-21 export uses the exact mixed filtered result set', (
    tester,
  ) async {
    final sharer = _CapturingRecordsFileSharer();
    final records = [
      SessionLead(
        localId: 'event-a-lead',
        folio: null,
        capturedAt: DateTime(2026, 9, 1),
        lead: lead(eventId: 'event-a', eventName: 'Evento A', name: 'Ana'),
      ),
      SessionLead(
        localId: 'direct-lead',
        folio: null,
        capturedAt: DateTime(2026, 9, 2),
        lead: lead(
          originKind: LeadOriginKind.direct,
          place: 'León',
          name: 'Diana',
        ),
      ),
      SessionLead(
        localId: 'event-b-lead',
        folio: null,
        capturedAt: DateTime(2026, 9, 3),
        lead: lead(eventId: 'event-b', eventName: 'Evento B', name: 'Beto'),
      ),
    ];
    await tester.pumpWidget(
      recordsApp(
        FakeVoiceNoteService(),
        records: records,
        events: [
          AppEvent(
            id: 'event-a',
            name: 'Evento A',
            startsOn: DateTime(2026, 9, 1),
            endsOn: DateTime(2026, 9, 2),
          ),
          AppEvent(
            id: 'event-b',
            name: 'Evento B',
            startsOn: DateTime(2026, 9, 3),
            endsOn: DateTime(2026, 9, 4),
          ),
        ],
        fileSharer: sharer,
      ),
    );

    await tester.tap(find.byKey(const Key('recordsEventsFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recordsFilterEvent-event-a')));
    await tester.tap(find.byKey(const Key('applyRecordsFilters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recordsDirectFilter')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('recordsFilterDirectLead-direct-lead')),
    );
    await tester.tap(find.byKey(const Key('applyRecordsFilters')));
    await tester.pumpAndSettle();

    expect(find.text('Ana Sandoval Ruiz'), findsOneWidget);
    expect(find.text('Diana Sandoval Ruiz'), findsOneWidget);
    expect(find.text('Beto Sandoval Ruiz'), findsNothing);

    await tester.tap(find.byKey(const Key('exportButton')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('exportLeadSummary'))).data,
      contains('2 leads'),
    );
    expect(
      find.byKey(const Key('directExportContent-content-burritos')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('exportCsvOption')));
    await tester.tap(find.byKey(const Key('confirmExportButton')));
    await tester.pumpAndSettle();

    expect(sharer.file, isNotNull);
    final csv = String.fromCharCodes(sharer.file!.bytes.skip(3));
    expect(csv, contains('Ana'));
    expect(csv, contains('Diana'));
    expect(csv, isNot(contains('Beto')));
  });

  testWidgets(
    'REG-05 detail prefers renamed local Event over stale Lead snapshot',
    (tester) async {
      const owner = 'owner-a';
      const eventId = '41414141-4141-4414-8414-414141414141';
      final persistence = LocalPersistence.inMemory();
      addTearDown(persistence.close);
      final original = AppEvent(
        id: eventId,
        name: 'Expo México',
        startsOn: DateTime(2026, 9, 1),
        endsOn: DateTime(2026, 9, 2),
        active: true,
      );
      await persistence.events.save(owner, original);
      final renamed = original.copyWith(name: 'Expo México 2026');
      await persistence.events.save(owner, renamed);
      final record = SessionLead(
        localId: 'lead-event',
        folio: null,
        capturedAt: DateTime(2026, 9, 1),
        lead: lead(eventId: eventId, eventName: 'Expo México'),
      );
      await tester.pumpWidget(
        recordsApp(
          FakeVoiceNoteService(),
          records: [record],
          events: [renamed],
          eventNameForId: (id) => persistence.events.nameForId(owner, id),
        ),
      );
      await tester.tap(find.text('Mariana Sandoval Ruiz'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widgetList<SelectableText>(find.byType(SelectableText))
            .map((value) => value.data),
        contains('Expo México 2026'),
      );
      expect(find.text('Expo México'), findsNothing);
      expect(await persistence.events.nameForId('owner-b', eventId), isNull);
    },
  );

  testWidgets('REG-05 soft-deleted Event still names its retained Lead', (
    tester,
  ) async {
    const owner = 'owner-a';
    const eventId = '42424242-4242-4424-8424-424242424242';
    final persistence = LocalPersistence.inMemory();
    addTearDown(persistence.close);
    final event = AppEvent(
      id: eventId,
      name: 'Expo León',
      startsOn: DateTime(2026, 9, 1),
      endsOn: DateTime(2026, 9, 2),
    );
    await persistence.events.save(owner, event);
    await persistence.events.delete(owner, event);
    expect(await persistence.events.list(owner), isEmpty);
    final record = SessionLead(
      localId: 'lead-deleted-event',
      folio: null,
      capturedAt: DateTime(2026, 9, 1),
      lead: lead(eventId: eventId, eventName: 'Nombre anterior'),
    );
    await tester.pumpWidget(
      recordsApp(
        FakeVoiceNoteService(),
        records: [record],
        eventNameForId: (id) => persistence.events.nameForId(owner, id),
      ),
    );
    await tester.tap(find.text('Mariana Sandoval Ruiz'));
    await tester.pumpAndSettle();

    expect(find.text('Expo León'), findsOneWidget);
    expect(find.text('Nombre anterior'), findsNothing);
  });

  for (final locale in const [Locale('es'), Locale('en')]) {
    testWidgets(
      'REG-05 direct origin includes Lugar in ${locale.languageCode}',
      (tester) async {
        final record = SessionLead(
          localId: 'direct-place',
          folio: null,
          capturedAt: DateTime(2026, 9, 1),
          lead: lead(
            originKind: LeadOriginKind.direct,
            place: 'León, Guanajuato',
          ),
        );
        await tester.pumpWidget(
          recordsApp(FakeVoiceNoteService(), records: [record], locale: locale),
        );
        await tester.tap(find.text('Mariana Sandoval Ruiz'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            locale.languageCode == 'es'
                ? 'Lead directo · León, Guanajuato'
                : 'Direct lead · León, Guanajuato',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'REG-05 direct origin omits empty Lugar in ${locale.languageCode}',
      (tester) async {
        final record = SessionLead(
          localId: 'direct-empty',
          folio: null,
          capturedAt: DateTime(2026, 9, 1),
          lead: lead(originKind: LeadOriginKind.direct),
        );
        await tester.pumpWidget(
          recordsApp(FakeVoiceNoteService(), records: [record], locale: locale),
        );
        await tester.tap(find.text('Mariana Sandoval Ruiz'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            locale.languageCode == 'es' ? 'Lead directo' : 'Direct lead',
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widgetList<SelectableText>(find.byType(SelectableText))
              .map((value) => value.data)
              .where(
                (value) =>
                    value?.startsWith(
                      locale.languageCode == 'es'
                          ? 'Lead directo ·'
                          : 'Direct lead ·',
                    ) ==
                    true,
              ),
          isEmpty,
        );
      },
    );
  }
}
