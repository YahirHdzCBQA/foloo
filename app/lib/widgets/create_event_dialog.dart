/// Shared event-creation dialog used from onboarding, capture and Mis eventos.
///
/// Content assignment is available to every V1 account (EVT-11/CON-06).
library;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/app_event.dart';
import '../models/content_file.dart';
import '../services/pdf_picker_service.dart';
import '../l10n/l10n.dart';
import 'content_assignment_sheet.dart';
import 'event_date_field.dart';

/// Opens event creation and returns a session model after local validation.
Future<AppEvent?> showCreateEventDialog(
  BuildContext context, {
  List<ContentFile> contentFiles = const [],
  PdfPickerService? pdfPickerService,
  ValueChanged<ContentFile>? onContentAdded,
}) async {
  return showDialog<AppEvent>(
    context: context,
    builder: (_) => _CreateEventDialog(
      contentFiles: contentFiles,
      pdfPickerService: pdfPickerService,
      onContentAdded: onContentAdded,
    ),
  );
}

class _CreateEventDialog extends StatefulWidget {
  const _CreateEventDialog({
    required this.contentFiles,
    required this.pdfPickerService,
    required this.onContentAdded,
  });
  final List<ContentFile> contentFiles;
  final PdfPickerService? pdfPickerService;
  final ValueChanged<ContentFile>? onContentAdded;

  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  final _name = TextEditingController();
  final Set<String> _selectedFiles = {};
  final List<ContentFile> _newFiles = [];
  late final PdfPickerService _pdfPicker;
  late final String _eventId;
  late DateTime _startsOn;
  late DateTime _endsOn;
  int _step = 0;
  String? _nameError;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _pdfPicker = widget.pdfPickerService ?? const DevicePdfPickerService();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _startsOn = today;
    _endsOn = today;
    _eventId = const Uuid().v4();
  }

  List<ContentFile> get _availableFiles => [
    ...widget.contentFiles,
    ..._newFiles,
  ];

  Future<void> _uploadContent() async {
    PickedPdf? picked;
    try {
      picked = await _pdfPicker.pickPdf();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.pdfSelectionError)));
      }
      return;
    }
    if (!mounted || picked == null) return;
    if (picked.byteSize > 25000000) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.pdfTooLarge)));
      return;
    }
    final provisionalEvent = AppEvent(
      id: _eventId,
      name: _name.text.trim().isEmpty
          ? context.l10n.createEvent
          : _name.text.trim(),
      startsOn: _startsOn,
      endsOn: _endsOn,
      active: true,
    );
    final created = await showContentAssignmentSheet(
      context,
      events: [provisionalEvent],
      pickedPdf: picked,
    );
    if (!mounted || created == null) return;
    final assigned = created.copyWith(
      allEvents: false,
      eventIds: {...created.eventIds, _eventId},
    );
    setState(() {
      _newFiles.add(assigned);
      _selectedFiles.add(assigned.id);
    });
  }

  Future<void> _pickStart() async {
    final selected = await showFolooDatePicker(context, initialDate: _startsOn);
    if (selected == null || !mounted) return;
    setState(() {
      _startsOn = selected;
      if (_endsOn.isBefore(selected)) _endsOn = selected;
    });
  }

  Future<void> _pickEnd() async {
    final selected = await showFolooDatePicker(
      context,
      initialDate: _endsOn.isBefore(_startsOn) ? _startsOn : _endsOn,
      firstDate: _startsOn,
    );
    if (selected != null && mounted) setState(() => _endsOn = selected);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _next() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = context.l10n.requiredField);
      return;
    }
    if (_endsOn.isBefore(_startsOn)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _nameError = null;
      _step = 1;
    });
  }

  void _back() => setState(() => _step = 0);

  void _create() {
    if (_creating) return;
    final name = _name.text.trim();
    if (name.isEmpty || _endsOn.isBefore(_startsOn)) {
      setState(() {
        _step = 0;
        _nameError = name.isEmpty ? context.l10n.requiredField : null;
      });
      return;
    }
    setState(() => _creating = true);
    for (final file in _newFiles) {
      widget.onContentAdded?.call(file);
    }
    Navigator.pop(
      context,
      AppEvent(
        id: _eventId,
        name: name,
        startsOn: _startsOn,
        endsOn: _endsOn,
        active: true,
        contentFileIds: {..._selectedFiles},
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      _step == 0 ? context.l10n.createEvent : context.l10n.contentForEvent,
    ),
    content: SizedBox(
      width: double.maxFinite,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: _step == 0 ? _eventDataStep() : _contentStep(),
      ),
    ),
    actions: _step == 0
        ? [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              key: const Key('nextCreateEventButton'),
              onPressed: _next,
              child: Text(context.l10n.next),
            ),
          ]
        : [
            TextButton(
              key: const Key('backCreateEventButton'),
              onPressed: _creating ? null : _back,
              child: Text(context.l10n.back),
            ),
            FilledButton(
              key: const Key('confirmCreateEventButton'),
              onPressed: _creating ? null : _create,
              child: Text(context.l10n.createAction),
            ),
          ],
  );

  Widget _eventDataStep() => SingleChildScrollView(
    key: const ValueKey('createEventDataStep'),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.eventCreationHelp,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        TextField(
          key: const Key('newEventNameField'),
          controller: _name,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _next(),
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
          decoration: InputDecoration(
            labelText: context.l10n.eventName,
            errorText: _nameError,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: EventDateField(
                key: const Key('newEventStartDate'),
                label: context.l10n.starts,
                date: _startsOn,
                onTap: _pickStart,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: EventDateField(
                key: const Key('newEventEndDate'),
                label: context.l10n.ends,
                date: _endsOn,
                onTap: _pickEnd,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _contentStep() => ConstrainedBox(
    key: const ValueKey('createEventContentStep'),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .52,
    ),
    child: ListView(
      shrinkWrap: true,
      children: [
        Text(
          context.l10n.createEventContentHelp,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('createEventUploadContentButton'),
          onPressed: _uploadContent,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(context.l10n.uploadContent),
        ),
        if (_availableFiles.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '${context.l10n.contentForEvent} · ${context.l10n.selectedOfTotal(_selectedFiles.length, _availableFiles.length)}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.contentAssignmentHelp,
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 6),
          for (final file in _availableFiles)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _selectedFiles.contains(file.id),
              title: Text(file.displayName),
              onChanged: (selected) => setState(() {
                if (selected ?? false) {
                  _selectedFiles.add(file.id);
                } else {
                  _selectedFiles.remove(file.id);
                }
              }),
            ),
        ],
      ],
    ),
  );
}
