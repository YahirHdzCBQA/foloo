/// Verifies the compile-time contract of the approved TestFlight Build 7 file.
///
/// The test is skipped in the ordinary default suite and becomes active only
/// when Flutter receives the homologated `--dart-define-from-file` input.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/config/qa_runtime_flags.dart';
import 'package:foloo/config/runtime_environment.dart';
import 'package:foloo/services/card_text_recognition_service.dart';

const _isBuild7Configuration =
    String.fromEnvironment('FOLOO_ENVIRONMENT') == 'dev' &&
    bool.fromEnvironment('FOLOO_ALLOW_DEV_RELEASE') &&
    bool.fromEnvironment('FOLOO_APPLE_SIGNIN');

void main() {
  test(
    'REL-06 Build 7 defines enable only the approved DEV capabilities',
    () {
      final environment = FolooRuntimeEnvironment.fromBuild(isRelease: true);

      expect(environment.name, FolooEnvironment.dev);
      expect(folooUnlimitedQaMode, isFalse);
      expect(folooAccountDeletionEnabled, isTrue);
      expect(folooAppleSignInEnabled, isTrue);
      expect(folooMicrosoftSignInEnabled, isFalse);
      expect(folooWebAccountLinkEnabled, isFalse);
      expect(ocrQaDiagnosticsEnabled, isFalse);
    },
    skip: _isBuild7Configuration
        ? false
        : 'Run with config/testflight-dev-build7.json.',
  );
}
