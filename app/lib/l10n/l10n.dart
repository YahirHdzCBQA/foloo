/// Localization access and shared locale state for Foloo.
///
/// Login and Drawer consume the same session locale so language changes are
/// immediate throughout the app (NAV-09 / RNF-19).
library;

import 'package:flutter/material.dart';

import 'app_localizations.dart';
import 'app_localizations_es.dart';

/// Provides concise access to generated Foloo strings from a build context.
extension FolooLocalizations on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      AppLocalizationsEs();
}

/// Exposes the single locale selection shared by the complete application.
///
/// TODO(PRODUCTION): Persist the preference after a local-storage foundation
/// is approved; the current implementation intentionally lasts one session.
class AppLanguageScope extends InheritedWidget {
  const AppLanguageScope({
    required this.locale,
    required this.onLocaleChanged,
    required super.child,
    super.key,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  static AppLanguageScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    assert(scope != null, 'AppLanguageScope is missing above this context.');
    return scope!;
  }

  static AppLanguageScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLanguageScope>();

  @override
  bool updateShouldNotify(AppLanguageScope oldWidget) =>
      locale != oldWidget.locale;
}
