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
import '../l10n/l10n.dart';
import '../l10n/app_localizations.dart';
import '../widgets/module_header.dart';
import '../widgets/segmented_bubble.dart';
import '../services/email_connection_service.dart';
import '../data/local/app_database.dart';

enum _TemplateKind { event, direct }

enum _TemplateField { subject, body }

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
  final _subjectFocus = FocusNode();
  final _bodyFocus = FocusNode();
  final Map<String, EmailTemplateData> _stored = {};
  _TemplateKind _kind = _TemplateKind.event;
  String? _error;
  String? _languageCode;
  EmailConnectionView? _connection;
  List<StoredEmailFollowUp> _followUps = const [];
  List<StoredEmailSendIntent> _intents = const [];
  bool _connectionBusy = false;
  bool _connectionUnavailable = false;
  int _deliveryRequestGeneration = 0;
  _TemplateField _lastTemplateField = _TemplateField.body;

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
    WidgetsBinding.instance.addObserver(this);
    _loadTemplates();
    _loadDelivery();
  }

  @override
  void didUpdateWidget(covariant EmailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerSub != widget.ownerSub) {
      _stored.clear();
      _connection = null;
      _loadTemplates();
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
    if (mounted) setState(() => _connectionBusy = true);
    final followUps = await widget.deliveryRepository?.list(owner) ?? const [];
    final intents = await widget.deliveryRepository?.intents(owner) ?? const [];
    EmailConnectionView? connection;
    var unavailable = false;
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
      unavailable = widget.connectionService != null;
    }
    if (!mounted ||
        owner != widget.ownerSub ||
        generation != _deliveryRequestGeneration) {
      return;
    }
    setState(() {
      _followUps = followUps;
      _intents = intents;
      _connection = connection;
      _connectionUnavailable = unavailable;
      _connectionBusy = false;
    });
  }

  bool get _english => (_languageCode ?? 'es') == 'en';

  Future<void> _connect(String provider) async {
    final owner = widget.ownerSub;
    final service = widget.connectionService;
    if (owner == null || service == null) return;
    setState(() => _connectionBusy = true);
    try {
      await service.connect(owner, provider);
    } finally {
      if (mounted) setState(() => _connectionBusy = false);
    }
  }

  Future<void> _disconnect() async {
    final owner = widget.ownerSub;
    if (owner == null) return;
    setState(() => _connectionBusy = true);
    await widget.connectionService?.disconnect(owner);
    final connection = _connection;
    if (connection != null) {
      await widget.deliveryRepository?.saveConnection(
        owner: owner,
        connectionId: connection.id,
        provider: connection.provider,
        senderAddress: connection.senderAddress,
        status: 'disconnected',
      );
    }
    await _loadDelivery();
  }

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

  Widget _connectionCard() {
    final palette = FolooPalette.of(context);
    final connected = _connection?.status == 'connected';
    return Container(
      key: const Key('emailConnectionCard'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.paper,
        borderRadius: BorderRadius.circular(FolooRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.emailSendingAccount,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          if (_connection == null) ...[
            const SizedBox(height: 4),
            Text(context.l10n.emailNoSendingAccount),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              '${_connection!.provider == 'microsoft' ? 'Microsoft' : 'Google'} · ${_connection!.senderAddress}',
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  connected ? Icons.check_circle_outline : Icons.sync_problem,
                  size: 15,
                ),
                const SizedBox(width: 5),
                Text(
                  connected
                      ? context.l10n.emailConnectionConnected
                      : context.l10n.emailConnectionReconnect,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
          if (_connectionUnavailable) ...[
            const SizedBox(height: 6),
            Text(
              context.l10n.emailConnectionUnavailable,
              style: TextStyle(color: palette.inkSecondary, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          if (connected)
            Row(
              children: [
                TextButton(
                  onPressed: _connectionBusy ? null : _disconnect,
                  child: Text(context.l10n.emailConnectionDisconnect),
                ),
                TextButton(
                  key: const Key('emailChangeAccountButton'),
                  onPressed: _connectionBusy
                      ? null
                      : () => _connect(_connection!.provider),
                  child: Text(context.l10n.emailChangeAccount),
                ),
                const Spacer(),
                IconButton(
                  tooltip: context.l10n.emailConnectionRefresh,
                  onPressed: _connectionBusy ? null : _loadDelivery,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _connectionBusy
                        ? null
                        : () => _connect('google'),
                    child: const Text('Google'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _connectionBusy
                        ? null
                        : () => _connect('microsoft'),
                    child: const Text('Microsoft'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _followUpList() {
    if (_followUps.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text(
          context.l10n.emailFollowUps,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        ..._followUps.map((followUp) {
          final intent = _intentFor(followUp.localId);
          final status = intent?.status ?? 'ready';
          final attachmentDecision =
              intent != null && _attachmentDecisionIds(intent).isNotEmpty;
          final recipientOptedOut = isRecipientOptedOutError(intent?.errorCode);
          final terminalFailure = isTerminalEmailDeliveryError(
            intent?.errorCode,
          );
          final label = attachmentDecision
              ? context.l10n.emailFollowUpAttachmentDecision
              : intent?.errorCode == 'cancelled_by_seller'
              ? context.l10n.emailFollowUpCancelled
              : recipientOptedOut
              ? context.l10n.emailRecipientOptedOutStatus
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
    _deliveryRequestGeneration++;
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
    _subjectFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  /// Inserts a supported token at the current caret without changing its name.
  void _insert(String variable) {
    final target = _subjectFocus.hasFocus
        ? _TemplateField.subject
        : _bodyFocus.hasFocus
        ? _TemplateField.body
        : _lastTemplateField;
    final controller = target == _TemplateField.subject ? _subject : _body;
    final focusNode = target == _TemplateField.subject
        ? _subjectFocus
        : _bodyFocus;
    final selection = controller.selection;
    final offset = selection.isValid ? selection.start : controller.text.length;
    controller.text = controller.text.replaceRange(
      offset,
      selection.isValid ? selection.end : offset,
      variable,
    );
    controller.selection = TextSelection.collapsed(
      offset: offset + variable.length,
    );
    _lastTemplateField = target;
    focusNode.requestFocus();
    setState(() {});
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
                  const SizedBox(height: 14),
                  _connectionCard(),
                  const SizedBox(height: 18),
                  Text(
                    context.l10n.subject,
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(height: 7),
                  TextField(
                    key: ValueKey('emailSubject-${_kind.name}'),
                    controller: _subject,
                    focusNode: _subjectFocus,
                    onTap: () => _lastTemplateField = _TemplateField.subject,
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
                    focusNode: _bodyFocus,
                    onTap: () => _lastTemplateField = _TemplateField.body,
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
                  _followUpList(),
                ],
              ),
            ),
          ),
        ],
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
            child: FilledButton(
              key: const Key('saveEmailTemplateButton'),
              onPressed: _save,
              child: Text(context.l10n.saveTemplate),
            ),
          ),
        ),
      ),
    );
  }
}
