/// Owns the platform camera-permission lifecycle for every Foloo capture flow.
///
/// It separates native permission state from UI and records a Settings round
/// trip so screens can revalidate without reopening the camera automatically.
library;

import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

enum CameraAccessState { granted, denied, permanentlyDenied, restricted }

abstract interface class CameraPermissionGateway {
  Future<CameraAccessState> check();
  Future<CameraAccessState> request();
  Future<bool> openSettings();
}

/// Production adapter for the single CAMERA permission used by OCR-10.
class DeviceCameraPermissionGateway implements CameraPermissionGateway {
  bool _requestedInProcess = false;

  CameraAccessState _map(
    PermissionStatus status, {
    required bool afterRequest,
  }) {
    if (status.isGranted || status.isLimited) return CameraAccessState.granted;
    if (status.isPermanentlyDenied) return CameraAccessState.permanentlyDenied;
    if (status.isRestricted) return CameraAccessState.restricted;
    if (Platform.isIOS && afterRequest && status.isDenied) {
      return CameraAccessState.permanentlyDenied;
    }
    return CameraAccessState.denied;
  }

  @override
  Future<CameraAccessState> check() async =>
      _map(await Permission.camera.status, afterRequest: _requestedInProcess);

  @override
  Future<CameraAccessState> request() async {
    _requestedInProcess = true;
    return _map(await Permission.camera.request(), afterRequest: true);
  }

  @override
  Future<bool> openSettings() => openAppSettings();
}

/// Reusable permission coordinator shared by camera surfaces and widget tests.
class CameraAccessCoordinator {
  CameraAccessCoordinator([CameraPermissionGateway? gateway])
    : _gateway = gateway ?? DeviceCameraPermissionGateway();

  final CameraPermissionGateway _gateway;
  bool _waitingForSettings = false;

  Future<CameraAccessState> check() => _gateway.check();
  Future<CameraAccessState> request() => _gateway.request();

  Future<bool> openSettings() async {
    final opened = await _gateway.openSettings();
    _waitingForSettings = opened;
    return opened;
  }

  /// Revalidates only after this flow opened Settings; never launches camera.
  Future<CameraAccessState?> revalidateAfterSettings() async {
    if (!_waitingForSettings) return null;
    _waitingForSettings = false;
    return _gateway.check();
  }
}
