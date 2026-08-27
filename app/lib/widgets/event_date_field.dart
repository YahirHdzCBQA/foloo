/// Foloo-styled event date control and calendar picker.
///
/// ES: Reutiliza el mismo tratamiento visual al crear y editar eventos.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/foloo_theme.dart';

/// Opens a localized Material calendar remapped to Foloo design tokens.
Future<DateTime?> showFolooDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  final palette = FolooPalette.of(context);
  final first = firstDate ?? DateTime(2020);
  final last = lastDate ?? DateTime(DateTime.now().year + 20, 12, 31);
  return showDatePicker(
    context: context,
    initialDate: DateUtils.dateOnly(initialDate),
    firstDate: DateUtils.dateOnly(first),
    lastDate: DateUtils.dateOnly(last),
    builder: (context, child) {
      final theme = Theme.of(context);
      return Theme(
        data: theme.copyWith(
          datePickerTheme: DatePickerThemeData(
            backgroundColor: palette.card,
            surfaceTintColor: Colors.transparent,
            headerBackgroundColor: palette.ink,
            headerForegroundColor: palette.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FolooRadii.lg),
            ),
            dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.selected)
                  ? FolooColors.lime
                  : null;
            }),
            dayForegroundColor: WidgetStateProperty.resolveWith((states) {
              return states.contains(WidgetState.selected)
                  ? FolooColors.ink
                  : palette.ink;
            }),
            todayBorder: BorderSide(color: palette.ink),
            cancelButtonStyle: TextButton.styleFrom(
              foregroundColor: palette.ink,
            ),
            confirmButtonStyle: TextButton.styleFrom(
              foregroundColor: palette.ink,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        child: child!,
      );
    },
  );
}

/// Tappable, borderless date field matching the event mockups.
class EventDateField extends StatelessWidget {
  const EventDateField({
    required this.label,
    required this.date,
    required this.onTap,
    super.key,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    final value = DateFormat(
      'd MMM y',
      Localizations.localeOf(context).toLanguageTag(),
    ).format(date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 7),
        Material(
          color: palette.paper,
          borderRadius: BorderRadius.circular(FolooRadii.md),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(FolooRadii.md),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 15),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
