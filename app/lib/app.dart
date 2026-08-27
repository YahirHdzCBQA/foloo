/// Root application shell for the Foloo frontend prototype.
///
/// Owns navigation and demo capability selection while loading durable profile,
/// preferences, events and captured leads from the local repository boundary.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'l10n/l10n.dart';
import 'data/repositories/local_repositories.dart';

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

/// Coordinates the top-level Foloo flow from login through the capture shell.
///
/// ES: Coordina navegación, capacidades demo y datos locales durables.
class FolooApp extends StatefulWidget {
  const FolooApp({
    this.initialLocale,
    this.useSystemLocale = false,
    this.persistence,
    this.useDemoFixtures = true,
    super.key,
  });

  final Locale? initialLocale;
  final bool useSystemLocale;
  final LocalPersistence? persistence;
  final bool useDemoFixtures;

  @override
  State<FolooApp> createState() => _FolooAppState();
}

class _FolooAppState extends State<FolooApp> {
  // Session orchestration and capability fixtures.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  _AppStage _stage = _AppStage.login;
  ThemeMode _themeMode = ThemeMode.light;
  AppDestination _destination = AppDestination.home;
  // DEMO: Development plan selector used to preview the capability boundary.
  // RNF-18 requires production capabilities to come from the account backend.
  AppPlan _plan = AppPlan.basic;
  AppDestination _eventsReturnDestination = AppDestination.home;
  DemoProfile _profile = DemoBasicData.profile;
  bool _profileCompleted = false;
  late List<AppEvent> _events;
  late List<ContentFile> _contentFiles;
  OriginSelection? _origin;
  final List<SessionLead> _sessionLeads = [];
  late Locale _locale;
  late final LocalPersistence _persistence;

  @override
  void initState() {
    super.initState();
    _persistence = widget.persistence ?? LocalPersistence.inMemory();
    _events = List.of(DemoBasicData.events);
    _contentFiles = List.of(DemoProData.files);
    final system = WidgetsBinding.instance.platformDispatcher.locale;
    final requested =
        widget.initialLocale ??
        (widget.useSystemLocale ? system : const Locale('es'));
    final supported = AppLocalizations.supportedLocales.any(
      (locale) => locale.languageCode == requested.languageCode,
    );
    _locale = supported ? Locale(requested.languageCode) : const Locale('es');
    unawaited(_loadPersistentState());
  }

  Future<void> _loadPersistentState() async {
    try {
      await _loadPersistentStateUnchecked();
    } catch (_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPersistenceError();
      });
    }
  }

  Future<void> _loadPersistentStateUnchecked() async {
    await _persistence.initialize();
    final storedProfile = await _persistence.profiles.load();
    var storedEvents = await _persistence.events.list();
    if (storedEvents.isEmpty && widget.useDemoFixtures) {
      for (final event in DemoBasicData.events) {
        await _persistence.events.save(event, makeActive: event.active);
      }
      storedEvents = await _persistence.events.list();
    }
    final storedTheme = await _persistence.preferences.read('themeMode');
    final storedLocale = await _persistence.preferences.read('locale');
    final storedLeads = await _persistence.leads.listAll();
    if (!mounted) return;
    setState(() {
      if (storedProfile != null) {
        _profile = storedProfile;
        _profileCompleted = true;
      }
      if (storedEvents.isNotEmpty || !widget.useDemoFixtures) {
        _events = storedEvents;
      }
      _sessionLeads
        ..clear()
        ..addAll(storedLeads);
      if (storedTheme == 'dark') _themeMode = ThemeMode.dark;
      if (storedTheme == 'light') _themeMode = ThemeMode.light;
      if (storedLocale != null &&
          AppLocalizations.supportedLocales.any(
            (locale) => locale.languageCode == storedLocale,
          )) {
        _locale = Locale(storedLocale);
      }
    });
  }

  /// Stores the submitted draft before navigating to confirmation.
  ///
  /// CAP-15/SYN-01: confirmation is allowed only after this durable write.
  Future<SessionLead> _saveLead(LeadDraft lead) async {
    final record = await _persistence.leads.saveDraft(
      lead,
      capturedBy: _profile,
    );
    if (mounted) setState(() => _sessionLeads.insert(0, record));
    return record;
  }

  void _authenticate() {
    setState(
      () => _stage = _profileCompleted ? _AppStage.origin : _AppStage.profile,
    );
  }

  Future<void> _completeProfile(DemoProfile profile) async {
    try {
      await _persistence.profiles.save(profile);
    } catch (_) {
      if (mounted) _showPersistenceError();
      return;
    }
    if (!mounted) return;
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
    // DEMO: This authentication shell is session-only. AUT-08 requires local
    // leads to survive logout, so
    // this in-memory prototype deliberately keeps the current session list.
    setState(() {
      _stage = _AppStage.login;
      _destination = AppDestination.home;
    });
  }

  void _setAppearance(bool darkMode) {
    unawaited(
      _persistence.preferences.write('themeMode', darkMode ? 'dark' : 'light'),
    );
    setState(() => _themeMode = darkMode ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> _createEvent(AppEvent event) async {
    try {
      await _persistence.events.save(event, makeActive: true);
    } catch (_) {
      if (mounted) _showPersistenceError();
      return;
    }
    if (!mounted) return;
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

  Future<void> _updateEvent(AppEvent event) async {
    try {
      await _persistence.events.save(event);
    } catch (_) {
      if (mounted) _showPersistenceError();
      return;
    }
    if (!mounted) return;
    setState(() {
      _events = _events
          .map((item) => item.id == event.id ? event : item)
          .toList();
      if (_origin?.event?.id == event.id) {
        _origin = OriginSelection(kind: LeadOriginKind.event, event: event);
      }
    });
  }

  Future<void> _deleteEvent(AppEvent event) async {
    try {
      await _persistence.events.delete(event);
    } catch (_) {
      if (mounted) _showPersistenceError();
      return;
    }
    if (!mounted) return;
    setState(() {
      _events.removeWhere((item) => item.id == event.id);
      if (_origin?.event?.id == event.id) {
        if (_events.isNotEmpty) {
          _events = [_events.first.copyWith(active: true), ..._events.skip(1)];
        }
        final replacement = _events.isEmpty ? null : _events.first;
        _origin = replacement == null
            ? const OriginSelection(kind: LeadOriginKind.direct)
            : OriginSelection(kind: LeadOriginKind.event, event: replacement);
      }
    });
  }

  void _showPersistenceError() {
    _messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(lookupAppLocalizations(_locale).localSaveError)),
    );
  }

  @override
  void dispose() {
    unawaited(_persistence.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _messengerKey,
      onGenerateTitle: (_) => 'Foloo · ${_profile.name}',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: FolooTheme.light,
      darkTheme: FolooTheme.dark,
      themeMode: _themeMode,
      builder: (context, child) => AppLanguageScope(
        locale: _locale,
        onLocaleChanged: (locale) {
          unawaited(
            _persistence.preferences.write('locale', locale.languageCode),
          );
          setState(() => _locale = locale);
        },
        child: child ?? const SizedBox.shrink(),
      ),
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

  /// Keeps shared destinations alive so Drawer navigation reuses session state.
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
          eventId: origin.event?.id,
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
