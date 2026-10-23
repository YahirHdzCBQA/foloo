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

/// MON-14: no price, commercial call to action, button or link on the paywall.
void _expectNoCommercialCopy(WidgetTester tester) {
  final forbidden = RegExp(
    r'pagar|comprar|pago|upgrade|mejorar|suscrib|\$|\bpay\b|\bbuy\b|subscribe|price',
    caseSensitive: false,
  );
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    expect(forbidden.hasMatch(text.data ?? ''), isFalse, reason: text.data);
  }
  expect(find.byType(FilledButton), findsOne);
  expect(find.byType(TextButton), findsNothing);
  expect(find.byType(OutlinedButton), findsNothing);
}

void main() {
  testWidgets('Paywall is localized and renders in light and dark', (
    tester,
  ) async {
    await tester.pumpWidget(paywall(const Locale('es'), ThemeMode.light));
    expect(find.text('Tus 5 leads gratuitos ya fueron utilizados'), findsOne);
    expect(find.byKey(const Key('paywallViewRecords')), findsOne);
    expect(find.textContaining('web de Foloo'), findsOne);
    _expectNoCommercialCopy(tester);

    await tester.pumpWidget(paywall(const Locale('en'), ThemeMode.dark));
    await tester.pump();
    expect(find.text('Your 5 free leads have been used'), findsOne);
    expect(find.textContaining('Foloo website'), findsOne);
    _expectNoCommercialCopy(tester);
    expect(tester.takeException(), isNull);
  });
}
