import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/l10n/app_localizations.dart';
import 'package:foloo/services/camera_access_service.dart';
import 'package:foloo/widgets/camera_access_dialog.dart';

class _FakePermissionGateway implements CameraPermissionGateway {
  _FakePermissionGateway(this.state, {this.requestedState});

  CameraAccessState state;
  CameraAccessState? requestedState;
  int checks = 0;
  int requests = 0;
  int settingsOpens = 0;

  @override
  Future<CameraAccessState> check() async {
    checks++;
    return state;
  }

  @override
  Future<CameraAccessState> request() async {
    requests++;
    state = requestedState ?? state;
    return state;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpens++;
    return true;
  }
}

Widget _app(CameraAccessCoordinator coordinator) => MaterialApp(
  locale: const Locale('es'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) => Scaffold(
      body: FilledButton(
        key: const Key('requestCamera'),
        onPressed: () => ensureCameraAccess(context, coordinator),
        child: const Text('camera'),
      ),
    ),
  ),
);

void main() {
  testWidgets('OCR-10 requests a requestable permission and continues', (
    tester,
  ) async {
    final gateway = _FakePermissionGateway(
      CameraAccessState.denied,
      requestedState: CameraAccessState.granted,
    );
    await tester.pumpWidget(_app(CameraAccessCoordinator(gateway)));
    await tester.tap(find.byKey(const Key('requestCamera')));
    await tester.pumpAndSettle();
    expect(gateway.requests, 1);
    expect(
      find.byKey(const Key('cameraPermissionSettingsDialog')),
      findsNothing,
    );
  });

  for (final state in [
    CameraAccessState.permanentlyDenied,
    CameraAccessState.restricted,
  ]) {
    testWidgets('OCR-10 $state offers Settings and revalidates', (
      tester,
    ) async {
      final gateway = _FakePermissionGateway(state);
      final coordinator = CameraAccessCoordinator(gateway);
      await tester.pumpWidget(_app(coordinator));
      await tester.tap(find.byKey(const Key('requestCamera')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('cameraPermissionSettingsDialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('cameraPermissionOpenSettings')));
      await tester.pumpAndSettle();
      expect(gateway.settingsOpens, 1);
      gateway.state = CameraAccessState.granted;
      expect(
        await coordinator.revalidateAfterSettings(),
        CameraAccessState.granted,
      );
      expect(await coordinator.revalidateAfterSettings(), isNull);
    });
  }

  testWidgets('OCR-10 temporary denial remains retryable', (tester) async {
    final gateway = _FakePermissionGateway(CameraAccessState.denied);
    await tester.pumpWidget(_app(CameraAccessCoordinator(gateway)));
    await tester.tap(find.byKey(const Key('requestCamera')));
    await tester.pumpAndSettle();
    expect(gateway.requests, 1);
    expect(
      find.byKey(const Key('cameraPermissionSettingsDialog')),
      findsNothing,
    );
    expect(find.textContaining('denegó'), findsOneWidget);
  });
}
