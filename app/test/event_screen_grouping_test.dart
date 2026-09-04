import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/l10n/app_localizations.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/screens/event_screen.dart';
import 'package:foloo/theme/foloo_theme.dart';

AppEvent event(
  String id,
  DateTime startsOn,
  DateTime endsOn, {
  bool active = false,
}) => AppEvent(
  id: id,
  name: id,
  startsOn: startsOn,
  endsOn: endsOn,
  active: active,
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
            onBack: () {},
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
}
