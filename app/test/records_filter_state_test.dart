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

  List<String> ids(
    RecordsFilterState state, {
    Map<String, Set<String>> sent = const {},
  }) => state.apply(records, sentByLead: sent).map((r) => r.localId).toList();

  test('REG-F01–08: exclusive modes, multi-event, all and explicit none', () {
    const events = RecordsFilterState();
    expect(ids(events), ['event-b-supplier', 'event-a-customer']);
    expect(ids(events.copyWith(eventIds: {'event-a'})), ['event-a-customer']);
    expect(ids(events.copyWith(eventIds: {'event-a', 'event-b'})), ids(events));
    expect(ids(events.copyWith(eventIds: {})), isEmpty);
    expect(ids(events.copyWith(mode: RecordsMode.direct)), ['direct-partner']);
    expect(events.apply([...records, records.first]).length, 2);
  });

  test('REG-F09–15: name and company search with other filters', () {
    expect(ids(const RecordsFilterState(query: 'mariana qa')), [
      'event-b-supplier',
      'event-a-customer',
    ]);
    expect(
      ids(
        const RecordsFilterState(
          query: ' cbqa  solutions ',
          eventIds: {'event-a'},
          leadTypes: {LeadType.customer, LeadType.partner},
          interests: {InterestLevel.high, InterestLevel.medium},
        ),
      ),
      ['event-a-customer'],
    );
    expect(
      ids(const RecordsFilterState(query: 'ÁNGEL', mode: RecordsMode.direct)),
      ['direct-partner'],
    );
    expect(ids(const RecordsFilterState(query: 'not-found')), isEmpty);
  });

  test(
    'REG-F16–19/30: sent UUIDs OR with no sent content; not associations',
    () {
      const filter = RecordsFilterState(
        contentIds: {'catalogue', 'other'},
        leadTypes: {LeadType.customer, LeadType.supplier},
        interests: {InterestLevel.high},
        query: 'cbqa',
      );
      const sent = {
        'event-a-customer': {'other'},
        'direct-partner': {'catalogue'},
      };
      expect(ids(filter, sent: sent), ['event-a-customer']);
      expect(ids(filter.copyWith(withoutContent: true), sent: sent), [
        'event-b-supplier',
        'event-a-customer',
      ]);
      expect(
        ids(filter.copyWith(contentIds: {}, withoutContent: true), sent: sent),
        ['event-b-supplier'],
      );
      expect(ids(filter, sent: {}), isEmpty);
    },
  );

  test('REG-F23–29: civil dates through month/year and inclusive midnight', () {
    final now = DateTime(2026, 1, 2, 17);
    final month = RecordsDateRange.preset(RecordsDatePreset.thisMonth, now);
    expect(month.from, DateTime(2026, 1, 1));
    expect(month.to, DateTime(2026, 1, 2));
    expect(month.contains(DateTime(2026, 1, 1).toUtc()), isTrue);
    expect(month.contains(DateTime(2026, 1, 2, 23, 59, 59).toUtc()), isTrue);
    expect(month.contains(DateTime(2026, 1, 3).toUtc()), isFalse);
    final last = RecordsDateRange.preset(RecordsDatePreset.lastMonth, now);
    expect(last.from, DateTime(2025, 12, 1));
    expect(last.to, DateTime(2025, 12, 31));
    final ninety = RecordsDateRange.preset(RecordsDatePreset.last90Days, now);
    expect(ninety.from, DateTime(2025, 10, 5));
    expect(ninety.to, DateTime(2026, 1, 2));
    expect(const RecordsDateRange().contains(DateTime(2000)), isTrue);
    expect(RecordsDateRange(month.to, month.from).valid, isFalse);
    expect(RecordsDateRange(month.from, month.from).valid, isTrue);
  });

  test('REG-03 QA-V06: local weeks start Monday and include today', () {
    for (final (today, monday) in [
      (DateTime(2026, 1, 5), DateTime(2026, 1, 5)),
      (DateTime(2026, 1, 11), DateTime(2026, 1, 5)),
      (DateTime(2026, 5, 2), DateTime(2026, 4, 27)),
      (DateTime(2026, 1, 2), DateTime(2025, 12, 29)),
    ]) {
      final range = RecordsDateRange.preset(
        RecordsDatePreset.thisWeek,
        DateTime(today.year, today.month, today.day, 17).toUtc(),
      );
      expect(range.from, monday);
      expect(range.to, today);
      expect(range.contains(monday.toUtc()), isTrue);
      expect(
        range.contains(monday.subtract(const Duration(seconds: 1))),
        isFalse,
      );
      expect(
        range.contains(
          DateTime(today.year, today.month, today.day, 23, 59, 59),
        ),
        isTrue,
      );
      expect(
        range.contains(DateTime(today.year, today.month, today.day + 1)),
        isFalse,
      );
    }
  });

  test(
    'REG-03 QA-V06: identical weekly/monthly bounds retain explicit selection',
    () {
      final now = DateTime(2026, 6, 3, 12);
      final week = RecordsDateRange.preset(RecordsDatePreset.thisWeek, now);
      final month = RecordsDateRange.preset(RecordsDatePreset.thisMonth, now);
      expect(week.from, month.from);
      expect(week.to, month.to);
      expect(week.matchingPreset(now), RecordsDatePreset.thisWeek);
      expect(month.matchingPreset(now), RecordsDatePreset.thisMonth);
      expect(
        RecordsDateRange(month.from, DateTime(2026, 6, 2)).matchingPreset(now),
        isNull,
      );
    },
  );

  test('REG-F33: switching modes preserves independent date/event scope', () {
    final state = RecordsFilterState(
      eventIds: const {'event-a'},
      dates: RecordsDateRange(DateTime(2026, 11, 11), DateTime(2026, 11, 11)),
    );
    expect(ids(state), ['event-a-customer']);
    final direct = state.copyWith(mode: RecordsMode.direct);
    expect(ids(direct), ['direct-partner']);
    expect(ids(direct.copyWith(mode: RecordsMode.events)), ids(state));
  });
}
