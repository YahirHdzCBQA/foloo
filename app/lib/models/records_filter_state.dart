/// Owner-scoped Records criteria shared by previews, list and export.
/// A draft can change criteria without mutating the applied session state.
library;

import 'lead_draft.dart';
import 'session_lead.dart';

enum RecordsMode { events, direct }

enum RecordsDatePreset { thisWeek, thisMonth, lastMonth, last90Days, all }

/// Inclusive civil-date range in the device's local time zone (REG-03).
class RecordsDateRange {
  const RecordsDateRange([this.from, this.to]) : _selectedPreset = null;
  const RecordsDateRange._preset(this.from, this.to, this._selectedPreset);

  factory RecordsDateRange.preset(RecordsDatePreset option, DateTime now) {
    final local = now.toLocal();
    final y = local.year, m = local.month, d = local.day;
    final today = DateTime(y, m, d);
    final (from, to) = switch (option) {
      RecordsDatePreset.thisWeek => (
        DateTime(y, m, d - (local.weekday - DateTime.monday)),
        today,
      ),
      RecordsDatePreset.thisMonth => (DateTime(y, m), today),
      RecordsDatePreset.lastMonth => (DateTime(y, m - 1), DateTime(y, m, 0)),
      RecordsDatePreset.last90Days => (DateTime(y, m, d - 89), today),
      RecordsDatePreset.all => (null, null),
    };
    return RecordsDateRange._preset(from, to, option);
  }

  final DateTime? from;
  final DateTime? to;
  final RecordsDatePreset? _selectedPreset;

  DateTime? get _start =>
      from == null ? null : DateTime(from!.year, from!.month, from!.day);
  DateTime? get _end =>
      to == null ? null : DateTime(to!.year, to!.month, to!.day + 1);

  bool get valid => _start == null || _end == null || _start!.isBefore(_end!);
  bool get unrestricted => from == null && to == null;

  bool contains(DateTime capturedAt) =>
      valid &&
      !(_start?.isAfter(capturedAt) ?? false) &&
      (_end?.isAfter(capturedAt) ?? true);

  RecordsDatePreset? matchingPreset(DateTime now) {
    // The first week and month can have identical dates. Keep the user's
    // explicit choice while those dates still match.
    for (final preset in {?_selectedPreset, ...RecordsDatePreset.values}) {
      final candidate = RecordsDateRange.preset(preset, now);
      if (candidate.from == from && candidate.to == to) return preset;
    }
    return null;
  }
}

/// Applied filters for one Records session. Null event IDs means all events;
/// an explicit empty set means no events. Common dimensions combine with AND.
class RecordsFilterState {
  const RecordsFilterState({
    this.mode = RecordsMode.events,
    this.eventIds,
    this.dates = const RecordsDateRange(),
    this.leadTypes = const {},
    this.interests = const {},
    this.query = '',
    this.contentIds = const {},
    this.withoutContent = false,
  });

  final RecordsMode mode;
  final Set<String>? eventIds;
  final RecordsDateRange dates;
  final Set<LeadType> leadTypes;
  final Set<InterestLevel> interests;
  final String query;
  final Set<String> contentIds;
  final bool withoutContent;

  bool get hasAdditional =>
      interests.isNotEmpty || contentIds.isNotEmpty || withoutContent;
  bool get isActive =>
      (mode == RecordsMode.events ? eventIds != null : !dates.unrestricted) ||
      leadTypes.isNotEmpty ||
      query.trim().isNotEmpty ||
      hasAdditional;

  RecordsFilterState copyWith({
    RecordsMode? mode,
    Set<String>? eventIds,
    bool allEvents = false,
    RecordsDateRange? dates,
    Set<LeadType>? leadTypes,
    Set<InterestLevel>? interests,
    String? query,
    Set<String>? contentIds,
    bool? withoutContent,
  }) => RecordsFilterState(
    mode: mode ?? this.mode,
    eventIds: allEvents ? null : eventIds ?? this.eventIds,
    dates: dates ?? this.dates,
    leadTypes: leadTypes ?? this.leadTypes,
    interests: interests ?? this.interests,
    query: query ?? this.query,
    contentIds: contentIds ?? this.contentIds,
    withoutContent: withoutContent ?? this.withoutContent,
  );

  List<SessionLead> apply(
    Iterable<SessionLead> records, {
    Map<String, Set<String>> sentByLead = const {},
  }) {
    final search = normalizeRecordsQuery(query);
    final seen = <String>{};
    final matches = records.where((record) {
      if (!seen.add(record.localId)) return false;
      final lead = record.lead;
      if (mode == RecordsMode.direct) {
        if (lead.originKind != LeadOriginKind.direct ||
            !dates.contains(record.capturedAt)) {
          return false;
        }
      } else if (lead.originKind != LeadOriginKind.event ||
          (eventIds != null && !eventIds!.contains(lead.eventLocalId))) {
        return false;
      }
      if (leadTypes.isNotEmpty && !leadTypes.contains(lead.type)) return false;
      if (interests.isNotEmpty && !interests.contains(lead.interest)) {
        return false;
      }
      if (search.isNotEmpty &&
          !normalizeRecordsQuery(lead.fullName).contains(search) &&
          !normalizeRecordsQuery(lead.company).contains(search)) {
        return false;
      }
      if (withoutContent || contentIds.isNotEmpty) {
        final sent = sentByLead[record.localId] ?? const <String>{};
        if (!(withoutContent && sent.isEmpty) &&
            !sent.any(contentIds.contains)) {
          return false;
        }
      }
      return true;
    }).toList();
    matches.sort((a, b) {
      final byDate = b.capturedAt.compareTo(a.capturedAt);
      return byDate != 0 ? byDate : a.localId.compareTo(b.localId);
    });
    return matches;
  }
}

String normalizeRecordsQuery(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
