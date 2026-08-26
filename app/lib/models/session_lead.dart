/// Session-local lead records and synchronization fixtures.
///
/// DEMO: SYN-* requires durable local-first storage before network delivery.
library;

import 'lead_draft.dart';

/// Simplified upload state displayed in the Records prototype.
enum SessionUploadState { pending, inSheet }

/// Captured lead retained in memory for the current application session.
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

/// Stable event/contact fixtures used by demo confirmation and detail views.
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
    // DEMO: Human-readable folio generation only. D-03 remains unresolved.
    return SessionLead(
      folio: '$eventCode-${sequence.toString().padLeft(3, '0')}',
      capturedAt: capturedAt ?? DateTime.now(),
      lead: lead,
    );
  }
}
