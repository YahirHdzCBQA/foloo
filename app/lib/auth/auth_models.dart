/// Authentication identity and state shared by app bootstrap and session UI.
///
/// The stable user id is an authentication identifier (future Cognito `sub`),
/// not the editable Foloo business profile stored in Drift.
library;

enum AuthStatus { initializing, authenticated, unauthenticated, error }

/// Minimal authenticated identity required to scope local data.
class AuthUser {
  const AuthUser({required this.id, required this.username});

  final String id;
  final String username;
}

/// Single source of truth for authentication lifecycle state.
class AuthState {
  const AuthState._(this.status, {this.user, this.error});

  const AuthState.initializing() : this._(AuthStatus.initializing);
  const AuthState.unauthenticated() : this._(AuthStatus.unauthenticated);
  const AuthState.authenticated(AuthUser user)
    : this._(AuthStatus.authenticated, user: user);
  const AuthState.error(Object error) : this._(AuthStatus.error, error: error);

  final AuthStatus status;
  final AuthUser? user;
  final Object? error;
}
