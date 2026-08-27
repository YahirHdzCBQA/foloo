/// Continuous, scrollable lead-capture workflow shared by Basic and Pro.
///
/// Coordinates origin, card OCR, editable lead data, relationship, voice note
/// and submission while delegating native work to dedicated services.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_destination.dart';
import '../models/app_event.dart';
import '../models/app_plan.dart';
import '../models/pro_demo_data.dart';
import '../models/lead_draft.dart';
import '../models/session_lead.dart';
import '../models/voice_note_state.dart';
import '../services/card_text_recognition_service.dart';
import '../services/voice_note_service.dart';
import '../theme/foloo_theme.dart';
import '../l10n/l10n.dart';
import '../utils/business_card_parser.dart';
import '../widgets/app_drawer.dart';
import '../widgets/create_event_dialog.dart';
import '../widgets/progress_header.dart';
import '../widgets/section_card.dart';
import '../widgets/segmented_bubble.dart';
import 'lead_confirmation_screen.dart';

/// Reports an origin change without coupling capture to root application state.
typedef LeadOriginChanged = void Function(LeadOriginKind kind, AppEvent? event);

/// Displays the single-screen four-section capture experience (CAP-05).
///
/// Pro additions are capability-gated and absent, rather than disabled, in
/// Basic. ES: Coordina la captura completa de una conexión.
class LeadCaptureScreen extends StatefulWidget {
  const LeadCaptureScreen({
    required this.originKind,
    required this.events,
    required this.recordsCount,
    required this.darkMode,
    required this.onLeadSaved,
    required this.onDestinationSelected,
    required this.onAppearanceChanged,
    required this.onLogout,
    required this.onOriginChanged,
    required this.onCreateEvent,
    this.plan = AppPlan.basic,
    this.contentFiles = const [],
    this.profile = DemoBasicData.profile,
    this.eventId,
    this.eventName,
    this.initialPlace,
    this.voiceNoteService,
    super.key,
  });

  final LeadOriginKind originKind;
  final String? eventId;
  final String? eventName;
  final String? initialPlace;
  final List<AppEvent> events;
  final int recordsCount;
  final bool darkMode;
  final FutureOr<SessionLead> Function(LeadDraft lead) onLeadSaved;
  final ValueChanged<AppDestination> onDestinationSelected;
  final ValueChanged<bool> onAppearanceChanged;
  final VoidCallback onLogout;
  final LeadOriginChanged onOriginChanged;
  final ValueChanged<AppEvent> onCreateEvent;
  final DemoProfile profile;
  final VoiceNoteService? voiceNoteService;
  final AppPlan plan;
  final List<ContentFile> contentFiles;

  @override
  State<LeadCaptureScreen> createState() => _LeadCaptureScreenState();
}

class _LeadCaptureScreenState extends State<LeadCaptureScreen>
    with WidgetsBindingObserver {
  // Form, OCR and image-capture state.
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  final _textRecognitionService = CardTextRecognitionService();
  final _cardParser = const BusinessCardParser();
  final _name = TextEditingController();
  final _lastName = TextEditingController();
  final _role = TextEditingController();
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  final _place = TextEditingController();
  late final VoiceNoteService _voiceNoteService;
  late final StreamSubscription<void> _playbackCompletedSubscription;

  // Derived media and manual-edit guards for OCR-05.
  Uint8List? _cardBytes;
  String? _cardPath;
  String? _imageMessage;
  bool _isReadingCard = false;
  bool _ocrFailed = false;
  bool _nameEdited = false;
  bool _lastNameEdited = false;
  bool _roleEdited = false;
  bool _companyEdited = false;
  bool _emailEdited = false;
  bool _phoneEdited = false;
  LeadType? _leadType;
  InterestLevel _interest = InterestLevel.medium;
  bool _showValidation = false;
  VoiceNoteState _voiceNote = const VoiceNoteState();
  String? _voiceNoteMessage;
  bool _voiceActionInProgress = false;
  bool _voiceNoteTransferred = false;
  late Set<String> _selectedContentIds;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voiceNoteService = widget.voiceNoteService ?? DeviceVoiceNoteService();
    _place.text = widget.initialPlace ?? '';
    _selectedContentIds = _defaultContentIds();
    _playbackCompletedSubscription = _voiceNoteService.playbackCompleted.listen(
      (_) {
        if (mounted && _voiceNote.isPlaying) {
          setState(() => _voiceNote = _voiceNote.completePlayback());
        }
      },
    );
    for (final controller in [
      _name,
      _lastName,
      _company,
      _email,
      _phone,
      _note,
      _place,
    ]) {
      controller.addListener(_refreshProgress);
    }
  }

  Set<String> _defaultContentIds() {
    if (!widget.plan.isPro) return {};
    final event = _selectedEvent;
    if (event == null) return {};
    return widget.contentFiles
        .where((file) => file.appliesTo(event))
        .map((file) => file.id)
        .toSet();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _playbackCompletedSubscription.cancel();
    unawaited(_disposeVoiceResources());
    unawaited(_textRecognitionService.close());
    _scrollController.dispose();
    for (final controller in [
      _name,
      _lastName,
      _role,
      _company,
      _email,
      _phone,
      _note,
      _place,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (_voiceNote.isRecording) {
        unawaited(_stopRecording());
      } else if (_voiceNote.isPlaying) {
        unawaited(_pausePlayback());
      }
    }
  }

  /// Releases native audio resources without deleting a recording transferred
  /// into the submitted lead snapshot.
  Future<void> _disposeVoiceResources() async {
    try {
      if (_voiceNote.isRecording) {
        await _voiceNoteService.cancelRecording();
      } else {
        await _voiceNoteService.stopPlayback();
      }
      final path = _voiceNote.localPath;
      if (!_voiceNoteTransferred && path != null) {
        await _voiceNoteService.deleteFile(path);
      }
    } catch (_) {
      // Best-effort cleanup while the widget tree is being disposed.
    } finally {
      try {
        await _voiceNoteService.dispose();
      } catch (_) {
        // Native resources may already be unavailable during app teardown.
      }
    }
  }

  void _refreshProgress() {
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Card capture and OCR
  // ---------------------------------------------------------------------------

  /// Selects the original card image and immediately starts local demo OCR.
  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1568,
        maxHeight: 1568,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _cardBytes = bytes;
        _cardPath = image.path;
        _imageMessage = context.l10n.cardReading;
        _ocrFailed = false;
      });
      await _readCard(image.path);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _imageMessage = context.l10n.cardOpenError;
        _ocrFailed = true;
      });
    }
  }

  void _removeImage() {
    setState(() {
      _cardBytes = null;
      _cardPath = null;
      _imageMessage = null;
      _ocrFailed = false;
    });
  }

  void _clearLeadFields() {
    for (final controller in [
      _name,
      _lastName,
      _role,
      _company,
      _email,
      _phone,
    ]) {
      controller.clear();
    }
    setState(() {
      _nameEdited = false;
      _lastNameEdited = false;
      _roleEdited = false;
      _companyEdited = false;
      _emailEdited = false;
      _phoneEdited = false;
      _showValidation = false;
    });
  }

  AppEvent? get _selectedEvent {
    final byName = widget.events.where(
      (event) => event.name == widget.eventName,
    );
    if (byName.isNotEmpty) return byName.first;
    final active = widget.events.where((event) => event.active);
    if (active.isNotEmpty) return active.first;
    return widget.events.isEmpty ? null : widget.events.first;
  }

  List<ContentFile> get _defaultContentForEvent {
    final event = _selectedEvent;
    if (event == null) return const [];
    return widget.contentFiles
        .where(
          (file) =>
              file.appliesTo(event) || event.contentFileIds.contains(file.id),
        )
        .toList();
  }

  void _changeOrigin(LeadOriginKind kind) {
    if (kind == LeadOriginKind.direct) {
      widget.onOriginChanged(kind, null);
    } else {
      widget.onOriginChanged(kind, _selectedEvent);
    }
  }

  Future<void> _createEventFromCapture() async {
    final event = await showCreateEventDialog(
      context,
      plan: widget.plan,
      contentFiles: widget.contentFiles,
    );
    if (event == null || !mounted) return;
    widget.onCreateEvent(event);
    widget.onOriginChanged(LeadOriginKind.event, event);
  }

  /// Maps OCR output only into untouched empty fields.
  ///
  /// OCR-05 makes manual edits authoritative across every reprocessing pass.
  Future<void> _readCard(String imagePath) async {
    // DEMO: Local extraction only. OCR-03 keeps production extraction behind
    // the Foloo backend boundary.
    if (_isReadingCard) return;
    setState(() {
      _isReadingCard = true;
      _ocrFailed = false;
      _imageMessage = context.l10n.cardReading;
    });

    try {
      final lines = await _textRecognitionService.recognizeLines(imagePath);
      final card = _cardParser.parse(lines);
      if (!mounted) return;

      _fillFromOcr(_name, card.name, manuallyEdited: _nameEdited);
      _fillFromOcr(_lastName, card.lastName, manuallyEdited: _lastNameEdited);
      _fillFromOcr(_role, card.role, manuallyEdited: _roleEdited);
      _fillFromOcr(_company, card.company, manuallyEdited: _companyEdited);
      _fillFromOcr(_email, card.email, manuallyEdited: _emailEdited);
      _fillFromOcr(_phone, card.phone, manuallyEdited: _phoneEdited);

      final coreFieldsDetected =
          card.name.isNotEmpty &&
          card.company.isNotEmpty &&
          card.email.isNotEmpty &&
          card.phone.isNotEmpty;
      setState(() {
        _imageMessage = coreFieldsDetected
            ? context.l10n.cardReadSuccess
            : context.l10n.cardReadIncomplete;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ocrFailed = true;
        _imageMessage = context.l10n.cardReadError;
      });
    } finally {
      if (mounted) setState(() => _isReadingCard = false);
    }
  }

  void _fillFromOcr(
    TextEditingController controller,
    String value, {
    required bool manuallyEdited,
  }) {
    if (shouldApplyExtractedValue(
      currentValue: controller.text,
      extractedValue: value,
      manuallyEdited: manuallyEdited,
    )) {
      controller.text = value;
    }
  }

  // ---------------------------------------------------------------------------
  // Local voice-note lifecycle
  // ---------------------------------------------------------------------------

  Future<void> _toggleRecording() async {
    if (_voiceActionInProgress) return;
    if (_voiceNote.isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final previous = _voiceNote;
    setState(() {
      _voiceActionInProgress = true;
      _voiceNoteMessage = null;
    });
    try {
      await _voiceNoteService.stopPlayback();
      final path = await _voiceNoteService.startRecording();
      if (!mounted) {
        await _voiceNoteService.cancelRecording();
        return;
      }
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted) return;
        setState(() {
          _voiceNote = _voiceNote.updateElapsed(
            _voiceNote.elapsed + const Duration(milliseconds: 250),
          );
        });
      });
      setState(() {
        _voiceNote = _voiceNote.startRecording(path);
        _voiceNoteTransferred = false;
      });
      if (previous.localPath != null && previous.localPath != path) {
        try {
          await _voiceNoteService.deleteFile(previous.localPath!);
        } catch (_) {
          // The new recording is valid even if stale draft cleanup must retry.
        }
      }
    } on VoiceNotePermissionDeniedException {
      if (!mounted) return;
      setState(() {
        _voiceNote = previous;
        _voiceNoteMessage = context.l10n.microphoneDenied;
      });
    } catch (_) {
      try {
        await _voiceNoteService.cancelRecording();
      } catch (_) {
        // Preserve the manual fallback even when cleanup also fails.
      }
      if (!mounted) return;
      setState(() {
        _voiceNote = previous;
        _voiceNoteMessage = context.l10n.recordStartError;
      });
    } finally {
      if (mounted) setState(() => _voiceActionInProgress = false);
    }
  }

  Future<void> _stopRecording() async {
    if (!_voiceNote.isRecording) return;
    _recordingTimer?.cancel();
    final currentPath = _voiceNote.localPath;
    try {
      final path = await _voiceNoteService.stopRecording() ?? currentPath;
      if (!mounted) return;
      if (path == null) {
        setState(() {
          _voiceNote = const VoiceNoteState();
          _voiceNoteMessage = context.l10n.recordKeepError;
        });
        return;
      }
      final elapsed = _voiceNote.elapsed;
      setState(() {
        _voiceNote = _voiceNote.finishRecording(path, elapsed);
        _voiceNoteMessage = context.l10n.voiceSaved;
      });
    } catch (_) {
      try {
        await _voiceNoteService.cancelRecording();
        if (currentPath != null) {
          await _voiceNoteService.deleteFile(currentPath);
        }
      } catch (_) {
        // Preserve the manual fallback even when cleanup also fails.
      }
      if (!mounted) return;
      setState(() {
        _voiceNote = const VoiceNoteState();
        _voiceNoteMessage = context.l10n.recordStopError;
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (_voiceActionInProgress || !_voiceNote.hasRecording) return;
    setState(() => _voiceActionInProgress = true);
    try {
      if (_voiceNote.isPlaying) {
        await _pausePlayback();
      } else if (_voiceNote.isPaused) {
        await _voiceNoteService.resumePlayback();
        if (mounted) setState(() => _voiceNote = _voiceNote.startPlayback());
      } else {
        await _voiceNoteService.play(_voiceNote.localPath!);
        if (mounted) setState(() => _voiceNote = _voiceNote.startPlayback());
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _voiceNote = _voiceNote.completePlayback();
          _voiceNoteMessage = context.l10n.audioPlayError;
        });
      }
    } finally {
      if (mounted) setState(() => _voiceActionInProgress = false);
    }
  }

  Future<void> _pausePlayback() async {
    try {
      await _voiceNoteService.pausePlayback();
      if (mounted) setState(() => _voiceNote = _voiceNote.pausePlayback());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _voiceNote = _voiceNote.completePlayback();
        _voiceNoteMessage = context.l10n.audioPauseError;
      });
    }
  }

  Future<void> _deleteVoiceNote() async {
    if (_voiceActionInProgress || _voiceNote.localPath == null) return;
    setState(() => _voiceActionInProgress = true);
    final path = _voiceNote.localPath!;
    try {
      if (_voiceNote.isRecording) {
        _recordingTimer?.cancel();
        await _voiceNoteService.cancelRecording();
      } else {
        await _voiceNoteService.stopPlayback();
        await _voiceNoteService.deleteFile(path);
      }
      if (!mounted) return;
      setState(() {
        _voiceNote = const VoiceNoteState();
        _voiceNoteMessage = context.l10n.audioDeleted;
        _voiceNoteTransferred = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _voiceNoteMessage = context.l10n.audioDeleteError;
        });
      }
    } finally {
      if (mounted) setState(() => _voiceActionInProgress = false);
    }
  }

  String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds;
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }

  String _formatEventDate(DateTime date) {
    return DateFormat(
      'd MMM y',
      Localizations.localeOf(context).toLanguageTag(),
    ).format(date);
  }

  String? _required(String? value, String message) {
    return value == null || value.trim().isEmpty ? message : null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      if (_phone.text.trim().isEmpty) return context.l10n.emailOrPhoneRequired;
      return null;
    }
    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    return valid ? null : context.l10n.invalidEmail;
  }

  String? _validatePhone(String? value) {
    if ((value?.trim().isEmpty ?? true) && _email.text.trim().isEmpty) {
      return context.l10n.phoneOrEmailRequired;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Validation and local demo submission
  // ---------------------------------------------------------------------------

  /// Validates shared fields plus capability-specific requirements before
  /// handing an immutable draft to the session-local application store.
  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_voiceNote.isRecording) await _stopRecording();
    if (_voiceNote.isPlaying || _voiceNote.isPaused) {
      await _voiceNoteService.stopPlayback();
      if (mounted) setState(() => _voiceNote = _voiceNote.completePlayback());
    }
    if (!mounted) return;
    setState(() => _showValidation = true);
    final fieldsValid = _formKey.currentState?.validate() ?? false;
    final relationshipValid = _leadType != null;
    if (!fieldsValid || !relationshipValid) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.reviewFields)));
      return;
    }

    final lead = LeadDraft(
      name: _name.text.trim(),
      lastName: _lastName.text.trim(),
      role: _role.text.trim(),
      company: _company.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      type: _leadType!,
      interest: _interest,
      note: _note.text.trim(),
      originKind: widget.originKind,
      eventLocalId: widget.eventId,
      eventName: widget.eventName,
      cardImageLocalPath: _cardPath,
      audioLocalPath: _voiceNote.hasRecording ? _voiceNote.localPath : null,
      audioSeconds: _voiceNote.hasRecording ? _voiceNote.elapsed.inSeconds : 0,
      place: widget.plan.isPro && widget.originKind == LeadOriginKind.direct
          ? _place.text.trim()
          : null,
      contentFileIds: _selectedContentIds.toList(),
      contentNames: widget.contentFiles
          .where((file) => _selectedContentIds.contains(file.id))
          .map((file) => file.displayName)
          .toList(),
      transcription: widget.plan.isPro && _voiceNote.hasRecording
          ? DemoProData.transcript
          : null,
    );
    late final SessionLead record;
    try {
      record = await Future<SessionLead>.sync(() => widget.onLeadSaved(lead));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.localSaveError)));
      return;
    }
    if (!mounted) return;
    _voiceNoteTransferred = record.lead.hasVoiceNote;
    final sourceAudio = lead.audioLocalPath;
    if (sourceAudio != null &&
        record.lead.audioLocalPath != null &&
        sourceAudio != record.lead.audioLocalPath) {
      unawaited(_voiceNoteService.deleteFile(sourceAudio));
    }

    if (record.mediaIncomplete) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.mediaSaveWarning)));
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LeadConfirmationScreen(
          record: record,
          plan: widget.plan,
          onCaptureAnother: () {
            Navigator.of(context).pop();
            _reset();
          },
        ),
      ),
    );
  }

  void _reset() {
    _recordingTimer?.cancel();
    unawaited(_voiceNoteService.stopPlayback());
    for (final controller in [
      _name,
      _lastName,
      _role,
      _company,
      _email,
      _phone,
      _note,
    ]) {
      controller.clear();
    }
    setState(() {
      _cardBytes = null;
      _cardPath = null;
      _imageMessage = null;
      _isReadingCard = false;
      _ocrFailed = false;
      _nameEdited = false;
      _lastNameEdited = false;
      _roleEdited = false;
      _companyEdited = false;
      _emailEdited = false;
      _phoneEdited = false;
      _leadType = null;
      _interest = InterestLevel.medium;
      _showValidation = false;
      _voiceNote = const VoiceNoteState();
      _voiceNoteMessage = null;
      _voiceActionInProgress = false;
      _voiceNoteTransferred = false;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  List<bool> get _progress => [
    _cardBytes != null,
    _name.text.trim().isNotEmpty &&
        _company.text.trim().isNotEmpty &&
        (_email.text.trim().isNotEmpty || _phone.text.trim().isNotEmpty),
    _leadType != null,
    _note.text.trim().isNotEmpty ||
        _voiceNote.hasRecording ||
        _voiceNote.isRecording,
  ];

  Future<void> _selectDestination(AppDestination destination) async {
    if (_voiceNote.isRecording) await _stopRecording();
    if (_voiceNote.isPlaying) await _pausePlayback();
    if (mounted) widget.onDestinationSelected(destination);
  }

  Future<void> _logout() async {
    if (_voiceNote.isRecording) {
      _recordingTimer?.cancel();
      await _voiceNoteService.cancelRecording();
    } else {
      await _voiceNoteService.stopPlayback();
      if (!_voiceNoteTransferred && _voiceNote.localPath != null) {
        await _voiceNoteService.deleteFile(_voiceNote.localPath!);
      }
    }
    if (mounted) widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: FolooPalette.of(context).card,
      endDrawer: AppDrawer(
        plan: widget.plan,
        contentCount: widget.contentFiles.length,
        profile: widget.profile,
        activeDestination: AppDestination.home,
        recordsCount: widget.recordsCount,
        darkMode: widget.darkMode,
        onDestinationSelected: (value) => unawaited(_selectDestination(value)),
        onAppearanceChanged: widget.onAppearanceChanged,
        onLogout: () => unawaited(_logout()),
      ),
      body: Column(
        children: [
          ProgressHeader(
            completed: _progress,
            onMenuPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              autovalidateMode: _showValidation
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: SingleChildScrollView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        _buildOriginSection(),
                        const SizedBox(height: 14),
                        _buildCardSection(),
                        const SizedBox(height: 14),
                        _buildDataSection(),
                        const SizedBox(height: 14),
                        _buildRelationshipSection(),
                        const SizedBox(height: 14),
                        _buildNoteSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 160),
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 11, 16, keyboardVisible ? 8 : 11),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.35),
                ),
              ),
            ),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const Key('saveLeadButton'),
                    onPressed: _submit,
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.send_outlined),
                    label: Text(
                      widget.plan.isPro
                          ? context.l10n.savePro
                          : context.l10n.save,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOriginSection() {
    final palette = FolooPalette.of(context);
    final selectedEvent = _selectedEvent;
    final direct = widget.originKind == LeadOriginKind.direct;
    return Container(
      key: const Key('captureOriginSection'),
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(FolooRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.leadSource,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          SegmentedBubble<LeadOriginKind>(
            key: const Key('captureOriginBubble'),
            selectedHorizontalPadding: 8,
            selected: widget.originKind,
            onSelected: _changeOrigin,
            options: [
              SegmentedBubbleOption(
                key: Key('captureOriginEventTab'),
                value: LeadOriginKind.event,
                label: context.l10n.event,
                leading: const Icon(Icons.calendar_today_outlined, size: 15),
              ),
              SegmentedBubbleOption(
                key: Key('captureOriginDirectTab'),
                value: LeadOriginKind.direct,
                label: context.l10n.directLead,
                leading: const Icon(Icons.person_outline, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (direct)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.directLeadHelp,
                  style: TextStyle(
                    color: palette.inkSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                if (widget.plan.isPro) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('directPlaceField'),
                    controller: _place,
                    decoration: InputDecoration(labelText: context.l10n.place),
                    validator: (value) =>
                        _required(value, context.l10n.placeRequired),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.directPlaceHelp('{lugar}'),
                    style: TextStyle(color: palette.inkSecondary, fontSize: 11),
                  ),
                ],
              ],
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: palette.paper,
                      borderRadius: BorderRadius.circular(FolooRadii.md),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: const Key('captureEventDropdown'),
                        value: selectedEvent?.id,
                        isExpanded: true,
                        hint: Text(context.l10n.event),
                        icon: const Icon(Icons.keyboard_arrow_down, size: 19),
                        items: widget.events
                            .map(
                              (event) => DropdownMenuItem(
                                value: event.id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: FolooColors.lime,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Text(
                                        event.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (id) {
                          if (id == null) return;
                          final event = widget.events.firstWhere(
                            (item) => item.id == id,
                          );
                          setState(() {
                            _selectedContentIds = widget.contentFiles
                                .where((file) => file.appliesTo(event))
                                .map((file) => file.id)
                                .toSet();
                          });
                          widget.onOriginChanged(LeadOriginKind.event, event);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const Key('captureCreateEventButton'),
                  tooltip: context.l10n.createEvent,
                  onPressed: _createEventFromCapture,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(56, 56),
                    backgroundColor: palette.paper,
                    foregroundColor: palette.ink,
                  ),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (selectedEvent != null) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.recentEventHelp(
                  _formatEventDate(selectedEvent.startsOn),
                ),
                style: TextStyle(color: palette.inkSecondary, fontSize: 11),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCardSection() {
    final palette = FolooPalette.of(context);
    final hasCard = _cardBytes != null;
    return SectionCard(
      key: const Key('cardSection'),
      number: '01',
      title: context.l10n.cardSection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Semantics(
                  label: hasCard
                      ? context.l10n.selectedCardPreview
                      : context.l10n.noCardPhotoSemantics,
                  image: hasCard,
                  child: Container(
                    height: 64,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: hasCard ? palette.ink : palette.paper,
                      borderRadius: BorderRadius.circular(FolooRadii.sm),
                    ),
                    child: hasCard
                        ? Image.memory(
                            _cardBytes!,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          )
                        : Icon(
                            Icons.center_focus_weak_outlined,
                            color: palette.inkSecondary,
                            size: 24,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Text(
                  hasCard ? context.l10n.reprocess : context.l10n.noCardPhoto,
                  style: TextStyle(
                    color: palette.inkSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                key: const Key('galleryButton'),
                tooltip: context.l10n.chooseGallery,
                onPressed: _isReadingCard
                    ? null
                    : () => _pickImage(ImageSource.gallery),
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: palette.paper,
                  foregroundColor: palette.inkSecondary,
                ),
                icon: const Icon(Icons.photo_outlined, size: 20),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                key: const Key('cameraButton'),
                tooltip: hasCard
                    ? context.l10n.changePhoto
                    : context.l10n.takePhoto,
                onPressed: _isReadingCard
                    ? null
                    : () => _pickImage(ImageSource.camera),
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: palette.ink,
                  foregroundColor: palette.card,
                ),
                icon: const Icon(Icons.photo_camera_outlined, size: 20),
              ),
            ],
          ),
          if (hasCard) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton.icon(
                  key: const Key('readCardButton'),
                  onPressed: _isReadingCard || _cardPath == null
                      ? null
                      : () => _readCard(_cardPath!),
                  style: TextButton.styleFrom(foregroundColor: palette.ink),
                  icon: _isReadingCard
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync, size: 17),
                  label: Text(_isReadingCard ? '…' : context.l10n.reprocess),
                ),
                const Spacer(),
                TextButton(
                  key: const Key('removeCardButton'),
                  onPressed: _isReadingCard ? null : _removeImage,
                  style: TextButton.styleFrom(foregroundColor: palette.ink),
                  child: Text(context.l10n.remove),
                ),
              ],
            ),
          ],
          if (_imageMessage != null) ...[
            const SizedBox(height: 4),
            Semantics(
              liveRegion: true,
              child: Text(
                _imageMessage!,
                style: TextStyle(
                  color: _ocrFailed ? palette.error : palette.inkSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDataSection() {
    final theme = Theme.of(context);
    final borderless = theme.inputDecorationTheme.copyWith(
      border: FolooBorders.borderlessField,
      enabledBorder: FolooBorders.borderlessField,
      focusedBorder: FolooBorders.borderlessField,
      errorBorder: FolooBorders.borderlessField,
      focusedErrorBorder: FolooBorders.borderlessField,
    );
    return Theme(
      data: theme.copyWith(inputDecorationTheme: borderless),
      child: SectionCard(
        key: const Key('dataSection'),
        number: '02',
        title: context.l10n.leadData,
        trailing: TextButton(
          key: const Key('clearLeadFieldsButton'),
          onPressed: _clearLeadFields,
          style: TextButton.styleFrom(
            foregroundColor: FolooPalette.of(context).inkSecondary,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text(context.l10n.clear),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _LabeledField(
                    label: context.l10n.firstName,
                    field: TextFormField(
                      key: const Key('nameField'),
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.givenName],
                      onChanged: (_) => _nameEdited = true,
                      validator: (value) =>
                          _required(value, context.l10n.leadNameRequired),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LabeledField(
                    label: context.l10n.lastName,
                    field: TextFormField(
                      key: const Key('lastNameField'),
                      controller: _lastName,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.familyName],
                      onChanged: (_) => _lastNameEdited = true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: context.l10n.role,
              field: TextFormField(
                key: const Key('roleField'),
                controller: _role,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.jobTitle],
                onChanged: (_) => _roleEdited = true,
              ),
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: context.l10n.company.toUpperCase(),
              field: TextFormField(
                key: const Key('companyField'),
                controller: _company,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _companyEdited = true,
                validator: (value) =>
                    _required(value, context.l10n.leadCompanyRequired),
              ),
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: context.l10n.email,
              field: TextFormField(
                key: const Key('emailField'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textCapitalization: TextCapitalization.none,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                onChanged: (_) => _emailEdited = true,
                validator: _validateEmail,
              ),
            ),
            const SizedBox(height: 16),
            _LabeledField(
              label: context.l10n.phone,
              field: TextFormField(
                key: const Key('phoneField'),
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                onChanged: (_) => _phoneEdited = true,
                validator: _validatePhone,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelationshipSection() {
    return SectionCard(
      key: const Key('relationshipSection'),
      number: '03',
      title: context.l10n.leadType,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: LeadType.values.map((type) {
              final selected = _leadType == type;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _RelationshipChoice(
                    type: type,
                    selected: selected,
                    onTap: () => setState(() => _leadType = type),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_showValidation && _leadType == null) ...[
            const SizedBox(height: 6),
            Text(
              context.l10n.chooseLeadType,
              style: TextStyle(color: FolooColors.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            context.l10n.interestLevel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedBubble<InterestLevel>(
            key: const Key('interestBubble'),
            height: 50,
            selectedHorizontalPadding: 8,
            selectedVerticalInset: 3,
            selected: _interest,
            onSelected: (value) => setState(() => _interest = value),
            options: [
              SegmentedBubbleOption(
                key: Key('interest-low'),
                value: InterestLevel.low,
                label: context.l10n.interestLow,
                leading: const _InterestDot(color: FolooColors.interestLow),
              ),
              SegmentedBubbleOption(
                key: Key('interest-medium'),
                value: InterestLevel.medium,
                label: context.l10n.interestMedium,
                leading: const _InterestDot(color: FolooColors.interestMedium),
              ),
              SegmentedBubbleOption(
                key: Key('interest-high'),
                value: InterestLevel.high,
                label: context.l10n.interestHigh,
                leading: const _InterestDot(color: FolooColors.interestHigh),
              ),
            ],
          ),
          if (widget.plan.isPro &&
              widget.originKind == LeadOriginKind.event &&
              _defaultContentForEvent.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              context.l10n.contentToShare,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            ..._defaultContentForEvent.map(
              (file) => _ContentSelectionPill(
                key: Key('captureContent-${file.id}'),
                label: file.displayName,
                selected: _selectedContentIds.contains(file.id),
                onTap: () => setState(() {
                  if (_selectedContentIds.contains(file.id)) {
                    _selectedContentIds.remove(file.id);
                  } else {
                    _selectedContentIds.add(file.id);
                  }
                }),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              context.l10n.contentAttachmentSummary(
                _selectedContentIds.length,
                _defaultContentForEvent.length,
                _contentEventLabel,
              ),
              style: TextStyle(
                color: FolooPalette.of(context).inkSecondary,
                fontSize: 10.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String get _contentEventLabel =>
      (_selectedEvent?.name ?? context.l10n.thisEventLower).replaceFirst(
        ' México',
        '',
      );

  Widget _buildNoteSection() {
    return SectionCard(
      key: const Key('noteSection'),
      number: '04',
      title: context.l10n.conversationNote,
      trailing: _voiceNote.isRecording
          ? Text(
              '● ${context.l10n.recording}',
              style: TextStyle(
                color: FolooColors.error,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.voiceNoteOptional,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          // TODO(BACKEND/AUDIO): Upload the local voice note when media delivery is implemented.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FolooPalette.of(context).paper,
              borderRadius: BorderRadius.circular(FolooRadii.md),
            ),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: _voiceNote.isRecording
                      ? context.l10n.stopRecording
                      : _voiceNote.hasRecording
                      ? context.l10n.recordAgain
                      : context.l10n.startRecording,
                  child: IconButton.filled(
                    key: const Key('recordButton'),
                    onPressed: _voiceActionInProgress ? null : _toggleRecording,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(52, 52),
                      backgroundColor: FolooColors.ink,
                      foregroundColor: _voiceNote.isRecording
                          ? FolooColors.lime
                          : FolooColors.white,
                    ),
                    icon: _voiceActionInProgress
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            _voiceNote.isRecording
                                ? Icons.stop_rounded
                                : Icons.mic_none_rounded,
                            size: _voiceNote.isRecording ? 23 : 24,
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _Waveform(
                          active:
                              _voiceNote.isRecording || _voiceNote.isPlaying,
                          tick: _voiceNote.elapsed.inMilliseconds,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatDuration(_voiceNote.elapsed),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.mic_none_rounded,
                size: 14,
                color: FolooPalette.of(context).inkSecondary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  context.l10n.offlineSaveHelp,
                  style: TextStyle(
                    color: FolooPalette.of(context).inkSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
          if (_voiceNote.hasRecording) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _AudioActionButton(
                    key: const Key('deleteVoiceNoteButton'),
                    tooltip: context.l10n.deleteAudio,
                    icon: Icons.delete_outline_rounded,
                    onPressed: _voiceActionInProgress ? null : _deleteVoiceNote,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AudioActionButton(
                    key: const Key('rerecordButton'),
                    tooltip: context.l10n.recordAgain,
                    icon: Icons.replay_rounded,
                    onPressed: _voiceActionInProgress ? null : _startRecording,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AudioActionButton(
                    key: const Key('playPauseButton'),
                    tooltip: _voiceNote.isPlaying
                        ? context.l10n.pauseAudio
                        : context.l10n.playAudio,
                    icon: _voiceNote.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    onPressed: _voiceActionInProgress ? null : _togglePlayback,
                  ),
                ),
              ],
            ),
          ],
          if (widget.plan.isPro) ...[
            const SizedBox(height: 12),
            Container(
              key: const Key('transcriptionDemo'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FolooPalette.of(context).paper,
                borderRadius: BorderRadius.circular(FolooRadii.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.transcriptionDemo,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _voiceNote.hasRecording
                        ? context.l10n.demoTranscript
                        : context.l10n.transcriptionPending,
                  ),
                ],
              ),
            ),
            // TODO(BACKEND/AUDIO): Connect recording/transcription when the audio feature is implemented.
          ],
          if (_voiceNote.isRecording) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('deleteVoiceNoteButton'),
                onPressed: _voiceActionInProgress ? null : _deleteVoiceNote,
                icon: const Icon(Icons.delete_outline),
                label: Text(context.l10n.cancelAndDelete),
                style: TextButton.styleFrom(
                  foregroundColor: FolooPalette.of(context).ink,
                ),
              ),
            ),
          ],
          if (_voiceNoteMessage != null) ...[
            const SizedBox(height: 6),
            Semantics(
              liveRegion: true,
              child: Text(
                _voiceNoteMessage!,
                key: const Key('voiceNoteMessage'),
                style: TextStyle(
                  color: _voiceNote.phase == VoiceNotePhase.idle
                      ? FolooPalette.of(context).error
                      : Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: 0.68),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _LabeledField(
            label: context.l10n.writtenNote,
            field: TextFormField(
              key: const Key('noteField'),
              controller: _note,
              decoration: InputDecoration(
                hintText: context.l10n.writtenNoteHint,
                border: FolooBorders.borderlessField,
                enabledBorder: FolooBorders.borderlessField,
                focusedBorder: FolooBorders.borderlessField,
              ),
              minLines: 4,
              maxLines: 7,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentSelectionPill extends StatelessWidget {
  const _ContentSelectionPill({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Semantics(
          button: true,
          selected: selected,
          child: Material(
            color: selected ? FolooSelection.surface(context) : palette.paper,
            shape: StadiumBorder(
              side: BorderSide(
                color: selected ? palette.ink : Colors.transparent,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              customBorder: const StadiumBorder(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 15,
                        color: selected ? palette.ink : palette.inkSecondary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected
                                ? palette.ink
                                : palette.inkSecondary,
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check, size: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioActionButton extends StatelessWidget {
  const _AudioActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: FolooPalette.of(context).paper,
      borderRadius: BorderRadius.circular(FolooRadii.sm),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(FolooRadii.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Icon(
            icon,
            size: 21,
            color: onPressed == null
                ? FolooPalette.of(context).inkMuted
                : FolooPalette.of(context).ink,
          ),
        ),
      ),
    ),
  );
}

class _RelationshipChoice extends StatelessWidget {
  const _RelationshipChoice({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final LeadType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      LeadType.supplier => context.l10n.supplier,
      LeadType.partner => context.l10n.partner,
      LeadType.customer => context.l10n.client,
    };
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        key: Key('leadType-${type.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 160),
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: selected
                ? FolooSelection.surface(context)
                : FolooPalette.of(context).paper,
            borderRadius: BorderRadius.circular(FolooRadii.sm),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                switch (type) {
                  LeadType.supplier => Icons.local_shipping_outlined,
                  LeadType.partner => Icons.people_outline,
                  LeadType.customer => Icons.person_add_alt_1_outlined,
                },
                color: selected
                    ? FolooSelection.foreground(context)
                    : Theme.of(context).colorScheme.onSurface,
                size: 18,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: type == LeadType.supplier ? 11 : 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.field});

  final String label;
  final Widget field;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: 0.75),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}

class _InterestDot extends StatelessWidget {
  const _InterestDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.active, required this.tick});

  final bool active;
  final int tick;
  static const heights = <double>[
    10,
    20,
    14,
    28,
    18,
    34,
    12,
    24,
    16,
    30,
    13,
    22,
  ];

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: active ? 0.68 : 0.18);
    return SizedBox(
      height: 34,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: heights.indexed
            .map(
              (entry) => AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                width: 3,
                height: active
                    ? entry.$2 *
                          (.58 +
                              .42 *
                                  math.sin((tick / 190) + entry.$1 * .82).abs())
                    : entry.$2 * 0.48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
