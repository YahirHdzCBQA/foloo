import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/app.dart';
import 'package:foloo/services/connectivity_service.dart';

class _FakeConnectivityService implements ConnectivityService {
  _FakeConnectivityService(this.connected);

  bool connected;
  final controller = StreamController<bool>.broadcast();

  @override
  Stream<bool> get changes => controller.stream;

  @override
  Future<bool> isConnected() async => connected;

  void emit(bool value) {
    connected = value;
    controller.add(value);
  }
}

void main() {
  testWidgets(
    'SYN-05 connectivity indicator follows device transport changes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final connectivity = _FakeConnectivityService(false);
      addTearDown(connectivity.controller.close);
      await tester.pumpWidget(FolooApp(connectivityService: connectivity));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('loginEmailField')), 'qa');
      await tester.enterText(
        find.byKey(const Key('loginPasswordField')),
        'demo',
      );
      await tester.tap(find.byKey(const Key('loginButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profileContinueButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('originContinueButton')));
      await tester.pumpAndSettle();

      expect(find.text('SIN CONEXIÓN'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

      connectivity.emit(true);
      await tester.pumpAndSettle();
      expect(find.text('EN LÍNEA'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_rounded), findsOneWidget);

      connectivity.emit(false);
      await tester.pumpAndSettle();
      expect(find.text('SIN CONEXIÓN'), findsOneWidget);
    },
  );
}
