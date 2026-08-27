/// Shared event-creation dialog used from onboarding, capture and Mis eventos.
///
/// Pro content assignment is included only when the caller supplies that
/// capability; Basic retains the same core event fields.
library;

import 'package:flutter/material.dart';

import '../models/app_event.dart';
import '../models/app_plan.dart';
import '../models/pro_demo_data.dart';
import '../l10n/l10n.dart';
import 'event_date_field.dart';

/// Opens event creation and returns a session model after local validation.
Future<AppEvent?> showCreateEventDialog(
  BuildContext context, {
  AppPlan plan = AppPlan.basic,
  List<ContentFile> contentFiles = const [],
}) async {
  return showDialog<AppEvent>(
    context: context,
    builder: (_) => _CreateEventDialog(plan: plan, contentFiles: contentFiles),
  );
}

class _CreateEventDialog extends StatefulWidget {
  const _CreateEventDialog({required this.plan, required this.contentFiles});
  final AppPlan plan;
  final List<ContentFile> contentFiles;

  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  final _name = TextEditingController();
  final Set<String> _selectedFiles = {};
  DateTime _startsOn = DateTime(2026, 8, 12);
  DateTime _endsOn = DateTime(2026, 8, 14);

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
        if (widget.plan.isPro && widget.contentFiles.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '${context.l10n.contentForEvent} · ${context.l10n.selectedOfTotal(_selectedFiles.length, widget.contentFiles.length)}',
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
              children: widget.contentFiles
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
          Navigator.pop(
            context,
            AppEvent(
              id: 'demo-${DateTime.now().microsecondsSinceEpoch}',
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
