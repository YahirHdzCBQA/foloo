/// Exposes the authenticated profile editor from shared navigation surfaces.
///
/// The scope keeps drawer consumers independent from profile persistence and
/// navigation details owned by the application shell (AUT-05, NAV-03).
library;

import 'package:flutter/widgets.dart';

/// Provides the action that opens the current owner's profile editor.
class ProfileScope extends InheritedWidget {
  const ProfileScope({required this.onOpen, required super.child, super.key});

  final VoidCallback onOpen;

  static ProfileScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProfileScope>();

  @override
  bool updateShouldNotify(ProfileScope oldWidget) => onOpen != oldWidget.onOpen;
}
