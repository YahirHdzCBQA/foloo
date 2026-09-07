/// One-time Amplify bootstrap for the normal application runtime.
library;

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

import 'cognito_configuration.dart';

abstract final class CognitoRuntime {
  static Future<void> configure(
    CognitoEnvironmentConfiguration configuration,
  ) async {
    if (Amplify.isConfigured) return;
    await Amplify.addPlugin(AmplifyAuthCognito());
    await Amplify.configure(configuration.toAmplifyConfiguration());
  }
}
