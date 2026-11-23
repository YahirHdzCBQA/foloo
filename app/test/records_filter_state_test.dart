import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/models/lead_draft.dart';
import 'package:foloo/models/records_filter_state.dart';
import 'package:foloo/models/session_lead.dart';

SessionLead _record({
  required String id,
  required DateTime capturedAt,
  required LeadOriginKind origin,
  String? eventId,
  String name = 'Mariana',
  String company = 'Foloo',
  LeadType type = LeadType.customer,
  InterestLevel interest = InterestLevel.high,
  List<String> contentIds = const [],
}) => SessionLead(
  localId: id,
  folio: null,
  capturedAt: capturedAt,
  lead: LeadDraft(
    name: name,
    lastName: 'QA',
    role: '',
    company: company,
    email: 'qa@example.com',
    phone: '',
    type: type,
    interest: interest,
    note: '',
    originKind: origin,
    eventLocalId: eventId,
    eventName: eventId,
    audioSeconds: 0,
    contentFileIds: contentIds,
  ),
);

void main() {
  final records = [
    _record(
      id: 'event-a-customer',
      capturedAt: DateTime(2026, 11, 10, 23, 59),
      origin: LeadOriginKind.event,
      eventId: 'event-a',
      company: '  CBQA   Solutions ',
      contentIds: const ['catalogue'],
    ),
    _record(
      id: 'direct-partner',
      capturedAt: DateTime(2026, 11, 11),
      origin: LeadOriginKind.direct,
      name: 'Ángel',
      company: 'Otra',
      type: LeadType.partner,
      interest: InterestLevel.medium,
      contentIds: const ['presentation'],
    ),
    _record(
      id: 'event-b-supplier',
      capturedAt: DateTime(2026, 11, 12),
      origin: LeadOriginKind.event,
      eventId: 'event-b',
      company: 'CBQA Solutions',
      type: LeadType.supplier,
      contentIds: const ['catalogue', 'presentation'],
    ),
  ];

  test('QA-20 unions origins and intersects independent categories', () {
    final result = RecordsFilterState(
      eventIds: const {'event-a'},
      includeDirect: true,
      leadTypes: const {LeadType.customer, LeadType.partner},
      interests: const {InterestLevel.high, InterestLevel.medium},
    ).apply(records);

    expect(result.map((item) => item.localId), [
      'event-a-customer',
      'direct-partner',
    ]);
  });

  test('QA-20 normalizes Company and keeps date boundaries inclusive', () {
    final result = RecordsFilterState(
      companies: const {'cbqa solutions'},
      fromDate: DateTime(2026, 11, 10),
      toDate: DateTime(2026, 11, 10),
    ).apply(records);

    expect(result.single.localId, 'event-a-customer');
  });

  test('QA-20 content values are OR and duplicated records stay unique', () {
    final result = RecordsFilterState(
      contentIds: const {'catalogue', 'presentation'},
    ).apply([...records, records.first]);

    expect(result.map((item) => item.localId).toSet(), {
      'event-a-customer',
      'direct-partner',
      'event-b-supplier',
    });
    expect(result, hasLength(3));
  });
}
