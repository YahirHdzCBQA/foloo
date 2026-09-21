/// Covers the explicit SAL-01 review step without any real provider account.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/l10n/app_localizations.dart';
import 'package:foloo/models/email_review.dart';
import 'package:foloo/models/lead_draft.dart';
import 'package:foloo/models/session_lead.dart';
import 'package:foloo/screens/email_review_screen.dart';
import 'package:foloo/theme/foloo_theme.dart';

final record = SessionLead(
  localId: 'lead-1',
  folio: null,
  capturedAt: DateTime.utc(2026, 9, 20),
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
    originKind: LeadOriginKind.event,
    audioSeconds: 0,
  ),
);

const draft = EmailReviewDraft(
  followUpId: 'follow-up-1',
  leadName: 'Mariana Sandoval',
  recipientAddress: 'mariana@example.com',
  subject: 'Seguimiento · Expo México',
  message: 'Hola Mariana,\n\nMensaje concreto.',
  attachmentNames: ['Ficha técnica.pdf'],
);

Widget harness({
  required Future<EmailReviewOutcome> Function(EmailReviewDraft) onConfirm,
  VoidCallback? onConnectionRequired,
  EmailReviewDraft reviewDraft = draft,
}) => MaterialApp(
  locale: const Locale('es'),
  theme: FolooTheme.light,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: EmailReviewScreen(
    record: record,
    draft: reviewDraft,
    onConfirm: onConfirm,
    onConnectionRequired: onConnectionRequired ?? () {},
    onCaptureAnother: () {},
  ),
);

void main() {
  testWidgets('recipient is immutable and concrete edits reach confirmation', (
    tester,
  ) async {
    EmailReviewDraft? confirmed;
    await tester.pumpWidget(
      harness(
        onConfirm: (value) async {
          confirmed = value;
          return EmailReviewOutcome.pending;
        },
      ),
    );

    expect(find.textContaining('mariana@example.com'), findsOneWidget);
    expect(find.textContaining('{nombre}'), findsNothing);
    await tester.enterText(
      find.byKey(const Key('emailReviewMessage')),
      'Mensaje editado solo para este lead.',
    );
    await tester.tap(find.byKey(const Key('confirmFollowUpButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(confirmed?.recipientAddress, 'mariana@example.com');
    expect(confirmed?.message, 'Mensaje editado solo para este lead.');
    expect(find.text('Correo pendiente'), findsOneWidget);
  });

  testWidgets('missing provider asks for connection without losing review', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(onConfirm: (_) async => EmailReviewOutcome.connectionRequired),
    );
    await tester.tap(find.byKey(const Key('confirmFollowUpButton')));
    await tester.pumpAndSettle();

    expect(find.text('Conecta tu correo'), findsOneWidget);
    expect(find.byKey(const Key('emailReviewMessage')), findsOneWidget);
  });

  testWidgets(
    'keyboard inset keeps CTA reachable and dismiss preserves a long edit',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final longMessage = List.filled(
        12,
        'Seguimiento detallado que debe conservarse.',
      ).join('\n');
      EmailReviewDraft? confirmed;
      await tester.pumpWidget(
        harness(
          reviewDraft: draft.copyWith(message: longMessage),
          onConfirm: (value) async {
            confirmed = value;
            return EmailReviewOutcome.pending;
          },
        ),
      );

      final message = find.byKey(const Key('emailReviewMessage'));
      await tester.ensureVisible(message);
      await tester.enterText(message, '$longMessage\nEdición final');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();

      final button = find.byKey(const Key('confirmFollowUpButton'));
      expect(tester.getRect(button).bottom, lessThanOrEqualTo(568 - 260));
      expect(find.byKey(const Key('emailReviewScroll')), findsOneWidget);

      await tester.drag(
        find.byKey(const Key('emailReviewScroll')),
        const Offset(0, -40),
      );
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(message);
      expect(field.focusNode?.hasFocus, isFalse);
      expect(field.controller?.text, endsWith('Edición final'));

      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(confirmed?.message, endsWith('Edición final'));
      expect(tester.takeException(), isNull);
    },
  );
}
