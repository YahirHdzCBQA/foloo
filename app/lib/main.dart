/// Foloo application entry point.
///
/// Starts the shared Basic/Pro Flutter shell and delegates application state
/// to [FolooApp]. ES: Punto de entrada de la aplicación.
library;

import 'package:flutter/widgets.dart';

import 'app.dart';
import 'data/repositories/local_repositories.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final persistence = await LocalPersistence.production();
  runApp(
    FolooApp(
      useSystemLocale: true,
      persistence: persistence,
      useDemoFixtures: false,
    ),
  );
}
