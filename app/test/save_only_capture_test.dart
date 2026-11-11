/// FL-024 CAP-03/CAP-09/CAP-11: save-only reuses confirmation and resets capture.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/l10n/app_localizations.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/models/lead_draft.dart';
import 'package:foloo/models/session_lead.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/theme/foloo_theme.dart';
import 'package:foloo/screens/lead_capture_screen.dart';

import 'support/fake_voice_note_service.dart';
import 'voice_note_widget_test.dart' show completeRequiredFields;

void main() {
  for (final immediate in [false, true]) {
    testWidgets('FL-024 CAP-11 save-only reset immediate=$immediate', (
      tester,
    ) async {
      final saved = <LeadDraft>[];
      final persistence = LocalPersistence.inMemory(unlimitedQaMode: true);
      addTearDown(persistence.close);
      var reviews = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          theme: FolooTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LeadCaptureScreen(
            originKind: immediate
                ? LeadOriginKind.direct
                : LeadOriginKind.event,
            eventName: immediate ? null : DemoEventData.eventName,
            initialPlace: 'Demo venue',
            events: DemoAppData.events,
            recordsCount: 0,
            darkMode: false,
            isOnline: immediate,
            voiceNoteService: FakeVoiceNoteService(),
            onLeadSaved: (lead) async {
              saved.add(lead);
              final record = await persistence.leads.saveDraft(
                'owner-a',
                lead,
                capturedBy: const DemoProfile(name: 'Seller', company: 'Foloo'),
              );
              await persistence.emailDelivery.prepareForLead(
                owner: 'owner-a',
                leadId: record.localId,
                lead: lead,
                seller: const DemoProfile(name: 'Seller', company: 'Foloo'),
                language: 'en',
              );
              return record;
            },
            onEmailReviewRequested: (_) {
              reviews++;
              return null;
            },
            onOriginChanged: (_, _) {},
            onCreateEvent: (_) {},
            onDestinationSelected: (_) {},
            onAppearanceChanged: (_) {},
            onLogout: () {},
          ),
        ),
      );
      await completeRequiredFields(tester);
      await tester.enterText(find.byKey(const Key('emailField')), '');
      await tester.enterText(find.byKey(const Key('phoneField')), '5551234567');
      await tester.scrollUntilVisible(
        find.byKey(const Key('saveOnlyLeadButton')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('saveOnlyLeadButton')));
      await tester.tap(find.byKey(const Key('saveOnlyLeadButton')));
      await tester.pumpAndSettle();
      expect(saved, hasLength(1));
      expect(reviews, 0);
      expect(find.text('Lead saved!'), findsOneWidget);
      if (immediate) {
        await tester.tap(find.byKey(const Key('captureAnotherButton')));
      } else {
        await tester.pump(const Duration(seconds: 7));
      }
      await tester.pumpAndSettle();
      for (final field in [
        'name',
        'lastName',
        'role',
        'company',
        'email',
        'phone',
        'note',
      ]) {
        final input = tester.widget<TextFormField>(
          find.byKey(Key('${field}Field')),
        );
        expect(input.controller!.text, isEmpty, reason: '$field must reset');
      }
      expect(saved.single.name, 'Ana López');
      expect(saved.single.place, immediate ? 'Demo venue' : null);
      expect(
        saved.single.originKind,
        immediate ? LeadOriginKind.direct : LeadOriginKind.event,
      );
      expect(
        saved.single.eventName,
        immediate ? null : DemoEventData.eventName,
      );
      await completeRequiredFields(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('saveOnlyLeadButton')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('saveOnlyLeadButton')));
      await tester.pumpAndSettle();
      expect(saved, hasLength(2));
      final records = await persistence.leads.listAll('owner-a');
      expect(records, hasLength(2));
      expect(records.map((record) => record.localId).toSet(), hasLength(2));
      expect(await persistence.leads.listAll('owner-b'), isEmpty);
      expect(await persistence.emailDelivery.intents('owner-a'), isEmpty);
      expect(saved.last.place, immediate ? 'Demo venue' : null);
      expect(saved.last.eventName, immediate ? null : DemoEventData.eventName);
      expect(reviews, 0);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
