/// Environment-scoped public Cognito identifiers for AUT-01/AUT-10.
library;

import 'dart:convert';

enum FolooEnvironment { dev, prod }

class CognitoEnvironmentConfiguration {
  const CognitoEnvironmentConfiguration({
    required this.region,
    required this.userPoolId,
    required this.appClientId,
    this.hostedUiDomain = '',
    this.signInRedirectUri = '',
    this.signOutRedirectUri = '',
    this.oauthRequired = false,
  });

  final String region;
  final String userPoolId;
  final String appClientId;
  final String hostedUiDomain;
  final String signInRedirectUri;
  final String signOutRedirectUri;
  final bool oauthRequired;

  bool get hasHostedUi =>
      hostedUiDomain.isNotEmpty &&
      signInRedirectUri.isNotEmpty &&
      signOutRedirectUri.isNotEmpty;

  bool get _hasAnyHostedUiValue =>
      hostedUiDomain.isNotEmpty ||
      signInRedirectUri.isNotEmpty ||
      signOutRedirectUri.isNotEmpty;

  /// Amplify Gen 2 configuration containing public identifiers only.
  String toAmplifyConfiguration() {
    if ((oauthRequired || _hasAnyHostedUiValue) && !hasHostedUi) {
      throw StateError(
        'Incomplete Cognito OAuth configuration: domain, sign-in redirect, '
        'and sign-out redirect are all required.',
      );
    }
    final auth = <String, Object>{
      'aws_region': region,
      'user_pool_id': userPoolId,
      'user_pool_client_id': appClientId,
      'username_attributes': ['email'],
      'user_verification_types': ['email'],
      'standard_required_attributes': <String>[],
      'unauthenticated_identities_enabled': false,
      'mfa_configuration': 'NONE',
      'mfa_methods': <String>[],
    };
    if (hasHostedUi) {
      auth['oauth'] = {
        'domain': hostedUiDomain,
        'identity_providers': ['GOOGLE'],
        'redirect_sign_in_uri': [signInRedirectUri],
        'redirect_sign_out_uri': [signOutRedirectUri],
        'response_type': 'code',
        'scopes': ['openid', 'email', 'profile'],
      };
    }
    return jsonEncode({'version': '1.0', 'auth': auth});
  }
}

abstract final class CognitoConfigurations {
  static const dev = CognitoEnvironmentConfiguration(
    region: 'us-east-1',
    userPoolId: 'us-east-1_QVm3dWe4O',
    appClientId: '6jong3atp2crqcsde6g215ant8',
    hostedUiDomain: String.fromEnvironment(
      'FOLOO_COGNITO_HOSTED_UI_DOMAIN',
      defaultValue: 'us-east-1qvm3dwe4o.auth.us-east-1.amazoncognito.com',
    ),
    signInRedirectUri: String.fromEnvironment(
      'FOLOO_AUTH_SIGN_IN_REDIRECT',
      defaultValue: 'foloo://callback/',
    ),
    signOutRedirectUri: String.fromEnvironment(
      'FOLOO_AUTH_SIGN_OUT_REDIRECT',
      defaultValue: 'foloo://signout/',
    ),
    oauthRequired: true,
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
