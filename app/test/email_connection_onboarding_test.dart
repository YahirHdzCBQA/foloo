import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/app.dart';
import 'package:foloo/auth/auth_models.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/data/local/app_database.dart';
import 'package:foloo/l10n/app_localizations.dart';
import 'package:foloo/l10n/l10n.dart';
import 'package:foloo/models/app_destination.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/models/lead_draft.dart';
import 'package:foloo/screens/email_screen.dart';
import 'package:foloo/screens/email_onboarding_screen.dart';
import 'package:foloo/services/email_connection_service.dart';
import 'package:foloo/sync/sync_models.dart';
import 'package:foloo/theme/foloo_theme.dart';

class _Session implements SyncSessionProvider {
  const _Session();

  @override
  Future<String?> accessTokenFor(String ownerSub) async => 'token-$ownerSub';
}

class _ConnectionApi implements SyncApi {
  Map<String, Object?>? connection;
  bool fail = false;
  final owners = <String>[];
  final requests = <SyncRequest>[];

  @override
  Future<SyncResponse> send(String accessToken, SyncRequest request) async {
    owners.add(accessToken.replaceFirst('token-', ''));
    requests.add(request);
    if (fail) throw const SyncTransportException();
    if (request.method == 'POST') {
      return const SyncResponse(
        statusCode: 200,
        data: {
          'data': {'authorizationUrl': 'https://accounts.example.test/oauth'},
        },
      );
    }
    return SyncResponse(statusCode: 200, data: {'data': connection});
  }
}

Widget _localized(Widget child, {Locale locale = const Locale('es')}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: FolooTheme.light,
      home: Builder(
        builder: (context) => AppLanguageScope(
          locale: locale,
          onLocaleChanged: (_) {},
          child: child,
        ),
      ),
    );

Future<void> _loginAndCompleteProfile(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('loginEmailField')), 'new-user');
  await tester.enterText(find.byKey(const Key('loginPasswordField')), 'demo');
  await tester.tap(find.byKey(const Key('loginButton')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('profileContinueButton')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'AUT-15 same social account starts fresh sender OAuth without auth tokens',
    (tester) async {
      final api = _ConnectionApi();
      Uri? launched;
      final service = EmailConnectionService(
        api,
        const _Session(),
        launcher: (uri) async {
          launched = uri;
          return true;
        },
      );
      await tester.pumpWidget(
        _localized(
          EmailOnboardingScreen(
            ownerSub: 'seller-a',
            accountEmail: 'social@example.com',
            authProvider: AuthProvider.google,
            connectionService: service,
            onComplete: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('emailOnboardingSameAccountButton')),
        findsOneWidget,
      );
      expect(find.text('social@example.com'), findsOneWidget);
      expect(find.text('google_123456'), findsNothing);
      await tester.tap(
        find.byKey(const Key('emailOnboardingSameAccountButton')),
      );
      await tester.pumpAndSettle();

      final request = api.requests.last;
      expect(request.path, '/v1/email/connection/google');
      expect(request.body, null);
      expect(launched, Uri.parse('https://accounts.example.test/oauth'));
    },
  );

  testWidgets('AUT-15 password account does not imply a sender provider', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localized(
        EmailOnboardingScreen(
          ownerSub: 'seller-a',
          accountEmail: 'password@example.com',
          connectionService: EmailConnectionService(
            _ConnectionApi(),
            const _Session(),
          ),
          onComplete: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('emailOnboardingSameAccountButton')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('emailOnboardingGoogleButton')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('emailOnboardingMicrosoftButton')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('emailOnboardingMicrosoftNotice')),
      findsOneWidget,
    );
    expect(
      find.textContaining('cuentas personales (como Outlook o Hotmail)'),
      findsOneWidget,
    );
  });

  testWidgets('Microsoft sender limitation is localized before OAuth', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localized(
        EmailOnboardingScreen(
          ownerSub: 'seller-a',
          connectionService: EmailConnectionService(
            _ConnectionApi(),
            const _Session(),
          ),
          onComplete: (_) async {},
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Microsoft connection is available for personal accounts',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('emailOnboardingMicrosoftButton')),
      findsOneWidget,
    );
  });

  testWidgets('new user sees optional sending-account step after profile', (
    tester,
  ) async {
    final persistence = LocalPersistence.inMemory();
    await tester.pumpWidget(FolooApp(persistence: persistence));
    await tester.pumpAndSettle();
    await _loginAndCompleteProfile(tester);

    expect(find.byKey(const Key('emailOnboardingScreen')), findsOneWidget);
    expect(find.text('Envía seguimientos\ndesde tu correo'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('emailOnboardingSkipButton')),
    );
    await tester.tap(find.byKey(const Key('emailOnboardingSkipButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('originScreen')), findsOneWidget);
    final preferences = await persistence.database
        .select(persistence.database.localUserPreferences)
        .get();
    expect(
      preferences.any(
        (item) =>
            item.key == 'emailOnboardingStatus' && item.value == 'skipped',
      ),
      isTrue,
    );

    await tester.tap(find.byKey(const Key('originContinueButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cardSection')), findsOneWidget);

    await tester.tap(find.byKey(const Key('hamburgerMenuButton')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logoutButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('loginEmailField')),
      'new-user',
    );
    await tester.enterText(find.byKey(const Key('loginPasswordField')), 'demo');
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('emailOnboardingScreen')), findsNothing);
    expect(find.byKey(const ValueKey('originScreen')), findsOneWidget);
  });

  testWidgets('connection state comes from backend and refreshes on resume', (
    tester,
  ) async {
    final api = _ConnectionApi();
    var completed = false;
    await tester.pumpWidget(
      _localized(
        EmailOnboardingScreen(
          ownerSub: 'seller-a',
          connectionService: EmailConnectionService(api, const _Session()),
          onComplete: (_) async => completed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No has conectado una cuenta'), findsNothing);
    expect(
      find.byKey(const Key('emailOnboardingGoogleButton')),
      findsOneWidget,
    );

    api.connection = {
      'id': 'connection-a',
      'provider': 'google',
      'senderAddress': 'se***@example.com',
      'status': 'connected',
    };
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Google'), findsOneWidget);
    expect(find.text('se***@example.com'), findsOneWidget);
    expect(find.text('Conectada'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('emailOnboardingContinueButton')),
    );
    await tester.tap(find.byKey(const Key('emailOnboardingContinueButton')));
    await tester.pump();
    expect(completed, isTrue);
  });

  testWidgets('owner change never reuses previous connection state', (
    tester,
  ) async {
    final api = _ConnectionApi()
      ..connection = {
        'id': 'connection-a',
        'provider': 'microsoft',
        'senderAddress': 'sa***@company.com',
        'status': 'connected',
      };
    final service = EmailConnectionService(api, const _Session());

    await tester.pumpWidget(
      _localized(
        EmailOnboardingScreen(
          ownerSub: 'seller-a',
          connectionService: service,
          onComplete: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('sa***@company.com'), findsOneWidget);

    api.connection = null;
    await tester.pumpWidget(
      _localized(
        EmailOnboardingScreen(
          ownerSub: 'seller-b',
          connectionService: service,
          onComplete: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('sa***@company.com'), findsNothing);
    expect(
      find.byKey(const Key('emailOnboardingGoogleButton')),
      findsOneWidget,
    );
    expect(api.owners, containsAllInOrder(['seller-a', 'seller-b']));
  });

  testWidgets('transport failure never promotes a local connected state', (
    tester,
  ) async {
    final api = _ConnectionApi()..fail = true;
    await tester.pumpWidget(
      _localized(
        EmailOnboardingScreen(
          ownerSub: 'seller-a',
          connectionService: EmailConnectionService(api, const _Session()),
          onComplete: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conectada'), findsNothing);
    expect(find.textContaining('No se pudo comprobar'), findsOneWidget);
    expect(
      find.byKey(const Key('emailOnboardingGoogleButton')),
      findsOneWidget,
    );
  });

  testWidgets('EmailScreen renders safe Google and Microsoft backend states', (
    tester,
  ) async {
    final persistence = LocalPersistence.inMemory();
    await persistence.initialize();
    addTearDown(persistence.close);
    final api = _ConnectionApi()
      ..connection = {
        'id': 'connection-a',
        'provider': 'google',
        'senderAddress': 'go***@gmail.com',
        'status': 'connected',
      };
    final service = EmailConnectionService(api, const _Session());

    Widget screen(bool active) => _localized(
      EmailScreen(
        recordsCount: 0,
        contentCount: 0,
        records: const [],
        contentFiles: const [],
        profile: const DemoProfile(name: 'Seller', company: 'Foloo'),
        darkMode: false,
        ownerSub: 'seller-a',
        templateRepository: persistence.templates,
        deliveryRepository: persistence.emailDelivery,
        connectionService: service,
        active: active,
        onDestinationSelected: (AppDestination _) {},
        onAppearanceChanged: (_) {},
        onLogout: () {},
      ),
    );

    await tester.pumpWidget(screen(true));
    await tester.pumpAndSettle();
    expect(find.text('Google · go***@gmail.com'), findsOneWidget);
    expect(find.text('Conectada'), findsOneWidget);
    expect(
      find.byKey(const Key('emailMicrosoftConnectionNotice')),
      findsNothing,
    );

    await tester.pumpWidget(screen(false));
    await tester.pump();
    api.connection = {
      'id': 'connection-b',
      'provider': 'microsoft',
      'senderAddress': 'mi***@company.com',
      'status': 'connected',
    };
    await tester.pumpWidget(screen(true));
    await tester.pumpAndSettle();
    expect(find.text('Microsoft · mi***@company.com'), findsOneWidget);
    expect(find.text('Google · go***@gmail.com'), findsNothing);
    expect(
      find.byKey(const Key('emailMicrosoftConnectionNotice')),
      findsOneWidget,
    );

    await tester.pumpWidget(screen(false));
    await tester.pump();
    api.connection = {
      'id': 'connection-b',
      'provider': 'microsoft',
      'senderAddress': 'mi***@company.com',
      'status': 'reconnect_required',
    };
    await tester.pumpWidget(screen(true));
    await tester.pumpAndSettle();
    expect(find.text('Necesita reconexión'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Microsoft'), findsWidgets);
    expect(
      find.byKey(const Key('emailMicrosoftConnectionNotice')),
      findsOneWidget,
    );
  });

  testWidgets('Correo no longer duplicates follow-up history', (tester) async {
    final persistence = LocalPersistence.inMemory();
    await persistence.initialize();
    addTearDown(persistence.close);
    final now = DateTime.utc(2026, 9, 21, 19, 4);
    final lead = await persistence.leads.saveDraft(
      'seller-a',
      LeadDraft(
        name: 'Mariana',
        lastName: '',
        role: '',
        company: 'Lácteos Norte',
        email: 'lead@example.com',
        phone: '',
        type: LeadType.customer,
        interest: InterestLevel.high,
        note: '',
        originKind: LeadOriginKind.direct,
        audioSeconds: 0,
        place: 'Monterrey',
      ),
      capturedBy: const DemoProfile(name: 'Seller', company: 'Foloo'),
    );
    await persistence.database.emailDeliveryDao.saveFollowUp(
      LocalEmailFollowUpsCompanion.insert(
        localId: 'follow-up-a',
        ownerUserId: 'seller-a',
        leadLocalId: lead.localId,
        recipientAddress: 'lead@example.com',
        subject: 'Damos seguimiento, Mariana',
        plainBody: 'Hola Mariana',
        htmlBody: '<p>Hola Mariana</p>',
        languageCode: 'es',
        preparedAt: now,
      ),
    );
    await persistence.database.emailDeliveryDao.saveFollowUp(
      LocalEmailFollowUpsCompanion.insert(
        localId: 'follow-up-b',
        ownerUserId: 'seller-a',
        leadLocalId: lead.localId,
        recipientAddress: 'lead@example.com',
        subject: 'Seguimiento más reciente',
        plainBody: 'Hola Mariana',
        htmlBody: '<p>Hola Mariana</p>',
        languageCode: 'es',
        preparedAt: now.add(const Duration(minutes: 1)),
      ),
    );
    await persistence.database.emailDeliveryDao.saveIntent(
      LocalEmailSendIntentsCompanion.insert(
        localId: 'intent-a',
        ownerUserId: 'seller-a',
        followUpLocalId: 'follow-up-a',
        status: const Value('error'),
        errorCode: const Value('recipient_opted_out'),
        createdAt: now,
        updatedAt: now,
      ),
    );

    await tester.pumpWidget(
      _localized(
        EmailScreen(
          recordsCount: 1,
          contentCount: 0,
          records: [lead],
          contentFiles: const [],
          profile: const DemoProfile(name: 'Seller', company: 'Foloo'),
          darkMode: false,
          ownerSub: 'seller-a',
          templateRepository: persistence.templates,
          deliveryRepository: persistence.emailDelivery,
          active: true,
          onDestinationSelected: (AppDestination _) {},
          onAppearanceChanged: (_) {},
          onLogout: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('emailFollowUp-follow-up-a')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('emailFollowUp-follow-up-b')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('emailRetry-intent-a')), findsNothing);
    expect(find.textContaining('Pendiente'), findsNothing);
  });
}
