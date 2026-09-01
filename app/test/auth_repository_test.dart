import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/auth/auth_models.dart';
import 'package:foloo/auth/auth_repository.dart';
import 'package:foloo/auth/auth_service.dart';
import 'package:foloo/auth/development_auth_service.dart';

class _MemoryAuthStore implements DevelopmentAuthStore {
  AuthUser? session;
  final ids = <String, String>{};

  @override
  Future<void> clearSession() async => session = null;

  @override
  Future<String?> readAssignedUserId(String username) async => ids[username];

  @override
  Future<AuthUser?> readSession() async => session;

  @override
  Future<void> writeAssignedUserId(String username, String userId) async {
    ids[username] = userId;
  }

  @override
  Future<void> writeSession(AuthUser user) async => session = user;
}

class _FailingAuthService implements AuthService {
  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<AuthUser> signIn({
    required String username,
    required String password,
  }) => throw StateError('fake failure');

  @override
  Future<void> signOut() async {}
}

void main() {
  test(
    'AUT-02 development auth restores stable identity and logs out',
    () async {
      final store = _MemoryAuthStore();
      var nextId = 0;
      final repository = AuthRepository(
        DevelopmentAuthService(
          store,
          userIdFactory: () => 'fake-user-${++nextId}',
        ),
      );

      expect(repository.state.status, AuthStatus.initializing);
      await repository.initialize();
      expect(repository.state.status, AuthStatus.unauthenticated);

      expect(
        await repository.signIn(username: 'user-a', password: 'not-stored'),
        isTrue,
      );
      expect(repository.state.user?.id, 'fake-user-1');
      expect(store.session?.username, 'user-a');

      final restored = AuthRepository(
        DevelopmentAuthService(store, userIdFactory: () => 'unexpected'),
      );
      await restored.initialize();
      expect(restored.state.status, AuthStatus.authenticated);
      expect(restored.state.user?.id, 'fake-user-1');

      await restored.signOut();
      expect(restored.state.status, AuthStatus.unauthenticated);
      expect(store.session, isNull);

      await repository.signIn(username: 'user-a', password: 'another-value');
      expect(repository.state.user?.id, 'fake-user-1');
    },
  );

  test('authentication failures use the centralized error state', () async {
    final repository = AuthRepository(_FailingAuthService());
    await repository.initialize();
    expect(
      await repository.signIn(username: 'user-a', password: 'bad'),
      isFalse,
    );
    expect(repository.state.status, AuthStatus.error);
    expect(repository.state.user, isNull);
  });
}
