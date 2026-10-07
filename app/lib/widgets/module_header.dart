/// Shared header for Foloo's primary modules.
///
/// Keeps module switching on the existing right-side Drawer without adding
/// Navigator routes or duplicating menu contents (NAV-01).
library;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/foloo_theme.dart';

/// Displays a left-aligned module title and the global Drawer action.
class ModuleHeader extends StatelessWidget {
  const ModuleHeader({
    required this.title,
    required this.subtitle,
    required this.onMenuPressed,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback onMenuPressed;

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
              const SizedBox(width: 12),
              DrawerMenuButton(
                key: const Key('hamburgerMenuButton'),
                onPressed: onMenuPressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Accessible trigger shared by module and pre-capture headers.
class DrawerMenuButton extends StatelessWidget {
  const DrawerMenuButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    return IconButton.outlined(
      tooltip: context.l10n.openMenu,
      onPressed: onPressed,
      icon: const Icon(Icons.menu_rounded),
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: palette.ink,
        side: BorderSide(color: palette.ink.withValues(alpha: .5)),
      ),
    );
  }
}
