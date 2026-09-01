/// Root application shell for the Foloo frontend prototype.
///
/// Owns navigation and demo capability selection while loading durable profile,
/// preferences, events and captured leads from the local repository boundary.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'auth/auth_models.dart';
import 'auth/auth_repository.dart';
import 'auth/development_auth_service.dart';
import 'auth/drift_development_auth_store.dart';
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
import 'services/connectivity_service.dart';
import 'services/pdf_picker_service.dart';
import 'theme/foloo_theme.dart';

enum _AuthenticatedStage { profile, origin, shell }

/// Coordinates the top-level Foloo flow from login through the capture shell.
///
/// ES: Coordina navegación, capacidades demo y datos locales durables.
class FolooApp extends StatefulWidget {
  const FolooApp({
    this.initialLocale,
    this.useSystemLocale = false,
    this.persistence,
    this.useDemoFixtures = true,
    this.connectivityService,
    this.pdfPickerService,
    this.authRepository,
    super.key,
  });

  final Locale? initialLocale;
  final bool useSystemLocale;
  final LocalPersistence? persistence;
  final bool useDemoFixtures;
  final ConnectivityService? connectivityService;
  final PdfPickerService? pdfPickerService;
  final AuthRepository? authRepository;

  @override
  State<FolooApp> createState() => _FolooAppState();
}

class _FolooAppState extends State<FolooApp> {
  // Session orchestration and capability fixtures.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  _AuthenticatedStage _stage = _AuthenticatedStage.profile;
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
  late Locale _defaultLocale;
  late final LocalPersistence _persistence;
  late final ConnectivityService _connectivity;
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isOnline = false;
  late final AuthRepository _authRepository;
  late final bool _ownsAuthRepository;
  bool _appInitialized = false;

  String get _userId {
    final user = _authRepository.state.user;
    if (user == null) throw StateError('Authenticated user required.');
    return user.id;
  }

  List<AppEvent> get _eventsWithCounts {
    final projected = _events.map((event) {
      final records = _sessionLeads.where(
        (record) =>
            record.lead.eventLocalId == event.id ||
            (record.lead.eventLocalId == null &&
                record.lead.eventName == event.name),
      );
      return event.copyWith(
        leadCount: records.length,
        pendingCount: records
            .where((record) => record.uploadState != SessionUploadState.inSheet)
            .length,
      );
    }).toList();
    // EVT-06: the active event is always the first visible option while the
    // remaining repository order stays stable.
    return [
      ...projected.where((event) => event.active),
      ...projected.where((event) => !event.active),
    ];
  }

  @override
  void initState() {
    super.initState();
    _persistence = widget.persistence ?? LocalPersistence.inMemory();
    _ownsAuthRepository = widget.authRepository == null;
    _authRepository =
        widget.authRepository ??
        AuthRepository(
          DevelopmentAuthService(
            DriftDevelopmentAuthStore(_persistence.globalPreferences),
          ),
        );
    _authRepository.addListener(_onAuthStateChanged);
    _connectivity = widget.connectivityService ?? DeviceConnectivityService();
    _events = List.of(DemoBasicData.events);
    _contentFiles = List.of(DemoProData.files);
    final system = WidgetsBinding.instance.platformDispatcher.locale;
    final requested =
        widget.initialLocale ??
        (widget.useSystemLocale ? system : const Locale('es'));
    final supported = AppLocalizations.supportedLocales.any(
      (locale) => locale.languageCode == requested.languageCode,
    );
    _defaultLocale = supported
        ? Locale(requested.languageCode)
        : const Locale('es');
    _locale = _defaultLocale;
    unawaited(_initializeConnectivity());
    unawaited(_initializeApplication());
  }

  void _onAuthStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeConnectivity() async {
    try {
      final connected = await _connectivity.isConnected();
      if (mounted) setState(() => _isOnline = connected);
    } catch (_) {
      // Device transport is advisory UI state; plugin failures stay offline.
    }
    if (!mounted) return;
    _connectivitySubscription = _connectivity.changes.listen((connected) {
      if (mounted && connected != _isOnline) {
        setState(() => _isOnline = connected);
      }
    }, onError: (_) {});
  }

  Future<void> _initializeApplication() async {
    try {
      await _persistence.initialize();
      await _authRepository.initialize();
      final user = _authRepository.state.user;
      if (user != null) await _loadUserState(user.id);
      if (mounted) setState(() => _appInitialized = true);
    } catch (_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPersistenceError();
      });
    }
  }

  Future<void> _loadUserState(String userId) async {
    // A locale chosen on Login applies immediately to the session. A stored
    // user preference takes precedence when one already exists.
    final sessionLocale = _locale;
    final storedProfile = await _persistence.profiles.load(userId);
    var storedEvents = await _persistence.events.list(userId);
    if (storedEvents.isEmpty && widget.useDemoFixtures) {
      for (final event in DemoBasicData.events) {
        await _persistence.events.save(userId, event, makeActive: event.active);
      }
      storedEvents = await _persistence.events.list(userId);
    }
    final storedTheme = await _persistence.preferences.read(
      userId,
      'themeMode',
    );
    final storedLocale = await _persistence.preferences.read(userId, 'locale');
    final storedLeads = await _persistence.leads.listAll(userId);
    if (!mounted) return;
    setState(() {
      _profile = storedProfile ?? DemoBasicData.profile;
      _profileCompleted = storedProfile != null;
      _events = storedEvents;
      _contentFiles = List.of(DemoProData.files);
      _sessionLeads
        ..clear()
        ..addAll(storedLeads);
      _origin = null;
      _destination = AppDestination.home;
      _stage = _profileCompleted
          ? _AuthenticatedStage.origin
          : _AuthenticatedStage.profile;
      _themeMode = storedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
      _locale =
          storedLocale != null &&
              AppLocalizations.supportedLocales.any(
                (locale) => locale.languageCode == storedLocale,
              )
          ? Locale(storedLocale)
          : sessionLocale;
    });
  }

  /// Stores the submitted draft before navigating to confirmation.
  ///
  /// CAP-15/SYN-01: confirmation is allowed only after this durable write.
  Future<SessionLead> _saveLead(LeadDraft lead) async {
    final record = await _persistence.leads.saveDraft(
      _userId,
      lead,
      capturedBy: _profile,
    );
    if (mounted) setState(() => _sessionLeads.insert(0, record));
    return record;
  }

  Future<bool> _authenticate(String username, String password) async {
    final authenticated = await _authRepository.signIn(
      username: username,
      password: password,
    );
    final user = _authRepository.state.user;
    if (!authenticated || user == null) return false;
    await _loadUserState(user.id);
    return true;
  }

  Future<void> _completeProfile(DemoProfile profile) async {
    try {
      await _persistence.profiles.save(_userId, profile);
    } catch (_) {
      if (mounted) _showPersistenceError();
      return;
    }
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _profileCompleted = true;
      _stage = _AuthenticatedStage.origin;
    });
  }

  void _selectOrigin(OriginSelection selection) {
    setState(() {
      _origin = selection;
      _destination = AppDestination.home;
      _stage = _AuthenticatedStage.shell;
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

  Future<void> _logout() async {
    await _authRepository.signOut();
    if (!mounted) return;
    setState(() {
      _destination = AppDestination.home;
      _stage = _AuthenticatedStage.profile;
      _profileCompleted = false;
      _profile = DemoBasicData.profile;
      _events = [];
      _contentFiles = List.of(DemoProData.files);
      _sessionLeads.clear();
      _origin = null;
    });
  }

  void _setAppearance(bool darkMode) {
    unawaited(
      _persistence.preferences.write(
        _userId,
        'themeMode',
        darkMode ? 'dark' : 'light',
      ),
    );
    setState(() => _themeMode = darkMode ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> _createEvent(AppEvent event) async {
    try {
      await _persistence.events.save(_userId, event, makeActive: true);
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

  void _addContentFile(ContentFile file) {
    setState(() => _contentFiles.add(file));
  }

  Future<void> _updateEvent(AppEvent event) async {
    try {
      await _persistence.events.save(_userId, event);
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
      await _persistence.events.delete(_userId, event);
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
    unawaited(_connectivitySubscription?.cancel());
    _authRepository.removeListener(_onAuthStateChanged);
    if (_ownsAuthRepository) _authRepository.dispose();
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
          final user = _authRepository.state.user;
          if (user != null) {
            unawaited(
              _persistence.preferences.write(
                user.id,
                'locale',
                locale.languageCode,
              ),
            );
          }
          setState(() => _locale = locale);
        },
        child: child ?? const SizedBox.shrink(),
      ),
      home: !_appInitialized
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _authRepository.state.status != AuthStatus.authenticated
          ? LoginScreen(
              key: const ValueKey('loginScreen'),
              onAuthenticated: _authenticate,
              authenticating:
                  _authRepository.state.status == AuthStatus.initializing,
              authenticationFailed:
                  _authRepository.state.status == AuthStatus.error,
              selectedPlan: _plan,
              onPlanChanged: (plan) => setState(() => _plan = plan),
            )
          : switch (_stage) {
              _AuthenticatedStage.profile => ProfileSetupScreen(
                key: const ValueKey('profileScreen'),
                onContinue: _completeProfile,
              ),
              _AuthenticatedStage.origin => OriginSelectionScreen(
                key: const ValueKey('originScreen'),
                events: List.unmodifiable(_eventsWithCounts),
                onContinue: _selectOrigin,
                onCreateEvent: _createEvent,
                onContentAdded: _addContentFile,
                pdfPickerService: widget.pdfPickerService,
                plan: _plan,
                contentFiles: List.unmodifiable(_contentFiles),
              ),
              _AuthenticatedStage.shell => _buildShell(),
            },
    );
  }

  /// Keeps shared destinations alive so Drawer navigation reuses session state.
  Widget _buildShell() {
    final darkMode = _themeMode == ThemeMode.dark;
    final events = _eventsWithCounts;
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
          events: List.unmodifiable(events),
          profile: _profile,
          recordsCount: _sessionLeads.length,
          darkMode: darkMode,
          onLeadSaved: _saveLead,
          onOriginChanged: _changeCaptureOrigin,
          onCreateEvent: _createEvent,
          onContentAdded: _addContentFile,
          pdfPickerService: widget.pdfPickerService,
          onDestinationSelected: _selectDestination,
          onAppearanceChanged: _setAppearance,
          onLogout: _logout,
          plan: _plan,
          contentFiles: List.unmodifiable(_contentFiles),
          isOnline: _isOnline,
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
          events: List.unmodifiable(events),
        ),
        EventScreen(
          key: const ValueKey('eventsScreen'),
          events: List.unmodifiable(events),
          profile: _profile,
          recordsCount: _sessionLeads.length,
          darkMode: darkMode,
          onDestinationSelected: _selectDestination,
          onAppearanceChanged: _setAppearance,
          onLogout: _logout,
          onCreate: _createEvent,
          onContentAdded: _addContentFile,
          pdfPickerService: widget.pdfPickerService,
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
            events: List.unmodifiable(events),
            recordsCount: _sessionLeads.length,
            profile: _profile,
            darkMode: darkMode,
            onDestinationSelected: _selectDestination,
            onAppearanceChanged: _setAppearance,
            onLogout: _logout,
            onFileAdded: _addContentFile,
            onFileUpdated: (file) => setState(
              () => _contentFiles = _contentFiles
                  .map((item) => item.id == file.id ? file : item)
                  .toList(),
            ),
            onFileDeleted: (file) => setState(
              () => _contentFiles.removeWhere((item) => item.id == file.id),
            ),
            pdfPickerService: widget.pdfPickerService,
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
