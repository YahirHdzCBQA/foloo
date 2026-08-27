/// Domain projection of durable local lead records plus isolated demo fixtures.
library;

import 'lead_draft.dart';

/// Simplified upload state displayed in the Records prototype.
enum SessionUploadState { local, pending, inSheet }

/// Captured lead loaded from local persistence or created by an isolated demo.
class SessionLead {
  const SessionLead({
    required this.localId,
    required this.folio,
    required this.capturedAt,
    required this.lead,
    this.uploadState = SessionUploadState.pending,
    this.mediaIncomplete = false,
  });

  final String localId;
  final String? folio;
  final DateTime capturedAt;
  final LeadDraft lead;
  final SessionUploadState uploadState;
  final bool mediaIncomplete;

  String get uiKey => folio ?? localId;
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
      localId: '$eventCode-${sequence.toString().padLeft(3, '0')}',
      folio: '$eventCode-${sequence.toString().padLeft(3, '0')}',
      capturedAt: capturedAt ?? DateTime.now(),
      lead: lead,
    );
  }
}
