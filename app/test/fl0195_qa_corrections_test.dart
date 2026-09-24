/// Regression coverage for the isolated FL-019.5 account onboarding fixes.
///
/// Verifies Cognito-policy copy and owner-scoped drawer identity without
/// relying on live AWS identities, provider tokens, or platform UI.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_codec;
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/l10n/app_localizations.dart';
import 'package:foloo/l10n/l10n.dart';
import 'package:foloo/models/app_destination.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/theme/foloo_theme.dart';
import 'package:foloo/widgets/app_drawer.dart';
import 'package:foloo/widgets/auth_account_scope.dart';

Widget _drawerHarness({
  required DemoProfile profile,
  required String accountEmail,
  ThemeMode themeMode = ThemeMode.light,
}) => MaterialApp(
  locale: const Locale('es'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  theme: FolooTheme.light,
  darkTheme: FolooTheme.dark,
  themeMode: themeMode,
  home: AuthAccountScope(
    email: accountEmail,
    provider: null,
    child: AppLanguageScope(
      locale: const Locale('es'),
      onLocaleChanged: (_) {},
      child: Scaffold(
        body: AppDrawer(
          activeDestination: AppDestination.home,
          recordsCount: 0,
          darkMode: themeMode == ThemeMode.dark,
          profile: profile,
          onDestinationSelected: _ignoreDestination,
          onAppearanceChanged: _ignoreAppearance,
          onLogout: _ignore,
        ),
      ),
    ),
  ),
);

void _ignoreDestination(AppDestination _) {}
void _ignoreAppearance(bool _) {}
void _ignore() {}

void main() {
  test(
    'AUT-10 weak-password copy matches Cognito DEV policy in ES/EN',
    () async {
      final es = await AppLocalizations.delegate.load(const Locale('es'));
      final en = await AppLocalizations.delegate.load(const Locale('en'));

      expect(
        es.authWeakPassword,
        'La contraseña debe tener al menos 8 caracteres e incluir una '
        'mayúscula, una minúscula, un número y un símbolo.',
      );
      expect(
        en.authWeakPassword,
        'Password must be at least 8 characters and include an uppercase '
        'letter, lowercase letter, number, and symbol.',
      );
    },
  );

  test(
    'AUT-05 profile photo remains owner scoped in private storage',
    () async {
      final root = await Directory.systemTemp.createTemp('foloo_profile_test_');
      final source = File('${root.path}/source.png');
      await source.writeAsBytes(
        image_codec.encodePng(image_codec.Image(width: 2, height: 2)),
      );
      final persistence = LocalPersistence.inMemory(mediaRoot: root);
      addTearDown(() async {
        await persistence.close();
        if (await root.exists()) await root.delete(recursive: true);
      });

      final durablePath = await persistence.mediaStorage.persistProfileImage(
        sourcePath: source.path,
        ownerSub: 'owner-a',
      );
      await persistence.profiles.save(
        'owner-a',
        DemoProfile(
          name: 'Owner A',
          company: 'Foloo',
          photoLocalPath: durablePath,
        ),
      );

      expect(
        (await persistence.profiles.load('owner-a'))?.photoLocalPath,
        durablePath,
      );
      expect(await persistence.profiles.load('owner-b'), isNull);
    },
  );

  test('drawer resolves an existing persisted photo', () async {
    final root = await Directory.systemTemp.createTemp('foloo_drawer_test_');
    final photo = File('${root.path}/avatar.png');
    await photo.writeAsBytes(
      image_codec.encodePng(image_codec.Image(width: 2, height: 2)),
    );
    addTearDown(() async => root.delete(recursive: true));

    final image = drawerProfileImageFor(
      DemoProfile(
        name: 'Owner A',
        company: 'Foloo',
        photoLocalPath: photo.path,
      ),
    );
    expect(image, isA<FileImage>());
  });

  testWidgets('drawer falls back to initials and changes owner identity', (
    tester,
  ) async {
    await tester.pumpWidget(
      _drawerHarness(
        profile: const DemoProfile(name: 'Owner A', company: 'Company A'),
        accountEmail: 'account-a@example.com',
        themeMode: ThemeMode.dark,
      ),
    );
    await tester.pump();
    expect(find.text('OA'), findsOneWidget);
    expect(find.text('account-a@example.com'), findsOneWidget);
    expect(find.text('google_123456'), findsNothing);

    await tester.pumpWidget(
      _drawerHarness(
        profile: const DemoProfile(name: 'Owner B', company: 'Company B'),
        accountEmail: 'account-b@example.com',
        themeMode: ThemeMode.dark,
      ),
    );
    await tester.pump();
    expect(find.text('OB'), findsOneWidget);
    expect(find.text('account-b@example.com'), findsOneWidget);
    expect(find.text('account-a@example.com'), findsNothing);
    expect(find.text('google_123456'), findsNothing);
  });
}
