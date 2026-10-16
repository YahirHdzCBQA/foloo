/// Presents recovery UI for an optional voice-note permission failure.
///
/// The native prompt is requested only after the record action. Permanently
/// blocked access offers Settings while preserving the written-note fallback.
library;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/microphone_access_service.dart';

Future<bool> ensureMicrophoneAccess(
  BuildContext context,
  MicrophoneAccessCoordinator coordinator,
) async {
  var state = await coordinator.check();
  if (state == MicrophoneAccessState.granted) return true;
  if (state == MicrophoneAccessState.denied) {
    state = await coordinator.request();
    if (state == MicrophoneAccessState.granted) return true;
  }
  if (!context.mounted) return false;
  if (state == MicrophoneAccessState.denied) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.microphoneDenied)));
    return false;
  }
  final open = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const Key('microphonePermissionSettingsDialog'),
      title: Text(context.l10n.microphonePermissionTitle),
      content: Text(context.l10n.microphonePermissionDescription),
      actions: [
        TextButton(
          key: const Key('microphonePermissionWrittenNote'),
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(context.l10n.continueWithWrittenNote),
        ),
        FilledButton(
          key: const Key('microphonePermissionOpenSettings'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(context.l10n.openSettings),
        ),
      ],
    ),
  );
  if (open == true) await coordinator.openSettings();
  return false;
}
