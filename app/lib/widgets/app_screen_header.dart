/// Standard top header for authenticated Foloo list screens.
///
/// Keeps title, optional context and the right-drawer trigger consistent.
library;

import 'package:flutter/material.dart';

import '../theme/brand_theme.dart';
import '../l10n/l10n.dart';

/// Displays a screen title, optional badge/subtitle and menu action.
class AppScreenHeader extends StatelessWidget {
  const AppScreenHeader({
    required this.title,
    required this.onMenuPressed,
    required this.onLogoPressed,
    this.subtitle,
    this.badge,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? badge;
  final VoidCallback onMenuPressed;
  final VoidCallback onLogoPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: context.l10n.drawerHome,
                    child: InkWell(
                      key: const Key('screenLogoButton'),
                      onTap: onLogoPressed,
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 64,
                        height: 44,
                        child: Image.asset(
                          FolooBrand.logoFor(theme.brightness),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton.outlined(
                    key: const Key('hamburgerMenuButton'),
                    tooltip: context.l10n.openMenu,
                    onPressed: onMenuPressed,
                    icon: const Icon(Icons.menu_rounded),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: ink,
                      side: BorderSide(color: ink.withValues(alpha: 0.5)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(title, style: theme.textTheme.headlineSmall),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: ink.withValues(alpha: 0.55)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge!,
                        style: TextStyle(
                          color: ink.withValues(alpha: 0.72),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: ink.withValues(alpha: 0.56),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
