import 'package:flutter/material.dart';

import '../theme/foloo_theme.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.number,
    required this.title,
    required this.child,
    this.hint,
    super.key,
  });

  final String number;
  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  number,
                  style: const TextStyle(
                    color: FolooColors.cobalt,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(
                hint!,
                style: TextStyle(
                  color: FolooColors.ink.withValues(alpha: 0.66),
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
