/// Drift-backed session metadata for the FL-013A development auth adapter.
///
/// Values are device-global because they identify the currently active local
/// session before a user-scoped repository can be selected. No password is
/// stored. Historical v1 preferences remain untouched.
library;

import 'dart:convert';

import '../data/repositories/local_repositories.dart';
import 'auth_models.dart';
import 'auth_service.dart';

class DriftDevelopmentAuthStore implements DevelopmentAuthStore {
  const DriftDevelopmentAuthStore(this._preferences);

  static const _activeId = 'developmentAuth.activeUserId';
  static const _activeUsername = 'developmentAuth.activeUsername';
  static const _accountPrefix = 'developmentAuth.account.';

  final GlobalPreferencesRepository _preferences;

  @override
  Future<AuthUser?> readSession() async {
    final id = await _preferences.read(_activeId);
    final username = await _preferences.read(_activeUsername);
    if (id == null || username == null) return null;
    return AuthUser(id: id, username: username);
  }

  @override
  Future<void> writeSession(AuthUser user) async {
    await _preferences.write(_activeId, user.id);
    await _preferences.write(_activeUsername, user.username);
  }

  @override
  Future<void> clearSession() async {
    await _preferences.delete(_activeId);
    await _preferences.delete(_activeUsername);
  }

  @override
  Future<String?> readAssignedUserId(String username) =>
      _preferences.read(_accountKey(username));

  @override
  Future<void> writeAssignedUserId(String username, String userId) =>
      _preferences.write(_accountKey(username), userId);

  String _accountKey(String username) =>
      '$_accountPrefix${base64Url.encode(utf8.encode(username))}';
}
