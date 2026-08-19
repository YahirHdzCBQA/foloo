import 'package:flutter/material.dart';

import 'models/app_destination.dart';
import 'models/lead_draft.dart';
import 'models/session_lead.dart';
import 'screens/event_screen.dart';
import 'screens/lead_capture_screen.dart';
import 'screens/login_screen.dart';
import 'screens/records_screen.dart';
import 'theme/foloo_theme.dart';

class FolooApp extends StatefulWidget {
  const FolooApp({super.key});

  @override
  State<FolooApp> createState() => _FolooAppState();
}

class _FolooAppState extends State<FolooApp> {
  bool _demoAccessGranted = false;
  ThemeMode _themeMode = ThemeMode.light;
  AppDestination _destination = AppDestination.home;
  final List<SessionLead> _sessionLeads = [];

  SessionLead _saveLead(LeadDraft lead) {
    final record = DemoEventData.createSessionLead(
      lead: lead,
      sequence: _sessionLeads.length + 1,
    );
    setState(() => _sessionLeads.insert(0, record));
    return record;
  }

  void _logout() {
    setState(() {
      _demoAccessGranted = false;
      _destination = AppDestination.home;
      _sessionLeads.clear();
    });
  }

  void _setAppearance(bool darkMode) {
    setState(() => _themeMode = darkMode ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foloo',
      debugShowCheckedModeBanner: false,
      theme: FolooTheme.light,
      darkTheme: FolooTheme.dark,
      themeMode: _themeMode,
      home: _demoAccessGranted ? _buildShell() : _buildLogin(),
    );
  }

  Widget _buildLogin() {
    return LoginScreen(
      key: const ValueKey('loginScreen'),
      onAuthenticated: () => setState(() => _demoAccessGranted = true),
    );
  }

  Widget _buildShell() {
    final darkMode = _themeMode == ThemeMode.dark;
    return IndexedStack(
      index: _destination.index,
      children: [
        LeadCaptureScreen(
          key: const ValueKey('leadCaptureScreen'),
          recordsCount: _sessionLeads.length,
          darkMode: darkMode,
          onLeadSaved: _saveLead,
          onDestinationSelected: (value) =>
              setState(() => _destination = value),
          onAppearanceChanged: _setAppearance,
          onLogout: _logout,
        ),
        RecordsScreen(
          key: const ValueKey('recordsScreen'),
          records: List.unmodifiable(_sessionLeads),
          darkMode: darkMode,
          onDestinationSelected: (value) =>
              setState(() => _destination = value),
          onAppearanceChanged: _setAppearance,
          onLogout: _logout,
        ),
        EventScreen(
          key: const ValueKey('eventScreen'),
          recordsCount: _sessionLeads.length,
          darkMode: darkMode,
          onDestinationSelected: (value) =>
              setState(() => _destination = value),
          onAppearanceChanged: _setAppearance,
          onLogout: _logout,
          onBackToCapture: () =>
              setState(() => _destination = AppDestination.home),
        ),
      ],
    );
  }
}
