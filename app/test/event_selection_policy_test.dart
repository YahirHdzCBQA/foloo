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
}
