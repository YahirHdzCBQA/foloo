/// Centralized authentication state consumed by Foloo application bootstrap.
///
/// Widgets never invoke development or future Cognito adapters directly.
library;

import 'package:flutter/foundation.dart';

import 'auth_models.dart';
import 'auth_service.dart';

class AuthRepository extends ChangeNotifier {
  AuthRepository(this._service);

  final AuthService _service;
  AuthState _state = const AuthState.initializing();

  AuthState get state => _state;

  Future<void> initialize() async {
    _setState(const AuthState.initializing());
    try {
      final user = await _service.restoreSession();
      _setState(
        user == null
            ? const AuthState.unauthenticated()
            : AuthState.authenticated(user),
      );
    } catch (error) {
      _setState(AuthState.error(error));
    }
  }

  Future<bool> signIn({
    required String username,
    required String password,
  }) async {
    _setState(const AuthState.initializing());
    try {
      final user = await _service.signIn(
        username: username,
        password: password,
      );
      _setState(AuthState.authenticated(user));
      return true;
    } catch (error) {
      _setState(AuthState.error(error));
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _service.signOut();
      _setState(const AuthState.unauthenticated());
    } catch (error) {
      _setState(AuthState.error(error));
    }
  }

  void _setState(AuthState value) {
    _state = value;
    notifyListeners();
  }
}
