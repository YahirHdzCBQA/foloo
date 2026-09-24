/// Exposes the current Foloo account identity to shared authenticated chrome.
///
/// The scope contains authentication metadata only; sender OAuth identity is
/// deliberately excluded so navigation cannot confuse the two accounts.
library;

import 'package:flutter/widgets.dart';

import '../auth/auth_models.dart';

/// Read-only authenticated account context rebuilt on login and logout.
class AuthAccountScope extends InheritedWidget {
  const AuthAccountScope({
    required this.email,
    required this.provider,
    required super.child,
    super.key,
  });

  final String email;
  final AuthProvider? provider;

  static AuthAccountScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthAccountScope>();

  @override
  bool updateShouldNotify(AuthAccountScope oldWidget) =>
      email != oldWidget.email || provider != oldWidget.provider;
}
