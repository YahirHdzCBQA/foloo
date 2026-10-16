/// Presents Foloo's minimal camera-permission recovery UI.
///
/// Native permission prompts remain platform-owned; this helper only explains
/// blocked access and offers Settings without changing existing screen design.
library;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/camera_access_service.dart';
import '../services/image_capture_service.dart';

Future<bool> ensureCameraAccess(
  BuildContext context,
  CameraAccessCoordinator coordinator,
) async {
  var state = await coordinator.check();
  if (state == CameraAccessState.granted) return true;
  if (state == CameraAccessState.denied) {
    state = await coordinator.request();
    if (state == CameraAccessState.granted) return true;
  }
  if (!context.mounted) return false;
  if (state == CameraAccessState.denied) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.cameraPermissionDenied)),
    );
    return false;
  }
  final open = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const Key('cameraPermissionSettingsDialog'),
      title: Text(context.l10n.cameraPermissionTitle),
      content: Text(context.l10n.cameraPermissionDescription),
      actions: [
        TextButton(
          key: const Key('cameraPermissionNotNow'),
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(context.l10n.notNow),
        ),
        FilledButton(
          key: const Key('cameraPermissionOpenSettings'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(context.l10n.openSettings),
        ),
      ],
    ),
  );
  if (open == true) await coordinator.openSettings();
  return false;
}

String imageCaptureFailureMessage(BuildContext context, Object error) {
  if (error is! ImageCaptureFailure) return context.l10n.imageOpenError;
  return switch (error.kind) {
    ImageCaptureFailureKind.permissionDenied =>
      context.l10n.cameraPermissionDenied,
    ImageCaptureFailureKind.cameraUnavailable => context.l10n.cameraUnavailable,
    ImageCaptureFailureKind.fileUnavailable => context.l10n.imageOpenError,
    ImageCaptureFailureKind.platform => context.l10n.imageOpenError,
  };
}
