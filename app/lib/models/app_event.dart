/// Session models and fixtures for Foloo event/profile flows.
///
/// They support the frontend demo and are not an approved persistence schema.
library;

/// Event data used by origin selection, capture and event management screens.
///
/// Counts are projections derived from local leads; fixtures may seed previews.
class AppEvent {
  const AppEvent({
    required this.id,
    required this.name,
    required this.startsOn,
    required this.endsOn,
    this.active = false,
    this.demoLeadCount = 0,
    this.demoPendingCount = 0,
    this.contentFileIds = const <String>{},
  });

  final String id;
  final String name;
  final DateTime startsOn;
  final DateTime endsOn;
  final bool active;
  final int demoLeadCount;
  final int demoPendingCount;
  final Set<String> contentFileIds;

  AppEvent copyWith({
    String? name,
    DateTime? startsOn,
    DateTime? endsOn,
    bool? active,
    int? leadCount,
    int? pendingCount,
    Set<String>? contentFileIds,
  }) => AppEvent(
    id: id,
    name: name ?? this.name,
    startsOn: startsOn ?? this.startsOn,
    endsOn: endsOn ?? this.endsOn,
    active: active ?? this.active,
    demoLeadCount: leadCount ?? demoLeadCount,
    demoPendingCount: pendingCount ?? demoPendingCount,
    contentFileIds: contentFileIds ?? this.contentFileIds,
  );
}

/// Session-only seller profile attached to locally captured demo leads.
class DemoProfile {
  const DemoProfile({required this.name, required this.company});

  final String name;
  final String company;
}

/// Centralized Basic fixtures used to exercise event and profile flows.
abstract final class DemoBasicData {
  static const profile = DemoProfile(
    name: 'Yahir Hernández',
    company: 'CBQA Solutions',
  );

  static final events = <AppEvent>[
    AppEvent(
      id: 'expo-alimentaria',
      name: 'Expo Alimentaria México',
      startsOn: DateTime(2026, 8, 12),
      endsOn: DateTime(2026, 8, 14),
      active: true,
      demoLeadCount: 6,
      demoPendingCount: 2,
      contentFileIds: const {'scanley-ims', 'vision-ai'},
    ),
    AppEvent(
      id: 'foro-lacteo',
      name: 'Foro Lácteo Bajío',
      startsOn: DateTime(2026, 6, 4),
      endsOn: DateTime(2026, 6, 4),
      demoLeadCount: 18,
    ),
    AppEvent(
      id: 'expo-empaque',
      name: 'Expo Empaque Norte',
      startsOn: DateTime(2026, 3, 18),
      endsOn: DateTime(2026, 3, 18),
      demoLeadCount: 31,
    ),
  ];
}
