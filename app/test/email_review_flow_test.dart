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
  Future<void> Function(EmailReviewDraft)? onDraftSaved,
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
    onDraftSaved: onDraftSaved,
  ),
);

void main() {
  testWidgets('Review cards are subtle until their editor receives focus', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(onConfirm: (_) async => EmailReviewOutcome.pending),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(
      scaffold.backgroundColor,
      FolooPalette.of(tester.element(find.byType(Scaffold))).card,
    );
    final backFrame = find.byKey(const Key('emailReviewBackFrame'));
    expect(tester.getSize(backFrame), const Size.square(56));
    final title = find.text('Revisar');
    expect(
      tester.getTopLeft(title).dx,
      greaterThan(tester.getTopRight(backFrame).dx),
    );
    expect(
      tester.getTopLeft(title).dx - tester.getTopRight(backFrame).dx,
      lessThanOrEqualTo(16),
    );

    final field = tester.widget<TextField>(
      find.byKey(const Key('emailReviewSubject')),
    );
    expect(field.decoration?.filled, isFalse);
    expect(field.decoration?.enabledBorder, InputBorder.none);
    expect(field.decoration?.focusedBorder, InputBorder.none);
    for (final key in const [
      Key('emailReviewSubjectCard'),
      Key('emailReviewMessageCard'),
      Key('emailReviewSignatureCard'),
    ]) {
      final normalCard = tester.widget<Container>(find.byKey(key));
      final decoration = normalCard.decoration! as BoxDecoration;
      expect(decoration.border, isNull);
      expect(decoration.borderRadius, BorderRadius.circular(FolooRadii.md));
      expect(normalCard.clipBehavior, Clip.antiAlias);
    }

    final editButton = find.byKey(const Key('emailReviewSubjectEdit'));
    final editMaterial = tester.widget<Material>(
      find.ancestor(of: editButton, matching: find.byType(Material)).first,
    );
    expect(
      editMaterial.color,
      FolooPalette.of(tester.element(editButton)).card,
    );

    await tester.tap(editButton);
    await tester.pump();

    final editingCard = tester.widget<Container>(
      find.byKey(const Key('emailReviewSubjectCard')),
    );
    final border = (editingCard.decoration! as BoxDecoration).border! as Border;
    expect(border.top.width, 2);
    expect(
      (editingCard.decoration! as BoxDecoration).borderRadius,
      BorderRadius.circular(FolooRadii.md),
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('emailReviewSubject')))
          .focusNode
          ?.hasFocus,
      isTrue,
    );

    await tester.tap(find.text('Mensaje'));
    await tester.pump();
    final finishedCard = tester.widget<Container>(
      find.byKey(const Key('emailReviewSubjectCard')),
    );
    expect((finishedCard.decoration! as BoxDecoration).border, isNull);
  });

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
    expect(find.byKey(const Key('emailReviewAdvanceIcon')), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    await tester.tap(find.byKey(const Key('emailReviewMessageEdit')));
    await tester.pump();
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

  testWidgets('Review renders every selected Content attachment', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        reviewDraft: const EmailReviewDraft(
          followUpId: 'follow-up-1',
          leadName: 'Mariana Sandoval',
          recipientAddress: 'mariana@example.com',
          subject: 'Seguimiento',
          message: 'Mensaje concreto',
          attachmentNames: ['Ficha A.pdf', 'Ficha B.pdf'],
        ),
        onConfirm: (_) async => EmailReviewOutcome.pending,
      ),
    );

    expect(find.text('Ficha A.pdf'), findsOneWidget);
    expect(find.text('Ficha B.pdf'), findsOneWidget);
    expect(find.text('Se adjuntan 2 archivos'), findsOneWidget);
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

  testWidgets('Back persists concrete Review edits and marks them manual', (
    tester,
  ) async {
    EmailReviewDraft? saved;
    await tester.pumpWidget(
      harness(
        onConfirm: (_) async => EmailReviewOutcome.pending,
        onDraftSaved: (value) async {
          saved = value;
        },
      ),
    );
    await tester.tap(find.byKey(const Key('emailReviewSubjectEdit')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('emailReviewSubject')),
      'Asunto manual',
    );
    await tester.tap(find.byKey(const Key('emailReviewMessageEdit')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('emailReviewMessage')),
      'Mensaje manual específico',
    );
    await tester.tap(find.byKey(const Key('emailReviewBack')));
    await tester.pumpAndSettle();

    expect(saved?.subject, 'Asunto manual');
    expect(saved?.message, 'Mensaje manual específico');
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
      await tester.tap(find.byKey(const Key('emailReviewMessageEdit')));
      await tester.pump();
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
