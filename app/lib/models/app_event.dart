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
    Set<String>? contentFileIds,
  }) => AppEvent(
    id: id,
    name: name ?? this.name,
    startsOn: startsOn ?? this.startsOn,
    endsOn: endsOn ?? this.endsOn,
    active: active ?? this.active,
    demoLeadCount: demoLeadCount,
    demoPendingCount: demoPendingCount,
    contentFileIds: contentFileIds ?? this.contentFileIds,
  );
}

class DemoProfile {
  const DemoProfile({required this.name, required this.company});

  final String name;
  final String company;
}

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
