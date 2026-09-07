/// Replaceable authentication adapter contract for Foloo.
///
/// Cognito and the controlled development adapter live behind this boundary.
library;

import 'auth_models.dart';

abstract interface class AuthService {
  Future<AuthUser?> restoreSession();

  Future<AuthSignUpResult> signUp({
    required String email,
    required String password,
  });

  Future<void> confirmSignUp({required String email, required String code});

  Future<void> resendSignUpCode({required String email});

  Future<AuthUser> signIn({required String username, required String password});

  Future<void> signOut();
}

/// Optional future capability kept separate so deferred recovery does not
/// expand or break the active [AuthService] contract (AUT-13).
abstract interface class AccountRecoveryService {
  Future<void> requestPasswordReset({required String email});

  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  });
}

/// Semantic storage boundary used only by the development adapter.
abstract interface class DevelopmentAuthStore {
  Future<AuthUser?> readSession();

  Future<void> writeSession(AuthUser user);

  Future<void> clearSession();

  Future<String?> readAssignedUserId(String username);

  Future<void> writeAssignedUserId(String username, String userId);
}
