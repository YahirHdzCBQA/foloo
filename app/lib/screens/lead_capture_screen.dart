import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_destination.dart';
import '../models/lead_draft.dart';
import '../models/session_lead.dart';
import '../models/voice_note_state.dart';
import '../services/card_text_recognition_service.dart';
import '../services/voice_note_service.dart';
import '../theme/foloo_theme.dart';
import '../utils/business_card_parser.dart';
import '../widgets/app_drawer.dart';
import '../widgets/progress_header.dart';
import '../widgets/section_card.dart';
import 'lead_confirmation_screen.dart';

class LeadCaptureScreen extends StatefulWidget {
  const LeadCaptureScreen({
    required this.recordsCount,
    required this.darkMode,
    required this.onLeadSaved,
    required this.onDestinationSelected,
    required this.onAppearanceChanged,
    required this.onLogout,
    this.voiceNoteService,
    super.key,
  });

  final int recordsCount;
  final bool darkMode;
  final SessionLead Function(LeadDraft lead) onLeadSaved;
  final ValueChanged<AppDestination> onDestinationSelected;
  final ValueChanged<bool> onAppearanceChanged;
  final VoidCallback onLogout;
  final VoiceNoteService? voiceNoteService;

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
  late final VoiceNoteService _voiceNoteService;
  late final StreamSubscription<void> _playbackCompletedSubscription;

  Uint8List? _cardBytes;
  String? _cardPath;
  String? _cardName;
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
  NextStep? _nextStep;
  bool _showValidation = false;
  VoiceNoteState _voiceNote = const VoiceNoteState();
  String? _voiceNoteMessage;
  bool _voiceActionInProgress = false;
  bool _voiceNoteTransferred = false;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voiceNoteService = widget.voiceNoteService ?? DeviceVoiceNoteService();
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
    ]) {
      controller.addListener(_refreshProgress);
    }
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
        _cardName = image.name;
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
      _cardName = null;
      _imageMessage = null;
      _ocrFailed = false;
    });
  }

  Future<void> _readCard(String imagePath) async {
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
            ? 'Tarjeta leída. Revisa los datos.'
            : 'Lectura completada. Completa los datos faltantes manualmente.';
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
    final relationshipValid = _leadType != null && _nextStep != null;
    if (!fieldsValid || !relationshipValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisa los campos marcados antes de continuar.'),
        ),
      );
      return;
    }

    final lead = LeadDraft(
      // UI-only split: the conceptual model still has one `nombre` field.
      name: '${_name.text.trim()} ${_lastName.text.trim()}'.trim(),
      role: _role.text.trim(),
      company: _company.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      type: _leadType!,
      interest: _interest,
      nextStep: _nextStep!,
      note: _note.text.trim(),
      audioLocalPath: _voiceNote.hasRecording ? _voiceNote.localPath : null,
      audioSeconds: _voiceNote.hasRecording ? _voiceNote.elapsed.inSeconds : 0,
    );
    final record = widget.onLeadSaved(lead);
    _voiceNoteTransferred = lead.hasVoiceNote;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LeadConfirmationScreen(
          record: record,
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
      _cardName = null;
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
      _nextStep = null;
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
    _leadType != null && _nextStep != null,
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
                    label: const Text('Guardar y enviar'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardSection() {
    return SectionCard(
      key: const Key('cardSection'),
      number: '01',
      title: 'La tarjeta',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_cardBytes != null) ...[
            Semantics(
              label: 'Vista previa de la tarjeta seleccionada',
              image: true,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AspectRatio(
                  aspectRatio: 1.7,
                  child: Image.memory(
                    _cardBytes!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _cardName ?? 'Tarjeta seleccionada',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: _isReadingCard ? null : _removeImage,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Quitar'),
                ),
              ],
            ),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('galleryButton'),
                  onPressed: _isReadingCard
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Elegir de galería'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('cameraButton'),
                  onPressed: _isReadingCard
                      ? null
                      : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(
                    _cardBytes == null ? 'Tomar foto' : 'Cambiar foto',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                  ),
                ),
              ),
            ],
          ),
          if (_cardBytes != null) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              key: const Key('readCardButton'),
              onPressed: _isReadingCard || _cardPath == null
                  ? null
                  : () => _readCard(_cardPath!),
              icon: _isReadingCard
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.document_scanner_outlined),
              label: Text(_isReadingCard ? 'LEYENDO TARJETA…' : 'LEER TARJETA'),
            ),
          ],
          if (_imageMessage != null) ...[
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Text(
                _imageMessage!,
                style: TextStyle(
                  color: _ocrFailed || _cardBytes == null
                      ? FolooColors.error
                      : FolooColors.pine,
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
      title: 'Relación',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: LeadType.values.map((type) {
              final selected = _leadType == type;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: type == LeadType.partner ? 5 : 0,
                    left: type == LeadType.partner ? 0 : 5,
                  ),
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
              'Elige Partner o Cliente potencial',
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
          Row(
            children:
                [
                  InterestLevel.low,
                  InterestLevel.medium,
                  InterestLevel.high,
                ].map((interest) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: interest == InterestLevel.high ? 0 : 6,
                      ),
                      child: _InterestChoice(
                        interest: interest,
                        selected: _interest == interest,
                        onTap: () => setState(() => _interest = interest),
                      ),
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 14),
          const Text(
            'SIGUIENTE PASO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<NextStep>(
            key: const Key('nextStepField'),
            isExpanded: true,
            initialValue: _nextStep,
            decoration: const InputDecoration(
              hintText: 'Selecciona una opción',
            ),
            items: NextStep.values
                .map(
                  (step) =>
                      DropdownMenuItem(value: step, child: Text(step.label)),
                )
                .toList(),
            onChanged: (value) => setState(() => _nextStep = value),
            validator: (value) =>
                value == null ? 'Selecciona el siguiente paso' : null,
          ),
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
      title: 'Nota de la plática',
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
          // TODO(BACKEND/AUDIO): Upload the local voice note and connect server-side transcription.
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
                  icon: const Icon(Icons.mic_none),
                  label: const Text('VOLVER A GRABAR'),
                ),
                TextButton.icon(
                  key: const Key('deleteVoiceNoteButton'),
                  onPressed: _voiceActionInProgress ? null : _deleteVoiceNote,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('BORRAR AUDIO'),
                ),
              ],
            ),
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
                      ? FolooColors.error
                      : Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: 0.68),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _LabeledField(
            label: 'TEXTO DE LA NOTA',
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
          const SizedBox(height: 8),
          Text(
            'La transcripción automática requiere el backend y aún no está disponible.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.55),
              fontSize: 10,
              fontWeight: FontWeight.w600,
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
          height: 148,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? FolooColors.lime.withValues(alpha: 0.34)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: FolooColors.ink,
                      offset: Offset(0, 3),
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                type == LeadType.partner
                    ? Icons.people_outline
                    : Icons.person_add_alt_1_outlined,
                color: selected
                    ? FolooColors.success
                    : Theme.of(context).colorScheme.onSurface,
              ),
              const Spacer(),
              Text(
                type.label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: type == LeadType.potentialCustomer ? 17 : 18,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                type == LeadType.partner ? 'CANAL / ALIANZA' : 'COMPRA DIRECTA',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.5),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
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

class _InterestChoice extends StatelessWidget {
  const _InterestChoice({
    required this.interest,
    required this.selected,
    required this.onTap,
  });

  final InterestLevel interest;
  final bool selected;
  final VoidCallback onTap;

  Color get color => switch (interest) {
    InterestLevel.low => FolooColors.success,
    InterestLevel.medium => const Color(0xFFFFD900),
    InterestLevel.high => const Color(0xFFFF3217),
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Interés ${interest.label}',
      child: InkWell(
        key: Key('interest-${interest.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 76),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : color.withValues(alpha: 0.5),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [BoxShadow(color: color, offset: const Offset(0, 5))]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(height: 7),
              Text(
                interest.label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
