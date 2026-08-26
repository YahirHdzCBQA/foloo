/// Header for focused Pro modules that use a back action instead of the Drawer.
///
/// Used by Content and Email subflows to preserve a consistent hierarchy.
library;

import 'package:flutter/material.dart';

import '../theme/foloo_theme.dart';

/// Displays a module title, context subtitle and accessible back control.
class ModuleHeader extends StatelessWidget {
  const ModuleHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    return Material(
      color: palette.card,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
          child: Row(
            children: [
              IconButton.filled(
                key: const Key('moduleBackButton'),
                onPressed: onBack,
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  backgroundColor: FolooColors.lime,
                  foregroundColor: FolooColors.ink,
                ),
                icon: const Icon(Icons.arrow_back, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.45,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: palette.inkSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
