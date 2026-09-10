/// Foloo application entry point.
///
/// Starts the unified Foloo V1 Flutter shell and delegates application state
/// to [FolooApp]. ES: Punto de entrada de la aplicación.
library;

import 'package:flutter/widgets.dart';

import 'app.dart';
import 'auth/auth_repository.dart';
import 'auth/cognito_auth_service.dart';
import 'auth/cognito_configuration.dart';
import 'auth/cognito_runtime.dart';
import 'auth/cognito_sync_session_provider.dart';
import 'data/repositories/local_repositories.dart';
import 'sync/foloo_api_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CognitoRuntime.configure(
    CognitoConfigurations.forEnvironment(FolooEnvironment.dev),
  );
  final persistence = await LocalPersistence.production();
  runApp(
    FolooApp(
      useSystemLocale: true,
      persistence: persistence,
      useDemoFixtures: false,
      authRepository: AuthRepository(
        const CognitoAuthService(AmplifyCognitoAuthClient()),
      ),
      syncApi: FolooApiClient(configuration: FolooApiConfiguration.dev),
      syncSessionProvider: const CognitoSyncSessionProvider(),
    ),
  );
}
