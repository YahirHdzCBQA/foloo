import 'lead_draft.dart';

enum SessionUploadState {
  pending('Por subir'),
  inSheet('En la hoja');

  const SessionUploadState(this.label);
  final String label;
}

class SessionLead {
  const SessionLead({
    required this.folio,
    required this.capturedAt,
    required this.lead,
    this.uploadState = SessionUploadState.pending,
  });

  final String folio;
  final DateTime capturedAt;
  final LeadDraft lead;
  final SessionUploadState uploadState;
}

class DemoEventData {
  const DemoEventData._();

  static const eventCode = 'EXP-260812';
  static const eventName = 'Expo Alimentaria México 2026';
  static const eventDate = '12–14 AGO 2026';
  static const location = 'CENTRO CITIBANAMEX, CDMX';
  static const capturePerson = 'Yahir Hernández';
  static const captureEmail = 'y.hernandez@cbqasolutions.com';
  static const captureRole = 'CBQA SOLUTIONS · VENTAS';
  static const adminEmail = 'marketing@cbqasolutions.com';

  static SessionLead createSessionLead({
    required LeadDraft lead,
    required int sequence,
    DateTime? capturedAt,
  }) {
    // Demo-only sequencing. OQ-A04 must be resolved before production folios.
    return SessionLead(
      folio: '$eventCode-${sequence.toString().padLeft(3, '0')}',
      capturedAt: capturedAt ?? DateTime.now(),
      lead: lead,
    );
  }
}
