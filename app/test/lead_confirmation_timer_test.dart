/// Verifies the readable FL-019.5 confirmation dwell time (CAP-11).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/l10n/app_localizations.dart';
import 'package:foloo/models/lead_draft.dart';
import 'package:foloo/models/session_lead.dart';
import 'package:foloo/screens/lead_confirmation_screen.dart';
import 'package:foloo/theme/foloo_theme.dart';

void main() {
  testWidgets('CAP-11 confirmation returns automatically after 7 seconds', (
    tester,
  ) async {
    var returned = false;
    final record = SessionLead(
      localId: 'lead-1',
      folio: null,
      capturedAt: DateTime.utc(2026, 9, 23),
      lead: LeadDraft(
        name: 'Mariana',
        lastName: 'Sandoval',
        role: '',
        company: 'Lácteos Norte',
        email: 'mariana@example.com',
        phone: '',
        type: LeadType.customer,
        interest: InterestLevel.high,
        note: '',
        originKind: LeadOriginKind.direct,
        audioSeconds: 0,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        theme: FolooTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LeadConfirmationScreen(
          record: record,
          onCaptureAnother: () => returned = true,
        ),
      ),
    );

    expect(find.text('Regresas a captura en 7 s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(returned, isFalse);
    expect(find.text('Regresas a captura en 1 s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(returned, isTrue);
  });
  for (final language in ['es', 'en']) {
    for (final immediate in [false, true]) {
      testWidgets('FL-024 CAP-11 $language immediate=$immediate returns once', (
        tester,
      ) async {
        var returns = 0;
        final record = SessionLead(
          localId: 'saved',
          folio: null,
          capturedAt: DateTime.utc(2026, 11, 11),
          lead: LeadDraft(
            name: 'Ana',
            lastName: '',
            role: '',
            company: '',
            email: '',
            phone: '5551234567',
            type: LeadType.customer,
            interest: InterestLevel.high,
            note: '',
            originKind: LeadOriginKind.direct,
            audioSeconds: 0,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            theme: FolooTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: LeadConfirmationScreen(
              record: record,
              savedWithoutEmail: true,
              onCaptureAnother: () => returns++,
            ),
          ),
        );
        expect(
          find.text(language == 'es' ? '¡Lead guardado!' : 'Lead saved!'),
          findsOneWidget,
        );
        expect(
          find.text(
            language == 'es'
                ? 'El contacto se guardó en Registros. No se envió ningún correo de seguimiento.'
                : 'The contact was saved to Records. No follow-up email was sent.',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            language == 'es' ? 'Capturar otro lead' : 'Capture another lead',
          ),
          findsOneWidget,
        );
        if (immediate) {
          await tester.tap(find.byKey(const Key('captureAnotherButton')));
          await tester.pump();
        } else {
          await tester.pump(const Duration(seconds: 6));
          expect(returns, 0);
          await tester.pump(const Duration(seconds: 1));
        }
        expect(returns, 1);
        await tester.pump(const Duration(seconds: 8));
        expect(returns, 1);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
