import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/l10n/app_localizations.dart';
import 'package:foloo/models/app_destination.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/models/lead_draft.dart';
import 'package:foloo/models/session_lead.dart';
import 'package:foloo/screens/records_screen.dart';
import 'package:foloo/services/records_export_service.dart';
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
  note: '',
  originKind: originKind,
  eventLocalId: originKind == LeadOriginKind.event ? eventId : null,
  eventName: originKind == LeadOriginKind.event ? eventName : null,
  place: place,
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
  Future<void> Function(SessionLead, LeadDraft)? onLeadUpdated,
  Future<String?> Function(String eventId)? eventNameForId,
  Locale locale = const Locale('es'),
}) => MaterialApp(
  theme: FolooTheme.light,
  darkTheme: FolooTheme.dark,
  themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: RecordsScreen(
    records: records,
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
    onLeadUpdated: onLeadUpdated,
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

    tester
        .widget<DropdownButton<String>>(
          find.byKey(const Key('recordsEventFilter')),
        )
        .onChanged!('__all_events__');
    await tester.pump();

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
        records: const [],
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

  testWidgets('REG-07 detail edits structured data and leaves media out', (
    tester,
  ) async {
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
        onLeadUpdated: (_, value) async => updated = value,
      ),
    );
    await tester.tap(find.text('Mariana Sandoval Ruiz'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editLeadButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'María José');
    await tester.tap(find.byKey(const Key('saveLeadEditButton')));
    await tester.pumpAndSettle();
    expect(updated?.name, 'María José');
    expect(updated?.cardImageLocalPath, '/private/card.jpg');
    expect(find.byKey(const Key('recordsList')), findsOneWidget);
  });

  testWidgets('REG-10 all events requires one concrete export event', (
    tester,
  ) async {
    final sharer = _CapturingRecordsFileSharer();
    final events = [
      AppEvent(
        id: 'event-a',
        name: 'Evento A',
        startsOn: DateTime(2026, 9, 1),
        endsOn: DateTime(2026, 9, 2),
        active: true,
      ),
      AppEvent(
        id: 'event-b',
        name: 'Evento B',
        startsOn: DateTime(2026, 9, 3),
        endsOn: DateTime(2026, 9, 4),
      ),
    ];
    await tester.pumpWidget(
      recordsApp(
        FakeVoiceNoteService(),
        records: [
          SessionLead(
            localId: 'b',
            folio: null,
            capturedAt: DateTime(2026, 9, 3),
            lead: lead(eventId: 'event-b', eventName: 'Evento B'),
          ),
        ],
        events: events,
        fileSharer: sharer,
      ),
    );
    await tester.tap(find.byKey(const Key('recordsEventFilter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todos los eventos').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exportButton')));
    await tester.pumpAndSettle();
    expect(find.text('Elige el evento que deseas exportar'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('exportEvent-event-b')),
        matching: find.byKey(const Key('exportOptionSelectionIndicator')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('exportEvent-event-b')),
        matching: find.byIcon(Icons.check),
      ),
      findsNothing,
    );
    await tester.tap(find.text('Evento B').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exportXlsOption')), findsOneWidget);
    expect(find.byKey(const Key('exportCsvOption')), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmExportButton')));
    await tester.pumpAndSettle();
    expect(sharer.file?.filename, startsWith('foloo_Evento B_'));
    expect(sharer.file?.filename, endsWith('.xlsx'));
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
