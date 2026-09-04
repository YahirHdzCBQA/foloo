import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/services/event_selection_policy.dart';

AppEvent event(String id, DateTime start, DateTime end) =>
    AppEvent(id: id, name: id, startsOn: start, endsOn: end);

void main() {
  group('EVT-12 automatic event selection', () {
    test('prefers an event spanning today over a future event', () {
      final selected = EventSelectionPolicy.automaticChoice([
        event('future', DateTime(2026, 9, 3), DateTime(2026, 9, 4)),
        event('current', DateTime(2026, 8, 31), DateTime(2026, 9, 2)),
      ], now: DateTime(2026, 9, 1, 23, 45));

      expect(selected?.id, 'current');
    });

    test('chooses the nearest future start using the supplied local day', () {
      final events = [
        event('later', DateTime(2026, 9, 20), DateTime(2026, 9, 22)),
        event('next', DateTime(2026, 9, 3), DateTime(2026, 9, 5)),
        event('past', DateTime(2026, 8, 12), DateTime(2026, 8, 14)),
      ];

      expect(
        EventSelectionPolicy.automaticChoice(
          events,
          now: DateTime(2026, 9, 1),
        )?.id,
        'next',
      );
      expect(
        EventSelectionPolicy.automaticChoice(
          events,
          now: DateTime(2026, 9, 6),
        )?.id,
        'later',
      );
    });

    test('does not invent a fallback when every event has ended', () {
      expect(
        EventSelectionPolicy.automaticChoice([
          event('past', DateTime(2026, 8, 12), DateTime(2026, 8, 14)),
        ], now: DateTime(2026, 9, 1)),
        isNull,
      );
    });
  });

  group('EVT-13 Mis eventos date grouping', () {
    test('keeps the active event separate and orders future and past', () {
      final active = event(
        'active',
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 2),
      ).copyWith(active: true);
      final groups = EventGroupingPolicy.group([
        event('past-far', DateTime(2026, 8, 20), DateTime(2026, 8, 20)),
        event('future-far', DateTime(2026, 9, 8), DateTime(2026, 9, 9)),
        active,
        event('past-near', DateTime(2026, 8, 30), DateTime(2026, 8, 30)),
        event('future-near', DateTime(2026, 9, 3), DateTime(2026, 9, 4)),
      ], now: DateTime(2026, 9, 2, 23, 59));

      expect(groups.active?.id, 'active');
      expect(groups.future.map((item) => item.id), [
        'future-near',
        'future-far',
      ]);
      expect(groups.past.map((item) => item.id), ['past-near', 'past-far']);
      expect(
        [...groups.future, ...groups.past].where((item) => item.id == 'active'),
        isEmpty,
      );
    });

    test('multi-day event changes group only after its local end date', () {
      final spanning = event(
        'spanning',
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 3),
      );

      expect(
        EventGroupingPolicy.group([
          spanning,
        ], now: DateTime(2026, 9, 2)).future.single.id,
        'spanning',
      );
      expect(
        EventGroupingPolicy.group([
          spanning,
        ], now: DateTime(2026, 9, 4)).past.single.id,
        'spanning',
      );
    });
  });
}
