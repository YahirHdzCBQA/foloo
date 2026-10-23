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

/// STORE-02 UI is hidden until the destructive backend dependencies are
/// approved and enabled in the target environment.
const bool folooAccountDeletionEnabled = bool.fromEnvironment(
  'FOLOO_ACCOUNT_DELETION_ENABLED',
  defaultValue: false,
);

/// Shows the Microsoft sign-in button in Login and Create account (AUT-23).
///
/// AUT-23 is Proposed until the Cognito OIDC provider is validated in DEV, so
/// this stays off unless the build passes `--dart-define=FOLOO_MICROSOFT_SIGNIN=true`.
const bool folooMicrosoftSignInEnabled = bool.fromEnvironment(
  'FOLOO_MICROSOFT_SIGNIN',
  defaultValue: false,
);
