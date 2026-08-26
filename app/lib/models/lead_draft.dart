/// In-progress lead values shared between capture and confirmation.
///
/// This frontend object is not the final local-storage or spreadsheet schema.
library;

/// Commercial relationship selected for a lead (CAP-09 / CAP-10).
enum LeadType { supplier, partner, customer }

/// Interest semaphore used by capture and record rails.
enum InterestLevel { high, medium, low }

/// Distinguishes event-associated captures from direct leads.
enum LeadOriginKind { event, direct }

/// Snapshot of the current capture when the user submits a valid lead.
///
/// Basic fields are shared. Pro-only values remain optional and must never be
/// surfaced to Basic accounts (RNF-18 and the capability matrix).
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
    this.place,
    this.contentFileIds = const <String>[],
    this.contentNames = const <String>[],
    this.transcription,
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
  final String? place;
  final List<String> contentFileIds;
  final List<String> contentNames;
  final String? transcription;

  String get fullName => '$name $lastName'.trim();
  bool get hasVoiceNote => audioLocalPath?.isNotEmpty ?? false;
}
