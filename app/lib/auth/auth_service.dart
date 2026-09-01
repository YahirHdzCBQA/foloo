/// Replaceable authentication adapter contract for Foloo.
///
/// FL-013A supplies a development adapter. FL-013B will add Cognito behind this
/// same boundary without changing consumers.
library;

import 'auth_models.dart';

abstract interface class AuthService {
  Future<AuthUser?> restoreSession();

  Future<AuthUser> signIn({required String username, required String password});

  Future<void> signOut();
}

/// Semantic storage boundary used only by the development adapter.
abstract interface class DevelopmentAuthStore {
  Future<AuthUser?> readSession();

  Future<void> writeSession(AuthUser user);

  Future<void> clearSession();

  Future<String?> readAssignedUserId(String username);

  Future<void> writeAssignedUserId(String username, String userId);
}
