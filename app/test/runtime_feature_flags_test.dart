/// Regression coverage for public runtime feature defaults.
///
/// External identity providers and storefront links remain opt-in until their
/// environment and policy approvals are complete.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/config/qa_runtime_flags.dart';

void main() {
  test('external providers and web account link default to disabled', () {
    expect(folooAppleSignInEnabled, isFalse);
    expect(folooMicrosoftSignInEnabled, isFalse);
    expect(folooWebAccountLinkEnabled, isFalse);
  });
}
