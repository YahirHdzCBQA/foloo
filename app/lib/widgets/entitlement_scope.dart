/// Exposes the current owner-scoped entitlement to authenticated UI only.
library;

import 'package:flutter/widgets.dart';

import '../models/entitlement.dart';

class EntitlementScope extends InheritedWidget {
  const EntitlementScope({
    required this.entitlement,
    required super.child,
    super.key,
  });

  final EntitlementSnapshot entitlement;

  static EntitlementSnapshot? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<EntitlementScope>()
      ?.entitlement;

  @override
  bool updateShouldNotify(EntitlementScope oldWidget) =>
      entitlement.status != oldWidget.entitlement.status ||
      entitlement.trialLeadsUsed != oldWidget.entitlement.trialLeadsUsed ||
      entitlement.verified != oldWidget.entitlement.verified;
}
