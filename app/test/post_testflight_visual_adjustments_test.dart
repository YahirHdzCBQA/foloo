import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/l10n/app_localizations.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/models/content_file.dart';
import 'package:foloo/models/entitlement.dart';
import 'package:foloo/models/lead_draft.dart';
import 'package:foloo/models/session_lead.dart';
import 'package:foloo/screens/content_screen.dart';
import 'package:foloo/screens/lead_capture_screen.dart';
import 'package:foloo/theme/foloo_theme.dart';
import 'package:foloo/widgets/entitlement_scope.dart';
import 'package:foloo/widgets/module_header.dart';

Widget _localizedApp({
  required Widget home,
  Locale locale = const Locale('es'),
  bool dark = false,
}) => MaterialApp(
  theme: FolooTheme.light,
  darkTheme: FolooTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  locale: locale,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

Widget _capture({
  required EntitlementSnapshot entitlement,
  required bool isOnline,
  Locale locale = const Locale('es'),
  bool dark = false,
}) => _localizedApp(
  locale: locale,
  dark: dark,
  home: EntitlementScope(
    entitlement: entitlement,
    child: LeadCaptureScreen(
      originKind: LeadOriginKind.event,
      eventName: DemoEventData.eventName,
      events: DemoAppData.events,
      recordsCount: 0,
      darkMode: dark,
      isOnline: isOnline,
      onLeadSaved: (lead) =>
          DemoEventData.createSessionLead(lead: lead, sequence: 1),
      onOriginChanged: (_, _) {},
      onCreateEvent: (_) {},
      onDestinationSelected: (_) {},
      onAppearanceChanged: (_) {},
      onLogout: () {},
    ),
  ),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'MON-01 capture balance is bold below the CTA and reflects offline reservations',
    (tester) async {
      _phone(tester);
      const entitlement = EntitlementSnapshot(
        status: SubscriptionStatus.trial,
        serverTrialLeadsUsed: 1,
        pendingLocalLeads: 2,
        verified: true,
      );

      await tester.pumpWidget(
        _capture(entitlement: entitlement, isOnline: false),
      );

      final balance = find.byKey(const Key('captureTrialBalance'));
      final save = find.byKey(const Key('saveLeadButton'));
      expect(find.text('2 leads gratuitos disponibles'), findsOneWidget);
      expect(
        tester.getTopLeft(balance).dy,
        greaterThan(tester.getBottomLeft(save).dy),
      );
      expect(
        find.ancestor(
          of: balance,
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      final text = tester.widget<Text>(
        find.descendant(of: balance, matching: find.byType(Text)),
      );
      expect(text.style?.fontWeight, FontWeight.w700);
      expect(
        find.descendant(of: balance, matching: find.byType(Icon)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'MON-01 capture balance localizes singular and active semantics',
    (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _capture(
          entitlement: const EntitlementSnapshot(
            status: SubscriptionStatus.trial,
            serverTrialLeadsUsed: 4,
            pendingLocalLeads: 0,
            verified: true,
          ),
          isOnline: true,
          locale: const Locale('en'),
          dark: true,
        ),
      );
      expect(find.text('1 free lead available'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _capture(
          entitlement: const EntitlementSnapshot(
            status: SubscriptionStatus.active,
            serverTrialLeadsUsed: 5,
            pendingLocalLeads: 0,
            verified: true,
          ),
          isOnline: true,
          locale: const Locale('en'),
          dark: true,
        ),
      );
      expect(find.text('Active subscription'), findsOneWidget);
      expect(find.textContaining('free lead'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('CON-01 content header keeps file count and removes MB summary', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _localizedApp(
        home: ContentScreen(
          files: DemoContentData.files,
          events: DemoAppData.events,
          recordsCount: 0,
          profile: DemoAppData.profile,
          darkMode: false,
          onDestinationSelected: (_) {},
          onAppearanceChanged: (_) {},
          onLogout: () {},
          onFileAdded: (_) async {},
          onFileUpdated: (_) async {},
          onFileDeleted: (_) async {},
          demoMode: true,
        ),
      ),
    );

    final header = find.byType(ModuleHeader);
    expect(
      find.descendant(of: header, matching: find.text('3 archivos')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: header, matching: find.textContaining('MB')),
      findsNothing,
    );
    expect(
      find.descendant(of: header, matching: find.textContaining('·')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
