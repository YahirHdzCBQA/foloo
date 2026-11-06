/// Presents the server-confirmed FREE 5/5 milestone without claiming that a
/// promotional email was delivered or exposing an unavailable checkout.
/// The backend event, not this dialog, owns notification scheduling (MON-22).
library;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/foloo_theme.dart';

/// Acknowledges the fifth historical Lead while preserving access to all data.
class TrialMilestoneDialog extends StatelessWidget {
  const TrialMilestoneDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    return AlertDialog(
      key: const Key('trialMilestoneDialog'),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Text(
            context.l10n.trialMilestoneTitle,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
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
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.trialMilestoneHeading,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(context.l10n.trialMilestoneSaved),
          const SizedBox(height: 8),
          Text(
            context.l10n.trialMilestoneOffline,
            style: TextStyle(color: palette.inkSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: palette.paper,
              borderRadius: BorderRadius.circular(FolooRadii.sm),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.mail_outline),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(context.l10n.trialMilestoneEmailDisabled),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
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
      ],
    );
  }
}
