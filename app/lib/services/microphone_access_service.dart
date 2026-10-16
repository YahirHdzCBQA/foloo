/// Owns the microphone-permission lifecycle for optional Foloo voice notes.
///
/// Native prompts remain user-initiated. A Settings round trip is remembered so
/// Capture can revalidate access without automatically starting a recording.
library;

import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

enum MicrophoneAccessState { granted, denied, permanentlyDenied, restricted }

abstract interface class MicrophonePermissionGateway {
  Future<MicrophoneAccessState> check();
  Future<MicrophoneAccessState> request();
  Future<bool> openSettings();
}

/// Production adapter for the microphone permission required by VOZ-06.
class DeviceMicrophonePermissionGateway implements MicrophonePermissionGateway {
  bool _requestedInProcess = false;

  MicrophoneAccessState _map(
    PermissionStatus status, {
    required bool afterRequest,
  }) {
    if (status.isGranted || status.isLimited) {
      return MicrophoneAccessState.granted;
    }
    if (status.isPermanentlyDenied) {
      return MicrophoneAccessState.permanentlyDenied;
    }
    if (status.isRestricted) return MicrophoneAccessState.restricted;
    if (Platform.isIOS && afterRequest && status.isDenied) {
      return MicrophoneAccessState.permanentlyDenied;
    }
    return MicrophoneAccessState.denied;
  }

  @override
  Future<MicrophoneAccessState> check() async => _map(
    await Permission.microphone.status,
    afterRequest: _requestedInProcess,
  );

  @override
  Future<MicrophoneAccessState> request() async {
    _requestedInProcess = true;
    return _map(await Permission.microphone.request(), afterRequest: true);
  }

  @override
  Future<bool> openSettings() => openAppSettings();
}

/// Coordinates request and Settings revalidation without recording side effects.
class MicrophoneAccessCoordinator {
  MicrophoneAccessCoordinator([MicrophonePermissionGateway? gateway])
    : _gateway = gateway ?? DeviceMicrophonePermissionGateway();

  final MicrophonePermissionGateway _gateway;
  bool _waitingForSettings = false;

  Future<MicrophoneAccessState> check() => _gateway.check();
  Future<MicrophoneAccessState> request() => _gateway.request();

  Future<bool> openSettings() async {
    final opened = await _gateway.openSettings();
    _waitingForSettings = opened;
    return opened;
  }

  /// Revalidates only after this flow opened Settings; never starts recording.
  Future<MicrophoneAccessState?> revalidateAfterSettings() async {
    if (!_waitingForSettings) return null;
    _waitingForSettings = false;
    return _gateway.check();
  }
}
