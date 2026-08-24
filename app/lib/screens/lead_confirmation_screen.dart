import 'dart:async';

import 'package:flutter/material.dart';

import '../models/session_lead.dart';
import '../theme/foloo_theme.dart';

class LeadConfirmationScreen extends StatefulWidget {
  const LeadConfirmationScreen({
    required this.record,
    required this.onCaptureAnother,
    super.key,
  });

  final SessionLead record;
  final VoidCallback onCaptureAnother;

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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.paper,
                  borderRadius: BorderRadius.circular(FolooRadii.lg),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: palette.successTint,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        size: 19,
                        color: palette.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'En la hoja de cálculo del evento',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      _time(record.capturedAt),
                      style: TextStyle(
                        color: palette.inkSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
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
}
