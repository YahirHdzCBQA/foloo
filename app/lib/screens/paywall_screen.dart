/// Informational FL-020 boundary shown only when new Lead creation is blocked.
/// Existing Foloo destinations remain reachable through the shared drawer.
library;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/app_destination.dart';
import '../models/app_event.dart';
import '../theme/foloo_theme.dart';
import '../widgets/app_drawer.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({
    required this.profile,
    required this.recordsCount,
    required this.contentCount,
    required this.darkMode,
    required this.onDestinationSelected,
    required this.onAppearanceChanged,
    required this.onLogout,
    super.key,
  });

  final DemoProfile profile;
  final int recordsCount;
  final int contentCount;
  final bool darkMode;
  final ValueChanged<AppDestination> onDestinationSelected;
  final ValueChanged<bool> onAppearanceChanged;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    final palette = FolooPalette.of(context);
    return Scaffold(
      key: scaffoldKey,
      endDrawer: AppDrawer(
        profile: profile,
        recordsCount: recordsCount,
        contentCount: contentCount,
        activeDestination: AppDestination.home,
        darkMode: darkMode,
        onDestinationSelected: onDestinationSelected,
        onAppearanceChanged: onAppearanceChanged,
        onLogout: onLogout,
      ),
      appBar: AppBar(
        title: const Text('foloo'),
        actions: [
          IconButton(
            key: const Key('paywallMenuButton'),
            onPressed: () => scaffoldKey.currentState?.openEndDrawer(),
            icon: const Icon(Icons.menu),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: FolooColors.lime,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline, size: 34),
                ),
                const SizedBox(height: 24),
                Text(
                  context.l10n.paywallTitle,
                  key: const Key('paywallTitle'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                Text(
                  context.l10n.paywallBody,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: palette.inkSecondary),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('paywallViewRecords'),
                    onPressed: () =>
                        onDestinationSelected(AppDestination.records),
                    child: Text(context.l10n.paywallViewRecords),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.paywallFutureAction,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.inkSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
