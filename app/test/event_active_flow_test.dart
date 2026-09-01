import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/app.dart';
import 'package:foloo/auth/auth_models.dart';
import 'package:foloo/auth/auth_repository.dart';
import 'package:foloo/auth/auth_service.dart';
import 'package:foloo/data/repositories/local_repositories.dart';
import 'package:foloo/models/app_event.dart';

class _RestoredAuthService implements AuthService {
  static const user = AuthUser(id: 'fake-user-events', username: 'events');

  @override
  Future<AuthUser?> restoreSession() async => user;

  @override
  Future<AuthUser> signIn({
    required String username,
    required String password,
  }) async => user;

  @override
  Future<void> signOut() async {}
}

AppEvent datedEvent(String id, DateTime date) =>
    AppEvent(id: id, name: id, startsOn: date, endsOn: date);

Future<void> seed(LocalPersistence persistence) async {
  await persistence.profiles.save(
    _RestoredAuthService.user.id,
    const DemoProfile(name: 'Seller', company: 'Foloo'),
  );
  await persistence.events.save(
    _RestoredAuthService.user.id,
    datedEvent('nearest', DateTime(2026, 9, 3)),
  );
  await persistence.events.save(
    _RestoredAuthService.user.id,
    datedEvent('later', DateTime(2026, 9, 10)),
  );
}

void main() {
  testWidgets(
    'EVT-12 migrates an unclassified legacy active event to date selection',
    (tester) async {
      final persistence = LocalPersistence.inMemory();
      await seed(persistence);
      await persistence.events.activate(_RestoredAuthService.user.id, 'later');
      await tester.pumpWidget(
        FolooApp(
          persistence: persistence,
          authRepository: AuthRepository(_RestoredAuthService()),
          useDemoFixtures: false,
          nowProvider: () => DateTime(2026, 9, 1, 10),
        ),
      );
      await tester.pumpAndSettle();
      final selectedBeforeConfirmation = (await persistence.events.list(
        _RestoredAuthService.user.id,
      )).singleWhere((event) => event.active);
      expect(selectedBeforeConfirmation.id, 'nearest');
      expect(
        await persistence.preferences.read(
          _RestoredAuthService.user.id,
          'eventSelectionMode',
        ),
        'automatic',
      );

      await tester.tap(find.byKey(const Key('originContinueButton')));
      await tester.pumpAndSettle();

      final dropdown = tester.widget<DropdownButton<String>>(
        find.byKey(const Key('captureEventDropdown')),
      );
      expect(dropdown.value, 'nearest');
    },
  );

  testWidgets(
    'EVT-12 automatic choice is reevaluated after the local day changes',
    (tester) async {
      var now = DateTime(2026, 9, 1, 10);
      final persistence = LocalPersistence.inMemory();
      await seed(persistence);
      await tester.pumpWidget(
        FolooApp(
          persistence: persistence,
          authRepository: AuthRepository(_RestoredAuthService()),
          useDemoFixtures: false,
          nowProvider: () => now,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('originScreen')), findsOneWidget);

      now = DateTime(2026, 9, 4, 9);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('originContinueButton')));
      await tester.pumpAndSettle();

      final dropdown = tester.widget<DropdownButton<String>>(
        find.byKey(const Key('captureEventDropdown')),
      );
      expect(dropdown.value, 'later');
    },
  );

  testWidgets('EVT-12 a manual event remains active across date changes', (
    tester,
  ) async {
    var now = DateTime(2026, 9, 1, 10);
    final persistence = LocalPersistence.inMemory();
    await seed(persistence);
    await tester.pumpWidget(
      FolooApp(
        persistence: persistence,
        authRepository: AuthRepository(_RestoredAuthService()),
        useDemoFixtures: false,
        nowProvider: () => now,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('originEvent-later')));
    await tester.tap(find.byKey(const Key('originContinueButton')));
    await tester.pumpAndSettle();
    now = DateTime(2026, 9, 20, 9);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    final dropdown = tester.widget<DropdownButton<String>>(
      find.byKey(const Key('captureEventDropdown')),
    );
    expect(dropdown.value, 'later');
    expect(
      await persistence.preferences.read(
        _RestoredAuthService.user.id,
        'eventSelectionMode',
      ),
      'manual',
    );
  });
}
