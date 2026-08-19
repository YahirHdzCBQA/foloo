import 'package:flutter/material.dart';

import 'screens/lead_capture_screen.dart';
import 'screens/login_screen.dart';
import 'theme/foloo_theme.dart';

class FolooApp extends StatefulWidget {
  const FolooApp({super.key});

  @override
  State<FolooApp> createState() => _FolooAppState();
}

class _FolooAppState extends State<FolooApp> {
  bool _demoAccessGranted = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foloo',
      debugShowCheckedModeBanner: false,
      theme: FolooTheme.light,
      home: _demoAccessGranted
          ? LeadCaptureScreen(
              key: const ValueKey('leadCaptureScreen'),
              onLogout: () => setState(() => _demoAccessGranted = false),
            )
          : LoginScreen(
              key: const ValueKey('loginScreen'),
              onAuthenticated: () => setState(() => _demoAccessGranted = true),
            ),
    );
  }
}
