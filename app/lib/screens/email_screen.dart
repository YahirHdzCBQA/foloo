/// V1 email-template editor and local preview of the latest matching Lead.
///
/// Editable templates persist owner-scoped before sync. Sending remains a
/// separate, explicitly confirmed follow-up flow (PLT-*, SAL-01).
library;

import 'package:flutter/material.dart';

import '../models/app_destination.dart';
import '../models/app_event.dart';
import '../models/lead_draft.dart';
import '../models/content_file.dart';
import '../models/session_lead.dart';
import '../models/email_template.dart';
import '../data/repositories/local_repositories.dart';
import '../theme/foloo_theme.dart';
import '../l10n/l10n.dart';
import '../l10n/app_localizations.dart';
import '../widgets/module_header.dart';
import '../widgets/segmented_bubble.dart';

enum _TemplateKind { event, direct }

/// Edits the Event or Direct template without initiating a send.
class EmailScreen extends StatefulWidget {
  const EmailScreen({
    required this.recordsCount,
    required this.profile,
    required this.darkMode,
    required this.onDestinationSelected,
    required this.onAppearanceChanged,
    required this.onLogout,
    this.templateRepository,
    this.ownerSub,
    this.onTemplateSaved,
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
  final EmailTemplateRepository? templateRepository;
  final String? ownerSub;
  final VoidCallback? onTemplateSaved;
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
  final _eventSignature = TextEditingController();
  final _directSignature = TextEditingController();
  final Map<String, EmailTemplateData> _stored = {};
  _TemplateKind _kind = _TemplateKind.event;
  String? _error;
  String? _languageCode;

  TextEditingController get _subject =>
      _kind == _TemplateKind.event ? _eventSubject : _directSubject;
  TextEditingController get _body =>
      _kind == _TemplateKind.event ? _eventBody : _directBody;
  TextEditingController get _signature =>
      _kind == _TemplateKind.event ? _eventSignature : _directSignature;
  static const _variables = [
    '{nombre}',
    '{apellido}',
    '{empresa}',
    '{puesto}',
    '{evento}',
    '{lugar}',
    '{contenido}',
    '{nombreVendedor}',
    '{empresaVendedor}',
  ];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void didUpdateWidget(covariant EmailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerSub != widget.ownerSub) {
      _stored.clear();
      _loadTemplates();
    }
  }

  Future<void> _loadTemplates() async {
    final owner = widget.ownerSub;
    final repository = widget.templateRepository;
    if (owner == null || repository == null) return;
    final loaded = await repository.list(owner);
    if (!mounted || owner != widget.ownerSub) return;
    setState(() {
      _stored
        ..clear()
        ..addEntries(loaded.map((item) => MapEntry(item.key, item)));
      _applyLanguage(context.l10n);
    });
  }

  void _applyLanguage(AppLocalizations l10n) {
    final language = l10n.localeName.startsWith('en') ? 'en' : 'es';
    _languageCode = language;
    for (final origin in ['event', 'direct']) {
      final stored = _stored['$origin:$language'];
      final subject = origin == 'event' ? _eventSubject : _directSubject;
      final body = origin == 'event' ? _eventBody : _directBody;
      final signature = origin == 'event' ? _eventSignature : _directSignature;
      subject.text = stored?.subject ?? l10n.emailDefaultSubjectV1('{nombre}');
      body.text =
          stored?.body ??
          (origin == 'event'
              ? l10n.emailDefaultBodyEventV1(
                  '{contenido}',
                  '{evento}',
                  '{nombre}',
                )
              : l10n.emailDefaultBodyDirectV1(
                  '{contenido}',
                  '{lugar}',
                  '{nombre}',
                ));
      signature.text =
          stored?.signature ??
          l10n.emailDefaultSignatureV1('{empresaVendedor}', '{nombreVendedor}');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = context.l10n;
    final language = l10n.localeName.startsWith('en') ? 'en' : 'es';
    if (_languageCode != language) _applyLanguage(l10n);
  }

  @override
  void dispose() {
    for (final controller in [
      _eventSubject,
      _directSubject,
      _eventBody,
      _directBody,
      _eventSignature,
      _directSignature,
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

  Future<void> _save() async {
    final allowed = _variables.toSet();
    final found = RegExp(r'\{[^}]+\}')
        .allMatches('${_subject.text} ${_body.text} ${_signature.text}')
        .map((m) => m.group(0)!)
        .toSet();
    final invalid = found.difference(allowed);
    final source = '${_subject.text} ${_body.text} ${_signature.text}';
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
      final template = EmailTemplateData(
        origin: _kind.name,
        language: _languageCode ?? 'es',
        subject: _subject.text,
        body: _body.text,
        signature: _signature.text,
      );
      final repository = widget.templateRepository;
      final owner = widget.ownerSub;
      if (repository != null && owner != null) {
        await repository.save(owner, template);
        widget.onTemplateSaved?.call();
      }
      _stored[template.key] = template;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.templateSavedV1)));
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

  /// Resolves preview only from a real matching Lead, never from demo fixtures.
  String _preview(String value) {
    final lead = _previewRecord?.lead;
    if (lead == null) return '';
    final names = lead.contentNames
        .where((name) => name.trim().isNotEmpty)
        .toList();
    final connector = _languageCode == 'en' ? ' and ' : ' y ';
    final attachments = names.length <= 1
        ? (names.isEmpty ? '' : names.first)
        : '${names.take(names.length - 1).join(', ')}$connector${names.last}';
    var rendered = value
        .replaceAll('{nombre}', lead.name)
        .replaceAll('{apellido}', lead.lastName)
        .replaceAll('{empresa}', lead.company)
        .replaceAll('{puesto}', lead.role)
        .replaceAll('{evento}', lead.eventName ?? '')
        .replaceAll('{lugar}', lead.place ?? '')
        .replaceAll('{contenido}', attachments)
        .replaceAll('{nombreVendedor}', widget.profile.name)
        .replaceAll('{empresaVendedor}', widget.profile.company);
    if (attachments.isEmpty) {
      rendered = rendered
          .split('\n')
          .where(
            (line) =>
                !line.startsWith('Te comparto ') &&
                !line.startsWith("I'm sharing "),
          )
          .join('\n');
    }
    if ((lead.originKind == LeadOriginKind.event &&
            (lead.eventName?.trim().isEmpty ?? true)) ||
        (lead.originKind == LeadOriginKind.direct &&
            (lead.place?.trim().isEmpty ?? true))) {
      rendered = rendered
          .split('\n')
          .where(
            (line) =>
                !line.startsWith('Fue un gusto conocerte en ') &&
                !line.startsWith('It was great meeting you at '),
          )
          .join('\n');
    }
    return rendered.trim();
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
                  const SizedBox(height: 14),
                  Text(
                    context.l10n.emailSignatureV1,
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 7),
                  TextField(
                    key: ValueKey('emailSignature-${_kind.name}'),
                    controller: _signature,
                    minLines: 2,
                    maxLines: 4,
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
                        if (_previewRecord != null) ...[
                          Text(
                            context.l10n.previewTo(
                              _previewRecord!.lead.fullName,
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _preview(_subject.text),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const Divider(height: 24),
                          Text(_preview(_body.text)),
                          const SizedBox(height: 12),
                          Text(_preview(_signature.text)),
                          const SizedBox(height: 12),
                          Text(
                            (_kind == _TemplateKind.event
                                            ? _previewRecord!.lead.eventName
                                            : _previewRecord!.lead.place)
                                        ?.trim()
                                        .isNotEmpty ==
                                    true
                                ? (_kind == _TemplateKind.event
                                      ? context.l10n.emailFooterEventV1(
                                          _previewRecord!.lead.eventName!,
                                        )
                                      : context.l10n.emailFooterDirectV1(
                                          _previewRecord!.lead.place!,
                                        ))
                                : context.l10n.emailFooterGenericV1,
                          ),
                          Text(context.l10n.emailUnsubscribeV1),
                        ] else
                          Text(
                            context.l10n.emailNoLeadPreviewV1,
                            style: const TextStyle(fontSize: 11),
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
