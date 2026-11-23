/// Immutable filter criteria for the owner-scoped Records workspace.
///
/// Keeps QA-20 filtering deterministic and reusable by both the Records list
/// and QA-21 exports without mutating any persisted lead data.
library;

import 'lead_draft.dart';
import 'session_lead.dart';

class RecordsFilterState {
  const RecordsFilterState({
    this.eventIds = const {},
    this.includeDirect = false,
    this.leadTypes = const {},
    this.interests = const {},
    this.companies = const {},
    this.nameQuery = '',
    this.fromDate,
    this.toDate,
    this.contentIds = const {},
  });

  final Set<String> eventIds;
  final bool includeDirect;
  final Set<LeadType> leadTypes;
  final Set<InterestLevel> interests;
  final Set<String> companies;
  final String nameQuery;
  final DateTime? fromDate;
  final DateTime? toDate;
  final Set<String> contentIds;

  bool get hasOriginFilter => eventIds.isNotEmpty || includeDirect;
  bool get isActive =>
      hasOriginFilter ||
      leadTypes.isNotEmpty ||
      interests.isNotEmpty ||
      companies.isNotEmpty ||
      nameQuery.trim().isNotEmpty ||
      fromDate != null ||
      toDate != null ||
      contentIds.isNotEmpty;

  int get activeCategoryCount => [
    hasOriginFilter,
    leadTypes.isNotEmpty,
    interests.isNotEmpty,
    companies.isNotEmpty,
    nameQuery.trim().isNotEmpty,
    fromDate != null || toDate != null,
    contentIds.isNotEmpty,
  ].where((active) => active).length;

  RecordsFilterState copyWith({
    Set<String>? eventIds,
    bool? includeDirect,
    Set<LeadType>? leadTypes,
    Set<InterestLevel>? interests,
    Set<String>? companies,
    String? nameQuery,
    DateTime? fromDate,
    DateTime? toDate,
    bool clearFromDate = false,
    bool clearToDate = false,
    Set<String>? contentIds,
  }) => RecordsFilterState(
    eventIds: eventIds ?? this.eventIds,
    includeDirect: includeDirect ?? this.includeDirect,
    leadTypes: leadTypes ?? this.leadTypes,
    interests: interests ?? this.interests,
    companies: companies ?? this.companies,
    nameQuery: nameQuery ?? this.nameQuery,
    fromDate: clearFromDate ? null : fromDate ?? this.fromDate,
    toDate: clearToDate ? null : toDate ?? this.toDate,
    contentIds: contentIds ?? this.contentIds,
  );

  List<SessionLead> apply(Iterable<SessionLead> records) {
    final query = _canonical(nameQuery);
    final companyKeys = companies.map(_canonical).toSet();
    final start = fromDate == null
        ? null
        : DateTime(fromDate!.year, fromDate!.month, fromDate!.day);
    final endExclusive = toDate == null
        ? null
        : DateTime(toDate!.year, toDate!.month, toDate!.day + 1);
    final seen = <String>{};
    final matches = records.where((record) {
      if (!seen.add(record.localId)) return false;
      final lead = record.lead;
      if (hasOriginFilter) {
        final originMatches =
            (includeDirect && lead.originKind == LeadOriginKind.direct) ||
            (lead.originKind == LeadOriginKind.event &&
                lead.eventLocalId != null &&
                eventIds.contains(lead.eventLocalId));
        if (!originMatches) return false;
      }
      if (leadTypes.isNotEmpty && !leadTypes.contains(lead.type)) return false;
      if (interests.isNotEmpty && !interests.contains(lead.interest)) {
        return false;
      }
      if (companyKeys.isNotEmpty &&
          !companyKeys.contains(_canonical(lead.company))) {
        return false;
      }
      if (query.isNotEmpty && !_canonical(lead.fullName).contains(query)) {
        return false;
      }
      final captured = record.capturedAt.toLocal();
      if (start != null && captured.isBefore(start)) return false;
      if (endExclusive != null && !captured.isBefore(endExclusive)) {
        return false;
      }
      if (contentIds.isNotEmpty &&
          !lead.contentFileIds.any(contentIds.contains)) {
        return false;
      }
      return true;
    }).toList();
    matches.sort((left, right) {
      final byDate = left.capturedAt.compareTo(right.capturedAt);
      return byDate != 0 ? byDate : left.localId.compareTo(right.localId);
    });
    return matches;
  }
}

String canonicalCompanyName(String value) => _canonical(value);

String _canonical(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
