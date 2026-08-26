/// Demo representation of the Basic/Pro account capability.
///
/// DEMO: RNF-18 requires this value to be supplied by the backend in product.
enum AppPlan { basic, pro }

/// Convenience checks used to keep Pro-only surfaces absent from Basic.
extension AppPlanLabel on AppPlan {
  String get label => this == AppPlan.basic ? 'Basic' : 'Pro';
  bool get isPro => this == AppPlan.pro;
}
