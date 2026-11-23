/// Regression coverage for the keyboard-safe Content assignment sheet.
///
/// The form must keep its helper and actions usable on compact screens while
/// preserving a visually muted display-name placeholder (CON-05/06, RNF-03).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/l10n/app_localizations.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/services/pdf_picker_service.dart';
import 'package:foloo/theme/foloo_theme.dart';
import 'package:foloo/widgets/content_assignment_sheet.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'QA-15 keeps helper and actions separate with keyboard (${dark ? 'dark' : 'light'})',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.resetViewInsets();
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? FolooTheme.dark : FolooTheme.light,
            locale: const Locale('es'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => showContentAssignmentSheet(
                      context,
                      events: [
                        AppEvent(
                          id: 'event-a',
                          name: 'Expo QA',
                          startsOn: DateTime(2026, 11, 19),
                          endsOn: DateTime(2026, 11, 20),
                        ),
                      ],
                      pickedPdf: const PickedPdf(
                        name: 'qa.pdf',
                        byteSize: 1024,
                      ),
                    ),
                    child: const Text('Abrir'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();

        final fieldFinder = find.byKey(const Key('contentDisplayNameField'));
        final field = tester.widget<TextField>(fieldFinder);
        final placeholder = field.decoration!.labelStyle!.color!;
        expect(
          placeholder,
          isNot(FolooPalette.of(tester.element(fieldFinder)).ink),
        );

        await tester.showKeyboard(fieldFinder);
        tester.view.viewInsets = const FakeViewPadding(bottom: 220);
        await tester.pumpAndSettle();

        final helper = find.text(
          'Escribe el nombre del producto o solución. Este nombre será el que aparezca en el correo.',
        );
        final confirm = find.byKey(const Key('confirmContentButton'));
        expect(helper, findsOneWidget);
        expect(confirm, findsOneWidget);
        expect(
          tester.getRect(helper).bottom,
          lessThanOrEqualTo(tester.getRect(confirm).top),
        );
        expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(600 - 220));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
