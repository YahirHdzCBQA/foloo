/// Focused profile navigation, persistence boundary, and identity separation.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/l10n/app_localizations.dart';
import 'package:foloo/l10n/l10n.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/screens/profile_screen.dart';
import 'package:foloo/services/email_connection_service.dart';
import 'package:foloo/services/image_capture_service.dart';
import 'package:foloo/sync/sync_models.dart';
import 'package:foloo/theme/foloo_theme.dart';
import 'package:image_picker/image_picker.dart';

class _Session implements SyncSessionProvider {
  @override
  Future<String?> accessTokenFor(String ownerSub) async => 'token';
}

class _ConnectionApi implements SyncApi {
  _ConnectionApi({
    this.connection = const {
      'id': 'sender-a',
      'provider': 'google',
      'senderAddress': 'se***@example.test',
      'status': 'connected',
    },
  });

  Map<String, Object?>? connection;
  bool fail = false;
  final requests = <SyncRequest>[];

  @override
  Future<SyncResponse> send(String accessToken, SyncRequest request) async {
    requests.add(request);
    if (fail) throw const SyncTransportException();
    if (request.method == 'DELETE') connection = null;
    if (request.method == 'POST') {
      return const SyncResponse(
        statusCode: 200,
        data: {
          'data': {'authorizationUrl': 'https://example.test/oauth'},
        },
      );
    }
    return SyncResponse(statusCode: 200, data: {'data': connection});
  }
}

class _ImageCapture implements ImageCaptureService {
  int picks = 0;

  @override
  Future<CapturedImage?> pick({
    required ImageSource source,
    double maxWidth = 1568,
    double maxHeight = 1568,
    int imageQuality = 85,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
    picks += 1;
    return CapturedImage(
      path: '/private/tmp/profile-preview.jpg',
      bytes: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
  }

  @override
  Future<CapturedImage?> retrieveLostImage() async => null;
}

Widget _app({
  required Future<DemoProfile?> Function(DemoProfile) onSave,
  VoidCallback? onDelete,
  VoidCallback? onLogout,
  ImageCaptureService? imageCapture,
  EmailConnectionService? connectionService,
  EmailDeliveryRepository? deliveryRepository,
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
  home: AppLanguageScope(
    locale: const Locale('es'),
    onLocaleChanged: (_) {},
    child: ProfileScreen(
      profile: const DemoProfile(name: 'Seller Name', company: 'Foloo'),
      accountEmail: 'account@example.test',
      ownerSub: 'owner-a',
      onSave: onSave,
      onLogout: onLogout ?? () {},
      onDeleteAccount: onDelete ?? () {},
      accountDeletionEnabled: true,
      connectionService:
          connectionService ??
          EmailConnectionService(_ConnectionApi(), _Session()),
      deliveryRepository: deliveryRepository,
      imageCaptureService: imageCapture,
    ),
  ),
);

void main() {
  testWidgets(
    'AUT-05 edits real profile fields and previews a selected photo',
    (tester) async {
      DemoProfile? saved;
      final capture = _ImageCapture();
      await tester.pumpWidget(
        _app(
          imageCapture: capture,
          onSave: (profile) async {
            saved = profile;
            return profile;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('account@example.test'), findsOneWidget);
      expect(find.text('se***@example.test'), findsOneWidget);
      expect(find.text('Conectado'), findsOneWidget);
      expect(
        find.byKey(const Key('profileChangeEmailAccount')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('profileDisconnectEmailAccount')),
        findsOneWidget,
      );
      final accountField = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('profileAccountEmailField')),
          matching: find.byType(EditableText),
        ),
      );
      expect(accountField.readOnly, isTrue);

      await tester.enterText(
        find.byKey(const Key('profileEditNameField')),
        'Updated Seller',
      );
      await tester.tap(find.byKey(const Key('profilePhotoButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profileGalleryOption')));
      await tester.pumpAndSettle();
      expect(capture.picks, 1);

      await tester.tap(find.byKey(const Key('profileSaveButton')));
      await tester.pumpAndSettle();
      expect(saved?.name, 'Updated Seller');
      expect(saved?.photoLocalPath, '/private/tmp/profile-preview.jpg');
    },
  );

  testWidgets('AUT-05 back navigation protects unsaved edits', (tester) async {
    await tester.pumpWidget(_app(onSave: (profile) async => profile));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profileEditCompanyField')),
      'Changed',
    );
    await tester.tap(find.byKey(const Key('profileBackButton')));
    await tester.pumpAndSettle();
    expect(find.text('Tienes cambios sin guardar'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profileKeepEditingButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profileEditScreen')), findsOneWidget);
  });

  testWidgets('AUT-18 profile delegates to the existing STORE-02D flow', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      _app(onSave: (profile) async => profile, onDelete: () => opened = true),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('profileDeleteAccountButton'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    expect(opened, isTrue);
  });

  testWidgets('AUT-07 logout remains available from My profile', (
    tester,
  ) async {
    var loggedOut = false;
    await tester.pumpWidget(
      _app(
        onSave: (profile) async => profile,
        onLogout: () => loggedOut = true,
      ),
    );
    await tester.pumpAndSettle();
    final logout = find.byKey(const Key('profileLogoutButton'));
    await tester.ensureVisible(logout);
    await tester.tap(logout);
    expect(loggedOut, isTrue);
  });

  testWidgets('SAL-04 distinguishes unconfigured and disconnected senders', (
    tester,
  ) async {
    final api = _ConnectionApi(connection: null);
    final service = EmailConnectionService(
      api,
      _Session(),
      launcher: (_) async => false,
    );
    await tester.pumpWidget(
      _app(onSave: (profile) async => profile, connectionService: service),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sin correo configurado'), findsOneWidget);
    expect(find.byKey(const Key('profileConnectEmailAccount')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    final persistence = LocalPersistence.inMemory();
    await persistence.initialize();
    addTearDown(persistence.close);
    await persistence.emailDelivery.saveConnection(
      owner: 'owner-a',
      connectionId: 'sender-a',
      provider: 'google',
      senderAddress: 'long-address-for-layout@example.test',
      status: 'disconnected',
    );
    await tester.pumpWidget(
      _app(
        onSave: (profile) async => profile,
        connectionService: service,
        deliveryRepository: persistence.emailDelivery,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cuenta desconectada'), findsOneWidget);
    expect(find.byKey(const Key('profileConnectEmailAccount')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SAL-04 connected sender disconnects only after confirmation', (
    tester,
  ) async {
    final persistence = LocalPersistence.inMemory();
    await persistence.initialize();
    addTearDown(persistence.close);
    final api = _ConnectionApi();
    final service = EmailConnectionService(
      api,
      _Session(),
      launcher: (_) async => false,
    );
    await tester.pumpWidget(
      _app(
        onSave: (profile) async => profile,
        connectionService: service,
        deliveryRepository: persistence.emailDelivery,
      ),
    );
    await tester.pumpAndSettle();
    final disconnect = find.byKey(const Key('profileDisconnectEmailAccount'));
    await tester.ensureVisible(disconnect);
    await tester.tap(disconnect);
    await tester.pumpAndSettle();
    expect(
      api.requests.where((request) => request.method == 'DELETE'),
      isEmpty,
    );
    await tester.tap(find.byKey(const Key('profileConfirmDisconnect')));
    await tester.pumpAndSettle();
    expect(
      api.requests.where((request) => request.method == 'DELETE'),
      hasLength(1),
    );
    expect(find.text('Cuenta desconectada'), findsOneWidget);
  });

  testWidgets(
    'SAL-04 cancelled OAuth and failed verification never show connected',
    (tester) async {
      final persistence = LocalPersistence.inMemory();
      await persistence.initialize();
      addTearDown(persistence.close);
      final api = _ConnectionApi(connection: null);
      final service = EmailConnectionService(
        api,
        _Session(),
        launcher: (_) async => false,
      );
      await tester.pumpWidget(
        _app(
          onSave: (profile) async => profile,
          connectionService: service,
          deliveryRepository: persistence.emailDelivery,
        ),
      );
      await tester.pumpAndSettle();

      final connect = find.byKey(const Key('profileConnectEmailAccount'));
      await tester.ensureVisible(connect);
      await tester.tap(connect);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profileConnectGoogle')));
      await tester.pumpAndSettle();
      expect(find.text('Sin correo configurado'), findsOneWidget);

      await persistence.emailDelivery.saveConnection(
        owner: 'owner-a',
        connectionId: 'sender-a',
        provider: 'google',
        senderAddress: 'cached@example.test',
        status: 'connected',
      );
      api.fail = true;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _app(
          onSave: (profile) async => profile,
          connectionService: service,
          deliveryRepository: persistence.emailDelivery,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Conectado'), findsNothing);
      expect(find.text('Cuenta desconectada'), findsOneWidget);
      expect(
        find.textContaining('No se pudo comprobar la cuenta'),
        findsOneWidget,
      );
    },
  );

  testWidgets('SAL-04 long connected address does not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _ConnectionApi(
      connection: const {
        'id': 'sender-a',
        'provider': 'microsoft',
        'senderAddress': 'very-long-follow-up-address-for-layout@example.test',
        'status': 'connected',
      },
    );
    await tester.pumpWidget(
      _app(
        onSave: (profile) async => profile,
        connectionService: EmailConnectionService(api, _Session()),
      ),
    );
    await tester.pumpAndSettle();

    final address = tester.widget<Text>(
      find.byKey(const Key('profileFollowUpEmailAddress')),
    );
    expect(address.maxLines, 1);
    expect(address.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });
}
