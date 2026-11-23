/// Concrete, lead-scoped email snapshot shown immediately after local save.
///
/// It contains rendered text only: template tokens never belong in this UI or
/// in the immutable send intent created after explicit confirmation (SAL-01).
library;

/// Raised when Review cannot prove that its selected Content and attachments
/// still describe the same current lead snapshot (CON-08, SAL-01).
class EmailAttachmentResolutionException implements Exception {
  const EmailAttachmentResolutionException();
}

/// Editable presentation of one prepared follow-up.
class EmailReviewDraft {
  const EmailReviewDraft({
    required this.followUpId,
    required this.leadName,
    required this.recipientAddress,
    required this.subject,
    required this.message,
    this.attachmentIds = const [],
    required this.attachmentNames,
  });

  final String followUpId;
  final String leadName;
  final String recipientAddress;
  final String subject;
  final String message;
  final List<String> attachmentIds;
  final List<String> attachmentNames;

  EmailReviewDraft copyWith({
    String? subject,
    String? message,
    List<String>? attachmentIds,
    List<String>? attachmentNames,
  }) => EmailReviewDraft(
    followUpId: followUpId,
    leadName: leadName,
    recipientAddress: recipientAddress,
    subject: subject ?? this.subject,
    message: message ?? this.message,
    attachmentIds: attachmentIds ?? this.attachmentIds,
    attachmentNames: attachmentNames ?? this.attachmentNames,
  );
}

/// Truthful result used by the acknowledgement screen after confirmation.
enum EmailReviewOutcome {
  pending,
  sending,
  sent,

  error,
  confirmationRequired,
  connectionRequired,
}
