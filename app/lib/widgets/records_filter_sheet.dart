/// Full owner-scoped filter panel used by Records and its export action.
///
/// The sheet keeps a disposable draft until “View results” is confirmed, with
/// independent category/result scrolling and no persistence side effects.
library;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/app_event.dart';
import '../models/content_file.dart';
import '../models/lead_draft.dart';
import '../models/records_filter_state.dart';
import '../models/session_lead.dart';
import '../theme/foloo_theme.dart';

enum RecordsFilterCategory {
  events,
  direct,
  type,
  interest,
  company,
  name,
  date,
  content,
}

Future<RecordsFilterState?> showRecordsFilterSheet(
  BuildContext context, {
  required RecordsFilterState filters,
  required RecordsFilterCategory initialCategory,
  required List<SessionLead> records,
  required List<AppEvent> events,
  required List<ContentFile> contentFiles,
}) => showModalBottomSheet<RecordsFilterState>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (_) => RecordsFilterSheet(
    filters: filters,
    initialCategory: initialCategory,
    records: records,
    events: events,
    contentFiles: contentFiles,
  ),
);

class RecordsFilterSheet extends StatefulWidget {
  const RecordsFilterSheet({
    required this.filters,
    required this.initialCategory,
    required this.records,
    required this.events,
    required this.contentFiles,
    super.key,
  });

  final RecordsFilterState filters;
  final RecordsFilterCategory initialCategory;
  final List<SessionLead> records;
  final List<AppEvent> events;
  final List<ContentFile> contentFiles;

  @override
  State<RecordsFilterSheet> createState() => _RecordsFilterSheetState();
}

class _RecordsFilterSheetState extends State<RecordsFilterSheet> {
  late RecordsFilterCategory _category;
  late Set<String> _eventIds;
  late Set<String> _directLeadIds;
  late bool _onlyDirect;
  late Set<LeadType> _types;
  late Set<InterestLevel> _interests;
  late Set<String> _companies;
  late Set<String> _contentIds;
  late DateTime? _fromDate;
  late DateTime? _toDate;
  late final TextEditingController _name;
  final _companySearch = TextEditingController();

  @override
  void initState() {
    super.initState();
    final source = widget.filters;
    _category = widget.initialCategory;
    _eventIds = {...source.eventIds};
    _directLeadIds = {...source.directLeadIds};
    _onlyDirect = source.onlyDirect;
    _types = {...source.leadTypes};
    _interests = {...source.interests};
    _companies = {...source.companies};
    _contentIds = {...source.contentIds};
    _fromDate = source.fromDate;
    _toDate = source.toDate;
    _name = TextEditingController(text: source.nameQuery);
    _companySearch.addListener(_refresh);
  }

  @override
  void dispose() {
    _companySearch
      ..removeListener(_refresh)
      ..dispose();
    _name.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  RecordsFilterState get _draft => RecordsFilterState(
    eventIds: _eventIds,
    directLeadIds: _directLeadIds,
    onlyDirect: _onlyDirect,
    leadTypes: _types,
    interests: _interests,
    companies: _companies,
    nameQuery: _name.text,
    fromDate: _fromDate,
    toDate: _toDate,
    contentIds: _contentIds,
  );

  void _clear() {
    setState(() {
      _eventIds = {};
      _directLeadIds = {};
      _onlyDirect = false;
      _types = {};
      _interests = {};
      _companies = {};
      _contentIds = {};
      _fromDate = null;
      _toDate = null;
      _name.clear();
      _companySearch.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * .88;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: height,
        child: Material(
          color: palette.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.recordsFilters,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('closeRecordsFilters'),
                      tooltip: MaterialLocalizations.of(context)
                          .closeButtonLabel,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: palette.line),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 124,
                      child: ListView(
                        key: const Key('recordsFilterCategories'),
                        children: RecordsFilterCategory.values
                            .map(_categoryTile)
                            .toList(),
                      ),
                    ),
                    VerticalDivider(width: 1, color: palette.line),
                    Expanded(
                      child: ListView(
                        key: Key('recordsFilterOptions-${_category.name}'),
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                        children: _categoryContent(),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: palette.line),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          key: const Key('clearRecordsFilters'),
                          onPressed: _draft.isActive ? _clear : null,
                          child: Text(context.l10n.clearFilters),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          key: const Key('applyRecordsFilters'),
                          onPressed: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            Navigator.pop(context, _draft);
                          },
                          child: Text(
                            context.l10n.viewFilterResults(
                              _draft.apply(widget.records).length,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryTile(RecordsFilterCategory category) {
    final selected = category == _category;
    return Material(
      color: selected ? FolooSelection.surface(context) : Colors.transparent,
      child: InkWell(
        key: Key('recordsFilterCategory-${category.name}'),
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          setState(() => _category = category);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? FolooColors.lime : Colors.transparent,
                width: 4,
              ),
            ),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            _categoryLabel(category),
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _categoryContent() => switch (_category) {
    RecordsFilterCategory.events => [
      _heading(context.l10n.eventsFilter),
      if (widget.events.isEmpty) _empty(context.l10n.noEventsAvailable),
      for (final event in widget.events)
        CheckboxListTile(
          key: Key('recordsFilterEvent-${event.id}'),
          contentPadding: EdgeInsets.zero,
          value: _eventIds.contains(event.id),
          title: Text(event.name),
          onChanged: (value) => setState(() {
            value == true
                ? _eventIds.add(event.id)
                : _eventIds.remove(event.id);
          }),
        ),
    ],
    RecordsFilterCategory.direct => [
      _heading(context.l10n.directLeads),
      SwitchListTile(
        key: const Key('recordsFilterDirect'),
        contentPadding: EdgeInsets.zero,
        value: _onlyDirect,
        title: Text(context.l10n.onlyDirectLeads),
        subtitle: Text(context.l10n.onlyDirectLeadsHelp),
        onChanged: (value) => setState(() => _onlyDirect = value),
      ),
      const SizedBox(height: 8),
      ..._directLeadWidgets(),
    ],
    RecordsFilterCategory.type => [
      _heading(context.l10n.leadType),
      _chips<LeadType>(
        LeadType.values,
        selected: _types,
        label: (value) => switch (value) {
          LeadType.customer => context.l10n.client,
          LeadType.partner => context.l10n.partner,
          LeadType.supplier => context.l10n.supplier,
        },
        onChanged: (value, selected) => setState(() {
          selected ? _types.add(value) : _types.remove(value);
        }),
      ),
    ],
    RecordsFilterCategory.interest => [
      _heading(context.l10n.interestLevel),
      _chips<InterestLevel>(
        InterestLevel.values,
        selected: _interests,
        label: (value) => switch (value) {
          InterestLevel.low => context.l10n.interestLow,
          InterestLevel.medium => context.l10n.interestMedium,
          InterestLevel.high => context.l10n.interestHigh,
        },
        onChanged: (value, selected) => setState(() {
          selected ? _interests.add(value) : _interests.remove(value);
        }),
      ),
    ],
    RecordsFilterCategory.company => _companyWidgets(),
    RecordsFilterCategory.name => [
      _heading(context.l10n.nameFilter),
      TextField(
        key: const Key('recordsFilterName'),
        controller: _name,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: context.l10n.searchLeadName,
        ),
      ),
    ],
    RecordsFilterCategory.date => _dateWidgets(),
    RecordsFilterCategory.content => [
      _heading(context.l10n.contentTitle),
      if (widget.contentFiles.isEmpty)
        _empty(context.l10n.exportNoContentAvailable),
      for (final file in widget.contentFiles)
        CheckboxListTile(
          key: Key('recordsFilterContent-${file.id}'),
          contentPadding: EdgeInsets.zero,
          value: _contentIds.contains(file.id),
          title: Text(file.displayName),
          subtitle: file.fileName.isEmpty ? null : Text(file.fileName),
          onChanged: (value) => setState(() {
            value == true
                ? _contentIds.add(file.id)
                : _contentIds.remove(file.id);
          }),
        ),
    ],
  };

  List<Widget> _directLeadWidgets() {
    final direct =
        widget.records
            .where((record) => record.lead.originKind == LeadOriginKind.direct)
            .toList()
          ..sort((left, right) {
            final byName = left.lead.fullName.toLowerCase().compareTo(
              right.lead.fullName.toLowerCase(),
            );
            return byName != 0 ? byName : left.localId.compareTo(right.localId);
          });
    if (direct.isEmpty) return [_empty(context.l10n.noDirectLeadsAvailable)];
    return [
      for (final record in direct)
        CheckboxListTile(
          key: Key('recordsFilterDirectLead-${record.localId}'),
          contentPadding: EdgeInsets.zero,
          value: _directLeadIds.contains(record.localId),
          title: Text(record.lead.fullName),
          subtitle: Text(_directLeadSecondary(record)),
          onChanged: (value) => setState(() {
            value == true
                ? _directLeadIds.add(record.localId)
                : _directLeadIds.remove(record.localId);
          }),
        ),
    ];
  }

  String _directLeadSecondary(SessionLead record) {
    final details = <String>[
      if (record.lead.company.trim().isNotEmpty) record.lead.company.trim(),
      if (record.lead.place?.trim().isNotEmpty == true)
        record.lead.place!.trim(),
      MaterialLocalizations.of(context)
          .formatShortDate(record.capturedAt.toLocal()),
    ];
    return details.join(' · ');
  }

  List<Widget> _companyWidgets() {
    final byKey = <String, String>{};
    for (final record in widget.records) {
      final display = record.lead.company.trim().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      if (display.isNotEmpty) {
        byKey.putIfAbsent(canonicalCompanyName(display), () => display);
      }
    }
    final query = canonicalCompanyName(_companySearch.text);
    final companies =
        byKey.entries
            .where((entry) => query.isEmpty || entry.key.contains(query))
            .toList()
          ..sort((left, right) => left.value.compareTo(right.value));
    return [
      _heading(context.l10n.company),
      TextField(
        key: const Key('recordsFilterCompanySearch'),
        controller: _companySearch,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: context.l10n.searchCompany,
        ),
      ),
      const SizedBox(height: 14),
      if (companies.isEmpty) _empty(context.l10n.noCompaniesAvailable),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in companies)
            FilterChip(
              key: Key('recordsFilterCompany-${entry.key}'),
              label: Text(entry.value),
              selected: _companies.any(
                (value) => canonicalCompanyName(value) == entry.key,
              ),
              onSelected: (selected) => setState(() {
                _companies.removeWhere(
                  (value) => canonicalCompanyName(value) == entry.key,
                );
                if (selected) _companies.add(entry.value);
              }),
            ),
        ],
      ),
    ];
  }

  List<Widget> _dateWidgets() => [
    _heading(context.l10n.dateFilter),
    _dateTile(
      key: const Key('recordsFilterFromDate'),
      label: context.l10n.startDate,
      value: _fromDate,
      onPicked: (value) {
        if (_toDate != null && value.isAfter(_toDate!)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.invalidDateRange)),
          );
          return;
        }
        setState(() => _fromDate = value);
      },
      onClear: () => setState(() => _fromDate = null),
    ),
    const SizedBox(height: 10),
    _dateTile(
      key: const Key('recordsFilterToDate'),
      label: context.l10n.endDate,
      value: _toDate,
      onPicked: (value) {
        if (_fromDate != null && value.isBefore(_fromDate!)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.invalidDateRange)),
          );
          return;
        }
        setState(() => _toDate = value);
      },
      onClear: () => setState(() => _toDate = null),
    ),
  ];

  Widget _dateTile({
    required Key key,
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime> onPicked,
    required VoidCallback onClear,
  }) => ListTile(
    key: key,
    contentPadding: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(FolooRadii.md),
      side: BorderSide(color: FolooPalette.of(context).line),
    ),
    leading: const Icon(Icons.calendar_today_outlined),
    title: Text(label),
    subtitle: value == null
        ? Text(context.l10n.notSelected)
        : Text(MaterialLocalizations.of(context).formatMediumDate(value)),
    trailing: value == null
        ? const Icon(Icons.chevron_right)
        : IconButton(
            tooltip: context.l10n.clear,
            onPressed: onClear,
            icon: const Icon(Icons.close),
          ),
    onTap: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: value ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime.now().add(const Duration(days: 366)),
      );
      if (picked != null) onPicked(picked);
    },
  );

  Widget _chips<T>(
    Iterable<T> values, {
    required Set<T> selected,
    required String Function(T value) label,
    required void Function(T value, bool selected) onChanged,
  }) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final value in values)
        FilterChip(
          label: Text(label(value)),
          selected: selected.contains(value),
          onSelected: (active) => onChanged(value, active),
        ),
    ],
  );

  Widget _heading(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(
      value,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
    ),
  );

  Widget _empty(String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Text(
      value,
      style: TextStyle(color: FolooPalette.of(context).inkSecondary),
    ),
  );

  String _categoryLabel(RecordsFilterCategory category) => switch (category) {
    RecordsFilterCategory.events => context.l10n.eventsFilter,
    RecordsFilterCategory.direct => context.l10n.directLeads,
    RecordsFilterCategory.type => context.l10n.leadType,
    RecordsFilterCategory.interest => context.l10n.interestLevel,
    RecordsFilterCategory.company => context.l10n.company,
    RecordsFilterCategory.name => context.l10n.nameFilter,
    RecordsFilterCategory.date => context.l10n.dateFilter,
    RecordsFilterCategory.content => context.l10n.contentTitle,
  };
}
