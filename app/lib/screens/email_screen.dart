/// Pro-only email-template editor and deterministic preview.
///
/// Edits remain in memory; no message is sent and Basic accounts must not see
/// this destination (PLT-* / RNF-18).
library;

import 'package:flutter/material.dart';

import '../models/app_destination.dart';
import '../models/app_event.dart';
import '../models/lead_draft.dart';
import '../models/pro_demo_data.dart';
import '../models/session_lead.dart';
import '../theme/foloo_theme.dart';
import '../l10n/l10n.dart';
import '../widgets/module_header.dart';
import '../widgets/segmented_bubble.dart';

enum _TemplateKind { event, direct }

/// Edits the event or direct-lead Pro template for the current demo session.
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
  final _eventSubject = TextEditingController();
  final _directSubject = TextEditingController();
  final _eventBody = TextEditingController();
  final _directBody = TextEditingController();
  _TemplateKind _kind = _TemplateKind.event;
  String? _error;
  String? _previousEventSubject;
  String? _previousDirectSubject;
  String? _previousEventBody;
  String? _previousDirectBody;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = context.l10n;
    final eventSubject = l10n.defaultEmailSubject('{evento}');
    final directSubject = l10n.defaultEmailSubject('{lugar}');
    final eventBody = l10n.defaultEmailBody(
      '{capturadoPor}',
      '{contenido}',
      '{evento}',
      '{nombre}',
    );
    final directBody = l10n.defaultEmailBody(
      '{capturadoPor}',
      '{contenido}',
      '{lugar}',
      '{nombre}',
    );
    _replaceDefault(_eventSubject, _previousEventSubject, eventSubject);
    _replaceDefault(_directSubject, _previousDirectSubject, directSubject);
    _replaceDefault(_eventBody, _previousEventBody, eventBody);
    _replaceDefault(_directBody, _previousDirectBody, directBody);
    _previousEventSubject = eventSubject;
    _previousDirectSubject = directSubject;
    _previousEventBody = eventBody;
    _previousDirectBody = directBody;
  }

  void _replaceDefault(
    TextEditingController controller,
    String? previous,
    String next,
  ) {
    if (controller.text.isEmpty || controller.text == previous) {
      controller.text = next;
    }
  }

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

  /// Inserts a supported token at the current caret without changing its name.
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
          ? context.l10n.unclosedVariable
          : invalid.isEmpty
          ? null
          : context.l10n.invalidVariable(invalid.join(', ')),
    );
    if (_error == null) {
      // TODO(PRODUCTION): Persist PLT-* templates and send through the backend.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.templateSavedDemo)));
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

  /// Produces a local preview from known fixtures; it is not delivery output.
  String _preview(String value) {
    final lead = _previewRecord?.lead;
    final attachments = lead == null
        ? context.l10n.demoAttachments
        : lead.contentNames.isEmpty
        ? context.l10n.noAttachments
        : [
            for (var index = 0; index < lead.contentNames.length; index++)
              '• ${lead.contentNames[index]}${index < lead.contentFileIds.length ? _sizeFor(lead.contentFileIds[index]) : ''}',
          ].join('\n');
    return value
        .replaceAll('{nombre}', lead?.name ?? 'Mariana')
        .replaceAll('{empresa}', lead?.company ?? 'Grupo Lácteo del Norte')
        .replaceAll('{evento}', lead?.eventName ?? 'Expo Alimentaria México')
        .replaceAll('{lugar}', lead?.place ?? context.l10n.demoOffice)
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
      backgroundColor: FolooPalette.of(context).card,
      body: Column(
        children: [
          ModuleHeader(
            title: context.l10n.emailTitle,
            subtitle: _kind == _TemplateKind.event
                ? context.l10n.eventTemplate
                : context.l10n.directTemplate,
            onBack: () => widget.onDestinationSelected(AppDestination.home),
          ),
          Divider(height: 1, color: FolooPalette.of(context).line),
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
                    selectedHorizontalPadding: 8,
                    options: [
                      SegmentedBubbleOption(
                        value: _TemplateKind.event,
                        label: context.l10n.event,
                        leading: const Icon(
                          Icons.calendar_today_outlined,
                          size: 15,
                        ),
                      ),
                      SegmentedBubbleOption(
                        value: _TemplateKind.direct,
                        label: context.l10n.directLead,
                        leading: const Icon(
                          Icons.person_add_alt_1_outlined,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    context.l10n.subject,
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 7),
                  TextField(
                    key: ValueKey('emailSubject-${_kind.name}'),
                    controller: _subject,
                    decoration: const InputDecoration(
                      border: FolooBorders.borderlessField,
                      enabledBorder: FolooBorders.borderlessField,
                      focusedBorder: FolooBorders.borderlessField,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  Text(context.l10n.body, style: const TextStyle(fontSize: 11)),
                  const SizedBox(height: 7),
                  TextField(
                    key: ValueKey('emailBody-${_kind.name}'),
                    controller: _body,
                    minLines: 8,
                    maxLines: 12,
                    decoration: const InputDecoration(
                      border: FolooBorders.borderlessField,
                      enabledBorder: FolooBorders.borderlessField,
                      focusedBorder: FolooBorders.borderlessField,
                    ),
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
                  Text(
                    context.l10n.variables,
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
                  Text(
                    context.l10n.preview,
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
                          context.l10n.previewTo(
                            _previewRecord?.lead.fullName ??
                                'Mariana Sandoval Ruiz',
                          ),
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
                          context.l10n.emailPreviewServerHelp(
                            _previewRecord == null
                                ? context.l10n.demoFixture
                                : context.l10n.latestLeadData,
                          ),
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
        child: Container(
          decoration: BoxDecoration(
            color: FolooPalette.of(context).card,
            border: Border(
              top: BorderSide(color: FolooPalette.of(context).line),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: FilledButton(
            key: const Key('saveEmailTemplateButton'),
            onPressed: _save,
            child: Text(context.l10n.saveTemplate),
          ),
        ),
      ),
    );
  }
}
