/// Non-production authentication adapter for local development and tests.
///
/// THIS IS NOT PRODUCTION AUTHENTICATION. It performs no remote credential
/// validation and stores no password. FL-013B replaces it with Cognito.
library;

import 'package:uuid/uuid.dart';

import 'auth_models.dart';
import 'auth_service.dart';

typedef FakeUserIdFactory = String Function();

class DevelopmentAuthService implements AuthService {
  DevelopmentAuthService(this._store, {FakeUserIdFactory? userIdFactory})
    : _userIdFactory = userIdFactory ?? _defaultUserId;

  final DevelopmentAuthStore _store;
  final FakeUserIdFactory _userIdFactory;

  static String _defaultUserId() => 'fake-user-${const Uuid().v4()}';

  @override
  Future<AuthUser?> restoreSession() => _store.readSession();

  @override
  Future<AuthUser> signIn({
    required String username,
    required String password,
  }) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty || password.isEmpty) {
      throw const FormatException('Development credentials are required.');
    }
    final existingId = await _store.readAssignedUserId(normalized);
    final user = AuthUser(
      id: existingId ?? _userIdFactory(),
      username: username.trim(),
    );
    if (existingId == null) {
      await _store.writeAssignedUserId(normalized, user.id);
    }
    await _store.writeSession(user);
    return user;
  }

  @override
  Future<void> signOut() => _store.clearSession();
}
