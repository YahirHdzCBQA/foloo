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
import 'config/runtime_environment.dart';
import 'data/repositories/local_repositories.dart';
import 'services/account_deletion_service.dart';
import 'sync/foloo_api_client.dart';
import 'sync/media_binary_transfer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = FolooRuntimeEnvironment.fromBuild();
  await CognitoRuntime.configure(CognitoConfigurations.forRuntime(environment));
  final persistence = await LocalPersistence.production();
  final syncApi = FolooApiClient(
    configuration: FolooApiConfiguration(baseUrl: environment.apiBaseUrl),
  );
  const syncSessions = CognitoSyncSessionProvider();
  runApp(
    FolooApp(
      useSystemLocale: true,
      persistence: persistence,
      useDemoFixtures: false,
      authRepository: AuthRepository(
        const CognitoAuthService(AmplifyCognitoAuthClient()),
      ),
      syncApi: syncApi,
      syncSessionProvider: syncSessions,
      accountDeletionService: ApiAccountDeletionService(syncApi, syncSessions),
      mediaBinaryTransfer: IoMediaBinaryTransfer(),
    ),
  );
}
