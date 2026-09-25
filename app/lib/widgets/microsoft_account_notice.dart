/// Presents the Microsoft sender-account limitation before OAuth starts.
///
/// This callout is informational only and does not alter provider availability
/// or the sender-connection flow.
library;

import 'package:flutter/material.dart';

import '../theme/foloo_theme.dart';

/// A discreet, theme-aware notice for Microsoft personal-account support.
class MicrosoftAccountNotice extends StatelessWidget {
  const MicrosoftAccountNotice({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);

    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(FolooSpace.sm),
        decoration: BoxDecoration(
          color: palette.sunken,
          borderRadius: BorderRadius.circular(FolooRadii.sm),
          border: Border.all(color: palette.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18, color: palette.inkSecondary),
            const SizedBox(width: FolooSpace.xs),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: palette.inkSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
