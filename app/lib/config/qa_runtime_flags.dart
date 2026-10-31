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

/// Shows Sign in with Apple only after its external Cognito configuration has
/// been verified for the target environment (AUT-22, ADR-009).
const bool folooAppleSignInEnabled = bool.fromEnvironment(
  'FOLOO_APPLE_SIGNIN',
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

/// Shows the paywall action that opens the Foloo web account (MON-14).
///
/// Disabled by default while each storefront and region is reviewed. An
/// approved build must opt in explicitly (D-01).
const bool folooWebAccountLinkEnabled = bool.fromEnvironment(
  'FOLOO_WEB_ACCOUNT_LINK',
  defaultValue: false,
);

/// Web account page opened from the paywall; it hosts Stripe Checkout and the
/// Customer Portal (MON-15, MON-17). Matches the backend billing return URLs.
const String folooWebAccountUrl = String.fromEnvironment(
  'FOLOO_WEB_ACCOUNT_URL',
  defaultValue: 'https://foloo.io/dashboard',
);
