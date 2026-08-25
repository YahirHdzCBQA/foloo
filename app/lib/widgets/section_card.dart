import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.number,
    required this.title,
    required this.child,
    this.hint,
    this.trailing,
    super.key,
  });

  final String number;
  final String title;
  final String? hint;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                number,
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
              ?trailing,
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 12),
            Text(
              hint!,
              style: TextStyle(
                color: ink.withValues(alpha: 0.62),
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
