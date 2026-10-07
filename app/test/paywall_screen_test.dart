import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/l10n/app_localizations.dart';
import 'package:foloo/models/app_destination.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/models/entitlement.dart';
import 'package:foloo/screens/paywall_screen.dart';
import 'package:foloo/theme/foloo_theme.dart';
import 'package:foloo/widgets/entitlement_scope.dart';

Widget paywall(Locale locale, ThemeMode mode) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: FolooTheme.light,
  darkTheme: FolooTheme.dark,
  themeMode: mode,
  home: EntitlementScope(
    entitlement: const EntitlementSnapshot(
      status: SubscriptionStatus.trialExhausted,
      serverTrialLeadsUsed: 5,
      pendingLocalLeads: 0,
      verified: true,
    ),
    child: PaywallScreen(
      profile: const DemoProfile(name: 'Yahir', company: 'Foloo'),
      recordsCount: 5,
      contentCount: 1,
      darkMode: mode == ThemeMode.dark,
      onDestinationSelected: (AppDestination _) {},
      onAppearanceChanged: (_) {},
      onLogout: () {},
    ),
  ),
);

void main() {
  testWidgets('Paywall is localized and renders in light and dark', (
    tester,
  ) async {
    await tester.pumpWidget(paywall(const Locale('es'), ThemeMode.light));
    expect(find.text('Tus 5 leads gratuitos ya fueron utilizados'), findsOne);
    expect(find.byKey(const Key('paywallViewRecords')), findsOne);

    await tester.pumpWidget(paywall(const Locale('en'), ThemeMode.dark));
    await tester.pump();
    expect(find.text('Your 5 free leads have been used'), findsOne);
    expect(tester.takeException(), isNull);
  });
}
