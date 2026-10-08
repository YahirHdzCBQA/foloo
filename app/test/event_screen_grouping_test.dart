import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/l10n/app_localizations.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/data/local/app_database.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/screens/event_screen.dart';
import 'package:foloo/theme/foloo_theme.dart';

AppEvent event(
  String id,
  DateTime startsOn,
  DateTime endsOn, {
  bool active = false,
  int leadCount = 0,
  int pendingCount = 0,
}) => AppEvent(
  id: id,
  name: id,
  startsOn: startsOn,
  endsOn: endsOn,
  active: active,
  demoLeadCount: leadCount,
  demoPendingCount: pendingCount,
);

void main() {
  testWidgets(
    'EVT-13 renders active, future and past groups without duplicates',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: FolooTheme.light,
          locale: const Locale('es'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: EventScreen(
            events: [
              event('past', DateTime(2026, 8, 20), DateTime(2026, 8, 21)),
              event(
                'active',
                DateTime(2026, 9, 8),
                DateTime(2026, 9, 9),
                active: true,
              ),
              event('future', DateTime(2026, 9, 3), DateTime(2026, 9, 4)),
            ],
            recordsCount: 0,
            darkMode: false,
            onDestinationSelected: (_) {},
            onAppearanceChanged: (_) {},
            onLogout: () {},
            onCreate: (_) {},
            onUpdate: (_) {},
            onDelete: (_) {},
            nowProvider: () => DateTime(2026, 9, 2),
          ),
        ),
      );

      expect(find.byKey(const Key('activeEventsSection')), findsOneWidget);
      expect(find.byKey(const Key('futureEventsSection')), findsOneWidget);
      expect(find.byKey(const Key('pastEventsSection')), findsOneWidget);
      expect(find.byKey(const Key('event-active')), findsOneWidget);
      expect(find.text('active'), findsOneWidget);
    },
  );

  testWidgets('EVT-02 deletion requires explicit confirmation in ES', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var deleted = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: FolooTheme.light,
        locale: const Locale('es'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: EventScreen(
          events: [
            event(
              'evento-1',
              DateTime(2026, 9, 16),
              DateTime(2026, 9, 17),
              active: true,
            ),
          ],
          recordsCount: 0,
          darkMode: false,
          onDestinationSelected: (_) {},
          onAppearanceChanged: (_) {},
          onLogout: () {},
          onCreate: (_) {},
          onUpdate: (_) {},
          onDelete: (_) => deleted++,
          nowProvider: () => DateTime(2026, 9, 16),
        ),
      ),
    );
    await tester.drag(
      find.byKey(const Key('event-evento-1')),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('eventSwipeDelete-evento-1')), findsOneWidget);
    expect(deleted, 0);
    await tester.tap(find.byKey(const Key('eventSwipeDelete-evento-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('leads permanecerán guardados'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(deleted, 0);

    final eventMenu = find.byKey(const Key('eventMenu-evento-1'));
    expect(
      find.descendant(of: eventMenu, matching: find.byIcon(Icons.more_vert)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: eventMenu, matching: find.byIcon(Icons.more_horiz)),
      findsNothing,
    );
    await tester.tap(eventMenu);
    await tester.pumpAndSettle();
    expect(find.text('Editar evento'), findsOneWidget);
    expect(find.text('Eliminar evento'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    final deleteIcon = tester.widget<Icon>(find.byIcon(Icons.delete_outline));
    expect(
      deleteIcon.color,
      FolooPalette.of(tester.element(find.byIcon(Icons.delete_outline))).error,
    );
    expect(
      tester.widget<Text>(find.text('Eliminar evento')).style?.color,
      isNull,
    );
    await tester.tap(find.text('Editar evento'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('closeEventEditorButton')), findsOneWidget);
    await tester.tap(find.byKey(const Key('closeEventEditorButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('eventMenu-evento-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar evento').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDeleteEventButton')));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets('EVT-02 card taps are inert while explicit actions still work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var updated = 0;
    var deleted = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: FolooTheme.light,
        locale: const Locale('es'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: EventScreen(
          events: [
            event(
              'evento-inerte',
              DateTime(2026, 10, 8),
              DateTime(2026, 10, 8),
              active: true,
              leadCount: 7,
              pendingCount: 2,
            ),
          ],
          recordsCount: 0,
          darkMode: false,
          onDestinationSelected: (_) {},
          onAppearanceChanged: (_) {},
          onLogout: () {},
          onCreate: (_) {},
          onUpdate: (_) => updated++,
          onDelete: (_) => deleted++,
          nowProvider: () => DateTime(2026, 10, 8),
        ),
      ),
    );

    final card = find.byKey(const Key('event-evento-inerte'));
    final stats = find.descendant(
      of: card,
      matching: find.textContaining('7 leads'),
    );
    expect(
      find.ancestor(of: card, matching: find.byType(InkWell)),
      findsNothing,
    );

    await tester.tap(find.text('evento-inerte'));
    await tester.pumpAndSettle();
    await tester.tap(stats);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getRect(card).centerLeft + const Offset(8, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('closeEventEditorButton')), findsNothing);
    expect(updated, 0);
    expect(deleted, 0);

    await tester.drag(card, const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('eventSwipeEdit-evento-inerte')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('closeEventEditorButton')), findsNothing);
    expect(updated, 0);
    await tester.tap(find.byKey(const Key('eventSwipeEdit-evento-inerte')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('closeEventEditorButton')), findsOneWidget);
    await tester.tap(find.byKey(const Key('closeEventEditorButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('eventMenu-evento-inerte')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar evento'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('closeEventEditorButton')), findsOneWidget);
    await tester.tap(find.byKey(const Key('closeEventEditorButton')));
    await tester.pumpAndSettle();

    await tester.drag(card, const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('eventSwipeDelete-evento-inerte')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('confirmDeleteEventButton')), findsNothing);
    expect(deleted, 0);
    await tester.tap(find.byKey(const Key('eventSwipeDelete-evento-inerte')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirmDeleteEventButton')), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(deleted, 0);
    expect(updated, 0);
  });

  testWidgets('PLT-01 event template saves variables and safely reopens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    const owner = 'owner-event-template';
    final item = event(
      'event-template',
      DateTime(2026, 9, 16),
      DateTime(2026, 9, 17),
      active: true,
    );
    await EventRepository(database).save(owner, item);
    final templates = EventEmailTemplateRepository(database);

    await tester.pumpWidget(
      MaterialApp(
        theme: FolooTheme.light,
        locale: const Locale('es'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: EventScreen(
          events: [item],
          recordsCount: 0,
          darkMode: false,
          onDestinationSelected: (_) {},
          onAppearanceChanged: (_) {},
          onLogout: () {},
          onCreate: (_) {},
          onUpdate: (_) {},
          onDelete: (_) {},
          ownerSub: owner,
          eventEmailTemplateRepository: templates,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('eventMenu-event-template')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar evento'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('eventEmailTemplateTile')));
    await tester.tap(find.byKey(const Key('eventEmailTemplateTile')));
    await tester.pumpAndSettle();
    final saveTemplateButton = find.byKey(
      const Key('saveEventEmailTemplateButton'),
    );
    final cancelTemplateButton = find.byKey(
      const Key('cancelEventEmailTemplateButton'),
    );
    expect(
      tester.getSize(saveTemplateButton).width,
      tester.getSize(cancelTemplateButton).width,
    );
    expect(
      tester.getTopLeft(saveTemplateButton).dy,
      greaterThan(tester.getBottomLeft(cancelTemplateButton).dy),
    );
    final saveText = find.descendant(
      of: saveTemplateButton,
      matching: find.text('Guardar cambios'),
    );
    final saveTextBoxes = tester
        .renderObject<RenderParagraph>(saveText)
        .getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 15),
        );
    expect(saveTextBoxes.map((box) => box.top).toSet(), hasLength(1));
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('event-friendlyDocument-body')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('event-templateEdit-body')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('event-templateLightning-body')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('event-templateVariableSheet')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('event-templateVariableChoice-{empresa}')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('event-insertTemplateVariable')));
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    tester
        .widget<FilledButton>(
          find.byKey(const Key('saveEventEmailTemplateButton')),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(await templates.get(owner, item.id, 'es'), isNotNull);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('eventEmailTemplateTile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancelEventEmailTemplateButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('eventEmailTemplateTile')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
