/// Compile-time switches for explicitly authorized QA-only behavior.
///
/// Production-compatible builds keep every switch disabled unless the build
/// command opts in deliberately. These flags never grant commercial status.
library;

/// Temporarily bypasses only the new-Lead entitlement gate in QA builds.
const bool folooUnlimitedQaMode = bool.fromEnvironment(
  'FOLOO_UNLIMITED_QA_MODE',
  defaultValue: false,
);
