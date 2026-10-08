/// Shared event list, creation and editing experience.
///
/// Manages frontend event state and V1 content assignments; deletion preserves
/// associated Leads and is confirmed before changing local state.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_destination.dart';
import '../models/app_event.dart';
import '../models/content_file.dart';
import '../models/email_template.dart';
import '../data/repositories/local_repositories.dart';
import '../services/event_selection_policy.dart';
import '../services/pdf_picker_service.dart';
import '../theme/foloo_theme.dart';
import '../l10n/l10n.dart';
import '../widgets/app_drawer.dart';
import '../widgets/create_event_dialog.dart';
import '../widgets/event_date_field.dart';
import '../widgets/module_header.dart';
import '../widgets/swipe_action_card.dart';
import '../widgets/email_template_field_editor.dart';

/// Displays Mis eventos and its in-place editor (EVT-01–EVT-13).
class EventScreen extends StatefulWidget {
  const EventScreen({
    required this.events,
    required this.recordsCount,
    required this.darkMode,
    required this.onDestinationSelected,
    required this.onAppearanceChanged,
    required this.onLogout,
    required this.onCreate,
    this.onContentAdded,
    required this.onUpdate,
    required this.onDelete,
    this.contentFiles = const [],
    this.pdfPickerService,
    this.nowProvider,
    this.ownerSub,
    this.templateRepository,
    this.eventEmailTemplateRepository,
    this.profile = DemoProfile.empty,
    super.key,
  });

  final List<AppEvent> events;
  final int recordsCount;
  final bool darkMode;
  final ValueChanged<AppDestination> onDestinationSelected;
  final ValueChanged<bool> onAppearanceChanged;
  final VoidCallback onLogout;
  final ValueChanged<AppEvent> onCreate;
  final ValueChanged<ContentFile>? onContentAdded;
  final ValueChanged<AppEvent> onUpdate;
  final ValueChanged<AppEvent> onDelete;
  final DemoProfile profile;
  final List<ContentFile> contentFiles;
  final PdfPickerService? pdfPickerService;
  final DateTime Function()? nowProvider;
  final String? ownerSub;
  final EmailTemplateRepository? templateRepository;
  final EventEmailTemplateRepository? eventEmailTemplateRepository;

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _editingName = TextEditingController();
  AppEvent? _editing;
  DateTime? _editingStartsOn;
  DateTime? _editingEndsOn;
  String? _openSwipeEventId;

  @override
  void dispose() {
    _editingName.dispose();
    super.dispose();
  }

  /// Switches composition to the selected read/edit view without adding a route.
  void _startEditing(AppEvent event) {
    _editingName.text = event.name;
    setState(() {
      _openSwipeEventId = null;
      _editing = event;
      _editingStartsOn = event.startsOn;
      _editingEndsOn = event.endsOn;
    });
  }

  Future<void> _pickEditingStart() async {
    final current = _editingStartsOn;
    if (current == null) return;
    final selected = await showFolooDatePicker(context, initialDate: current);
    if (selected == null || !mounted) return;
    setState(() {
      _editingStartsOn = selected;
      if ((_editingEndsOn ?? selected).isBefore(selected)) {
        _editingEndsOn = selected;
      }
    });
  }

  Future<void> _pickEditingEnd() async {
    final start = _editingStartsOn;
    final end = _editingEndsOn;
    if (start == null || end == null) return;
    final selected = await showFolooDatePicker(
      context,
      initialDate: end.isBefore(start) ? start : end,
      firstDate: start,
    );
    if (selected != null && mounted) {
      setState(() => _editingEndsOn = selected);
    }
  }

  Future<void> _createEvent() async {
    final created = await showCreateEventDialog(
      context,
      contentFiles: widget.contentFiles,
      pdfPickerService: widget.pdfPickerService,
      onContentAdded: widget.onContentAdded,
    );
    if (created == null) return;
    widget.onCreate(created);
  }

  Future<void> _confirmDelete(AppEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.deleteEvent),
        content: Text(dialogContext.l10n.deleteEventQuestion(event.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton.icon(
            key: const Key('confirmDeleteEventButton'),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: Text(dialogContext.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.onDelete(event);
    setState(() => _editing = null);
  }

  Future<void> _editEmailOverride(AppEvent event) async {
    final owner = widget.ownerSub;
    final repository = widget.eventEmailTemplateRepository;
    if (owner == null || repository == null) return;
    final language = Localizations.localeOf(context).languageCode == 'en'
        ? 'en'
        : 'es';
    final existing = await repository.get(owner, event.id, language);
    final sellerTemplates = await widget.templateRepository?.list(owner) ?? [];
    final seller = sellerTemplates
        .where((item) => item.origin == 'event' && item.language == language)
        .firstOrNull;
    final inherited =
        seller ?? FolooEmailDefaults.forContext('event', language);
    if (!mounted) return;
    final result = await showModalBottomSheet<_EventTemplateResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EventEmailTemplateSheet(
        initial: EventEmailTemplateData(
          eventId: event.id,
          language: language,
          subject: existing?.subject ?? inherited.subject,
          body: existing?.body ?? inherited.body,
          signature: existing?.signature ?? inherited.signature,
        ),
        canUseDefault: existing != null,
      ),
    );
    if (result?.useDefault == true) {
      await repository.remove(owner, event.id, language);
    } else if (result?.template != null) {
      await repository.save(owner, result!.template!);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final editing = _editing;
    if (editing == null) return _buildList();
    final current = widget.events.where((event) => event.id == editing.id);
    return _buildEditor(current.isEmpty ? editing : current.first);
  }

  Widget _drawer() => AppDrawer(
    contentCount: widget.contentFiles.length,
    profile: widget.profile,
    activeDestination: AppDestination.events,
    recordsCount: widget.recordsCount,
    darkMode: widget.darkMode,
    onDestinationSelected: widget.onDestinationSelected,
    onAppearanceChanged: widget.onAppearanceChanged,
    onLogout: widget.onLogout,
  );

  Widget _buildList() {
    final palette = FolooPalette.of(context);
    final total = widget.events.fold<int>(
      0,
      (sum, event) => sum + event.demoLeadCount,
    );
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: palette.card,
      endDrawer: _drawer(),
      body: Column(
        children: [
          ModuleHeader(
            title: context.l10n.eventsTitle,
            subtitle:
                '${context.l10n.eventCount(widget.events.length)} · ${context.l10n.leadCount(total)}',
            onMenuPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          Divider(height: 1, color: palette.line),
          Expanded(
            child: widget.events.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 44),
                          const SizedBox(height: 14),
                          Text(
                            context.l10n.emptyEvents,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.l10n.createFirstEvent,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: palette.inkSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildGroupedEventList(palette),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: palette.card,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: FilledButton.icon(
            key: const Key('createEventButton'),
            onPressed: _createEvent,
            icon: const Icon(Icons.add),
            label: Text(context.l10n.createEvent),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedEventList(FolooPalette palette) {
    final groups = EventGroupingPolicy.group(
      widget.events,
      now: widget.nowProvider?.call() ?? DateTime.now(),
    );
    final children = <Widget>[];

    void addSection(Key key, String title, List<AppEvent> events) {
      if (events.isEmpty) return;
      if (children.isNotEmpty) children.add(const SizedBox(height: 18));
      children.add(
        Text(
          title,
          key: key,
          style: TextStyle(
            color: palette.inkSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: .7,
          ),
        ),
      );
      children.add(const SizedBox(height: 8));
      for (var index = 0; index < events.length; index++) {
        if (index > 0) children.add(const SizedBox(height: 8));
        children.add(_buildEventCard(events[index], palette));
      }
    }

    if (groups.active != null) {
      addSection(
        const Key('activeEventsSection'),
        context.l10n.activeEventSection,
        [groups.active!],
      );
    }
    addSection(
      const Key('futureEventsSection'),
      context.l10n.futureEventsSection,
      groups.future,
    );
    addSection(
      const Key('pastEventsSection'),
      context.l10n.pastEventsSection,
      groups.past,
    );
    children.add(const SizedBox(height: 20));
    children.add(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.paper,
          borderRadius: BorderRadius.circular(FolooRadii.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, size: 18, color: palette.inkSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.l10n.eventDeleteHelp,
                style: TextStyle(
                  color: palette.inkSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return ListView(
      key: const Key('eventsList'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: children,
    );
  }

  Widget _buildEventCard(
    AppEvent event,
    FolooPalette palette,
  ) => SwipeActionCard(
    key: Key('eventSwipe-${event.id}'),
    open: _openSwipeEventId == event.id,
    onOpened: () => setState(() => _openSwipeEventId = event.id),
    onClosed: () {
      if (_openSwipeEventId == event.id) {
        setState(() => _openSwipeEventId = null);
      }
    },
    startAction: SwipeCardAction(
      actionKey: Key('eventSwipeEdit-${event.id}'),
      icon: Icons.edit_outlined,
      label: context.l10n.edit,
      color: FolooColors.lime.withValues(alpha: .32),
      foregroundColor: palette.ink,
      onTap: () => _startEditing(event),
    ),
    endAction: SwipeCardAction(
      actionKey: Key('eventSwipeDelete-${event.id}'),
      icon: Icons.delete_outline,
      label: context.l10n.delete,
      color: palette.error,
      foregroundColor: Colors.white,
      onTap: () => _confirmDelete(event),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('event-${event.id}'),
        onTap: () => _startEditing(event),
        child: Container(
          height: 62,
          padding: const EdgeInsets.fromLTRB(13, 5, 5, 5),
          decoration: BoxDecoration(
            color: palette.paper,
            borderRadius: BorderRadius.circular(FolooRadii.md),
            border: event.active ? Border.all(color: palette.ink) : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            event.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (event.active) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: palette.card,
                              border: Border.all(color: palette.ink),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              context.l10n.active,
                              style: const TextStyle(fontSize: 9),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.eventStats(
                        _date(event.startsOn),
                        context.l10n.leadCount(event.demoLeadCount),
                        event.demoPendingCount > 0
                            ? ' · ${context.l10n.pendingCount(event.demoPendingCount)}'
                            : '',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.inkSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: Key('eventMenu-${event.id}'),
                tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                onSelected: (value) => value == 'edit'
                    ? _startEditing(event)
                    : _confirmDelete(event),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: Text(context.l10n.editEvent),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: palette.error),
                      title: Text(context.l10n.deleteEvent),
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_vert, size: 20),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildEditor(AppEvent event) {
    final palette = FolooPalette.of(context);
    return Scaffold(
      backgroundColor: palette.card,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              color: palette.card,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: Row(
                children: [
                  IconButton.filled(
                    key: const Key('closeEventEditorButton'),
                    onPressed: () => setState(() => _editing = null),
                    style: IconButton.styleFrom(
                      backgroundColor: FolooColors.lime,
                      foregroundColor: FolooColors.ink,
                    ),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.editEvent,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          event.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.inkSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.eventName,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 7),
                  TextField(
                    key: const Key('editEventNameField'),
                    controller: _editingName,
                    textInputAction: TextInputAction.done,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: palette.paper,
                      border: FolooBorders.borderlessField,
                      enabledBorder: FolooBorders.borderlessField,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(FolooRadii.md),
                        borderSide: BorderSide(color: palette.ink, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: EventDateField(
                          key: const Key('editEventStartDate'),
                          label: context.l10n.starts,
                          date: _editingStartsOn ?? event.startsOn,
                          onTap: _pickEditingStart,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: EventDateField(
                          key: const Key('editEventEndDate'),
                          label: context.l10n.ends,
                          date: _editingEndsOn ?? event.endsOn,
                          onTap: _pickEditingEnd,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    context.l10n.thisEvent,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          key: const Key('eventLeadCount'),
                          value: '${event.demoLeadCount}',
                          label: context.l10n.leadsLabel,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Metric(
                          key: const Key('eventPendingCount'),
                          value: '${event.demoPendingCount}',
                          label: context.l10n.pendingUpload,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (widget.ownerSub != null &&
                      widget.eventEmailTemplateRepository != null) ...[
                    FutureBuilder<EventEmailTemplateData?>(
                      future: widget.eventEmailTemplateRepository!.get(
                        widget.ownerSub!,
                        event.id,
                        Localizations.localeOf(context).languageCode == 'en'
                            ? 'en'
                            : 'es',
                      ),
                      builder: (context, snapshot) => ListTile(
                        key: const Key('eventEmailTemplateTile'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        tileColor: palette.paper,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(FolooRadii.md),
                        ),
                        leading: const Icon(Icons.mail_outline),
                        title: Text(context.l10n.customizeEventEmail),
                        subtitle: Text(
                          snapshot.data == null
                              ? context.l10n.usingDefaultTemplate
                              : context.l10n.customEventTemplate,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _editEmailOverride(event),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  OutlinedButton.icon(
                    key: const Key('deleteEventButton'),
                    onPressed: () => _confirmDelete(event),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.error,
                      side: BorderSide(color: palette.error),
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(context.l10n.deleteEvent),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    context.l10n.eventDeletedHelp,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.inkSecondary,
                      fontSize: 12.5,
                    ),
                  ),
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
            color: palette.card,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            child: FilledButton(
              key: const Key('saveEventButton'),
              onPressed: () {
                final value = _editingName.text.trim();
                if (value.isNotEmpty) {
                  widget.onUpdate(
                    event.copyWith(
                      name: value,
                      startsOn: _editingStartsOn,
                      endsOn: _editingEndsOn,
                    ),
                  );
                }
                setState(() => _editing = null);
              },
              child: Text(context.l10n.saveChanges),
            ),
          ),
        ),
      ),
    );
  }

  String _date(DateTime date) {
    return DateFormat(
      'd MMM y',
      Localizations.localeOf(context).toLanguageTag(),
    ).format(date);
  }
}

class _EventTemplateResult {
  const _EventTemplateResult.save(this.template) : useDefault = false;
  const _EventTemplateResult.useDefault() : template = null, useDefault = true;

  final EventEmailTemplateData? template;
  final bool useDefault;
}

/// Route-owned editor that keeps its controllers alive through sheet teardown.
class _EventEmailTemplateSheet extends StatefulWidget {
  const _EventEmailTemplateSheet({
    required this.initial,
    required this.canUseDefault,
  });

  final EventEmailTemplateData initial;
  final bool canUseDefault;

  @override
  State<_EventEmailTemplateSheet> createState() =>
      _EventEmailTemplateSheetState();
}

class _EventEmailTemplateSheetState extends State<_EventEmailTemplateSheet> {
  late final TextEditingController _subject;
  late final TextEditingController _body;
  late final TextEditingController _signature;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subject = TextEditingController(text: widget.initial.subject);
    _body = TextEditingController(text: widget.initial.body);
    _signature = TextEditingController(text: widget.initial.signature);
  }

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    _signature.dispose();
    super.dispose();
  }

  void _save() {
    final source = '${_subject.text} ${_body.text} ${_signature.text}';
    final found = RegExp(r'\{[^}]+\}')
        .allMatches(source)
        .map((match) => match.group(0)!)
        .toSet();
    final invalid = found.difference(emailTemplateVariables.toSet());
    final balanced =
        RegExp(r'\{').allMatches(source).length ==
        RegExp(r'\}').allMatches(source).length;
    setState(() {
      _error = !balanced
          ? context.l10n.unclosedVariable
          : invalid.isEmpty
          ? null
          : context.l10n.invalidVariable(invalid.join(', '));
    });
    if (_error != null) return;
    Navigator.pop(
      context,
      _EventTemplateResult.save(
        EventEmailTemplateData(
          eventId: widget.initial.eventId,
          language: widget.initial.language,
          subject: _subject.text,
          body: _body.text,
          signature: _signature.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: FolooPalette.of(context).card,
    body: SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.customizeEventEmail,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          Text(context.l10n.subject),
          const SizedBox(height: 7),
          EmailTemplateFieldEditor(
            fieldName: 'subject',
            controller: _subject,
            textFieldKey: const Key('eventEmailSubjectField'),
            keyPrefix: 'event',
            maxLines: 2,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 14),
          Text(context.l10n.body),
          const SizedBox(height: 7),
          EmailTemplateFieldEditor(
            fieldName: 'body',
            controller: _body,
            textFieldKey: const Key('eventEmailBodyField'),
            keyPrefix: 'event',
            minLines: 7,
            maxLines: 12,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 14),
          Text(context.l10n.emailSignatureV1),
          const SizedBox(height: 7),
          EmailTemplateFieldEditor(
            fieldName: 'signature',
            controller: _signature,
            textFieldKey: const Key('eventEmailSignatureField'),
            keyPrefix: 'event',
            minLines: 2,
            maxLines: 4,
            onChanged: () => setState(() {}),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                key: const Key('eventEmailVariableError'),
                style: TextStyle(color: FolooPalette.of(context).error),
              ),
            ),
          if (widget.canUseDefault)
            TextButton(
              key: const Key('useDefaultEventTemplateButton'),
              onPressed: () => Navigator.pop(
                context,
                const _EventTemplateResult.useDefault(),
              ),
              child: Text(context.l10n.useDefaultTemplate),
            ),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useVerticalLayout =
                constraints.maxWidth < 420 ||
                MediaQuery.textScalerOf(context).scale(14) > 18;
            final cancel = FilledButton(
              key: const Key('cancelEventEmailTemplateButton'),
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: FolooPalette.of(context).paper,
                foregroundColor: FolooPalette.of(context).ink,
              ),
              child: Text(context.l10n.cancel),
            );
            final save = FilledButton(
              key: const Key('saveEventEmailTemplateButton'),
              onPressed: _save,
              child: Text(context.l10n.saveChanges),
            );
            if (useVerticalLayout) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [cancel, const SizedBox(height: 8), save],
              );
            }
            return Row(
              children: [
                Expanded(child: cancel),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: save),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, super.key});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: FolooPalette.of(context).paper,
      borderRadius: BorderRadius.circular(FolooRadii.md),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
