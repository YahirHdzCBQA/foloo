/// FL-023 / MON-12: Unlimited QA hides the FREE balance in authenticated UI.
/// Exercises both locales and UI updates while retaining genuine PRO status.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/l10n/app_localizations.dart';
import 'package:foloo/l10n/l10n.dart';
import 'package:foloo/models/app_destination.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/models/entitlement.dart';
import 'package:foloo/screens/profile_screen.dart';
import 'package:foloo/theme/foloo_theme.dart';
import 'package:foloo/widgets/app_drawer.dart';
import 'package:foloo/widgets/entitlement_scope.dart';

EntitlementSnapshot snapshot({
  required bool unlimited,
  int used = 0,
  SubscriptionStatus status = SubscriptionStatus.trial,
}) => EntitlementSnapshot(
  status: status,
  serverTrialLeadsUsed: used,
  pendingLocalLeads: 0,
  verified: true,
  unlimitedQaMode: unlimited,
);

Widget app(
  String language,
  String surface,
  ValueNotifier<EntitlementSnapshot> value,
) {
  final locale = Locale(language);
  final screen = surface == 'profile'
      ? ProfileScreen(
          profile: const DemoProfile(name: 'QA Seller', company: 'Foloo'),
          accountEmail: 'qa@example.test',
          ownerSub: 'owner-a',
          onSave: (profile) async => profile,
          onLogout: () {},
          onDeleteAccount: () {},
          accountDeletionEnabled: true,
        )
      : Scaffold(
          body: AppDrawer(
            activeDestination: AppDestination.home,
            recordsCount: 7,
            darkMode: false,
            profile: const DemoProfile(name: 'QA Seller', company: 'Foloo'),
            onDestinationSelected: (_) {},
            onAppearanceChanged: (_) {},
            onLogout: () {},
          ),
        );
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: FolooTheme.light,
    home: ValueListenableBuilder<EntitlementSnapshot>(
      valueListenable: value,
      child: AppLanguageScope(
        locale: locale,
        onLocaleChanged: (_) {},
        child: screen,
      ),
      builder: (context, entitlement, child) =>
          EntitlementScope(entitlement: entitlement, child: child!),
    ),
  );
}

void main() {
  for (final language in ['es', 'en']) {
    for (final surface in ['drawer', 'profile']) {
      for (final used in [0, 5]) {
        testWidgets(
          'MON-12 $language $surface keeps FREE $used when QA is off and hides it when on',
          (tester) async {
            tester.view.physicalSize = const Size(390, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final value = ValueNotifier(snapshot(unlimited: false, used: used));
            addTearDown(value.dispose);
            await tester.pumpWidget(app(language, surface, value));
            await tester.pumpAndSettle();
            final context = tester.element(find.byType(EntitlementScope));
            final l10n = AppLocalizations.of(context);
            final label =
                '${l10n.planFree} · ${l10n.historicalLeadUsage(used)}';
            expect(find.text(label), findsOneWidget);

            value.value = snapshot(unlimited: true, used: used);
            await tester.pumpAndSettle();
            expect(find.byKey(Key('${surface}Entitlement')), findsNothing);
            expect(find.text(label), findsNothing);
            expect(find.text(l10n.planPro), findsNothing);
            expect(value.value.status, SubscriptionStatus.trial);
            expect(value.value.serverTrialLeadsUsed, used);

            final preserved = surface == 'profile'
                ? [
                    'profileEditNameField',
                    'profileAccountEmailField',
                    'profileSaveButton',
                    'profileLogoutButton',
                    'profileDeleteAccountButton',
                  ]
                : [
                    'drawerProfileButton',
                    'drawerHome',
                    'drawerContent',
                    'drawerEmail',
                    'drawerRecords',
                    'drawerEvents',
                    'appearanceSwitch',
                    'logoutButton',
                  ];
            for (final key in preserved) {
              expect(find.byKey(Key(key)), findsOneWidget);
            }

            value.value = snapshot(unlimited: false, used: used);
            await tester.pumpAndSettle();
            expect(find.text(label), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }

      testWidgets(
        'MON-21 $language $surface retains actual PRO in either QA mode',
        (tester) async {
          final value = ValueNotifier(
            snapshot(
              unlimited: false,
              used: 5,
              status: SubscriptionStatus.active,
            ),
          );
          addTearDown(value.dispose);
          await tester.pumpWidget(app(language, surface, value));
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(
            tester.element(find.byType(EntitlementScope)),
          );
          expect(find.text(l10n.planPro), findsOneWidget);
          value.value = snapshot(
            unlimited: true,
            used: 5,
            status: SubscriptionStatus.active,
          );
          await tester.pumpAndSettle();
          expect(find.text(l10n.planPro), findsOneWidget);
          expect(find.textContaining(l10n.planFree), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
