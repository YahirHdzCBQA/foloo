enum LeadType {
  supplier('Proveedor'),
  partner('Partner'),
  customer('Cliente');

  const LeadType(this.label);
  final String label;
}

enum InterestLevel {
  high('Alto'),
  medium('Medio'),
  low('Bajo');

  const InterestLevel(this.label);
  final String label;
}

enum LeadOriginKind { event, direct }

class LeadDraft {
  const LeadDraft({
    required this.name,
    required this.lastName,
    required this.role,
    required this.company,
    required this.email,
    required this.phone,
    required this.type,
    required this.interest,
    required this.note,
    required this.originKind,
    this.eventName,
    this.audioLocalPath,
    required this.audioSeconds,
  });

  final String name;
  final String lastName;
  final String role;
  final String company;
  final String email;
  final String phone;
  final LeadType type;
  final InterestLevel interest;
  final String note;
  final LeadOriginKind originKind;
  final String? eventName;
  final String? audioLocalPath;
  final int audioSeconds;

  String get fullName => '$name $lastName'.trim();
  String get originLabel => originKind == LeadOriginKind.event
      ? (eventName ?? 'Evento')
      : 'Lead directo';
  bool get hasVoiceNote => audioLocalPath?.isNotEmpty ?? false;
}
