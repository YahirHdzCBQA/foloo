import 'package:flutter/material.dart';

import 'app_localizations.dart';
import 'app_localizations_es.dart';

extension FolooLocalizations on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      AppLocalizationsEs();
}

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
