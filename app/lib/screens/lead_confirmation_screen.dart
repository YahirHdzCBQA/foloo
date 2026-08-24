import 'dart:async';

import 'package:flutter/material.dart';

import '../models/session_lead.dart';
import '../models/app_plan.dart';
import '../models/pro_demo_data.dart';
import '../theme/foloo_theme.dart';

class LeadConfirmationScreen extends StatefulWidget {
  const LeadConfirmationScreen({
    required this.record,
    required this.onCaptureAnother,
    this.plan = AppPlan.basic,
    super.key,
  });

  final SessionLead record;
  final VoidCallback onCaptureAnother;
  final AppPlan plan;

  @override
  State<LeadConfirmationScreen> createState() => _LeadConfirmationScreenState();
}

class _LeadConfirmationScreenState extends State<LeadConfirmationScreen> {
  Timer? _returnTimer;
  int _seconds = 3;

  @override
  void initState() {
    super.initState();
    // Demo navigation timing copied from the Basic mockup. D-06 still owns the
    // production acknowledgement semantics.
    _returnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_seconds <= 1) {
        timer.cancel();
        widget.onCaptureAnother();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  @override
  void dispose() {
    _returnTimer?.cancel();
    super.dispose();
  }

  void _captureAnother() {
    _returnTimer?.cancel();
    widget.onCaptureAnother();
  }

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    final record = widget.record;
    return Scaffold(
      backgroundColor: palette.card,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 36, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: FolooColors.lime,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: FolooColors.ink,
                  size: 58,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Lead guardado',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontSize: 30),
              ),
              const SizedBox(height: 8),
              Text(
                '${record.lead.fullName} · ${record.lead.company}',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.inkSecondary, fontSize: 15),
              ),
              const SizedBox(height: 18),
              Container(
                key: const Key('demoFolio'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: palette.lineStrong),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  record.folio,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .5,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // TODO(BACKEND): Replace demo processing status with real backend state.
              ..._statusRows(record).map(
                (status) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.paper,
                      borderRadius: BorderRadius.circular(FolooRadii.md),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 17,
                          backgroundColor: FolooColors.lime,
                          child: Icon(
                            Icons.check,
                            color: FolooColors.ink,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                status.$1,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                status.$2,
                                style: TextStyle(
                                  color: palette.inkSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _time(record.capturedAt),
                          style: TextStyle(
                            color: palette.inkSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Regresas a captura en $_seconds s',
                style: TextStyle(color: palette.inkSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: palette.card,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: OutlinedButton.icon(
            key: const Key('captureAnotherButton'),
            onPressed: _captureAnother,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Capturar otro ahora'),
            style: OutlinedButton.styleFrom(
              shape: const StadiumBorder(),
              minimumSize: const Size.fromHeight(56),
            ),
          ),
        ),
      ),
    );
  }

  static String _time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';

  List<(String, String)> _statusRows(SessionLead record) {
    final basic = <(String, String)>[
      ('En la hoja de cálculo del evento', 'Fila demo · ${record.folio}'),
    ];
    if (!widget.plan.isPro) return basic;
    final attachedNames = record.lead.contentNames;
    return [
      ...basic,
      (
        'Correo al lead',
        record.lead.email.isEmpty
            ? 'Demo · en cola'
            : 'Demo · ${record.lead.email}',
      ),
      ('Copia Admin', 'Demo · ${DemoProData.adminEmail}'),
      (
        'Contenido adjunto',
        attachedNames.isEmpty
            ? 'Demo · sin archivos'
            : 'Demo · ${attachedNames.join(' · ')}',
      ),
    ];
  }
}
