/// Regression checks for the iOS callback boundary used by Cognito Web UI.
///
/// These tests inspect only committed public configuration; credentials and
/// provider secrets remain external to the application bundle.
library;

import 'dart:convert';
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

  test('REL-06 TestFlight Build 7 keeps one explicit DEV configuration', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final configuration = jsonDecode(
      File('config/testflight-dev-build7.json').readAsStringSync(),
    ) as Map<String, Object?>;

    expect(pubspec, contains('version: 1.0.0+7'));
    expect(configuration, {
      'FOLOO_ENVIRONMENT': 'dev',
      'FOLOO_ALLOW_DEV_RELEASE': true,
      'FOLOO_UNLIMITED_QA_MODE': false,
      'FOLOO_ACCOUNT_DELETION_ENABLED': true,
      'FOLOO_APPLE_SIGNIN': true,
      'FOLOO_MICROSOFT_SIGNIN': false,
      'FOLOO_WEB_ACCOUNT_LINK': false,
      'FOLOO_OCR_QA_DIAGNOSTICS': false,
    });
  });

  test('REL-06 photo permission describes every current gallery use', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final english = File('ios/Runner/en.lproj/InfoPlist.strings')
        .readAsStringSync();
    final spanish = File('ios/Runner/es.lproj/InfoPlist.strings')
        .readAsStringSync();

    for (final value in [plist, english]) {
      expect(value, contains('business cards'));
      expect(value, contains('contact reference images'));
      expect(value, contains('profile photo'));
    }
    expect(spanish, contains('tarjetas de presentación'));
    expect(spanish, contains('imágenes de referencia'));
    expect(spanish, contains('foto de perfil'));
  });
}
