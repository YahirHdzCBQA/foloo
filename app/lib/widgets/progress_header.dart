import 'package:flutter/material.dart';

import '../theme/foloo_theme.dart';

class ProgressHeader extends StatelessWidget {
  const ProgressHeader({required this.completed, super.key});

  final List<bool> completed;
  static const labels = ['Tarjeta', 'Datos', 'Relación', 'Nota'];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color.fromARGB(255, 58, 60, 61),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FOLOO · CAPTURA DE LEADS',
                style: TextStyle(
                  color: FolooColors.paper,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'PROTOTIPO FRONTEND · SESIÓN LOCAL',
                style: TextStyle(
                  color: FolooColors.paper.withValues(alpha: 0.62),
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(labels.length, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(
                        right: index == labels.length - 1 ? 0 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: completed[index]
                            ? FolooColors.paper
                            : FolooColors.paper.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: labels
                    .map(
                      (label) => Text(
                        label.toUpperCase(),
                        style: TextStyle(
                          color: FolooColors.paper.withValues(alpha: 0.68),
                          fontSize: 9,
                          letterSpacing: 0.7,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
