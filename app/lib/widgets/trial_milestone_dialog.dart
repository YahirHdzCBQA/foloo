/// Presents the server-confirmed FREE 5/5 milestone without claiming that a
/// promotional email was delivered or exposing an unavailable checkout.
/// The backend event, not this dialog, owns notification scheduling (MON-22).
library;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/foloo_theme.dart';

/// Acknowledges the fifth historical Lead while preserving access to all data.
class TrialMilestoneDialog extends StatelessWidget {
  const TrialMilestoneDialog({this.accountEmail = '', super.key});

  final String accountEmail;

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    return Material(
      key: const Key('trialMilestoneDialog'),
      color: palette.card,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(FolooRadii.lg),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.trialMilestonePlan,
                style: TextStyle(
                  color: palette.inkSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: context.l10n.trialMilestoneCount,
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TextSpan(
                      text: ' ${context.l10n.trialMilestoneCapturedLabel}',
                      style: TextStyle(
                        color: palette.inkSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(
                  5,
                  (index) => Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: index == 4 ? 0 : 5),
                      decoration: BoxDecoration(
                        color: palette.ink,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.l10n.trialMilestoneHeading,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(context.l10n.trialMilestoneSaved),
              const SizedBox(height: 8),
              Text(
                context.l10n.trialMilestoneOffline,
                style: TextStyle(color: palette.inkSecondary, fontSize: 12),
              ),
              const SizedBox(height: 14),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.paper,
                  border: Border.all(color: palette.lineStrong),
                  borderRadius: BorderRadius.circular(FolooRadii.sm),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: FolooColors.lime,
                        foregroundColor: FolooColors.ink,
                        child: Icon(Icons.mail_outline),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.trialMilestoneEmailDisabled,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (accountEmail.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                accountEmail,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.inkSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                key: const Key('trialMilestoneUnderstood'),
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: FolooColors.lime,
                  foregroundColor: FolooColors.ink,
                ),
                child: Text(context.l10n.trialMilestoneUnderstood),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.trialMilestoneRecordsRemain,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.inkSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
