import 'package:flutter/material.dart';

import '../models/session_lead.dart';
import '../theme/foloo_theme.dart';

class LeadConfirmationScreen extends StatelessWidget {
  const LeadConfirmationScreen({
    required this.record,
    required this.onCaptureAnother,
    super.key,
  });

  final SessionLead record;
  final VoidCallback onCaptureAnother;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final lead = record.lead;
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 54, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: const BoxDecoration(
                      color: FolooColors.lime,
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(color: FolooColors.ink, width: 2),
                      ),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: FolooColors.ink,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Lead guardado',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: 30,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${lead.name} · ${lead.company}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.62),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    key: const Key('demoFolio'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: ink.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      record.folio,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: ink.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 13),
                          child: Text(
                            'ESTADOS DE MUESTRA · SIN BACKEND',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: FolooColors.gray,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        // TODO(BACKEND): Replace demo processing status with real backend state.
                        const _DemoProcessingRow(
                          title: 'En la hoja de cálculo del evento',
                          detail: 'Demo visual · no se escribió ninguna fila',
                        ),
                        _DemoProcessingRow(
                          title: 'Correo enviado al lead',
                          detail: lead.email.isEmpty
                              ? 'Demo visual · lead sin correo'
                              : '${lead.email} · sin envío real',
                        ),
                        const _DemoProcessingRow(
                          title: 'Copia Admin',
                          detail:
                              '${DemoEventData.adminEmail} · sin envío real',
                          last: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Divider(color: ink.withValues(alpha: 0.5), thickness: 2),
                  const SizedBox(height: 14),
                  const Text(
                    'REGISTRO DISPONIBLE EN ESTA SESIÓN LOCAL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: FolooColors.gray,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: ink.withValues(alpha: 0.35))),
          ),
          child: OutlinedButton.icon(
            key: const Key('captureAnotherButton'),
            onPressed: onCaptureAnother,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Capturar otro ahora'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoProcessingRow extends StatelessWidget {
  const _DemoProcessingRow({
    required this.title,
    required this.detail,
    this.last = false,
  });

  final String title;
  final String detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: ink.withValues(alpha: 0.35))),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 15,
            backgroundColor: FolooColors.success,
            child: Icon(Icons.check, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  detail,
                  style: TextStyle(
                    color: ink.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
