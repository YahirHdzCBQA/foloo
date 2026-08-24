enum AppPlan { basic, pro }

extension AppPlanLabel on AppPlan {
  String get label => this == AppPlan.basic ? 'Basic' : 'Pro';
  bool get isPro => this == AppPlan.pro;
}
