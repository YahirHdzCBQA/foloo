import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_destination.dart';
import '../models/lead_draft.dart';
import '../models/session_lead.dart';
import '../theme/foloo_theme.dart';
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
    super.key,
  });

  final int recordsCount;
  final bool darkMode;
  final SessionLead Function(LeadDraft lead) onLeadSaved;
  final ValueChanged<AppDestination> onDestinationSelected;
  final ValueChanged<bool> onAppearanceChanged;
  final VoidCallback onLogout;

  @override
  State<LeadCaptureScreen> createState() => _LeadCaptureScreenState();
}

class _LeadCaptureScreenState extends State<LeadCaptureScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  final _name = TextEditingController();
  final _lastName = TextEditingController();
  final _role = TextEditingController();
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();

  Uint8List? _cardBytes;
  String? _cardName;
  String? _imageMessage;
  LeadType? _leadType;
  InterestLevel _interest = InterestLevel.medium;
  NextStep? _nextStep;
  bool _showValidation = false;
  bool _demoRecording = false;
  bool _hasDemoAudio = false;
  int _demoSeconds = 0;
  Timer? _demoTimer;

  @override
  void initState() {
    super.initState();
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
    _demoTimer?.cancel();
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
        _cardName = image.name;
        _imageMessage = 'Imagen lista. La lectura automática no está conectada en este prototipo.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _imageMessage = 'No se pudo abrir la imagen. Puedes continuar capturando los datos a mano.';
      });
    }
  }

  void _removeImage() {
    setState(() {
      _cardBytes = null;
      _cardName = null;
      _imageMessage = null;
    });
  }

  void _simulateReading() {
    void fillIfEmpty(TextEditingController controller, String value) {
      if (controller.text.trim().isEmpty) controller.text = value;
    }

    fillIfEmpty(_name, 'Mariana');
    fillIfEmpty(_lastName, 'Sandoval Ruiz');
    fillIfEmpty(_role, 'Gerente de calidad');
    fillIfEmpty(_company, 'Grupo Lácteo del Norte');
    fillIfEmpty(_email, 'm.sandoval@lacteosnorte.mx');
    fillIfEmpty(_phone, '55 1234 5678');
    setState(() {
      _imageMessage = 'Demo completada. Revisa y edita todos los campos.';
    });
  }

  void _toggleDemoRecording() {
    if (_demoRecording) {
      _demoTimer?.cancel();
      setState(() {
        _demoRecording = false;
        _hasDemoAudio = _demoSeconds > 0;
      });
      return;
    }

    setState(() {
      _demoRecording = true;
      _hasDemoAudio = false;
      _demoSeconds = 0;
    });
    _demoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _demoSeconds++);
    });
  }

  void _deleteDemoAudio() {
    _demoTimer?.cancel();
    setState(() {
      _demoRecording = false;
      _hasDemoAudio = false;
      _demoSeconds = 0;
    });
  }

  String _formatDuration(int seconds) {
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

  void _submit() {
    FocusManager.instance.primaryFocus?.unfocus();
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
      demoAudioSeconds: _hasDemoAudio ? _demoSeconds : 0,
    );
    final record = widget.onLeadSaved(lead);

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
    _demoTimer?.cancel();
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
      _cardName = null;
      _imageMessage = null;
      _leadType = null;
      _interest = InterestLevel.medium;
      _nextStep = null;
      _showValidation = false;
      _demoRecording = false;
      _hasDemoAudio = false;
      _demoSeconds = 0;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  List<bool> get _progress => [
    _cardBytes != null,
    _name.text.trim().isNotEmpty &&
        _company.text.trim().isNotEmpty &&
        (_email.text.trim().isNotEmpty || _phone.text.trim().isNotEmpty),
    _leadType != null && _nextStep != null,
    _note.text.trim().isNotEmpty || _hasDemoAudio || _demoRecording,
  ];

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: AppDrawer(
        activeDestination: AppDestination.home,
        recordsCount: widget.recordsCount,
        darkMode: widget.darkMode,
        onDestinationSelected: widget.onDestinationSelected,
        onAppearanceChanged: widget.onAppearanceChanged,
        onLogout: widget.onLogout,
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
                  onPressed: _removeImage,
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
                  onPressed: () => _pickImage(ImageSource.gallery),
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
                  onPressed: () => _pickImage(ImageSource.camera),
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
              key: const Key('simulateReadingButton'),
              onPressed: _simulateReading,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('SIMULAR LECTURA · DEMO'),
            ),
          ],
          if (_imageMessage != null) ...[
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Text(
                _imageMessage!,
                style: TextStyle(
                  color: _cardBytes == null
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
            ),
          ),
          const SizedBox(height: 16),
          _LabeledField(
            label: 'EMPRESA',
            field: TextFormField(
              key: const Key('companyField'),
              controller: _company,
              textInputAction: TextInputAction.next,
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
    final status = _demoRecording
        ? 'Grabando demo · ${_formatDuration(_demoSeconds)}'
        : _hasDemoAudio
        ? 'Audio demo detenido · ${_formatDuration(_demoSeconds)}'
        : 'Listo para simular';
    return SectionCard(
      key: const Key('noteSection'),
      number: '04',
      title: 'Nota de la plática',
      trailing: _demoRecording
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
          // TODO(BACKEND/AUDIO): Connect recording/transcription when the audio feature is implemented.
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
                  label: _demoRecording
                      ? 'Detener grabación simulada'
                      : 'Iniciar grabación simulada',
                  child: IconButton.filled(
                    key: const Key('demoRecordButton'),
                    onPressed: _toggleDemoRecording,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(64, 64),
                      backgroundColor: _demoRecording
                          ? FolooColors.error
                          : FolooColors.ink,
                      foregroundColor: Colors.white,
                    ),
                    icon: Icon(_demoRecording ? Icons.stop : Icons.mic),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Waveform(active: _demoRecording),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _demoRecording
                                  ? 'Grabación simulada'
                                  : _hasDemoAudio
                                  ? 'Audio demo listo'
                                  : 'Toca para grabar',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(_demoSeconds),
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
          if (_hasDemoAudio || _demoRecording) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('deleteDemoAudioButton'),
                onPressed: _deleteDemoAudio,
                icon: const Icon(Icons.delete_outline),
                label: const Text('BORRAR DEMO'),
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
