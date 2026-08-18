import 'package:flutter/material.dart';

import 'screens/lead_capture_screen.dart';
import 'theme/foloo_theme.dart';

class FolooApp extends StatelessWidget {
  const FolooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foloo',
      debugShowCheckedModeBanner: false,
      theme: FolooTheme.light,
      home: const LeadCaptureScreen(),
    );
  }
}
