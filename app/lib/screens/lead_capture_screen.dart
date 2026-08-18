import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/lead_draft.dart';
import '../theme/foloo_theme.dart';
import '../widgets/progress_header.dart';
import '../widgets/section_card.dart';
import 'lead_confirmation_screen.dart';

class LeadCaptureScreen extends StatefulWidget {
  const LeadCaptureScreen({super.key});

  @override
  State<LeadCaptureScreen> createState() => _LeadCaptureScreenState();
}

class _LeadCaptureScreenState extends State<LeadCaptureScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  final _name = TextEditingController();
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
    for (final controller in [_name, _company, _email, _phone, _note]) {
      controller.addListener(_refreshProgress);
    }
  }

  @override
  void dispose() {
    _demoTimer?.cancel();
    _scrollController.dispose();
    for (final controller in [_name, _role, _company, _email, _phone, _note]) {
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

    fillIfEmpty(_name, 'Mariana Torres');
    fillIfEmpty(_role, 'Directora comercial');
    fillIfEmpty(_company, 'Norte Estudio');
    fillIfEmpty(_email, 'mariana@norte.example');
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
      name: _name.text.trim(),
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

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LeadConfirmationScreen(
          lead: lead,
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
    for (final controller in [_name, _role, _company, _email, _phone, _note]) {
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
    _scrollController.jumpTo(0);
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
      body: Column(
        children: [
          ProgressHeader(completed: _progress),
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
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
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
      bottomNavigationBar: keyboardVisible
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
                decoration: const BoxDecoration(
                  color: FolooColors.paper,
                  border: Border(top: BorderSide(color: FolooColors.line)),
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
                        icon: const Icon(Icons.check),
                        label: const Text('GUARDAR LEAD'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
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
      hint: 'Fotografía o elige una tarjeta. La lectura disponible aquí es solo una simulación de interfaz.',
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
                  key: const Key('cameraButton'),
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(_cardBytes == null ? 'CÁMARA' : 'CAMBIAR'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('galleryButton'),
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('GALERÍA'),
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
          TextFormField(
            key: const Key('nameField'),
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nombre *'),
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            validator: (value) => _required(value, 'El nombre es obligatorio'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _role,
            decoration: const InputDecoration(labelText: 'Puesto'),
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.jobTitle],
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('companyField'),
            controller: _company,
            decoration: const InputDecoration(labelText: 'Empresa *'),
            textInputAction: TextInputAction.next,
            validator: (value) => _required(value, 'La empresa es obligatoria'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('emailField'),
            controller: _email,
            decoration: const InputDecoration(labelText: 'Correo'),
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            validator: _validateEmail,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('phoneField'),
            controller: _phone,
            decoration: const InputDecoration(labelText: 'Teléfono'),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            validator: _validatePhone,
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
      hint: 'Define cómo continuar la conversación después del evento.',
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
            'INTERÉS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: InterestLevel.values
                .map(
                  (interest) => ChoiceChip(
                    label: Text(interest.label),
                    selected: _interest == interest,
                    onSelected: (_) => setState(() => _interest = interest),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<NextStep>(
            key: const Key('nextStepField'),
            isExpanded: true,
            initialValue: _nextStep,
            decoration: const InputDecoration(labelText: 'Siguiente paso *'),
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
      hint: 'La nota escrita siempre está disponible. No hay transcripción ni acceso real al micrófono en este prototipo.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAF7),
              border: Border.all(color: FolooColors.line),
              borderRadius: BorderRadius.circular(6),
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
                      minimumSize: const Size(56, 56),
                      backgroundColor: _demoRecording
                          ? FolooColors.error
                          : FolooColors.ink,
                    ),
                    icon: Icon(_demoRecording ? Icons.stop : Icons.mic),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GRABACIÓN SIMULADA · DEMO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
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
          TextFormField(
            key: const Key('noteField'),
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Texto de la nota',
              hintText: 'Escribe aquí lo importante de la conversación.',
              alignLabelWithHint: true,
            ),
            minLines: 4,
            maxLines: 7,
            textCapitalization: TextCapitalization.sentences,
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
          constraints: const BoxConstraints(minHeight: 126),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? FolooColors.cobalt.withValues(alpha: 0.08)
                : const Color(0xFFFAFAF7),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? FolooColors.cobalt : FolooColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? FolooColors.cobalt : FolooColors.ink,
              ),
              const SizedBox(height: 8),
              Text(
                type.label.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                type == LeadType.partner
                    ? 'Alianza, proveedor o canal'
                    : 'Puede comprar',
                style: TextStyle(
                  color: FolooColors.ink.withValues(alpha: 0.65),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
