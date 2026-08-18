enum LeadType {
  partner('Partner'),
  potentialCustomer('Cliente potencial');

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

enum NextStep {
  sendInformation('Enviar información'),
  scheduleCall('Agendar llamada'),
  quote('Cotizar'),
  followUpOnly('Solo seguimiento');

  const NextStep(this.label);
  final String label;
}

class LeadDraft {
  const LeadDraft({
    required this.name,
    required this.role,
    required this.company,
    required this.email,
    required this.phone,
    required this.type,
    required this.interest,
    required this.nextStep,
    required this.note,
    required this.demoAudioSeconds,
  });

  final String name;
  final String role;
  final String company;
  final String email;
  final String phone;
  final LeadType type;
  final InterestLevel interest;
  final NextStep nextStep;
  final String note;
  final int demoAudioSeconds;
}
