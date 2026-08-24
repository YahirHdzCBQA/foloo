import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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
import '../utils/business_card_parser.dart';
import '../widgets/app_drawer.dart';
import '../widgets/create_event_dialog.dart';
import '../widgets/progress_header.dart';
import '../widgets/section_card.dart';
import '../widgets/segmented_bubble.dart';
import 'lead_confirmation_screen.dart';

typedef LeadOriginChanged = void Function(LeadOriginKind kind, AppEvent? event);

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
    this.eventName,
    this.initialPlace,
    this.voiceNoteService,
    super.key,
  });

  final LeadOriginKind originKind;
  final String? eventName;
  final String? initialPlace;
  final List<AppEvent> events;
  final int recordsCount;
  final bool darkMode;
  final SessionLead Function(LeadDraft lead) onLeadSaved;
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
        _imageMessage = 'Leyendo tarjeta…';
        _ocrFailed = false;
      });
      await _readCard(image.path);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _imageMessage = 'No se pudo abrir la imagen. Puedes continuar capturando los datos a mano.';
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

  Future<void> _readCard(String imagePath) async {
    // Demo-only local extraction. OCR-03 keeps production extraction behind
    // the Foloo backend boundary.
    if (_isReadingCard) return;
    setState(() {
      _isReadingCard = true;
      _ocrFailed = false;
      _imageMessage = 'Leyendo tarjeta…';
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
            ? 'Lectura demo completada. Revisa los datos.'
            : 'Lectura demo completada. Completa los datos faltantes manualmente.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ocrFailed = true;
        _imageMessage =
            'No se pudo leer la tarjeta. Puedes continuar manualmente.';
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
        _voiceNoteMessage = 'Permiso de micrófono rechazado. Puedes continuar con la nota escrita.';
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
        _voiceNoteMessage = 'No se pudo iniciar la grabación. Puedes continuar con la nota escrita.';
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
          _voiceNoteMessage = 'No se pudo conservar la grabación. La nota escrita sigue disponible.';
        });
        return;
      }
      final elapsed = _voiceNote.elapsed;
      setState(() {
        _voiceNote = _voiceNote.finishRecording(path, elapsed);
        _voiceNoteMessage = 'Nota de voz guardada localmente.';
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
        _voiceNoteMessage = 'No se pudo terminar la grabación. Puedes continuar con la nota escrita.';
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
          _voiceNoteMessage = 'No se pudo reproducir el audio. Puedes borrarlo o volver a grabar.';
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
        _voiceNoteMessage =
            'No se pudo pausar el audio. Puedes reproducirlo de nuevo.';
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
        _voiceNoteMessage = 'Audio borrado. Puedes volver a grabar.';
        _voiceNoteTransferred = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _voiceNoteMessage =
              'No se pudo borrar el audio. Inténtalo nuevamente.';
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
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String? _required(String? value, String message) {
    return value == null || value.trim().isEmpty ? message : null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      if (_phone.text.trim().isEmpty) return 'Escribe correo o teléfono';
      return null;
    }
    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    return valid ? null : 'Revisa el formato del correo';
  }

  String? _validatePhone(String? value) {
    if ((value?.trim().isEmpty ?? true) && _email.text.trim().isEmpty) {
      return 'Escribe teléfono o correo';
    }
    return null;
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisa los campos marcados antes de continuar.'),
        ),
      );
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
      eventName: widget.eventName,
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
    final record = widget.onLeadSaved(lead);
    _voiceNoteTransferred = lead.hasVoiceNote;

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
                      widget.plan.isPro ? 'Guarda y da “foloo”' : 'Guardar',
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(FolooRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Origen del lead',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: SegmentedBubble<LeadOriginKind>(
                key: const Key('captureOriginBubble'),
                selectedHorizontalInset: 22,
                selected: widget.originKind,
                onSelected: _changeOrigin,
                options: const [
                  SegmentedBubbleOption(
                    key: Key('captureOriginEventTab'),
                    value: LeadOriginKind.event,
                    label: 'Evento',
                    leading: Icon(Icons.calendar_today_outlined, size: 15),
                  ),
                  SegmentedBubbleOption(
                    key: Key('captureOriginDirectTab'),
                    value: LeadOriginKind.direct,
                    label: 'Lead directo',
                    leading: Icon(Icons.person_outline, size: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (direct)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Se guarda sin evento, en tu base general de leads.',
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
                    decoration: const InputDecoration(labelText: 'Lugar'),
                    validator: (value) => _required(
                      value,
                      'Escribe dónde surgió la conversación',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Dónde surgió la conversación. Sustituye {lugar} en el correo demo.',
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
                        hint: const Text('Selecciona un evento'),
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
                  tooltip: 'Crear evento',
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
                '${_formatEventDate(selectedEvent.startsOn)} · el más reciente. Si no está, agrégalo con +.',
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
      title: 'La tarjeta',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Semantics(
                  label: hasCard
                      ? 'Vista previa de la tarjeta seleccionada'
                      : 'Sin foto de tarjeta',
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
                  hasCard ? 'Tarjeta lista · datos aplicados' : 'Sin foto aún',
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
                tooltip: 'Elegir de galería',
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
                tooltip: hasCard ? 'Cambiar foto' : 'Tomar foto',
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
                  label: Text(
                    _isReadingCard ? 'Leyendo tarjeta…' : 'Reprocesar',
                  ),
                ),
                const Spacer(),
                TextButton(
                  key: const Key('removeCardButton'),
                  onPressed: _isReadingCard ? null : _removeImage,
                  style: TextButton.styleFrom(foregroundColor: palette.ink),
                  child: const Text('Quitar'),
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
    return SectionCard(
      key: const Key('dataSection'),
      number: '02',
      title: 'Datos del lead',
      trailing: TextButton(
        key: const Key('clearLeadFieldsButton'),
        onPressed: _clearLeadFields,
        style: TextButton.styleFrom(
          foregroundColor: FolooPalette.of(context).inkSecondary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        child: const Text('Limpiar'),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _LabeledField(
                  label: 'NOMBRE',
                  field: TextFormField(
                    key: const Key('nameField'),
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.givenName],
                    onChanged: (_) => _nameEdited = true,
                    validator: (value) =>
                        _required(value, 'El nombre es obligatorio'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LabeledField(
                  label: 'APELLIDO',
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
            label: 'PUESTO',
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
            label: 'EMPRESA',
            field: TextFormField(
              key: const Key('companyField'),
              controller: _company,
              textInputAction: TextInputAction.next,
              onChanged: (_) => _companyEdited = true,
              validator: (value) =>
                  _required(value, 'La empresa es obligatoria'),
            ),
          ),
          const SizedBox(height: 16),
          _LabeledField(
            label: 'CORREO',
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
            label: 'TELÉFONO',
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
    );
  }

  Widget _buildRelationshipSection() {
    return SectionCard(
      key: const Key('relationshipSection'),
      number: '03',
      title: 'Tipo de Lead',
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
            const Text(
              'Elige Proveedor, Partner o Cliente',
              style: TextStyle(color: FolooColors.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 18),
          const Text(
            'NIVEL DE INTERÉS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: SegmentedBubble<InterestLevel>(
                key: const Key('interestBubble'),
                selected: _interest,
                onSelected: (value) => setState(() => _interest = value),
                options: const [
                  SegmentedBubbleOption(
                    key: Key('interest-low'),
                    value: InterestLevel.low,
                    label: 'Bajo',
                    leading: _InterestDot(color: FolooColors.interestLow),
                  ),
                  SegmentedBubbleOption(
                    key: Key('interest-medium'),
                    value: InterestLevel.medium,
                    label: 'Medio',
                    leading: _InterestDot(color: FolooColors.interestMedium),
                  ),
                  SegmentedBubbleOption(
                    key: Key('interest-high'),
                    value: InterestLevel.high,
                    label: 'Alto',
                    leading: _InterestDot(color: FolooColors.interestHigh),
                  ),
                ],
              ),
            ),
          ),
          if (widget.plan.isPro &&
              widget.originKind == LeadOriginKind.event &&
              _defaultContentForEvent.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'CONTENIDO A COMPARTIR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 7),
            ..._defaultContentForEvent.map(
              (file) => CheckboxListTile(
                key: Key('captureContent-${file.id}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _selectedContentIds.contains(file.id),
                title: Text(file.displayName),
                subtitle: Text(file.sizeLabel),
                onChanged: (value) => setState(() {
                  if (value ?? false) {
                    _selectedContentIds.add(file.id);
                  } else {
                    _selectedContentIds.remove(file.id);
                  }
                }),
              ),
            ),
            Text(
              '${_selectedContentIds.length} de ${_defaultContentForEvent.length} archivos se adjuntan al correo demo.',
              style: TextStyle(
                color: FolooPalette.of(context).inkSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoteSection() {
    final status = switch (_voiceNote.phase) {
      VoiceNotePhase.idle => 'Listo para grabar',
      VoiceNotePhase.recording =>
        'Grabando · ${_formatDuration(_voiceNote.elapsed)}',
      VoiceNotePhase.recorded =>
        'Nota de voz · ${_formatDuration(_voiceNote.elapsed)}',
      VoiceNotePhase.playing =>
        'Reproduciendo · ${_formatDuration(_voiceNote.elapsed)}',
      VoiceNotePhase.paused =>
        'Reproducción pausada · ${_formatDuration(_voiceNote.elapsed)}',
    };
    return SectionCard(
      key: const Key('noteSection'),
      number: '04',
      title: widget.plan.isPro
          ? 'Nota de voz (opcional)'
          : 'Nota de la plática',
      trailing: _voiceNote.isRecording
          ? const Text(
              '● GRABANDO',
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
          // TODO(BACKEND/AUDIO): Upload the local voice note when media delivery is implemented.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.45),
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: _voiceNote.isRecording
                      ? 'Detener grabación'
                      : _voiceNote.hasRecording
                      ? 'Volver a grabar'
                      : 'Iniciar grabación',
                  child: IconButton.filled(
                    key: const Key('recordButton'),
                    onPressed: _voiceActionInProgress ? null : _toggleRecording,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(64, 64),
                      backgroundColor: _voiceNote.isRecording
                          ? FolooColors.error
                          : FolooColors.ink,
                      foregroundColor: Colors.white,
                    ),
                    icon: _voiceActionInProgress
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(_voiceNote.isRecording ? Icons.stop : Icons.mic),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Waveform(
                        active: _voiceNote.isRecording || _voiceNote.isPlaying,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _voiceNote.isRecording
                                  ? 'Micrófono activo'
                                  : _voiceNote.hasRecording
                                  ? 'Audio guardado localmente'
                                  : 'Toca para grabar',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(_voiceNote.elapsed),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          status,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_voiceNote.hasRecording) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  key: const Key('playPauseButton'),
                  onPressed: _voiceActionInProgress ? null : _togglePlayback,
                  icon: Icon(
                    _voiceNote.isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                  label: Text(_voiceNote.isPlaying ? 'PAUSAR' : 'REPRODUCIR'),
                ),
                TextButton.icon(
                  key: const Key('rerecordButton'),
                  onPressed: _voiceActionInProgress ? null : _startRecording,
                  style: TextButton.styleFrom(
                    foregroundColor: FolooPalette.of(context).ink,
                  ),
                  icon: const Icon(Icons.mic_none),
                  label: const Text('Volver a grabar'),
                ),
                TextButton.icon(
                  key: const Key('deleteVoiceNoteButton'),
                  onPressed: _voiceActionInProgress ? null : _deleteVoiceNote,
                  style: TextButton.styleFrom(
                    foregroundColor: FolooPalette.of(context).ink,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Borrar audio'),
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
                  const Text(
                    'TRANSCRIPCIÓN · DEMO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _voiceNote.hasRecording ? DemoProData.transcript : 'Pendiente. Aparecerá después de guardar la nota de voz.',
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
                label: const Text('CANCELAR Y BORRAR'),
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
            label: 'Nota escrita',
            field: TextFormField(
              key: const Key('noteField'),
              controller: _note,
              decoration: const InputDecoration(
                hintText: 'Escribe aquí lo importante de la conversación.',
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
    return Semantics(
      button: true,
      selected: selected,
      label: type.label,
      child: InkWell(
        key: Key('leadType-${type.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 160),
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: selected
                ? FolooColors.limeTint
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
                  LeadType.supplier => Icons.inventory_2_outlined,
                  LeadType.partner => Icons.people_outline,
                  LeadType.customer => Icons.person_add_alt_1_outlined,
                },
                color: selected
                    ? FolooColors.ink
                    : Theme.of(context).colorScheme.onSurface,
                size: 18,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  type.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: type == LeadType.supplier ? 11 : 12,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 4),
                const Icon(Icons.check_circle, size: 14),
              ],
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
  const _Waveform({required this.active});

  final bool active;
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
    final color = active
        ? FolooColors.error
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.42);
    return SizedBox(
      height: 34,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: heights
            .map(
              (height) => AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                width: 3,
                height: active ? height : height * 0.55,
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
