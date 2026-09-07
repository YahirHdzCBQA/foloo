/// Environment-scoped public Cognito identifiers for AUT-01/AUT-10.
library;

import 'dart:convert';

enum FolooEnvironment { dev, prod }

class CognitoEnvironmentConfiguration {
  const CognitoEnvironmentConfiguration({
    required this.region,
    required this.userPoolId,
    required this.appClientId,
  });

  final String region;
  final String userPoolId;
  final String appClientId;

  /// Amplify Gen 2 configuration containing public identifiers only.
  String toAmplifyConfiguration() => jsonEncode({
    'version': '1.0',
    'auth': {
      'aws_region': region,
      'user_pool_id': userPoolId,
      'user_pool_client_id': appClientId,
      'username_attributes': ['email'],
      'user_verification_types': ['email'],
      'standard_required_attributes': <String>[],
      'unauthenticated_identities_enabled': false,
      'mfa_configuration': 'NONE',
      'mfa_methods': <String>[],
    },
  });
}

abstract final class CognitoConfigurations {
  static const dev = CognitoEnvironmentConfiguration(
    region: 'us-east-1',
    userPoolId: 'us-east-1_QVm3dWe4O',
    appClientId: '6jong3atp2crqcsde6g215ant8',
  );

  static CognitoEnvironmentConfiguration forEnvironment(
    FolooEnvironment environment,
  ) => switch (environment) {
    FolooEnvironment.dev => dev,
    FolooEnvironment.prod => throw UnsupportedError(
      'Cognito PROD configuration has not been supplied.',
    ),
  };
}
