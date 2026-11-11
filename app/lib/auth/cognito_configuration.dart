/// Environment-scoped public Cognito identifiers for AUT-01/AUT-10.
library;

import 'dart:convert';

import '../config/qa_runtime_flags.dart';
import '../config/runtime_environment.dart';

class CognitoEnvironmentConfiguration {
  const CognitoEnvironmentConfiguration({
    required this.region,
    required this.userPoolId,
    required this.appClientId,
    this.hostedUiDomain = '',
    this.signInRedirectUri = '',
    this.signOutRedirectUri = '',
    this.oauthRequired = false,
    this.hostedUiIdentityProviders = const [CognitoHostedUiProvider.google],
  });

  final String region;
  final String userPoolId;
  final String appClientId;
  final String hostedUiDomain;
  final String signInRedirectUri;
  final String signOutRedirectUri;
  final bool oauthRequired;
  final List<CognitoHostedUiProvider> hostedUiIdentityProviders;

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
        'identity_providers': hostedUiIdentityProviders
            .map((provider) => provider.amplifyName)
            .toList(growable: false),
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
  static CognitoEnvironmentConfiguration forRuntime(
    FolooRuntimeEnvironment environment,
  ) => CognitoEnvironmentConfiguration(
    region: environment.region,
    userPoolId: environment.userPoolId,
    appClientId: environment.appClientId,
    hostedUiDomain: environment.cognitoHostedUiDomain,
    signInRedirectUri: environment.signInRedirectUri,
    signOutRedirectUri: environment.signOutRedirectUri,
    oauthRequired: true,
    hostedUiIdentityProviders: [
      CognitoHostedUiProvider.google,
      if (folooAppleSignInEnabled) CognitoHostedUiProvider.apple,
    ],
  );

  static CognitoEnvironmentConfiguration get dev =>
      forRuntime(FolooRuntimeEnvironment.dev);
}

/// Built-in providers represented by the Amplify Outputs OAuth schema.
///
/// Microsoft is a named custom Cognito OIDC provider and is selected directly
/// by Amplify's custom provider API, so it is deliberately absent here.
enum CognitoHostedUiProvider {
  google('GOOGLE'),
  apple('SIGN_IN_WITH_APPLE');

  const CognitoHostedUiProvider(this.amplifyName);

  final String amplifyName;
}
