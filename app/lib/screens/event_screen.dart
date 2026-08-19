import 'package:flutter/material.dart';

import '../models/app_destination.dart';
import '../models/session_lead.dart';
import '../theme/foloo_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_screen_header.dart';

class EventScreen extends StatefulWidget {
  const EventScreen({
    required this.recordsCount,
    required this.darkMode,
    required this.onDestinationSelected,
    required this.onAppearanceChanged,
    required this.onLogout,
    required this.onBackToCapture,
    super.key,
  });

  final int recordsCount;
  final bool darkMode;
  final ValueChanged<AppDestination> onDestinationSelected;
  final ValueChanged<bool> onAppearanceChanged;
  final VoidCallback onLogout;
  final VoidCallback onBackToCapture;

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    // TODO(BACKEND): Load event/session information from backend.
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: AppDrawer(
        activeDestination: AppDestination.event,
        recordsCount: widget.recordsCount,
        darkMode: widget.darkMode,
        onDestinationSelected: widget.onDestinationSelected,
        onAppearanceChanged: widget.onAppearanceChanged,
        onLogout: widget.onLogout,
      ),
      body: Column(
        children: [
          AppScreenHeader(
            title: 'Evento',
            badge: '🔒 SOLO CONSULTA',
            onMenuPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          Divider(height: 1, color: ink.withValues(alpha: 0.45)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    children: [
                      Container(
                        key: const Key('eventInformationCard'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: ink.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                _LimeDot(),
                                SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    'EVENTO ACTIVO · ${DemoEventData.eventCode}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Divider(color: ink.withValues(alpha: 0.45)),
                            const SizedBox(height: 18),
                            const _EventLabel('NOMBRE DEL EVENTO'),
                            const SizedBox(height: 16),
                            const Text(
                              DemoEventData.eventName,
                              style: TextStyle(
                                fontSize: 25,
                                height: 1.02,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.7,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${DemoEventData.eventDate} · ${DemoEventData.location}',
                              style: TextStyle(
                                color: ink.withValues(alpha: 0.6),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.7,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Divider(color: ink.withValues(alpha: 0.45)),
                            const SizedBox(height: 20),
                            const _EventLabel('QUIÉN CAPTURA'),
                            const SizedBox(height: 14),
                            const Row(
                              children: [
                                CircleAvatar(
                                  radius: 25,
                                  backgroundColor: FolooColors.ink,
                                  child: Text(
                                    'YH',
                                    style: TextStyle(
                                      color: FolooColors.lime,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DemoEventData.capturePerson,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      SizedBox(height: 5),
                                      Text(
                                        DemoEventData.captureEmail,
                                        style: TextStyle(
                                          color: FolooColors.gray,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Divider(color: ink.withValues(alpha: 0.45)),
                            const SizedBox(height: 20),
                            const _EventLabel('CORREO DE ADMIN'),
                            const SizedBox(height: 14),
                            const Row(
                              children: [
                                Icon(Icons.mail_outline, size: 22),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    DemoEventData.adminEmail,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Recibe copia de cada lead que guardas.',
                              style: TextStyle(
                                color: ink.withValues(alpha: 0.58),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.55,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: ink.withValues(alpha: 0.48),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              color: ink.withValues(alpha: 0.55),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'El Admin configura estos datos antes de la expo. Si algo no coincide, avisa a tu coordinador; desde la app no se editan.',
                                style: TextStyle(
                                  color: ink.withValues(alpha: 0.65),
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: theme.colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: OutlinedButton.icon(
            key: const Key('backToCaptureButton'),
            onPressed: widget.onBackToCapture,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Volver a captura'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventLabel extends StatelessWidget {
  const _EventLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.56),
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _LimeDot extends StatelessWidget {
  const _LimeDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: FolooColors.lime,
        shape: BoxShape.circle,
        border: Border.fromBorderSide(BorderSide(color: FolooColors.ink)),
      ),
    );
  }
}
