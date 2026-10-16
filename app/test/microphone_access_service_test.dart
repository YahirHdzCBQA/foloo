import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/l10n/app_localizations.dart';
import 'package:foloo/services/microphone_access_service.dart';
import 'package:foloo/widgets/microphone_access_dialog.dart';

class _FakeMicrophoneGateway implements MicrophonePermissionGateway {
  _FakeMicrophoneGateway(this.state, {this.requestedState});

  MicrophoneAccessState state;
  MicrophoneAccessState? requestedState;
  int requests = 0;
  int settingsOpens = 0;

  @override
  Future<MicrophoneAccessState> check() async => state;

  @override
  Future<MicrophoneAccessState> request() async {
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

Widget _app(MicrophoneAccessCoordinator coordinator) => MaterialApp(
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
        key: const Key('requestMicrophone'),
        onPressed: () => ensureMicrophoneAccess(context, coordinator),
        child: const Text('microphone'),
      ),
    ),
  ),
);

void main() {
  testWidgets('VOZ-06 requests microphone only after the user action', (
    tester,
  ) async {
    final gateway = _FakeMicrophoneGateway(
      MicrophoneAccessState.denied,
      requestedState: MicrophoneAccessState.granted,
    );
    await tester.pumpWidget(_app(MicrophoneAccessCoordinator(gateway)));

    expect(gateway.requests, 0);
    await tester.tap(find.byKey(const Key('requestMicrophone')));
    await tester.pumpAndSettle();

    expect(gateway.requests, 1);
    expect(
      find.byKey(const Key('microphonePermissionSettingsDialog')),
      findsNothing,
    );
  });

  testWidgets('VOZ-06 blocked microphone offers Settings and written note', (
    tester,
  ) async {
    final gateway = _FakeMicrophoneGateway(
      MicrophoneAccessState.permanentlyDenied,
    );
    final coordinator = MicrophoneAccessCoordinator(gateway);
    await tester.pumpWidget(_app(coordinator));

    await tester.tap(find.byKey(const Key('requestMicrophone')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('microphonePermissionSettingsDialog')),
      findsOneWidget,
    );
    expect(find.text('Continuar con nota escrita'), findsOneWidget);

    await tester.tap(find.byKey(const Key('microphonePermissionOpenSettings')));
    await tester.pumpAndSettle();
    expect(gateway.settingsOpens, 1);

    gateway.state = MicrophoneAccessState.granted;
    expect(
      await coordinator.revalidateAfterSettings(),
      MicrophoneAccessState.granted,
    );
    expect(await coordinator.revalidateAfterSettings(), isNull);
  });
}
