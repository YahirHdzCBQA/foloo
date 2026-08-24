import 'package:flutter/material.dart';

import '../models/app_destination.dart';
import '../models/app_event.dart';
import '../models/app_plan.dart';
import '../models/lead_draft.dart';
import '../models/pro_demo_data.dart';
import '../models/session_lead.dart';
import '../theme/foloo_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_screen_header.dart';
import '../widgets/segmented_bubble.dart';

enum _TemplateKind { event, direct }

class EmailScreen extends StatefulWidget {
  const EmailScreen({
    required this.recordsCount,
    required this.profile,
    required this.darkMode,
    required this.onDestinationSelected,
    required this.onAppearanceChanged,
    required this.onLogout,
    required this.contentCount,
    required this.records,
    required this.contentFiles,
    super.key,
  });
  final int recordsCount;
  final DemoProfile profile;
  final bool darkMode;
  final ValueChanged<AppDestination> onDestinationSelected;
  final ValueChanged<bool> onAppearanceChanged;
  final VoidCallback onLogout;
  final int contentCount;
  final List<SessionLead> records;
  final List<ContentFile> contentFiles;

  @override
  State<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends State<EmailScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _eventSubject = TextEditingController(text: 'Seguimiento · {evento}');
  final _directSubject = TextEditingController(text: 'Seguimiento · {lugar}');
  final _eventBody = TextEditingController(
    text: 'Hola {nombre},\n\nGusto en coincidir en {evento}. Te comparto la información que platicamos:\n\n{contenido}\n\nQuedo al pendiente.\n\nSaludos,\n{capturadoPor}',
  );
  final _directBody = TextEditingController(
    text: 'Hola {nombre},\n\nGusto en coincidir en {lugar}. Te comparto la información que platicamos:\n\n{contenido}\n\nQuedo al pendiente.\n\nSaludos,\n{capturadoPor}',
  );
  _TemplateKind _kind = _TemplateKind.event;
  String? _error;

  TextEditingController get _subject =>
      _kind == _TemplateKind.event ? _eventSubject : _directSubject;
  TextEditingController get _body =>
      _kind == _TemplateKind.event ? _eventBody : _directBody;
  List<String> get _variables => _kind == _TemplateKind.event
      ? const [
          '{nombre}',
          '{empresa}',
          '{evento}',
          '{contenido}',
          '{capturadoPor}',
        ]
      : const [
          '{nombre}',
          '{empresa}',
          '{lugar}',
          '{contenido}',
          '{capturadoPor}',
        ];

  @override
  void dispose() {
    for (final controller in [
      _eventSubject,
      _directSubject,
      _eventBody,
      _directBody,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _insert(String variable) {
    final selection = _body.selection;
    final offset = selection.isValid ? selection.start : _body.text.length;
    _body.text = _body.text.replaceRange(
      offset,
      selection.isValid ? selection.end : offset,
      variable,
    );
    _body.selection = TextSelection.collapsed(offset: offset + variable.length);
    setState(() {});
  }

  void _save() {
    final allowed = _variables.toSet();
    final found = RegExp(r'\{[^}]+\}')
        .allMatches('${_subject.text} ${_body.text}')
        .map((m) => m.group(0)!)
        .toSet();
    final invalid = found.difference(allowed);
    final source = '${_subject.text} ${_body.text}';
    final bracesBalanced =
        RegExp(r'\{').allMatches(source).length ==
        RegExp(r'\}').allMatches(source).length;
    setState(
      () => _error = !bracesBalanced
          ? 'Hay una variable con llaves sin cerrar.'
          : invalid.isEmpty
          ? null
          : 'Variable no válida: ${invalid.join(', ')}',
    );
    if (_error == null) {
      // TODO(BACKEND): Persist account email templates and send from the server.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plantilla guardada solo en esta demo.')),
      );
    }
  }

  SessionLead? get _previewRecord {
    final origin = _kind == _TemplateKind.event
        ? LeadOriginKind.event
        : LeadOriginKind.direct;
    for (final record in widget.records) {
      if (record.lead.originKind == origin) return record;
    }
    return null;
  }

  String _preview(String value) {
    final lead = _previewRecord?.lead;
    final attachments = lead == null
        ? '• Scanley IMS · Ficha técnica · 1.2 MB\n• Vision AI · Casos de uso · 940 KB'
        : lead.contentNames.isEmpty
        ? 'Sin archivos adjuntos'
        : [
            for (var index = 0; index < lead.contentNames.length; index++)
              '• ${lead.contentNames[index]}${index < lead.contentFileIds.length ? _sizeFor(lead.contentFileIds[index]) : ''}',
          ].join('\n');
    return value
        .replaceAll('{nombre}', lead?.name ?? 'Mariana')
        .replaceAll('{empresa}', lead?.company ?? 'Grupo Lácteo del Norte')
        .replaceAll('{evento}', lead?.eventName ?? 'Expo Alimentaria México')
        .replaceAll('{lugar}', lead?.place ?? 'Oficinas de Grupo Lácteo')
        .replaceAll('{contenido}', attachments)
        .replaceAll('{capturadoPor}', widget.profile.name);
  }

  String _sizeFor(String id) {
    for (final file in widget.contentFiles) {
      if (file.id == id) return ' · ${file.sizeLabel}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: AppDrawer(
        plan: AppPlan.pro,
        contentCount: widget.contentCount,
        profile: widget.profile,
        activeDestination: AppDestination.email,
        recordsCount: widget.recordsCount,
        darkMode: widget.darkMode,
        onDestinationSelected: widget.onDestinationSelected,
        onAppearanceChanged: widget.onAppearanceChanged,
        onLogout: widget.onLogout,
      ),
      body: Column(
        children: [
          AppScreenHeader(
            title: 'Correo',
            subtitle: _kind == _TemplateKind.event
                ? 'PLANTILLA DE EVENTO'
                : 'PLANTILLA · LEADS DIRECTOS',
            badge: 'PRO',
            onMenuPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedBubble<_TemplateKind>(
                    key: const Key('emailTemplateBubble'),
                    selected: _kind,
                    onSelected: (value) => setState(() {
                      _kind = value;
                      _error = null;
                    }),
                    options: const [
                      SegmentedBubbleOption(
                        value: _TemplateKind.event,
                        label: 'Evento',
                        leading: Icon(Icons.calendar_today_outlined, size: 15),
                      ),
                      SegmentedBubbleOption(
                        value: _TemplateKind.direct,
                        label: 'Lead directo',
                        leading: Icon(
                          Icons.person_add_alt_1_outlined,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    key: ValueKey('emailSubject-${_kind.name}'),
                    controller: _subject,
                    decoration: const InputDecoration(labelText: 'Asunto'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: ValueKey('emailBody-${_kind.name}'),
                    controller: _body,
                    minLines: 8,
                    maxLines: 12,
                    decoration: const InputDecoration(labelText: 'Cuerpo'),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        key: const Key('emailVariableError'),
                        style: TextStyle(color: FolooPalette.of(context).error),
                      ),
                    ),
                  const SizedBox(height: 14),
                  const Text(
                    'Variables',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: _variables
                        .map(
                          (value) => ActionChip(
                            key: Key('variable-$value'),
                            label: Text(value),
                            onPressed: () => _insert(value),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Previsualización',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    key: const Key('emailPreview'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FolooPalette.of(context).paper,
                      borderRadius: BorderRadius.circular(FolooRadii.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Para: ${_previewRecord?.lead.fullName ?? 'Mariana Sandoval Ruiz'}',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _preview(_subject.text),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const Divider(height: 24),
                        Text(_preview(_body.text)),
                        const SizedBox(height: 18),
                        Text(
                          '${_previewRecord == null ? 'Fixture demo' : 'Con los datos del último lead capturado'} · El aviso de privacidad y la baja se agregan del lado del servidor.',
                          style: TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: FilledButton(
            key: const Key('saveEmailTemplateButton'),
            onPressed: _save,
            child: const Text('Guardar plantilla'),
          ),
        ),
      ),
    );
  }
}
