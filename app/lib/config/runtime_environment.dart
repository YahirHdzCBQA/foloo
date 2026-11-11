/// Selects the public AWS boundary used by the Foloo mobile runtime.
///
/// Debug keeps the established DEV defaults. Release builds must select an
/// environment explicitly, and PROD accepts only complete public identifiers.
library;

import 'package:flutter/foundation.dart';

/// AWS environment that owns identity, API data and server-side workflows.
enum FolooEnvironment { dev, prod }

/// Public, non-secret identifiers required by the mobile runtime.
class FolooRuntimeEnvironment {
  const FolooRuntimeEnvironment({
    required this.name,
    required this.region,
    required this.userPoolId,
    required this.appClientId,
    required this.cognitoHostedUiDomain,
    required this.apiBaseUrl,
    required this.signInRedirectUri,
    required this.signOutRedirectUri,
  });

  static const _devRegion = 'us-east-1';
  static const _devUserPoolId = 'us-east-1_QVm3dWe4O';
  static const _devAppClientId = '6jong3atp2crqcsde6g215ant8';
  static const _devHostedUiDomain =
      'us-east-1qvm3dwe4o.auth.us-east-1.amazoncognito.com';
  static const _devApiBaseUrl =
      'https://zbc91cpy10.execute-api.us-east-1.amazonaws.com';

  final FolooEnvironment name;
  final String region;
  final String userPoolId;
  final String appClientId;
  final String cognitoHostedUiDomain;
  final String apiBaseUrl;
  final String signInRedirectUri;
  final String signOutRedirectUri;

  /// Resolves compile-time values without ever accepting credentials.
  factory FolooRuntimeEnvironment.fromBuild({
    String environment = const String.fromEnvironment('FOLOO_ENVIRONMENT'),
    bool allowDevRelease = const bool.fromEnvironment(
      'FOLOO_ALLOW_DEV_RELEASE',
    ),
    bool isRelease = kReleaseMode,
    String prodRegion = const String.fromEnvironment('FOLOO_AWS_REGION'),
    String prodUserPoolId = const String.fromEnvironment(
      'FOLOO_COGNITO_USER_POOL_ID',
    ),
    String prodAppClientId = const String.fromEnvironment(
      'FOLOO_COGNITO_APP_CLIENT_ID',
    ),
    String prodHostedUiDomain = const String.fromEnvironment(
      'FOLOO_COGNITO_HOSTED_UI_DOMAIN',
    ),
    String prodApiBaseUrl = const String.fromEnvironment('FOLOO_API_BASE_URL'),
    String signInRedirectUri = const String.fromEnvironment(
      'FOLOO_AUTH_SIGN_IN_REDIRECT',
      defaultValue: 'foloo://callback/',
    ),
    String signOutRedirectUri = const String.fromEnvironment(
      'FOLOO_AUTH_SIGN_OUT_REDIRECT',
      defaultValue: 'foloo://signout/',
    ),
  }) {
    final selected = environment.trim().toLowerCase();
    if (selected.isEmpty) {
      if (isRelease) {
        throw StateError(
          'Release builds require --dart-define=FOLOO_ENVIRONMENT=dev|prod.',
        );
      }
      return dev;
    }
    if (selected == 'dev') {
      if (isRelease && !allowDevRelease) {
        throw StateError(
          'A DEV Release requires the explicit FOLOO_ALLOW_DEV_RELEASE=true '
          'QA opt-in. Public builds must select PROD.',
        );
      }
      return dev;
    }
    if (selected != 'prod') {
      throw StateError('FOLOO_ENVIRONMENT must be dev or prod.');
    }

    final required = <String, String>{
      'FOLOO_AWS_REGION': prodRegion,
      'FOLOO_COGNITO_USER_POOL_ID': prodUserPoolId,
      'FOLOO_COGNITO_APP_CLIENT_ID': prodAppClientId,
      'FOLOO_COGNITO_HOSTED_UI_DOMAIN': prodHostedUiDomain,
      'FOLOO_API_BASE_URL': prodApiBaseUrl,
    };
    final missing = required.entries
        .where((entry) => entry.value.trim().isEmpty)
        .map((entry) => entry.key)
        .toList(growable: false);
    if (missing.isNotEmpty) {
      throw StateError(
        'PROD mobile configuration is incomplete: ${missing.join(', ')}.',
      );
    }

    final api = Uri.tryParse(prodApiBaseUrl);
    if (api == null || api.scheme != 'https' || api.host.isEmpty) {
      throw StateError('FOLOO_API_BASE_URL must be an HTTPS origin.');
    }
    if (prodHostedUiDomain.contains('://') ||
        prodHostedUiDomain.contains('/') ||
        !prodHostedUiDomain.contains('.')) {
      throw StateError(
        'FOLOO_COGNITO_HOSTED_UI_DOMAIN must be a host without scheme or path.',
      );
    }
    if (!RegExp(r'^[a-z]{2}-[a-z]+-\d+_[A-Za-z0-9]+$')
        .hasMatch(prodUserPoolId)) {
      throw StateError('FOLOO_COGNITO_USER_POOL_ID is invalid.');
    }
    if (prodUserPoolId == _devUserPoolId ||
        prodAppClientId == _devAppClientId ||
        prodHostedUiDomain == _devHostedUiDomain ||
        api.host == Uri.parse(_devApiBaseUrl).host) {
      throw StateError('PROD must not reuse any known DEV identifier.');
    }
    if (!prodUserPoolId.startsWith('${prodRegion}_')) {
      throw StateError(
        'FOLOO_COGNITO_USER_POOL_ID must belong to FOLOO_AWS_REGION.',
      );
    }
    if (!prodHostedUiDomain.endsWith('.auth.$prodRegion.amazoncognito.com')) {
      throw StateError(
        'FOLOO_COGNITO_HOSTED_UI_DOMAIN must belong to '
        'FOLOO_AWS_REGION.',
      );
    }
    for (final redirect in [signInRedirectUri, signOutRedirectUri]) {
      final uri = Uri.tryParse(redirect);
      if (uri == null || uri.scheme != 'foloo' || uri.host.isEmpty) {
        throw StateError('Foloo OAuth redirect URIs are invalid.');
      }
    }

    return FolooRuntimeEnvironment(
      name: FolooEnvironment.prod,
      region: prodRegion,
      userPoolId: prodUserPoolId,
      appClientId: prodAppClientId,
      cognitoHostedUiDomain: prodHostedUiDomain,
      apiBaseUrl: api.toString().replaceFirst(RegExp(r'/$'), ''),
      signInRedirectUri: signInRedirectUri,
      signOutRedirectUri: signOutRedirectUri,
    );
  }

  /// Existing DEV behavior for Debug and explicitly authorized QA releases.
  static const dev = FolooRuntimeEnvironment(
    name: FolooEnvironment.dev,
    region: _devRegion,
    userPoolId: _devUserPoolId,
    appClientId: _devAppClientId,
    cognitoHostedUiDomain: _devHostedUiDomain,
    apiBaseUrl: _devApiBaseUrl,
    signInRedirectUri: 'foloo://callback/',
    signOutRedirectUri: 'foloo://signout/',
  );
}
