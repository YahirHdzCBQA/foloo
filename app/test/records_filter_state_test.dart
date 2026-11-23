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
  String? place,
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
    place: place,
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
      place: '  Expo   Industrial ',
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

  test('QA-28 unions selected direct places and events', () {
    final result = RecordsFilterState(
      eventIds: const {'event-a'},
      directPlaces: const {'expo industrial'},
      leadTypes: const {LeadType.customer, LeadType.partner},
      interests: const {InterestLevel.high, InterestLevel.medium},
    ).apply(records);

    expect(result.map((item) => item.localId), [
      'event-a-customer',
      'direct-partner',
    ]);
  });

  test(
    'QA-28 direct-only ignores dormant events and optionally filters places',
    () {
      final allDirect = RecordsFilterState(
        eventIds: const {'event-a'},
        onlyDirect: true,
      ).apply(records);
      expect(allDirect.map((item) => item.localId), ['direct-partner']);

      final selected = RecordsFilterState(
        eventIds: const {'event-a'},
        directPlaces: const {'expo industrial'},
        onlyDirect: true,
      ).apply(records);
      expect(selected.map((item) => item.localId), ['direct-partner']);

      final restoredUnion = RecordsFilterState(
        eventIds: const {'event-a'},
        directPlaces: const {'expo industrial'},
      ).apply(records);
      expect(restoredUnion.map((item) => item.localId), [
        'event-a-customer',
        'direct-partner',
      ]);
    },
  );

  test(
    'QA-28 excludes reassigned event leads from a selected direct place',
    () {
      final reassigned = _record(
        id: 'direct-partner',
        capturedAt: DateTime(2026, 11, 11),
        origin: LeadOriginKind.event,
        eventId: 'event-b',
      );
      final result = RecordsFilterState(directPlaces: const {'expo industrial'})
          .apply([reassigned]);
      expect(result, isEmpty);
    },
  );

  test('QA-28 normalizes place case and spaces and handles missing place', () {
    final samePlace = _record(
      id: 'direct-office',
      capturedAt: DateTime(2026, 11, 13),
      origin: LeadOriginKind.direct,
      place: 'EXPO industrial',
    );
    final noPlace = _record(
      id: 'direct-no-place',
      capturedAt: DateTime(2026, 11, 14),
      origin: LeadOriginKind.direct,
    );

    final byPlace = RecordsFilterState(directPlaces: const {'expo industrial'})
        .apply([...records, samePlace, noPlace]);
    expect(byPlace.map((item) => item.localId), [
      'direct-partner',
      'direct-office',
    ]);

    final allDirect = const RecordsFilterState(onlyDirect: true)
        .apply([...records, samePlace, noPlace]);
    expect(allDirect.map((item) => item.localId), [
      'direct-partner',
      'direct-office',
      'direct-no-place',
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
