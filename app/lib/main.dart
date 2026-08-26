/// Foloo application entry point.
///
/// Starts the shared Basic/Pro Flutter shell and delegates application state
/// to [FolooApp]. ES: Punto de entrada de la aplicación.
library;

import 'package:flutter/widgets.dart';

import 'app.dart';

void main() {
  runApp(const FolooApp(useSystemLocale: true));
}
