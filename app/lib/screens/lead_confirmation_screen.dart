/// Acknowledgement shown after a lead is accepted by the local demo store.
///
/// Basic and Pro render capability-aware status fixtures while the production
/// acknowledgement contract remains subject to D-06.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/session_lead.dart';
import '../models/app_plan.dart';
import '../models/pro_demo_data.dart';
import '../theme/foloo_theme.dart';
import '../l10n/l10n.dart';

/// Shows the saved lead summary and returns to clean capture after 3 seconds.
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
    // DEMO: Navigation timing copied from the Basic mockup. D-06 still owns the
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
    final statuses = _statusRows(record);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final confirmationBackground = dark ? FolooColors.ink : palette.card;
    return Scaffold(
      backgroundColor: confirmationBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 36, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                key: const Key('confirmationMark'),
                width: 140,
                height: 82,
                child: Image.asset(
                  dark
                      ? 'assets/branding/foloo_mark_dark.png'
                      : 'assets/branding/foloo_mark_light.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.l10n.savedLead,
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
              // TODO(PRODUCTION): Replace demo statuses with truthful backend state.
              Container(
                key: const Key('confirmationStatusCard'),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(FolooRadii.md),
                  border: Border.all(color: palette.line),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < statuses.length; index++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 10,
                              backgroundColor: FolooColors.success,
                              child: Icon(
                                Icons.check,
                                color: FolooColors.white,
                                size: 13,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    statuses[index].$1,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    statuses[index].$2,
                                    style: TextStyle(
                                      color: palette.inkSecondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _time(record.capturedAt),
                              style: TextStyle(
                                color: palette.inkSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (index < statuses.length - 1)
                        Divider(height: 1, color: palette.line),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  key: const Key('confirmationCountdownProgress'),
                  value: _seconds / 3,
                  minHeight: 3,
                  backgroundColor: palette.line,
                  valueColor: AlwaysStoppedAnimation<Color>(palette.ink),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.l10n.returnToCaptureIn(_seconds),
                style: TextStyle(color: palette.inkSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: confirmationBackground,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: FilledButton.icon(
            key: const Key('captureAnotherButton'),
            onPressed: _captureAnother,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: Text(context.l10n.captureAnother),
            style: FilledButton.styleFrom(
              backgroundColor: palette.paper,
              foregroundColor: palette.ink,
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
      (context.l10n.eventSpreadsheet, context.l10n.demoRow(record.folio)),
    ];
    if (!widget.plan.isPro) return basic;
    final attachedNames = record.lead.contentNames;
    return [
      ...basic,
      (
        context.l10n.leadEmail,
        record.lead.email.isEmpty
            ? context.l10n.demoQueued
            : context.l10n.demoValue(record.lead.email),
      ),
      (context.l10n.adminCopy, context.l10n.demoValue(DemoProData.adminEmail)),
      (
        context.l10n.attachedContent,
        attachedNames.isEmpty
            ? context.l10n.demoNoFiles
            : context.l10n.demoValue(attachedNames.join(' · ')),
      ),
    ];
  }
}
