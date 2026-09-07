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

  AuthFailureCode? get failure => switch (_state.error) {
    FolooAuthException(:final code) => code,
    _ => null,
  };

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

  Future<AuthSignUpResult?> signUp({
    required String email,
    required String password,
  }) async {
    _setState(const AuthState.initializing());
    try {
      final result = await _service.signUp(email: email, password: password);
      _setState(const AuthState.unauthenticated());
      return result;
    } catch (error) {
      _setState(AuthState.error(error));
      return null;
    }
  }

  Future<bool> confirmSignUp({
    required String email,
    required String code,
  }) async {
    _setState(const AuthState.initializing());
    try {
      await _service.confirmSignUp(email: email, code: code);
      _setState(const AuthState.unauthenticated());
      return true;
    } catch (error) {
      _setState(AuthState.error(error));
      return false;
    }
  }

  Future<bool> resendSignUpCode({required String email}) async {
    _setState(const AuthState.initializing());
    try {
      await _service.resendSignUpCode(email: email);
      _setState(const AuthState.unauthenticated());
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

  void clearFailure() {
    if (_state.status == AuthStatus.error) {
      _setState(const AuthState.unauthenticated());
    }
  }

  void _setState(AuthState value) {
    _state = value;
    notifyListeners();
  }
}
