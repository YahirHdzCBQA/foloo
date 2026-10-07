/// Drift-backed entitlement cache and historical offline trial reservations.
library;

import 'package:drift/drift.dart';

import '../../models/entitlement.dart';
import '../local/app_database.dart';

class EntitlementRepository {
  EntitlementRepository(this._database);

  final AppDatabase _database;

  Future<EntitlementSnapshot> load(String owner) async {
    final stored = await _database.entitlementDao.snapshot(owner);
    final pending = await _database.entitlementDao.pendingReservations(owner);
    return EntitlementSnapshot(
      status: _status(stored?.subscriptionStatus ?? 'trial'),
      serverTrialLeadsUsed: stored?.trialLeadsUsed ?? 0,
      pendingLocalLeads: pending,
      verified: stored != null,
      serverUpdatedAt: stored?.serverUpdatedAt,
    );
  }

  Future<void> reserveLead(String owner, String leadId, DateTime now) async {
    final entitlement = await load(owner);
    if (!entitlement.canCreateLead) {
      throw LeadCreationBlockedException(entitlement.effectiveStatus);
    }
    if (entitlement.effectiveStatus == SubscriptionStatus.trial) {
      await _database.entitlementDao.reserve(owner, leadId, now);
    }
  }

  Future<void> applyServerSnapshot(
    String owner,
    Map<String, Object?> data,
  ) async {
    final status = data['subscriptionStatus'];
    final used = data['trialLeadsUsed'];
    if (status is! String ||
        used is! int ||
        used < 0 ||
        used > trialLeadLimit) {
      throw const FormatException('Invalid entitlement snapshot.');
    }
    _status(status);
    final now = DateTime.now().toUtc();
    await _database.entitlementDao.saveSnapshot(
      LocalEntitlementsCompanion.insert(
        ownerUserId: owner,
        subscriptionStatus: status,
        trialLeadsUsed: used,
        serverUpdatedAt: Value(_dateOrNull(data['entitlementUpdatedAt'])),
        cachedAt: now,
      ),
    );
  }

  Future<void> acknowledgeLead(
    String owner,
    String leadId, {
    required bool incrementCachedUsage,
  }) async {
    if (!await _database.entitlementDao.hasReservation(owner, leadId)) return;
    final stored = await _database.entitlementDao.snapshot(owner);
    if (incrementCachedUsage &&
        stored != null &&
        stored.subscriptionStatus != 'active') {
      final used = (stored.trialLeadsUsed + 1).clamp(0, trialLeadLimit);
      await _database.entitlementDao.saveSnapshot(
        LocalEntitlementsCompanion.insert(
          ownerUserId: owner,
          subscriptionStatus: used == trialLeadLimit
              ? 'trial_exhausted'
              : stored.subscriptionStatus,
          trialLeadsUsed: used,
          serverUpdatedAt: Value(stored.serverUpdatedAt),
          cachedAt: DateTime.now().toUtc(),
        ),
      );
    }
    await _database.entitlementDao.removeReservation(owner, leadId);
  }

  static SubscriptionStatus _status(String value) => switch (value) {
    'trial' => SubscriptionStatus.trial,
    'trial_exhausted' => SubscriptionStatus.trialExhausted,
    'active' => SubscriptionStatus.active,
    'expired' => SubscriptionStatus.expired,
    _ => throw const FormatException('Unknown subscription status.'),
  };

  static DateTime? _dateOrNull(Object? value) => value is String
      ? DateTime.tryParse(value)?.toUtc()
      : value is DateTime
      ? value.toUtc()
      : null;
}
