/// Records bottom sheets with disposable drafts for event, date and extra filters.
/// The screen supplies the same evaluator used to render and export results.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/app_event.dart';
import '../models/lead_draft.dart';
import '../models/records_filter_state.dart';
import '../theme/foloo_theme.dart';
import 'event_date_field.dart';
import 'segmented_bubble.dart';

enum RecordsFilterPanel { events, dates, additional }

/// Formats civil dates without depending on the mocked dates in the design.
String recordsDateLabel(BuildContext context, RecordsDateRange range) {
  final l10n = context.l10n;
  if (range.unrestricted) return l10n.recordsAllDates;
  final format = DateFormat.yMMMd(
    Localizations.localeOf(context).toLanguageTag(),
  );
  final from = range.from;
  final to = range.to;
  if (from == null) return '${l10n.recordsDateTo} ${format.format(to!)}';
  if (to == null) return '${l10n.recordsDateFrom} ${format.format(from)}';
  final start = from.year == to.year
      ? DateFormat.MMMd(Localizations.localeOf(context).toLanguageTag())
            .format(from)
      : format.format(from);
  return '$start – ${format.format(to)}';
}

/// Presents a single filter sheet; dismissal returns null without applying.
Future<RecordsFilterState?> showRecordsFilterSheet(
  BuildContext context, {
  required RecordsFilterPanel panel,
  required RecordsFilterState filters,
  required List<AppEvent> events,
  required Map<String, int> eventCounts,
  required Map<String, String> contentNames,
  required int Function(RecordsFilterState) countResults,
  required ValueChanged<ModalRoute<RecordsFilterState>?> onRoute,
}) => showModalBottomSheet<RecordsFilterState>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: FolooPalette.of(context).card,
  builder: (sheetContext) {
    onRoute(ModalRoute.of<RecordsFilterState>(sheetContext));
    return _RecordsFilterSheet(
      panel: panel,
      filters: filters,
      events: events,
      eventCounts: eventCounts,
      contentNames: contentNames,
      countResults: countResults,
    );
  },
);

class _RecordsFilterSheet extends StatefulWidget {
  const _RecordsFilterSheet({
    required this.panel,
    required this.filters,
    required this.events,
    required this.eventCounts,
    required this.contentNames,
    required this.countResults,
  });

  final RecordsFilterPanel panel;
  final RecordsFilterState filters;
  final List<AppEvent> events;
  final Map<String, int> eventCounts;
  final Map<String, String> contentNames;
  final int Function(RecordsFilterState) countResults;

  @override
  State<_RecordsFilterSheet> createState() => _RecordsFilterSheetState();
}

class _RecordsFilterSheetState extends State<_RecordsFilterSheet> {
  late RecordsFilterState _draft = widget.filters;
  final DateTime _now = DateTime.now();
  String _eventQuery = '';

  Set<String> get _knownIds => widget.events.map((event) => event.id).toSet();

  void _toggleEvent(String id) {
    final selected = {...(_draft.eventIds ?? _knownIds)};
    if (!selected.remove(id)) selected.add(id);
    setState(() => _draft = _draft.copyWith(eventIds: selected));
  }

  Future<void> _pickDate(bool start) async {
    final now = _now;
    final selected = start ? _draft.dates.from : _draft.dates.to;
    final first = DateTime(1900);
    final last = DateTime(now.year + 100, 12, 31);
    final picked = await showFolooDatePicker(
      context,
      firstDate: first,
      lastDate: last,
      initialDate:
          selected == null || selected.isBefore(first) || selected.isAfter(last)
          ? now
          : selected,
    );
    if (!mounted || picked == null || picked == selected) return;
    setState(
      () => _draft = _draft.copyWith(
        dates: RecordsDateRange(
          start ? picked : _draft.dates.from,
          start ? _draft.dates.to : picked,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = FolooPalette.of(context);
    final eventPanel = widget.panel == RecordsFilterPanel.events;
    final datePanel = widget.panel == RecordsFilterPanel.dates;
    final title = switch (widget.panel) {
      RecordsFilterPanel.events => l10n.recordsChooseEvent,
      RecordsFilterPanel.dates => l10n.recordsWhichDates,
      RecordsFilterPanel.additional => l10n.recordsMoreFilters,
    };
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final expandedText = MediaQuery.textScalerOf(context).scale(12) > 16;
    final options = eventPanel
        ? _eventOptions(context)
        : datePanel
        ? _dateOptions(context)
        : _additionalOptions(context);
    final clear = TextButton(
      key: const Key('recordsClearAdditional'),
      onPressed: () => setState(
        () => _draft = _draft.copyWith(
          interests: const {},
          contentIds: const {},
          withoutContent: false,
        ),
      ),
      child: Text(
        l10n.recordsClear,
        style: TextStyle(
          color: palette.ink,
          decoration: TextDecoration.underline,
        ),
      ),
    );
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: inset),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                ((MediaQuery.sizeOf(context).height - inset) *
                        (eventPanel ? .88 : .76))
                    .clamp(0, double.infinity)
                    .toDouble(),
          ),
          child: Builder(
            builder: (context) {
              final children = <Widget>[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (eventPanel)
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: palette.paper,
                        ),
                        onPressed: () => Navigator.pop(context),
                        tooltip: MaterialLocalizations.of(context)
                            .closeButtonTooltip,
                        icon: const Icon(Icons.close),
                      ),
                    if (!eventPanel && !datePanel && !expandedText) clear,
                  ],
                ),
                if (!eventPanel && !datePanel && expandedText)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: clear,
                  ),
                if (eventPanel)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: TextField(
                      key: const Key('recordsEventSearch'),
                      onChanged: (value) => setState(() => _eventQuery = value),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: palette.ink),
                      decoration: InputDecoration(
                        hintText: l10n.recordsSearchEvent(widget.events.length),
                        isDense: true,
                        constraints: const BoxConstraints(minHeight: 44),
                        contentPadding: const EdgeInsetsDirectional.fromSTEB(
                          0,
                          9,
                          12,
                          9,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 38,
                          minHeight: 44,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 17,
                          color: palette.inkSecondary,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(FolooRadii.xl),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(FolooRadii.xl),
                          borderSide: BorderSide(color: palette.ink),
                        ),
                      ),
                    ),
                  ),
                if (expandedText)
                  ...options
                else
                  Flexible(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: options,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('recordsApplyFilters'),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.ink,
                    foregroundColor: palette.card,
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: datePanel && !_draft.dates.valid
                      ? null
                      : () => Navigator.pop(context, _draft),
                  child: Text(
                    eventPanel
                        ? l10n.recordsApplyEvents
                        : l10n.recordsSeeLeads(widget.countResults(_draft)),
                  ),
                ),
              ];
              final content = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              );
              return expandedText
                  ? SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: content,
                    )
                  : content;
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _eventOptions(BuildContext context) {
    final l10n = context.l10n;
    final palette = FolooPalette.of(context);
    final theme = Theme.of(context).textTheme;
    final titleStyle = theme.bodyMedium?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    final events =
        widget.events
            .where(
              (event) =>
                  normalizeRecordsQuery(event.name)
                      .contains(normalizeRecordsQuery(_eventQuery)),
            )
            .toList()
          ..sort(
            (a, b) => a.active == b.active
                ? b.startsOn.compareTo(a.startsOn)
                : a.active
                ? -1
                : 1,
          );
    return [
      CheckboxListTile(
        key: const Key('recordsSelectAllEvents'),
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.allEvents, style: titleStyle),
        value:
            _draft.eventIds == null ||
            (_knownIds.isNotEmpty && _draft.eventIds!.containsAll(_knownIds)),
        onChanged: (value) => setState(
          () => _draft = value == true
              ? _draft.copyWith(allEvents: true)
              : _draft.copyWith(eventIds: const {}),
        ),
      ),
      if (events.isEmpty)
        Text(
          widget.events.isEmpty
              ? l10n.noEventsAvailable
              : l10n.noFilteredRecords,
        ),
      for (final event in events) ...[
        Divider(height: 1, color: palette.line),
        CheckboxListTile(
          key: Key('recordsEvent-${event.id}'),
          contentPadding: EdgeInsets.zero,
          value: _draft.eventIds?.contains(event.id) ?? true,
          onChanged: (_) => _toggleEvent(event.id),
          title: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(event.name, style: titleStyle),
              if (event.active)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.paper,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: Text(l10n.active, style: theme.bodySmall),
                  ),
                ),
            ],
          ),
          subtitle: Text(
            '${recordsDateLabel(context, RecordsDateRange(event.startsOn, event.endsOn))} · '
            '${l10n.leadCount(widget.eventCounts[event.id] ?? 0)}',
            style: theme.bodySmall,
          ),
        ),
      ],
    ];
  }

  List<Widget> _dateOptions(BuildContext context) {
    final l10n = context.l10n;
    final labels = {
      RecordsDatePreset.thisWeek: l10n.recordsThisWeek,
      RecordsDatePreset.thisMonth: l10n.recordsThisMonth,
      RecordsDatePreset.lastMonth: l10n.recordsLastMonth,
      RecordsDatePreset.last90Days: l10n.recordsLast90Days,
      RecordsDatePreset.all: l10n.recordsAllDates,
    };
    final format = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final secondary = Theme.of(context).textTheme.bodySmall;
    final selectedPreset = _draft.dates.matchingPreset(_now);
    RecordsChoice preset(RecordsDatePreset value) => RecordsChoice(
      key: Key('recordsDatePreset-${value.name}'),
      label: labels[value]!,
      selected: selectedPreset == value,
      onTap: () => setState(
        () => _draft = _draft.copyWith(
          dates: RecordsDateRange.preset(value, _now),
        ),
      ),
    );
    Widget field(bool from, DateTime? date) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          from ? l10n.recordsDateFrom : l10n.recordsDateTo,
          style: secondary,
        ),
        const SizedBox(height: 6),
        OutlinedButton(
          key: Key(from ? 'recordsDateFrom' : 'recordsDateTo'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            minimumSize: const Size(44, 44),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          onPressed: () => _pickDate(from),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 17),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  date == null ? l10n.recordsPickDate : format.format(date),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return [
      Text(l10n.recordsDatesHelp, style: secondary),
      const SizedBox(height: 8),
      RecordsChoiceLayout(
        children: [for (final value in labels.keys.take(3)) preset(value)],
      ),
      RecordsChoiceLayout(
        children: [for (final value in labels.keys.skip(3)) preset(value)],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(child: field(true, _draft.dates.from)),
          const SizedBox(width: 8),
          Expanded(child: field(false, _draft.dates.to)),
        ],
      ),
      if (!_draft.dates.valid)
        Text(
          l10n.recordsInvalidDates,
          style: TextStyle(color: FolooPalette.of(context).error),
        ),
    ];
  }

  List<Widget> _additionalOptions(BuildContext context) {
    final l10n = context.l10n;
    final palette = FolooPalette.of(context);
    Widget title(String text) => Text(
      text.toUpperCase(),
      style: TextStyle(
        color: palette.inkSecondary,
        fontSize: 12,
        letterSpacing: .7,
        fontWeight: FontWeight.w600,
      ),
    );
    final interests = {
      InterestLevel.low: (l10n.interestLow, FolooColors.interestLow),
      InterestLevel.medium: (l10n.interestMedium, FolooColors.interestMedium),
      InterestLevel.high: (l10n.interestHigh, FolooColors.interestHigh),
    };
    void toggleInterest(InterestLevel value) {
      final selected = {..._draft.interests};
      if (!selected.remove(value)) selected.add(value);
      setState(() => _draft = _draft.copyWith(interests: selected));
    }

    return [
      const SizedBox(height: 8),
      title(l10n.interestLevel),
      const SizedBox(height: 9),
      if (MediaQuery.textScalerOf(context).scale(13) <= 17)
        SegmentedBubble<InterestLevel>.multiple(
          height: 50,
          selectedVerticalInset: 3,
          selectedColor: FolooSelection.surface(context),
          selectedBorderColor: palette.ink,
          selectedForegroundColor: FolooSelection.foreground(context),
          unselectedForegroundColor: palette.inkSecondary,
          selectedValues: _draft.interests,
          onSelected: toggleInterest,
          options: [
            for (final entry in interests.entries)
              SegmentedBubbleOption(
                key: Key('recordsInterest-${entry.key.name}'),
                value: entry.key,
                label: entry.value.$1,
                leading: Icon(Icons.circle, size: 8, color: entry.value.$2),
              ),
          ],
        )
      else
        Wrap(
          spacing: 5,
          children: [
            for (final entry in interests.entries)
              RecordsChoice(
                key: Key('recordsInterest-${entry.key.name}'),
                label: entry.value.$1,
                dot: entry.value.$2,
                selected: _draft.interests.contains(entry.key),
                onTap: () => toggleInterest(entry.key),
              ),
          ],
        ),
      const SizedBox(height: 14),
      title(l10n.recordsSentContent),
      if (widget.contentNames.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(l10n.noFiles),
        ),
      for (final item in widget.contentNames.entries)
        _contentTile(
          context,
          item.value,
          _draft.contentIds.contains(item.key),
          (checked) {
            final selected = {..._draft.contentIds};
            if (checked == true) {
              selected.add(item.key);
            } else {
              selected.remove(item.key);
            }
            setState(() => _draft = _draft.copyWith(contentIds: selected));
          },
          Key('recordsContent-${item.key}'),
        ),
      _contentTile(
        context,
        l10n.recordsWithoutSentContent,
        _draft.withoutContent,
        (checked) => setState(
          () => _draft = _draft.copyWith(withoutContent: checked ?? false),
        ),
        const Key('recordsWithoutContent'),
      ),
    ];
  }

  Widget _contentTile(
    BuildContext context,
    String label,
    bool value,
    ValueChanged<bool?> changed,
    Key key,
  ) => CheckboxListTile(
    key: key,
    contentPadding: EdgeInsets.zero,
    secondary: CircleAvatar(
      radius: 17,
      backgroundColor: FolooPalette.of(context).paper,
      foregroundColor: FolooPalette.of(context).ink,
      child: const Icon(Icons.description_outlined, size: 17),
    ),
    title: Text(
      label,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: FolooPalette.of(context).ink),
    ),
    value: value,
    onChanged: changed,
  );
}

/// Accessible Foloo pill shared by quick filters and sheet options.
class RecordsChoice extends StatelessWidget {
  const RecordsChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot,
    this.compact = false,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    return Semantics(
      selected: selected,
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 9,
            vertical: 6,
          ),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          backgroundColor: selected
              ? FolooSelection.surface(context)
              : palette.paper,
          foregroundColor: selected
              ? FolooSelection.foreground(context)
              : palette.inkSecondary,
          side: BorderSide(color: selected ? palette.ink : Colors.transparent),
          shape: const StadiumBorder(),
        ),
        onPressed: onTap,
        child: dot == null
            ? Text(label, textAlign: TextAlign.center)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dot != null) ...[
                    Icon(Icons.circle, color: dot, size: 10),
                    const SizedBox(width: 6),
                  ],
                  Flexible(child: Text(label, textAlign: TextAlign.center)),
                ],
              ),
      ),
    );
  }
}

/// Keeps choices on a row at normal sizes without shrinking or clipping text.
/// Larger accessibility text gets more room across additional rows.
class RecordsChoiceLayout extends StatelessWidget {
  const RecordsChoiceLayout({
    required this.children,
    this.splitWhenExpanded = false,
    super.key,
  });

  final List<RecordsChoice> children;
  final bool splitWhenExpanded;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final expanded = MediaQuery.textScalerOf(context).scale(12) > 16;
      if (!splitWhenExpanded && expanded) {
        return Wrap(spacing: 4, children: children);
      }
      Widget row(List<RecordsChoice> choices) => Row(
        children: [
          for (var i = 0; i < choices.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(flex: choices[i].label.length + 5, child: choices[i]),
          ],
        ],
      );
      if (splitWhenExpanded && (expanded || constraints.maxWidth < 260)) {
        return Column(
          children: [
            row(children.take(2).toList()),
            row(children.skip(2).toList()),
          ],
        );
      }
      return row(children);
    },
  );
}
