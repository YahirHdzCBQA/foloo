/// Right-side Foloo navigation drawer shared across authenticated screens.
///
/// Centralizes destination visibility, profile context, appearance/language
/// controls and protected logout behavior.
library;

import 'package:flutter/material.dart';

import '../models/app_destination.dart';
import '../models/app_event.dart';
import '../models/app_plan.dart';
import '../models/session_lead.dart';
import '../theme/brand_theme.dart';
import '../theme/foloo_theme.dart';
import '../l10n/l10n.dart';
import 'language_selector.dart';

/// Renders capability-aware navigation and keeps Pro destinations out of Basic.
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    required this.activeDestination,
    required this.recordsCount,
    required this.darkMode,
    required this.onDestinationSelected,
    required this.onAppearanceChanged,
    required this.onLogout,
    required this.plan,
    this.contentCount = 0,
    this.profile = DemoBasicData.profile,
    super.key,
  });

  final AppDestination activeDestination;
  final int recordsCount;
  final bool darkMode;
  final ValueChanged<AppDestination> onDestinationSelected;
  final ValueChanged<bool> onAppearanceChanged;
  final VoidCallback onLogout;
  final DemoProfile profile;
  final AppPlan plan;
  final int contentCount;

  String get _initials => profile.name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  /// Closes the drawer before dispatching navigation to avoid stacked surfaces.
  void _afterClose(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => action());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    return Drawer(
      key: const Key('appDrawer'),
      width: MediaQuery.sizeOf(context).width.clamp(300, 360).toDouble(),
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 18, 14),
              child: Row(
                children: [
                  Image.asset(
                    FolooBrand.logoFor(theme.brightness),
                    width: 86,
                    fit: BoxFit.contain,
                  ),
                  const Spacer(),
                  IconButton.outlined(
                    key: const Key('closeMenuButton'),
                    tooltip: context.l10n.drawerClose,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: ink,
                      side: BorderSide(color: ink.withValues(alpha: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: ink,
                    child: Text(
                      _initials,
                      style: const TextStyle(
                        color: FolooColors.lime,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${profile.company.toUpperCase()} · ${context.l10n.drawerSales}',
                          style: TextStyle(
                            color: ink.withValues(alpha: 0.55),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: ink.withValues(alpha: 0.35)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  children: [
                    _DestinationTile(
                      key: const Key('drawerHome'),
                      icon: Icons.person_add_alt_1_outlined,
                      label: context.l10n.drawerHome,
                      selected: activeDestination == AppDestination.home,
                      trailing: activeDestination == AppDestination.home
                          ? context.l10n.drawerHere
                          : null,
                      onTap: () => _afterClose(
                        context,
                        () => onDestinationSelected(AppDestination.home),
                      ),
                    ),
                    if (plan.isPro) ...[
                      _DestinationTile(
                        key: const Key('drawerContent'),
                        icon: Icons.folder_copy_outlined,
                        label: context.l10n.drawerContent,
                        trailing: '$contentCount',
                        selected: activeDestination == AppDestination.content,
                        onTap: () => _afterClose(
                          context,
                          () => onDestinationSelected(AppDestination.content),
                        ),
                      ),
                      _DestinationTile(
                        key: const Key('drawerEmail'),
                        icon: Icons.mail_outline,
                        label: context.l10n.drawerEmail,
                        selected: activeDestination == AppDestination.email,
                        onTap: () => _afterClose(
                          context,
                          () => onDestinationSelected(AppDestination.email),
                        ),
                      ),
                    ],
                    _DestinationTile(
                      key: const Key('drawerRecords'),
                      icon: Icons.people_outline,
                      label: context.l10n.drawerRecords,
                      selected: activeDestination == AppDestination.records,
                      trailing: '$recordsCount',
                      onTap: () => _afterClose(
                        context,
                        () => onDestinationSelected(AppDestination.records),
                      ),
                    ),
                    _DestinationTile(
                      key: const Key('drawerEvents'),
                      icon: Icons.calendar_today_outlined,
                      label: context.l10n.drawerEvents,
                      selected: activeDestination == AppDestination.events,
                      onTap: () => _afterClose(
                        context,
                        () => onDestinationSelected(AppDestination.events),
                      ),
                    ),
                    Divider(height: 20, color: ink.withValues(alpha: 0.45)),
                    Semantics(
                      toggled: darkMode,
                      label: context.l10n.drawerAppearanceSemantics,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        minTileHeight: 64,
                        leading: Icon(
                          darkMode
                              ? Icons.dark_mode_outlined
                              : Icons.brightness_2_outlined,
                        ),
                        title: Text(
                          context.l10n.drawerAppearance,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          darkMode
                              ? context.l10n.drawerDarkMode
                              : context.l10n.drawerLightMode,
                          style: TextStyle(
                            color: ink.withValues(alpha: 0.55),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        trailing: Switch(
                          key: const Key('appearanceSwitch'),
                          value: darkMode,
                          activeTrackColor: FolooColors.lime,
                          onChanged: onAppearanceChanged,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
                      child: Row(
                        children: [
                          const Icon(Icons.language_outlined),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              context.l10n.language,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const LanguageSelector(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: ink.withValues(alpha: 0.35)),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: OutlinedButton.icon(
                key: const Key('logoutButton'),
                onPressed: () => _afterClose(context, onLogout),
                icon: const Icon(Icons.logout),
                label: Text(context.l10n.drawerLogout),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  foregroundColor: FolooPalette.of(context).error,
                  side: BorderSide(
                    color: FolooPalette.of(context).error,
                    width: 1.3,
                  ),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(22, 8, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${plan.label.toUpperCase()} · ${DemoEventData.eventCode}',
                    style: TextStyle(
                      color: FolooColors.gray,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'FOLOO v1.0.0',
                    style: TextStyle(
                      color: FolooColors.gray,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? FolooColors.lime.withValues(alpha: 0.34)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          onTap: onTap,
          minTileHeight: 58,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: Icon(icon),
          title: Text(
            label,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          trailing: trailing == null
              ? null
              : Text(
                  trailing!,
                  style: TextStyle(
                    color: ink.withValues(alpha: 0.55),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
        ),
      ),
    );
  }
}
