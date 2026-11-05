/// Regression checks for the iOS callback boundary used by Cognito Web UI.
///
/// These tests inspect only committed public configuration; credentials and
/// provider secrets remain external to the application bundle.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AUT-22/AUT-23 iOS registers the Foloo OAuth callback scheme', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(plist, contains('<key>CFBundleURLTypes</key>'));
    expect(
      plist,
      contains('<string>foloo</string>'),
      reason: 'foloo://callback and foloo://signout must return to Runner.',
    );
  });

  test('REL-01 TestFlight V4 uses the next approved iOS build number', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('version: 1.0.0+4'));
  });
}
