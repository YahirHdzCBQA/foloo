/// Pro content upload/edit sheet for assigning one PDF to events.
///
/// The current sheet returns session metadata only; file transfer and durable
/// assignment remain backend work under CON-*.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_event.dart';
import '../models/pro_demo_data.dart';
import '../theme/foloo_theme.dart';
import '../l10n/l10n.dart';

/// Opens the capability-scoped editor and returns an updated local fixture.
Future<ContentFile?> showContentAssignmentSheet(
  BuildContext context, {
  required List<AppEvent> events,
  ContentFile? file,
}) => showModalBottomSheet<ContentFile>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (_) => _ContentAssignmentSheet(events: events, file: file),
);

/// Stateful form used for both adding and editing Pro content metadata.
class _ContentAssignmentSheet extends StatefulWidget {
  const _ContentAssignmentSheet({required this.events, this.file});
  final List<AppEvent> events;
  final ContentFile? file;

  @override
  State<_ContentAssignmentSheet> createState() =>
      _ContentAssignmentSheetState();
}

class _ContentAssignmentSheetState extends State<_ContentAssignmentSheet> {
  final _name = TextEditingController();
  final _search = TextEditingController();
  late Set<String> _selected;
  late Set<String> _selectionBeforeAll;
  late bool _all;

  @override
  void initState() {
    super.initState();
    _name.text = widget.file?.displayName ?? '';
    _selected = {...?widget.file?.eventIds};
    _selectionBeforeAll = {..._selected};
    _all = widget.file?.allEvents ?? false;
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _search.dispose();
    super.dispose();
  }

  void _toggleAll(bool value) {
    setState(() {
      if (value) _selectionBeforeAll = {..._selected};
      _all = value;
      if (!value) _selected = {..._selectionBeforeAll};
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = widget.events
        .where((event) => event.name.toLowerCase().contains(query))
        .toList();
    final editing = widget.file != null;
    return FractionallySizedBox(
      heightFactor: .78,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Scaffold(
          backgroundColor: FolooPalette.of(context).card,
          body: ListView(
            key: const Key('contentAssignmentScroll'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
            children: [
              Text(
                editing
                    ? context.l10n.editFileEvents
                    : context.l10n.uploadContent,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (editing) ...[
                const SizedBox(height: 3),
                Text(
                  '${widget.file!.fileName} · ${widget.file!.sizeLabel}',
                  style: TextStyle(
                    color: FolooPalette.of(context).inkSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (!editing) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: FolooPalette.of(context).paper,
                    borderRadius: BorderRadius.circular(FolooRadii.md),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.picture_as_pdf_outlined),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text('documento-demo.pdf · PDF · 1.2 MB'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const Key('contentDisplayNameField'),
                  controller: _name,
                  decoration: InputDecoration(
                    hintText: context.l10n.displayName,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                context.l10n.eventAssignmentCount(
                  _all ? widget.events.length : _selected.length,
                  widget.events.length,
                ),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('contentEventSearch'),
                controller: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: context.l10n.searchEvents,
                  border: FolooBorders.borderlessField,
                  enabledBorder: FolooBorders.borderlessField,
                  focusedBorder: FolooBorders.borderlessField,
                ),
              ),
              const SizedBox(height: 8),
              _AssignmentRow(
                key: const Key('allEventsSwitch'),
                selected: _all,
                title: context.l10n.allEvents,
                subtitle: context.l10n.allEventsHelp,
                onTap: () => _toggleAll(!_all),
              ),
              const SizedBox(height: 8),
              ListView.separated(
                key: const Key('contentEventsList'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visible.length,
                separatorBuilder: (_, _) => const SizedBox(height: 7),
                itemBuilder: (_, index) {
                  final event = visible[index];
                  return _AssignmentRow(
                    key: Key('contentEvent-${event.id}'),
                    enabled: !_all,
                    selected: _selected.contains(event.id),
                    title: event.name,
                    subtitle: event.active
                        ? '${context.l10n.active} · ${_date(context, event.startsOn)}'
                        : _date(context, event.startsOn),
                    onTap: () => setState(() {
                      if (!_selected.contains(event.id)) {
                        _selected.add(event.id);
                      } else {
                        _selected.remove(event.id);
                      }
                    }),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: FolooPalette.of(context).paper,
                        foregroundColor: FolooPalette.of(context).ink,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const Key('confirmContentButton'),
                      onPressed: () {
                        final displayName = editing
                            ? widget.file!.displayName
                            : _name.text.trim();
                        if (displayName.isEmpty) return;
                        // TODO(PRODUCTION): Upload PDFs and persist assignments.
                        Navigator.pop(
                          context,
                          (widget.file ??
                                  ContentFile(
                                    id: 'demo-${DateTime.now().microsecondsSinceEpoch}',
                                    displayName: displayName,
                                    fileName: 'documento-demo.pdf',
                                    sizeLabel: '1.2 MB',
                                  ))
                              .copyWith(
                                displayName: displayName,
                                allEvents: _all,
                                eventIds: {..._selected},
                              ),
                        );
                      },
                      child: Text(
                        editing ? context.l10n.save : context.l10n.upload,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _date(BuildContext context, DateTime date) => DateFormat(
    'd MMM y',
    Localizations.localeOf(context).toLanguageTag(),
  ).format(date);
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    return Opacity(
      opacity: enabled ? 1 : .5,
      child: Material(
        color: selected ? FolooSelection.surface(context) : palette.paper,
        borderRadius: BorderRadius.circular(FolooRadii.sm),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(FolooRadii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 21,
                  height: 21,
                  decoration: BoxDecoration(
                    color: selected ? palette.ink : Colors.transparent,
                    border: Border.all(color: palette.inkSecondary),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check,
                          color: FolooColors.lime,
                          size: 15,
                        )
                      : null,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: palette.inkSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
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
