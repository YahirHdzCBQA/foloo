/// Commercial entitlement used to gate only new Lead creation.
///
/// The server snapshot remains authoritative; pending local reservations are
/// added for offline enforcement and never expose a way to grant `active`.
library;

enum SubscriptionStatus { trial, trialExhausted, active, expired }

const trialLeadLimit = 5;

class EntitlementSnapshot {
  const EntitlementSnapshot({
    required this.status,
    required this.serverTrialLeadsUsed,
    required this.pendingLocalLeads,
    required this.verified,
    this.serverUpdatedAt,
    this.unlimitedQaMode = false,
  });

  factory EntitlementSnapshot.newTrial({
    bool verified = false,
    bool unlimitedQaMode = false,
  }) => EntitlementSnapshot(
    status: SubscriptionStatus.trial,
    serverTrialLeadsUsed: 0,
    pendingLocalLeads: 0,
    verified: verified,
    unlimitedQaMode: unlimitedQaMode,
  );

  final SubscriptionStatus status;
  final int serverTrialLeadsUsed;
  final int pendingLocalLeads;
  final bool verified;
  final DateTime? serverUpdatedAt;
  final bool unlimitedQaMode;

  int get trialLeadsUsed =>
      (serverTrialLeadsUsed + pendingLocalLeads).clamp(0, trialLeadLimit);
  int get trialLeadsRemaining =>
      (trialLeadLimit - trialLeadsUsed).clamp(0, trialLeadLimit);
  SubscriptionStatus get effectiveStatus =>
      status == SubscriptionStatus.trial && trialLeadsUsed >= trialLeadLimit
      ? SubscriptionStatus.trialExhausted
      : status;
  bool get canCreateLead =>
      unlimitedQaMode ||
      effectiveStatus == SubscriptionStatus.active ||
      (effectiveStatus == SubscriptionStatus.trial &&
          trialLeadsUsed < trialLeadLimit);
}

class LeadCreationBlockedException implements Exception {
  const LeadCreationBlockedException(this.status);

  final SubscriptionStatus status;
}
