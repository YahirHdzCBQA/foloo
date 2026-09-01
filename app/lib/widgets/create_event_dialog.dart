/// Shared event-creation dialog used from onboarding, capture and Mis eventos.
///
/// Pro content assignment is included only when the caller supplies that
/// capability; Basic retains the same core event fields.
library;

import 'package:flutter/material.dart';

import '../models/app_event.dart';
import '../models/app_plan.dart';
import '../models/pro_demo_data.dart';
import '../services/pdf_picker_service.dart';
import '../l10n/l10n.dart';
import 'content_assignment_sheet.dart';
import 'event_date_field.dart';

/// Opens event creation and returns a session model after local validation.
Future<AppEvent?> showCreateEventDialog(
  BuildContext context, {
  AppPlan plan = AppPlan.basic,
  List<ContentFile> contentFiles = const [],
  PdfPickerService? pdfPickerService,
  ValueChanged<ContentFile>? onContentAdded,
}) async {
  return showDialog<AppEvent>(
    context: context,
    builder: (_) => _CreateEventDialog(
      plan: plan,
      contentFiles: contentFiles,
      pdfPickerService: pdfPickerService,
      onContentAdded: onContentAdded,
    ),
  );
}

class _CreateEventDialog extends StatefulWidget {
  const _CreateEventDialog({
    required this.plan,
    required this.contentFiles,
    required this.pdfPickerService,
    required this.onContentAdded,
  });
  final AppPlan plan;
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

  @override
  void initState() {
    super.initState();
    _pdfPicker = widget.pdfPickerService ?? const DevicePdfPickerService();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _startsOn = today;
    _endsOn = today;
    _eventId = 'demo-${now.microsecondsSinceEpoch}';
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

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(context.l10n.createEvent),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.eventCreationHelp,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        Text(
          context.l10n.eventName,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 7),
        TextField(
          key: const Key('newEventNameField'),
          controller: _name,
          autofocus: true,
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
        if (widget.plan.isPro) ...[
          const SizedBox(height: 16),
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
              style: TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.maxFinite,
              height: 150,
              child: ListView(
                children: _availableFiles
                    .map(
                      (file) => CheckboxListTile(
                        dense: true,
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
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        key: const Key('confirmCreateEventButton'),
        onPressed: () {
          final value = _name.text.trim();
          if (value.isEmpty) return;
          for (final file in _newFiles) {
            widget.onContentAdded?.call(file);
          }
          Navigator.pop(
            context,
            AppEvent(
              id: _eventId,
              name: value,
              startsOn: _startsOn,
              endsOn: _endsOn,
              active: true,
              contentFileIds: {..._selectedFiles},
            ),
          );
        },
        child: Text(context.l10n.createAction),
      ),
    ],
  );
}
