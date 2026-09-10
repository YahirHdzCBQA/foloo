/// Supplies short-lived Cognito access tokens to the sync boundary.
///
/// Tokens stay in Amplify secure session storage and are never persisted in
/// Drift or copied into outbox rows (SYN-09, ADR-002).
library;

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

import '../sync/sync_models.dart';

class CognitoSyncSessionProvider implements SyncSessionProvider {
  const CognitoSyncSessionProvider();

  @override
  Future<String?> accessTokenFor(String ownerSub) async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      if (user.userId != ownerSub) return null;
      final session = await Amplify.Auth.fetchAuthSession();
      if (!session.isSignedIn || session is! CognitoAuthSession) return null;
      return session.userPoolTokensResult.value.accessToken.raw;
    } on SignedOutException {
      return null;
    } on AuthException {
      return null;
    }
  }
}
