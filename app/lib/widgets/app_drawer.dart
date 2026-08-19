import 'package:flutter/material.dart';

import '../models/app_destination.dart';
import '../models/session_lead.dart';
import '../theme/brand_theme.dart';
import '../theme/foloo_theme.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    required this.activeDestination,
    required this.recordsCount,
    required this.darkMode,
    required this.onDestinationSelected,
    required this.onAppearanceChanged,
    required this.onLogout,
    super.key,
  });

  final AppDestination activeDestination;
  final int recordsCount;
  final bool darkMode;
  final ValueChanged<AppDestination> onDestinationSelected;
  final ValueChanged<bool> onAppearanceChanged;
  final VoidCallback onLogout;

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
                    tooltip: 'Cerrar menú',
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
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: FolooColors.ink,
                    child: Text(
                      'YH',
                      style: TextStyle(
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
                          DemoEventData.capturePerson,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          DemoEventData.captureRole,
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
                      label: 'Home',
                      selected: activeDestination == AppDestination.home,
                      trailing: activeDestination == AppDestination.home
                          ? 'AQUÍ'
                          : null,
                      onTap: () => _afterClose(
                        context,
                        () => onDestinationSelected(AppDestination.home),
                      ),
                    ),
                    _DestinationTile(
                      key: const Key('drawerRecords'),
                      icon: Icons.people_outline,
                      label: 'Registros',
                      selected: activeDestination == AppDestination.records,
                      trailing: '$recordsCount',
                      onTap: () => _afterClose(
                        context,
                        () => onDestinationSelected(AppDestination.records),
                      ),
                    ),
                    _DestinationTile(
                      key: const Key('drawerEvent'),
                      icon: Icons.calendar_today_outlined,
                      label: 'Evento',
                      selected: activeDestination == AppDestination.event,
                      onTap: () => _afterClose(
                        context,
                        () => onDestinationSelected(AppDestination.event),
                      ),
                    ),
                    Divider(height: 20, color: ink.withValues(alpha: 0.45)),
                    Semantics(
                      toggled: darkMode,
                      label: 'Apariencia, modo oscuro',
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
                        title: const Text(
                          'Apariencia',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          darkMode ? 'MODO OSCURO' : 'MODO CLARO',
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
                label: const Text('Cerrar sesión'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  foregroundColor: FolooColors.error,
                  side: const BorderSide(color: FolooColors.error, width: 1.3),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 8, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${DemoEventData.eventCode} · EXPO ALIMENTARIA',
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
