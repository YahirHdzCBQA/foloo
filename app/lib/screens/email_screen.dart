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

enum _TemplateField { subject, body, signature }

/// Editable projection that keeps canonical tokens out of the visible text.
///
/// Invisible separators preserve native selection/copy/paste while the text
/// between them is the localized, human label shown as a highlighted chip.
class _FriendlyTemplateEditingController extends TextEditingController {
  static const _marker = '\u2063';
  Map<String, String> _tokenToLabel = const {};
  Map<String, String> _labelToToken = const {};

  void loadCanonical(String source, Map<String, String> labels) {
    _tokenToLabel = labels;
    _labelToToken = {
      for (final entry in labels.entries) entry.value: entry.key,
    };
    final projected = source.replaceAllMapped(RegExp(r'\{[^}]+\}'), (match) {
      final token = match.group(0)!;
      final label = labels[token];
      return label == null ? token : '$_marker$label$_marker';
    });
    value = TextEditingValue(
      text: projected,
      selection: TextSelection.collapsed(offset: projected.length),
    );
  }

  String get canonicalText {
    final buffer = StringBuffer();
    var offset = 0;
    while (offset < text.length) {
      if (text[offset] != _marker) {
        buffer.write(text[offset]);
        offset++;
        continue;
      }
      final end = text.indexOf(_marker, offset + 1);
      if (end < 0) {
        offset++;
        continue;
      }
      final label = text.substring(offset + 1, end);
      buffer.write(_labelToToken[label] ?? label);
      offset = end + 1;
    }
    return buffer.toString();
  }

  void insertToken(String token) {
    final label = _tokenToLabel[token] ?? token;
    final insertion = label == token ? token : '$_marker$label$_marker';
    final current = selection.isValid
        ? selection
        : TextSelection.collapsed(offset: text.length);
    final next = text.replaceRange(current.start, current.end, insertion);
    value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: current.start + insertion.length,
      ),
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final children = <InlineSpan>[];
    var offset = 0;
    while (offset < text.length) {
      final start = text.indexOf(_marker, offset);
      if (start < 0) {
        children.add(TextSpan(text: text.substring(offset), style: style));
        break;
      }
      if (start > offset) {
        children.add(
          TextSpan(text: text.substring(offset, start), style: style),
        );
      }
      final end = text.indexOf(_marker, start + 1);
      if (end < 0) {
        children.add(TextSpan(text: text.substring(start), style: style));
        break;
      }
      children.add(
        TextSpan(
          text: _marker,
          style: style?.copyWith(fontSize: 0, letterSpacing: 0),
        ),
      );
      children.add(
        TextSpan(
          text: text.substring(start + 1, end),
          style: style?.copyWith(
            color: FolooColors.ink,
            backgroundColor: FolooColors.lime.withValues(alpha: .28),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      children.add(
        TextSpan(
          text: _marker,
          style: style?.copyWith(fontSize: 0, letterSpacing: 0),
        ),
      );
      offset = end + 1;
    }
    return TextSpan(style: style, children: children);
  }
}

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
  final _subjectEditor = _FriendlyTemplateEditingController();
  final _bodyEditor = _FriendlyTemplateEditingController();
  final _signatureEditor = _FriendlyTemplateEditingController();
  final _subjectFocus = FocusNode();
  final _bodyFocus = FocusNode();
  final _signatureFocus = FocusNode();
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
  _TemplateField? _editingField;
  StreamSubscription<List<StoredEmailFollowUp>>? _followUpsSubscription;
  StreamSubscription<List<StoredEmailSendIntent>>? _intentsSubscription;

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
      if (widget.deliveryRepository == null) {
        _followUps = followUps;
        _intents = intents;
      }
      _connection = connection;
      _connectionUnavailable = unavailable;
      _connectionBusy = false;
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
    _editingField = null;
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
      _subjectEditor,
      _bodyEditor,
      _signatureEditor,
    ]) {
      controller.dispose();
    }
    _subjectFocus.dispose();
    _bodyFocus.dispose();
    _signatureFocus.dispose();
    super.dispose();
  }

  /// Inserts a supported token at the current caret without changing its name.
  void _insert(String variable) {
    final target = _subjectFocus.hasFocus
        ? _TemplateField.subject
        : _bodyFocus.hasFocus
        ? _TemplateField.body
        : _signatureFocus.hasFocus
        ? _TemplateField.signature
        : _lastTemplateField;
    final controller = switch (target) {
      _TemplateField.subject => _subject,
      _TemplateField.body => _body,
      _TemplateField.signature => _signature,
    };
    final focusNode = switch (target) {
      _TemplateField.subject => _subjectFocus,
      _TemplateField.body => _bodyFocus,
      _TemplateField.signature => _signatureFocus,
    };
    if (_editingField == target) {
      final editor = _editorFor(target);
      editor.insertToken(variable);
      controller.text = editor.canonicalText;
      _lastTemplateField = target;
      focusNode.requestFocus();
      setState(() {});
      return;
    }
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
    setState(() {
      _subject.text = official.subject;
      _body.text = official.body;
      _signature.text = official.signature;
      _editingField = null;
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

  String _friendlyToken(String token) => switch (token) {
    '{nombre}' => _english ? 'Contact name' : 'Nombre del contacto',
    '{apellido}' => _english ? 'Last name' : 'Apellido',
    '{empresa}' => _english ? 'Contact company' : 'Empresa del contacto',
    '{puesto}' => _english ? 'Role' : 'Puesto',
    '{evento}' => _english ? 'Event' : 'Evento',
    '{lugar}' => _english ? 'Place' : 'Lugar',
    '{contenido}' => _english ? 'Content' : 'Contenido',
    '{nombreVendedor}' => _english ? 'Your name' : 'Tu nombre',
    '{empresaVendedor}' => _english ? 'Your company' : 'Tu empresa',
    _ => token,
  };

  String _tokenSource(String token) => switch (token) {
    '{nombre}' || '{apellido}' || '{empresa}' || '{puesto}' =>
      _english ? 'From the captured lead' : 'Se toma del lead capturado',
    '{evento}' =>
      _english ? 'From the active event' : 'Se toma del evento activo',
    '{lugar}' => _english ? 'From the direct lead' : 'Se toma del lead directo',
    '{contenido}' =>
      _english ? 'From selected PDFs' : 'Se toma del contenido elegido',
    _ => _english ? 'From your profile' : 'Se toma de tu perfil',
  };

  _FriendlyTemplateEditingController _editorFor(_TemplateField field) =>
      switch (field) {
        _TemplateField.subject => _subjectEditor,
        _TemplateField.body => _bodyEditor,
        _TemplateField.signature => _signatureEditor,
      };

  void _prepareEditor(_TemplateField field, TextEditingController canonical) {
    _editorFor(field).loadCanonical(canonical.text, {
      for (final token in _variables) token: _friendlyToken(token),
    });
  }

  Future<void> _chooseVariable({
    String? replacing,
    int? replacementStart,
    _TemplateField? replacementField,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _english ? 'Insert data' : 'Insertar dato',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                _english
                    ? 'It fills automatically from the lead, event, or your profile.'
                    : 'Se llena solo con la información del lead, el evento o tu perfil.',
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _variables
                      .map(
                        (token) => ListTile(
                          key: Key('templateVariableChoice-$token'),
                          selected: token == replacing,
                          selectedTileColor: FolooColors.lime.withValues(
                            alpha: .25,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(FolooRadii.md),
                          ),
                          title: Text(_friendlyToken(token)),
                          subtitle: Text(_tokenSource(token)),
                          trailing: token == replacing
                              ? const Icon(Icons.check_circle)
                              : null,
                          onTap: () => Navigator.pop(sheetContext, token),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    if (replacing == null) {
      _insert(selected);
      return;
    }
    final field = replacementField ?? _lastTemplateField;
    final controller = switch (field) {
      _TemplateField.subject => _subject,
      _TemplateField.body => _body,
      _TemplateField.signature => _signature,
    };
    final start = replacementStart ?? controller.text.indexOf(replacing);
    if (start < 0 ||
        start + replacing.length > controller.text.length ||
        controller.text.substring(start, start + replacing.length) !=
            replacing) {
      return;
    }
    controller.text = controller.text.replaceRange(
      start,
      start + replacing.length,
      selected,
    );
    controller.selection = TextSelection.collapsed(
      offset: start + selected.length,
    );
    if (mounted) setState(() {});
  }

  Widget _friendlyDocument(
    TextEditingController controller,
    _TemplateField field,
  ) {
    final matches = RegExp(r'\{[^}]+\}').allMatches(controller.text).toList();
    final children = <Widget>[];
    var offset = 0;
    for (final match in matches) {
      if (match.start > offset) {
        children.add(Text(controller.text.substring(offset, match.start)));
      }
      final token = match.group(0)!;
      children.add(
        ActionChip(
          key: Key('friendlyToken-${field.name}-$token-${match.start}'),
          label: Text(_friendlyToken(token)),
          backgroundColor: FolooColors.lime.withValues(alpha: .25),
          onPressed: () {
            _lastTemplateField = field;
            _chooseVariable(
              replacing: token,
              replacementStart: match.start,
              replacementField: field,
            );
          },
        ),
      );
      offset = match.end;
    }
    if (offset < controller.text.length) {
      children.add(Text(controller.text.substring(offset)));
    }
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }

  Widget _templateField({
    required _TemplateField field,
    required TextEditingController controller,
    required FocusNode focusNode,
    required Key key,
    int minLines = 1,
    int maxLines = 4,
  }) {
    final editing = _editingField == field;
    final editor = _editorFor(field);
    final palette = FolooPalette.of(context);
    return Container(
      padding: editing
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: palette.paper,
        borderRadius: BorderRadius.circular(FolooRadii.md),
        border: editing ? Border.all(color: palette.ink, width: 2) : null,
      ),
      child: editing
          ? Stack(
              children: [
                TextField(
                  key: key,
                  controller: editor,
                  focusNode: focusNode,
                  minLines: minLines,
                  maxLines: maxLines,
                  onTap: () => _lastTemplateField = field,
                  onChanged: (_) {
                    controller.text = editor.canonicalText;
                    setState(() {});
                  },
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(14, 14, 52, 14),
                  ),
                ),
                Positioned(
                  top: 5,
                  right: 5,
                  child: IconButton.filled(
                    key: Key('templateLightning-${field.name}'),
                    tooltip: _english ? 'Insert data' : 'Insertar dato',
                    onPressed: _chooseVariable,
                    icon: const Icon(Icons.bolt, color: FolooColors.lime),
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _friendlyDocument(controller, field)),
                IconButton(
                  key: Key('templateEdit-${field.name}'),
                  tooltip: context.l10n.edit,
                  onPressed: () {
                    _prepareEditor(field, controller);
                    setState(() {
                      _editingField = field;
                      _lastTemplateField = field;
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      focusNode.requestFocus();
                      controller.selection = TextSelection.collapsed(
                        offset: controller.text.length,
                      );
                    });
                  },
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: FolooPalette.of(context).card,
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
              onBack: () {
                FocusManager.instance.primaryFocus?.unfocus();
                _applyLanguage(context.l10n);
                widget.onDestinationSelected(AppDestination.home);
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
                        _editingField = null;
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
                    _templateField(
                      key: ValueKey('emailSubject-${_kind.name}'),
                      field: _TemplateField.subject,
                      controller: _subject,
                      focusNode: _subjectFocus,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      context.l10n.body,
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 7),
                    _templateField(
                      key: ValueKey('emailBody-${_kind.name}'),
                      field: _TemplateField.body,
                      controller: _body,
                      focusNode: _bodyFocus,
                      minLines: 8,
                      maxLines: 12,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      context.l10n.emailSignatureV1,
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 7),
                    _templateField(
                      key: ValueKey('emailSignature-${_kind.name}'),
                      field: _TemplateField.signature,
                      controller: _signature,
                      focusNode: _signatureFocus,
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
