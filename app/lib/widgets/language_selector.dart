import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/foloo_theme.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({this.compact = true, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final language = AppLanguageScope.maybeOf(context);
    final locale = language?.locale ?? Localizations.localeOf(context);
    final palette = FolooPalette.of(context);
    return Semantics(
      label: context.l10n.language,
      child: Container(
        height: compact ? 36 : 44,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: palette.paper,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LanguageOption(
              key: const Key('languageEs'),
              label: context.l10n.languageSpanish,
              selected: locale.languageCode == 'es',
              onTap: () => language?.onLocaleChanged(const Locale('es')),
            ),
            _LanguageOption(
              key: const Key('languageEn'),
              label: context.l10n.languageEnglish,
              selected: locale.languageCode == 'en',
              onTap: () => language?.onLocaleChanged(const Locale('en')),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? FolooPalette.of(context).card : Colors.transparent,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 43, minHeight: 30),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
