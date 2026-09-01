/// Shared date policy for choosing an event only when no manual choice exists.
///
/// EVT-12 uses local calendar dates and deliberately returns no fallback when
/// every event has already ended, leaving that choice to the seller.
library;

import '../models/app_event.dart';

abstract final class EventSelectionPolicy {
  static AppEvent? automaticChoice(
    Iterable<AppEvent> events, {
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final available = events.toList();

    final current = available.where((event) {
      final start = _date(event.startsOn);
      final end = _date(event.endsOn);
      return !start.isAfter(today) && !end.isBefore(today);
    }).toList()..sort((a, b) => b.startsOn.compareTo(a.startsOn));
    if (current.isNotEmpty) return current.first;

    final future =
        available
            .where((event) => _date(event.startsOn).isAfter(today))
            .toList()
          ..sort((a, b) => a.startsOn.compareTo(b.startsOn));
    return future.isEmpty ? null : future.first;
  }

  static DateTime _date(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
