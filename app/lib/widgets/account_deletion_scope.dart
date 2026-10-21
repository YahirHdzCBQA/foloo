/// Exposes the guarded STORE-02 entry point to authenticated navigation.
library;

import 'package:flutter/widgets.dart';

class AccountDeletionScope extends InheritedWidget {
  const AccountDeletionScope({
    required this.enabled,
    required this.onOpen,
    required super.child,
    super.key,
  });

  final bool enabled;
  final VoidCallback onOpen;

  static AccountDeletionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountDeletionScope>();

  @override
  bool updateShouldNotify(AccountDeletionScope oldWidget) =>
      enabled != oldWidget.enabled || onOpen != oldWidget.onOpen;
}
