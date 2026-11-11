/// FL-023 / EVT-10: the localized location hint never becomes captured data.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/theme/foloo_theme.dart';
import 'package:foloo/l10n/app_localizations.dart';
import 'package:foloo/l10n/l10n.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/screens/origin_selection_screen.dart';

void main() {
  for (final language in ['es', 'en']) {
    testWidgets('EVT-10 $language location is localized and requires input', (
      tester,
    ) async {
      OriginSelection? selection;
      final locale = Locale(language);
      await tester.pumpWidget(
        MaterialApp(
          theme: FolooTheme.light,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: AppLanguageScope(
            locale: locale,
            onLocaleChanged: (_) {},
            child: OriginSelectionScreen(
              events: const [],
              contentFiles: const [],
              profile: DemoProfile.empty,
              recordsCount: 0,
              darkMode: false,
              onContinue: (value) => selection = value,
              onCreateEvent: (_) {},
              onDestinationSelected: (_) {},
              onAppearanceChanged: (_) {},
              onLogout: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('originDirectTab')));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const Key('originPlaceField')),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(OriginSelectionScreen)),
      );
      expect(field.decoration!.labelText, language == 'es' ? 'Lugar' : 'Place');
      expect(field.decoration!.hintText, l10n.placeExample);
      expect(field.decoration!.hintStyle!.color, isNotNull);
      expect(field.controller!.text, isEmpty);
      final emptyButton = tester.widget<FilledButton>(
        find.byKey(const Key('originContinueButton')),
      );
      expect(emptyButton.onPressed, isNull);
      await tester.enterText(
        find.byKey(const Key('originPlaceField')),
        'Client meeting',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('originContinueButton')));
      expect(selection!.place, 'Client meeting');
    });
  }
}
