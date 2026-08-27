/// Fixed capture header showing Foloo branding and four-step progress.
///
/// Progress reflects completion within one scrollable form; it does not turn
/// the capture experience into a wizard (CAP-05).
library;

import 'package:flutter/material.dart';

import '../theme/brand_theme.dart';
import '../theme/foloo_theme.dart';
import '../l10n/l10n.dart';

/// Derives and displays the active capture section from completion flags.
class ProgressHeader extends StatelessWidget {
  const ProgressHeader({
    required this.completed,
    required this.onMenuPressed,
    required this.onLogoPressed,
    super.key,
  });

  final List<bool> completed;
  final VoidCallback onMenuPressed;
  final VoidCallback onLogoPressed;

  int get _activeIndex {
    final firstIncomplete = completed.indexWhere((value) => !value);
    return firstIncomplete == -1 ? completed.length - 1 : firstIncomplete;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final surface = theme.colorScheme.surface;
    final active = _activeIndex;
    final labels = [
      context.l10n.progressCard,
      context.l10n.progressData,
      context.l10n.progressType,
      context.l10n.progressNote,
    ];
    return Material(
      color: surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: context.l10n.drawerHome,
                    child: InkWell(
                      key: const Key('captureLogoButton'),
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
                  Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: FolooColors.line),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          size: 15,
                          color: ink.withValues(alpha: 0.65),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          context.l10n.offline,
                          style: TextStyle(
                            color: ink.withValues(alpha: 0.72),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.outlined(
                    key: const Key('hamburgerMenuButton'),
                    tooltip: context.l10n.openMenu,
                    onPressed: onMenuPressed,
                    icon: const Icon(Icons.menu_rounded),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: ink,
                      side: BorderSide(color: ink.withValues(alpha: 0.55)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: List.generate(labels.length, (index) {
                  final color = index == active
                      ? FolooColors.lime
                      : index < active
                      ? ink
                      : FolooColors.gray.withValues(alpha: 0.65);
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index == labels.length - 1 ? 0 : 6,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            labels[index].toUpperCase(),
                            maxLines: 1,
                            style: TextStyle(
                              color: index == active
                                  ? ink
                                  : ink.withValues(
                                      alpha: index < active ? 0.82 : 0.4,
                                    ),
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.55,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: ink.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );
  }
}
