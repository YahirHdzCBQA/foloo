/// V1 email-template editor and local preview of the latest matching Lead.
///
/// Editable templates persist owner-scoped before sync. Sending remains a
/// separate, explicitly confirmed follow-up flow (PLT-*, SAL-01).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_destination.dart';
import '../models/app_event.dart';
import '../models/lead_draft.dart';
import '../models/content_file.dart';
import '../models/session_lead.dart';
import '../models/email_template.dart';
import '../models/email_delivery_error.dart';
import '../data/repositories/local_repositories.dart';
import '../theme/foloo_theme.dart';
import '../widgets/app_drawer.dart';
import '../l10n/l10n.dart';
import '../l10n/app_localizations.dart';
import '../widgets/module_header.dart';
import '../widgets/segmented_bubble.dart';
import '../widgets/email_template_field_editor.dart';
import '../services/email_connection_service.dart';
import '../data/local/app_database.dart';

enum _TemplateKind { event, direct }

enum _UnsavedTemplateDecision { save, discard, keepEditing }

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
    this.deliveryRepository,
    this.connectionService,
    this.onSendQueued,
    required this.contentCount,
    required this.records,
    required this.contentFiles,
    this.active = true,
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
  final EmailDeliveryRepository? deliveryRepository;
  final EmailConnectionService? connectionService;
  final VoidCallback? onSendQueued;
  final int contentCount;
  final List<SessionLead> records;
  final List<ContentFile> contentFiles;
  final bool active;

  @override
  State<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends State<EmailScreen> with WidgetsBindingObserver {
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
  EmailConnectionView? _connection;
  List<StoredEmailFollowUp> _followUps = const [];
  List<StoredEmailSendIntent> _intents = const [];
  int _deliveryRequestGeneration = 0;
  int _templateEditorRevision = 0;
  StreamSubscription<List<StoredEmailFollowUp>>? _followUpsSubscription;
  StreamSubscription<List<StoredEmailSendIntent>>? _intentsSubscription;

  TextEditingController get _subject =>
      _kind == _TemplateKind.event ? _eventSubject : _directSubject;
  TextEditingController get _body =>
      _kind == _TemplateKind.event ? _eventBody : _directBody;
  TextEditingController get _signature =>
      _kind == _TemplateKind.event ? _eventSignature : _directSignature;

  TextEditingController _subjectFor(_TemplateKind kind) =>
      kind == _TemplateKind.event ? _eventSubject : _directSubject;
  TextEditingController _bodyFor(_TemplateKind kind) =>
      kind == _TemplateKind.event ? _eventBody : _directBody;
  TextEditingController _signatureFor(_TemplateKind kind) =>
      kind == _TemplateKind.event ? _eventSignature : _directSignature;
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
    WidgetsBinding.instance.addObserver(this);
    _loadTemplates();
    _watchDelivery();
    _loadDelivery();
  }

  @override
  void didUpdateWidget(covariant EmailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerSub != widget.ownerSub) {
      _stored.clear();
      _connection = null;
      _loadTemplates();
      _watchDelivery();
      _loadDelivery();
    } else if (!oldWidget.active && widget.active) {
      unawaited(_loadDelivery());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.active) {
      unawaited(_loadDelivery());
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

  Future<void> _loadDelivery() async {
    final owner = widget.ownerSub;
    if (owner == null) return;
    final generation = ++_deliveryRequestGeneration;
    final followUps = await widget.deliveryRepository?.list(owner) ?? const [];
    final intents = await widget.deliveryRepository?.intents(owner) ?? const [];
    EmailConnectionView? connection;
    try {
      connection = await widget.connectionService?.status(owner);
      if (connection != null) {
        await widget.deliveryRepository?.saveConnection(
          owner: owner,
          connectionId: connection.id,
          provider: connection.provider,
          senderAddress: connection.senderAddress,
          status: connection.status,
        );
      }
    } on Object {
      connection = null;
    }
    if (!mounted ||
        owner != widget.ownerSub ||
        generation != _deliveryRequestGeneration) {
      return;
    }
    setState(() {
      if (widget.deliveryRepository == null) {
        _followUps = followUps;
        _intents = intents;
      }
      _connection = connection;
    });
  }

  void _watchDelivery() {
    unawaited(_followUpsSubscription?.cancel());
    unawaited(_intentsSubscription?.cancel());
    final owner = widget.ownerSub;
    final repository = widget.deliveryRepository;
    if (owner == null || repository == null) return;
    _followUpsSubscription = repository.watchFollowUps(owner).listen((value) {
      if (mounted && owner == widget.ownerSub) {
        setState(() => _followUps = value);
      }
    });
    _intentsSubscription = repository.watchIntents(owner).listen((value) {
      if (mounted && owner == widget.ownerSub) {
        setState(() => _intents = value);
      }
    });
  }

  bool get _english => (_languageCode ?? 'es') == 'en';

  Future<void> _queueSend(StoredEmailFollowUp followUp) async {
    final owner = widget.ownerSub;
    if (owner == null || widget.deliveryRepository == null) return;
    await widget.deliveryRepository!.confirm(
      owner: owner,
      followUpId: followUp.localId,
    );
    widget.onSendQueued?.call();
    await _loadDelivery();
  }

  List<String> _attachmentDecisionIds(StoredEmailSendIntent intent) {
    const prefix = 'attachment_decision:';
    final value = intent.errorCode;
    if (value == null || !value.startsWith(prefix)) return const [];
    try {
      return (jsonDecode(value.substring(prefix.length)) as List)
          .whereType<String>()
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<void> _resolveAttachmentDecision(
    StoredEmailFollowUp followUp,
    StoredEmailSendIntent intent,
  ) async {
    final ids = _attachmentDecisionIds(intent);
    final contentIds = (jsonDecode(followUp.contentFileIdsJson) as List)
        .whereType<String>()
        .toList();
    final contentNames = (jsonDecode(followUp.contentNamesJson) as List)
        .whereType<String>()
        .toList();
    final names = <String>[
      for (var index = 0; index < contentIds.length; index++)
        if (ids.contains(contentIds[index]))
          index < contentNames.length ? contentNames[index] : contentIds[index],
    ];
    final omit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _english ? 'Attachment cannot be sent' : 'No se puede adjuntar',
        ),
        content: Text(
          _english
              ? '${names.join(', ')} is unavailable or exceeds the provider limit. Send without it?'
              : '${names.join(', ')} no está disponible o supera el límite del proveedor. ¿Enviar sin adjuntarlo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_english ? 'Cancel' : 'Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_english ? 'Send without it' : 'Enviar sin adjunto'),
          ),
        ],
      ),
    );
    final owner = widget.ownerSub;
    final repository = widget.deliveryRepository;
    if (owner == null || repository == null) return;
    if (omit == true) {
      await repository.confirm(
        owner: owner,
        followUpId: followUp.localId,
        omittedContentIds: {
          ...ids,
          ...jsonDecode(intent.omittedContentIdsJson),
        }.whereType<String>().toList(),
        intentId: intent.localId,
      );
      widget.onSendQueued?.call();
    } else {
      await repository.cancelAttachmentDecision(owner: owner, intent: intent);
    }
    await _loadDelivery();
  }

  Future<void> _retry(StoredEmailSendIntent intent) async {
    final owner = widget.ownerSub;
    if (owner == null) return;
    await widget.deliveryRepository?.retry(owner: owner, intent: intent);
    widget.onSendQueued?.call();
    await _loadDelivery();
  }

  Future<void> _manualResend(
    StoredEmailFollowUp followUp,
    StoredEmailSendIntent previous,
  ) async {
    final owner = widget.ownerSub;
    final repository = widget.deliveryRepository;
    if (owner == null || repository == null) return;
    final currentSender = _connection?.senderAddress;
    final changed =
        previous.senderAddress != null &&
        currentSender != null &&
        previous.senderAddress != currentSender;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_english ? 'Send again?' : '¿Enviar nuevamente?'),
        content: Text(
          changed
              ? (_english
                    ? 'The connected sender changed to $currentSender. Confirm this new sender before resending.'
                    : 'El remitente conectado cambió a $currentSender. Confirma este nuevo remitente antes de reenviar.')
              : (_english
                    ? 'The previous result may be unknown. This creates a new manual send and could deliver a duplicate.'
                    : 'El resultado anterior puede ser desconocido. Esto crea un envío manual nuevo y podría entregar un duplicado.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_english ? 'Cancel' : 'Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_english ? 'Confirm resend' : 'Confirmar reenvío'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await repository.confirm(
      owner: owner,
      followUpId: followUp.localId,
      parentIntentId: previous.localId,
    );
    widget.onSendQueued?.call();
    await _loadDelivery();
  }

  StoredEmailSendIntent? _intentFor(String followUpId) {
    for (final intent in _intents) {
      if (intent.followUpLocalId == followUpId) return intent;
    }
    return null;
  }

  Future<void> _previewFollowUp(StoredEmailFollowUp followUp) =>
      showDialog<void>(
        context: context,
        builder: (context) {
          final names = (jsonDecode(followUp.contentNamesJson) as List)
              .whereType<String>()
              .toList();
          return AlertDialog(
            title: Text(followUp.subject),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(followUp.plainBody),
                  if (names.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      _english ? 'PDF attachments' : 'PDF adjuntos',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    ...names.map((name) => Text('• $name')),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_english ? 'Close' : 'Cerrar'),
              ),
            ],
          );
        },
      );

  // Historical renderer retained temporarily for migration evidence; the
  // active UX now renders this source in Records (REG-16).
  // ignore: unused_element
  Widget _followUpList() {
    final visible = <StoredEmailFollowUp>[];
    final preparedLeadIds = <String>{};
    for (final followUp in _followUps) {
      final hasIntent = _intents.any(
        (intent) => intent.followUpLocalId == followUp.localId,
      );
      if (hasIntent || preparedLeadIds.add(followUp.leadLocalId)) {
        visible.add(followUp);
      }
    }
    if (visible.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text(
          context.l10n.emailFollowUps,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        ...visible.map((followUp) {
          final intent = _intentFor(followUp.localId);
          final status = intent?.status ?? 'ready';
          final attachmentDecision =
              intent != null && _attachmentDecisionIds(intent).isNotEmpty;
          final terminalFailure = isTerminalEmailDeliveryError(
            intent?.errorCode,
          );
          final label = attachmentDecision
              ? context.l10n.emailFollowUpAttachmentDecision
              : intent?.errorCode == 'cancelled_by_seller'
              ? context.l10n.emailFollowUpCancelled
              : terminalFailure
              ? context.l10n.emailNotRetryableStatus
              : switch (status) {
                  'pending' => context.l10n.emailFollowUpPending,
                  'sending' => context.l10n.emailFollowUpSending,
                  'sent' => context.l10n.emailFollowUpSent,
                  'error' => context.l10n.emailFollowUpError,
                  'confirmation_required' =>
                    context.l10n.emailFollowUpConfirmation,
                  _ => context.l10n.emailFollowUpReady,
                };
          final visual = _followUpVisual(
            status,
            attachmentDecision: attachmentDecision,
            terminalFailure: terminalFailure,
          );
          final record = _recordForFollowUp(followUp.leadLocalId);
          final lead = record?.lead;
          final leadName = lead?.fullName.trim();
          final contextLabel = lead == null
              ? null
              : lead.originKind == LeadOriginKind.event
              ? lead.eventName?.trim().isNotEmpty == true
                    ? context.l10n.emailFollowUpEventContext(
                        lead.eventName!.trim(),
                      )
                    : context.l10n.event
              : lead.place?.trim().isNotEmpty == true
              ? context.l10n.emailFollowUpDirectContext(lead.place!.trim())
              : context.l10n.directLead;
          return Card(
            key: ValueKey('emailFollowUp-${followUp.localId}'),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _previewFollowUp(followUp),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(visual.$1, color: visual.$2, semanticLabel: label),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            leadName?.isNotEmpty == true
                                ? leadName!
                                : followUp.recipientAddress,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            followUp.recipientAddress,
                            style: TextStyle(
                              color: FolooPalette.of(context).inkSecondary,
                              fontSize: 12,
                            ),
                          ),
                          if (contextLabel != null) Text(contextLabel),
                          Text(
                            DateFormat.yMMMd(
                              Localizations.localeOf(context).toLanguageTag(),
                            ).add_Hm().format(followUp.preparedAt.toLocal()),
                            style: TextStyle(
                              color: FolooPalette.of(context).inkSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(followUp.subject),
                          const SizedBox(height: 7),
                          Semantics(
                            label: label,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: visual.$2.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: visual.$2,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (attachmentDecision)
                      IconButton(
                        tooltip: _english
                            ? 'Resolve attachment'
                            : 'Resolver adjunto',
                        onPressed: () =>
                            _resolveAttachmentDecision(followUp, intent),
                        icon: const Icon(Icons.attachment_outlined),
                      )
                    else if (status == 'ready')
                      IconButton(
                        tooltip: _english ? 'Confirm send' : 'Confirmar envío',
                        onPressed: _connection?.status == 'connected'
                            ? () => _queueSend(followUp)
                            : null,
                        icon: const Icon(Icons.send_outlined),
                      )
                    else if (status == 'error' &&
                        intent?.errorCode != 'cancelled_by_seller' &&
                        !terminalFailure)
                      IconButton(
                        key: ValueKey('emailRetry-${intent!.localId}'),
                        tooltip: _english ? 'Retry safely' : 'Reintentar',
                        onPressed: _connection?.status == 'connected'
                            ? () => _retry(intent)
                            : null,
                        icon: const Icon(Icons.refresh),
                      )
                    else if (status == 'confirmation_required' ||
                        status == 'sent')
                      IconButton(
                        tooltip: _english ? 'Resend manually' : 'Reenviar',
                        onPressed: _connection?.status == 'connected'
                            ? () => _manualResend(followUp, intent!)
                            : null,
                        icon: const Icon(Icons.forward_to_inbox_outlined),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  void _applyLanguage(AppLocalizations l10n) {
    final language = l10n.localeName.startsWith('en') ? 'en' : 'es';
    _languageCode = language;
    _templateEditorRevision++;
    for (final origin in ['event', 'direct']) {
      final stored = _stored['$origin:$language'];
      final subject = origin == 'event' ? _eventSubject : _directSubject;
      final body = origin == 'event' ? _eventBody : _directBody;
      final signature = origin == 'event' ? _eventSignature : _directSignature;
      final official = FolooEmailDefaults.forContext(origin, language);
      subject.text = stored?.subject ?? official.subject;
      body.text = stored?.body ?? official.body;
      signature.text = stored?.signature ?? official.signature;
    }
  }

  EmailTemplateData _effectiveStoredTemplate(_TemplateKind kind) {
    final language = _languageCode ?? 'es';
    final stored = _stored['${kind.name}:$language'];
    if (stored != null) return stored;
    final official = FolooEmailDefaults.forContext(kind.name, language);
    return EmailTemplateData(
      origin: kind.name,
      language: language,
      subject: official.subject,
      body: official.body,
      signature: official.signature,
    );
  }

  bool _isDirty(_TemplateKind kind) {
    final stored = _effectiveStoredTemplate(kind);
    return _subjectFor(kind).text != stored.subject ||
        _bodyFor(kind).text != stored.body ||
        _signatureFor(kind).text != stored.signature;
  }

  bool get _hasUnsavedChanges => _TemplateKind.values.any(_isDirty);

  void _discardKinds(Iterable<_TemplateKind> kinds) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      for (final kind in kinds) {
        final stored = _effectiveStoredTemplate(kind);
        _subjectFor(kind).text = stored.subject;
        _bodyFor(kind).text = stored.body;
        _signatureFor(kind).text = stored.signature;
      }
      _templateEditorRevision++;
      _error = null;
    });
  }

  String? _templateValidationError(_TemplateKind kind) {
    final source =
        '${_subjectFor(kind).text} ${_bodyFor(kind).text} ${_signatureFor(kind).text}';
    final found = RegExp(r'\{[^}]+\}')
        .allMatches(source)
        .map((match) => match.group(0)!)
        .toSet();
    final invalid = found.difference(_variables.toSet());
    final bracesBalanced =
        RegExp(r'\{').allMatches(source).length ==
        RegExp(r'\}').allMatches(source).length;
    if (!bracesBalanced) return context.l10n.unclosedVariable;
    if (invalid.isNotEmpty) {
      return context.l10n.invalidVariable(invalid.join(', '));
    }
    return null;
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
    _deliveryRequestGeneration++;
    unawaited(_followUpsSubscription?.cancel());
    unawaited(_intentsSubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
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

  SessionLead? _recordForFollowUp(String localId) {
    for (final record in widget.records) {
      if (record.localId == localId) return record;
    }
    return null;
  }

  (IconData, Color) _followUpVisual(
    String status, {
    required bool attachmentDecision,
    required bool terminalFailure,
  }) {
    final palette = FolooPalette.of(context);
    if (attachmentDecision) return (Icons.attach_file, Colors.orange.shade800);
    if (status == 'sent') return (Icons.check_circle, Colors.green.shade700);
    if (status == 'error' || terminalFailure) {
      return (Icons.error_outline, palette.error);
    }
    if (status == 'pending' || status == 'sending') {
      return (Icons.schedule, Colors.orange.shade800);
    }
    if (status == 'confirmation_required') {
      return (Icons.help_outline, palette.inkSecondary);
    }
    return (Icons.drafts_outlined, palette.inkSecondary);
  }

  Future<bool> _saveKinds(
    Iterable<_TemplateKind> kinds, {
    bool showConfirmation = true,
  }) async {
    final selected = kinds.toSet();
    for (final kind in selected) {
      final validationError = _templateValidationError(kind);
      if (validationError != null) {
        setState(() {
          _kind = kind;
          _error = validationError;
        });
        return false;
      }
    }
    final templates = selected
        .map(
          (kind) => EmailTemplateData(
            origin: kind.name,
            language: _languageCode ?? 'es',
            subject: _subjectFor(kind).text,
            body: _bodyFor(kind).text,
            signature: _signatureFor(kind).text,
          ),
        )
        .toList();
    try {
      await _persistTemplates(templates);
    } on Object {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.templateSaveFailed)));
      return false;
    }
    if (!mounted) return false;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      for (final template in templates) {
        _stored[template.key] = template;
      }
      _templateEditorRevision++;
      _error = null;
    });
    if (showConfirmation) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.templateSavedV1)));
    }
    return true;
  }

  Future<void> _persistTemplates(Iterable<EmailTemplateData> templates) async {
    final repository = widget.templateRepository;
    final owner = widget.ownerSub;
    if (repository == null || owner == null) return;
    for (final template in templates) {
      await repository.save(owner, template);
    }
    widget.onTemplateSaved?.call();
  }

  Future<void> _save() async {
    await _saveKinds([_kind]);
  }

  Future<bool> _resolveUnsavedChanges() async {
    if (!_hasUnsavedChanges) return true;
    final decision = await showDialog<_UnsavedTemplateDecision>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.profileUnsavedTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              _UnsavedTemplateDecision.keepEditing,
            ),
            child: Text(dialogContext.l10n.profileKeepEditing),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _UnsavedTemplateDecision.discard),
            child: Text(dialogContext.l10n.profileDiscardChanges),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _UnsavedTemplateDecision.save),
            child: Text(dialogContext.l10n.profileSaveAndExit),
          ),
        ],
      ),
    );
    switch (decision) {
      case _UnsavedTemplateDecision.save:
        return _saveKinds(
          _TemplateKind.values.where(_isDirty),
          showConfirmation: false,
        );
      case _UnsavedTemplateDecision.discard:
        _discardKinds(_TemplateKind.values.where(_isDirty));
        return true;
      case _UnsavedTemplateDecision.keepEditing:
      case null:
        return false;
    }
  }

  Future<void> _navigateTo(AppDestination destination) async {
    if (await _resolveUnsavedChanges()) {
      widget.onDestinationSelected(destination);
    }
  }

  Future<void> _changeLanguage(Locale locale) async {
    if (locale.languageCode == Localizations.localeOf(context).languageCode) {
      return;
    }
    if (!await _resolveUnsavedChanges() || !mounted) return;
    AppLanguageScope.maybeOf(context)?.onLocaleChanged(locale);
  }

  Future<void> _logout() async {
    if (await _resolveUnsavedChanges()) widget.onLogout();
  }

  Future<void> _restoreOfficialDefault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.restoreDefaultTemplateQuestion),
        content: Text(dialogContext.l10n.restoreDefaultTemplateHelp),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.restore),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final official = FolooEmailDefaults.forContext(
      _kind.name,
      _languageCode ?? 'es',
    );
    final restored = EmailTemplateData(
      origin: _kind.name,
      language: _languageCode ?? 'es',
      subject: official.subject,
      body: official.body,
      signature: official.signature,
    );
    try {
      await _persistTemplates([restored]);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.templateSaveFailed)));
      return;
    }
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _subject.text = restored.subject;
      _body.text = restored.body;
      _signature.text = restored.signature;
      _stored[restored.key] = restored;
      _templateEditorRevision++;
      _error = null;
    });
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
      endDrawer: AppDrawer(
        contentCount: widget.contentCount,
        profile: widget.profile,
        activeDestination: AppDestination.email,
        recordsCount: widget.recordsCount,
        darkMode: widget.darkMode,
        onDestinationSelected: (destination) =>
            unawaited(_navigateTo(destination)),
        onAppearanceChanged: widget.onAppearanceChanged,
        onLogout: () => unawaited(_logout()),
        onLanguageChanged: (locale) => unawaited(_changeLanguage(locale)),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Column(
          children: [
            ModuleHeader(
              title: context.l10n.emailTitle,
              subtitle: _kind == _TemplateKind.event
                  ? context.l10n.eventTemplate
                  : context.l10n.directTemplate,
              onMenuPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                _scaffoldKey.currentState?.openEndDrawer();
              },
            ),
            Divider(height: 1, color: FolooPalette.of(context).line),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
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
                    const SizedBox(height: 14),
                    Text(
                      context.l10n.sellerTemplateHelp,
                      style: TextStyle(
                        color: FolooPalette.of(context).inkSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      context.l10n.subject,
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 7),
                    EmailTemplateFieldEditor(
                      key: ValueKey(
                        'emailSubjectEditor-${_kind.name}-$_templateEditorRevision',
                      ),
                      fieldName: 'subject',
                      controller: _subject,
                      textFieldKey: ValueKey('emailSubject-${_kind.name}'),
                      onChanged: () => setState(() {}),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      context.l10n.body,
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 7),
                    EmailTemplateFieldEditor(
                      key: ValueKey(
                        'emailBodyEditor-${_kind.name}-$_templateEditorRevision',
                      ),
                      fieldName: 'body',
                      controller: _body,
                      textFieldKey: ValueKey('emailBody-${_kind.name}'),
                      onChanged: () => setState(() {}),
                      minLines: 8,
                      maxLines: 12,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      context.l10n.emailSignatureV1,
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 7),
                    EmailTemplateFieldEditor(
                      key: ValueKey(
                        'emailSignatureEditor-${_kind.name}-$_templateEditorRevision',
                      ),
                      fieldName: 'signature',
                      controller: _signature,
                      textFieldKey: ValueKey('emailSignature-${_kind.name}'),
                      onChanged: () => setState(() {}),
                      minLines: 2,
                      maxLines: 4,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _error!,
                          key: const Key('emailVariableError'),
                          style: TextStyle(
                            color: FolooPalette.of(context).error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const Key('restoreFolooTemplateButton'),
                        onPressed: _restoreOfficialDefault,
                        icon: const Icon(Icons.restore),
                        label: Text(context.l10n.restoreDefaultTemplate),
                      ),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Divider(height: 24),
                            Text(_preview(_body.text)),
                            const SizedBox(height: 12),
                            Text(_preview(_signature.text)),
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
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: FolooPalette.of(context).card,
              border: Border(
                top: BorderSide(color: FolooPalette.of(context).line),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: OutlinedButton(
                    key: const Key('cancelEmailTemplateButton'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, FolooSpace.dock),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: _isDirty(_kind)
                        ? () => _discardKinds([_kind])
                        : null,
                    child: Text(
                      context.l10n.cancel,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 6,
                  child: FilledButton(
                    key: const Key('saveEmailTemplateButton'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, FolooSpace.dock),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: _save,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        context.l10n.saveTemplate,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
