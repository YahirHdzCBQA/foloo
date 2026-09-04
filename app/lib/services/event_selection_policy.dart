/// Shared date policy for choosing an event only when no manual choice exists.
///
/// EVT-12 uses local calendar dates and deliberately returns no fallback when
/// every event has already ended, leaving that choice to the seller.
library;

import '../models/app_event.dart';

/// Date-derived buckets used by Mis eventos (EVT-13).
class EventDateGroups {
  const EventDateGroups({
    required this.active,
    required this.future,
    required this.past,
  });

  final AppEvent? active;
  final List<AppEvent> future;
  final List<AppEvent> past;
}

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

/// Classifies the event list against the device's local calendar day.
///
/// A non-active multi-day event remains actionable in the future bucket until
/// the day after its end. The active event is removed before both classifications.
abstract final class EventGroupingPolicy {
  static EventDateGroups group(
    Iterable<AppEvent> events, {
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    AppEvent? active;
    final future = <AppEvent>[];
    final past = <AppEvent>[];

    for (final event in events) {
      if (event.active && active == null) {
        active = event;
        continue;
      }
      final end = DateTime(
        event.endsOn.year,
        event.endsOn.month,
        event.endsOn.day,
      );
      if (end.isBefore(today)) {
        past.add(event);
      } else {
        future.add(event);
      }
    }

    future.sort((a, b) {
      final start = a.startsOn.compareTo(b.startsOn);
      return start != 0 ? start : a.id.compareTo(b.id);
    });
    past.sort((a, b) {
      final end = b.endsOn.compareTo(a.endsOn);
      if (end != 0) return end;
      final start = b.startsOn.compareTo(a.startsOn);
      return start != 0 ? start : a.id.compareTo(b.id);
    });

    return EventDateGroups(
      active: active,
      future: List.unmodifiable(future),
      past: List.unmodifiable(past),
    );
  }
}
