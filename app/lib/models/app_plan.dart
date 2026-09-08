/// Superseded development-only edition selector retained until FL-014 cleanup.
///
/// DEMO: Foloo V1 has one capability set; do not extend this enum or source it
/// from the backend. It exists only to avoid functional changes in FL-013C.
enum AppPlan { basic, pro }

/// Compatibility checks for the superseded demo UI.
extension AppPlanLabel on AppPlan {
  String get label => this == AppPlan.basic ? 'Basic' : 'Pro';
  bool get isPro => this == AppPlan.pro;
}
