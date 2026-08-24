import 'package:flutter/material.dart';

import 'models/app_destination.dart';
import 'models/app_event.dart';
import 'models/app_plan.dart';
import 'models/lead_draft.dart';
import 'models/pro_demo_data.dart';
import 'models/session_lead.dart';
import 'screens/event_screen.dart';
import 'screens/content_screen.dart';
import 'screens/email_screen.dart';
import 'screens/lead_capture_screen.dart';
import 'screens/login_screen.dart';
import 'screens/origin_selection_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/records_screen.dart';
import 'theme/foloo_theme.dart';

enum _AppStage { login, profile, origin, shell }

class FolooApp extends StatefulWidget {
  const FolooApp({super.key});

  @override
  State<FolooApp> createState() => _FolooAppState();
}

class _FolooAppState extends State<FolooApp> {
  _AppStage _stage = _AppStage.login;
  ThemeMode _themeMode = ThemeMode.light;
  AppDestination _destination = AppDestination.home;
  // Development/demo plan selector. Replace with account capabilities from backend when the capability contract is implemented.
  AppPlan _plan = AppPlan.basic;
  AppDestination _eventsReturnDestination = AppDestination.home;
  DemoProfile _profile = DemoBasicData.profile;
  bool _profileCompleted = false;
  late List<AppEvent> _events;
  late List<ContentFile> _contentFiles;
  OriginSelection? _origin;
  final List<SessionLead> _sessionLeads = [];

  @override
  void initState() {
    super.initState();
    _events = List.of(DemoBasicData.events);
    _contentFiles = List.of(DemoProData.files);
  }

  SessionLead _saveLead(LeadDraft lead) {
    final record = DemoEventData.createSessionLead(
      lead: lead,
      sequence: _sessionLeads.length + 1,
    );
    setState(() => _sessionLeads.insert(0, record));
    return record;
  }

  void _authenticate() {
    setState(
      () => _stage = _profileCompleted ? _AppStage.origin : _AppStage.profile,
    );
  }

  void _completeProfile(DemoProfile profile) {
    setState(() {
      _profile = profile;
      _profileCompleted = true;
      _stage = _AppStage.origin;
    });
  }

  void _selectOrigin(OriginSelection selection) {
    setState(() {
      _origin = selection;
      _destination = AppDestination.home;
      _stage = _AppStage.shell;
    });
  }

  void _selectDestination(AppDestination destination) {
    setState(() {
      if (destination == AppDestination.events) {
        _eventsReturnDestination = _destination == AppDestination.events
            ? AppDestination.home
            : _destination;
      }
      _destination = destination;
    });
  }

  void _backFromEvents() {
    setState(() => _destination = _eventsReturnDestination);
  }

  void _changeCaptureOrigin(LeadOriginKind kind, AppEvent? event) {
    setState(
      () => _origin = OriginSelection(
        kind: kind,
        event: event,
        place: kind == LeadOriginKind.direct ? _origin?.place : null,
      ),
    );
  }

  void _logout() {
    // Demo-only auth shell. AUT-08 requires local leads to survive logout, so
    // this in-memory prototype deliberately keeps the current session list.
    setState(() {
      _stage = _AppStage.login;
      _destination = AppDestination.home;
    });
  }

  void _setAppearance(bool darkMode) {
    setState(() => _themeMode = darkMode ? ThemeMode.dark : ThemeMode.light);
  }

  void _createEvent(AppEvent event) {
    setState(() {
      _events = [
        event.copyWith(active: true),
        ..._events.map((item) => item.copyWith(active: false)),
      ];
      _origin = OriginSelection(
        kind: LeadOriginKind.event,
        event: _events.first,
      );
    });
  }

  void _updateEvent(AppEvent event) {
    setState(() {
      _events = _events
          .map((item) => item.id == event.id ? event : item)
          .toList();
      if (_origin?.event?.id == event.id) {
        _origin = OriginSelection(kind: LeadOriginKind.event, event: event);
      }
    });
  }

  void _deleteEvent(AppEvent event) {
    setState(() {
      _events.removeWhere((item) => item.id == event.id);
      if (_origin?.event?.id == event.id) {
        final replacement = _events.isEmpty ? null : _events.first;
        _origin = replacement == null
            ? const OriginSelection(kind: LeadOriginKind.direct)
            : OriginSelection(kind: LeadOriginKind.event, event: replacement);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foloo · ${_profile.name}',
      debugShowCheckedModeBanner: false,
      theme: FolooTheme.light,
      darkTheme: FolooTheme.dark,
      themeMode: _themeMode,
      home: switch (_stage) {
        _AppStage.login => LoginScreen(
          key: const ValueKey('loginScreen'),
          onAuthenticated: _authenticate,
          selectedPlan: _plan,
          onPlanChanged: (plan) => setState(() => _plan = plan),
        ),
        _AppStage.profile => ProfileSetupScreen(
          key: const ValueKey('profileScreen'),
          onContinue: _completeProfile,
        ),
        _AppStage.origin => OriginSelectionScreen(
          key: const ValueKey('originScreen'),
          events: List.unmodifiable(_events),
          onContinue: _selectOrigin,
          onCreateEvent: _createEvent,
          plan: _plan,
          contentFiles: List.unmodifiable(_contentFiles),
        ),
        _AppStage.shell => _buildShell(),
      },
    );
  }

  Widget _buildShell() {
    final darkMode = _themeMode == ThemeMode.dark;
    final origin =
        _origin ?? const OriginSelection(kind: LeadOriginKind.direct);
    return IndexedStack(
      index: _destination.index,
      children: [
        LeadCaptureScreen(
          key: const ValueKey('leadCaptureScreen'),
          originKind: origin.kind,
          eventName: origin.event?.name,
          initialPlace: origin.place,
          events: List.unmodifiable(_events),
          profile: _profile,
          recordsCount: _sessionLeads.length,
          darkMode: darkMode,
          onLeadSaved: _saveLead,
          onOriginChanged: _changeCaptureOrigin,
          onCreateEvent: _createEvent,
          onDestinationSelected: _selectDestination,
          onAppearanceChanged: _setAppearance,
          onLogout: _logout,
          plan: _plan,
          contentFiles: List.unmodifiable(_contentFiles),
        ),
        RecordsScreen(
          key: const ValueKey('recordsScreen'),
          records: List.unmodifiable(_sessionLeads),
          profile: _profile,
          darkMode: darkMode,
          onDestinationSelected: _selectDestination,
          onAppearanceChanged: _setAppearance,
          onLogout: _logout,
          plan: _plan,
          contentFiles: List.unmodifiable(_contentFiles),
        ),
        EventScreen(
          key: const ValueKey('eventsScreen'),
          events: List.unmodifiable(_events),
          profile: _profile,
          recordsCount: _sessionLeads.length,
          darkMode: darkMode,
          onDestinationSelected: _selectDestination,
          onAppearanceChanged: _setAppearance,
          onLogout: _logout,
          onCreate: _createEvent,
          onUpdate: _updateEvent,
          onDelete: _deleteEvent,
          onBack: _backFromEvents,
          plan: _plan,
          contentFiles: List.unmodifiable(_contentFiles),
        ),
        if (_plan.isPro)
          ContentScreen(
            key: const ValueKey('contentScreen'),
            files: List.unmodifiable(_contentFiles),
            events: List.unmodifiable(_events),
            recordsCount: _sessionLeads.length,
            profile: _profile,
            darkMode: darkMode,
            onDestinationSelected: _selectDestination,
            onAppearanceChanged: _setAppearance,
            onLogout: _logout,
            onFileAdded: (file) => setState(() => _contentFiles.add(file)),
            onFileUpdated: (file) => setState(
              () => _contentFiles = _contentFiles
                  .map((item) => item.id == file.id ? file : item)
                  .toList(),
            ),
            onFileDeleted: (file) => setState(
              () => _contentFiles.removeWhere((item) => item.id == file.id),
            ),
          )
        else
          const SizedBox.shrink(),
        if (_plan.isPro)
          EmailScreen(
            key: const ValueKey('emailScreen'),
            recordsCount: _sessionLeads.length,
            contentCount: _contentFiles.length,
            records: List.unmodifiable(_sessionLeads),
            contentFiles: List.unmodifiable(_contentFiles),
            profile: _profile,
            darkMode: darkMode,
            onDestinationSelected: _selectDestination,
            onAppearanceChanged: _setAppearance,
            onLogout: _logout,
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }
}
