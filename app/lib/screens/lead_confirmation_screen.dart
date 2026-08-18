import 'package:flutter/material.dart';

import '../models/lead_draft.dart';
import '../theme/foloo_theme.dart';

class LeadConfirmationScreen extends StatelessWidget {
  const LeadConfirmationScreen({
    required this.lead,
    required this.onCaptureAnother,
    super.key,
  });

  final LeadDraft lead;
  final VoidCallback onCaptureAnother;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: FolooColors.pine,
                        size: 54,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'REGISTRO COMPLETADO',
                        style: TextStyle(
                          color: FolooColors.pine,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        lead.name,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lead.company,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 20),
                      const _DemoFolio(),
                      const SizedBox(height: 22),
                      _SummaryRow(label: 'Tipo', value: lead.type.label),
                      _SummaryRow(label: 'Interés', value: lead.interest.label),
                      _SummaryRow(
                        label: 'Siguiente paso',
                        value: lead.nextStep.label,
                      ),
                      if (lead.demoAudioSeconds > 0)
                        _SummaryRow(
                          label: 'Audio',
                          value: '${lead.demoAudioSeconds} s · demo',
                        ),
                      const SizedBox(height: 22),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: FolooColors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: FolooColors.amber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Text(
                          'Sesión temporal: no se guardó, sincronizó ni envió información.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 22),
                      ElevatedButton.icon(
                        key: const Key('captureAnotherButton'),
                        onPressed: onCaptureAnother,
                        icon: const Icon(Icons.add),
                        label: const Text('CAPTURAR OTRO LEAD'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoFolio extends StatelessWidget {
  const _DemoFolio();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: FolooColors.cobalt.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'FOLIO DEMO · SIN GENERACIÓN REAL',
        style: TextStyle(
          color: FolooColors.cobalt,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FolooColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(fontSize: 10, letterSpacing: 0.7),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
