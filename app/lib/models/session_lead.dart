import 'lead_draft.dart';

enum SessionUploadState { pending, inSheet }

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

  static const eventCode = 'FOL-260812';
  static const eventName = 'Expo Alimentaria México';
  static const capturePerson = 'Yahir Hernández';
  static const captureRole = 'CBQA SOLUTIONS · VENTAS';

  static SessionLead createSessionLead({
    required LeadDraft lead,
    required int sequence,
    DateTime? capturedAt,
  }) {
    // Demo-only folio. D-03 remains deliberately unresolved.
    return SessionLead(
      folio: '$eventCode-${sequence.toString().padLeft(3, '0')}',
      capturedAt: capturedAt ?? DateTime.now(),
      lead: lead,
    );
  }
}
