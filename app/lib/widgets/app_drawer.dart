import 'package:flutter/material.dart';

import '../theme/brand_theme.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({required this.onLogout, super.key});

  final VoidCallback onLogout;

  void _logout(BuildContext context) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => onLogout());
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      key: const Key('appDrawer'),
      width: MediaQuery.sizeOf(context).width.clamp(280, 360).toDouble(),
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 18, 14),
              child: Row(
                children: [
                  Image.asset(FolooBrand.logo, width: 86, fit: BoxFit.contain),
                  const Spacer(),
                  IconButton.outlined(
                    key: const Key('closeMenuButton'),
                    tooltip: 'Cerrar menú',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: FolooBrand.ink,
                      side: const BorderSide(color: FolooBrand.gray),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 10, 22, 22),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: FolooBrand.ink,
                    child: Text(
                      'YH',
                      style: TextStyle(
                        color: FolooBrand.lime,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yahir Hernández',
                          style: TextStyle(
                            color: FolooBrand.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'PERFIL VISUAL · DEMO LOCAL',
                          style: TextStyle(
                            color: FolooBrand.gray,
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
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                constraints: const BoxConstraints(minHeight: 64),
                decoration: BoxDecoration(
                  color: FolooBrand.lime.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const ListTile(
                  leading: Icon(Icons.person_add_alt_1_outlined),
                  title: Text(
                    'Captura de leads',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  trailing: Text(
                    'AQUÍ',
                    style: TextStyle(
                      color: FolooBrand.gray,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: OutlinedButton.icon(
                key: const Key('logoutButton'),
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  foregroundColor: FolooBrand.danger,
                  side: const BorderSide(color: FolooBrand.danger, width: 1.3),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 8, 22, 18),
              child: Text(
                'FOLOO v1.0.0 · SESIÓN LOCAL',
                style: TextStyle(
                  color: FolooBrand.gray,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
