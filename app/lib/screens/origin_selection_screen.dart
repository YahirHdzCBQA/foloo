import 'package:flutter/material.dart';

import '../models/app_event.dart';
import '../models/app_plan.dart';
import '../models/pro_demo_data.dart';
import '../models/lead_draft.dart';
import '../theme/brand_theme.dart';
import '../theme/foloo_theme.dart';
import '../l10n/l10n.dart';
import '../widgets/create_event_dialog.dart';
import '../widgets/segmented_bubble.dart';

class OriginSelection {
  const OriginSelection({required this.kind, this.event, this.place});
  final LeadOriginKind kind;
  final AppEvent? event;
  final String? place;
}

class OriginSelectionScreen extends StatefulWidget {
  const OriginSelectionScreen({
    required this.events,
    required this.onContinue,
    required this.onCreateEvent,
    required this.plan,
    required this.contentFiles,
    super.key,
  });

  final List<AppEvent> events;
  final ValueChanged<OriginSelection> onContinue;
  final ValueChanged<AppEvent> onCreateEvent;
  final AppPlan plan;
  final List<ContentFile> contentFiles;

  @override
  State<OriginSelectionScreen> createState() => _OriginSelectionScreenState();
}

class _OriginSelectionScreenState extends State<OriginSelectionScreen> {
  LeadOriginKind _kind = LeadOriginKind.event;
  AppEvent? _event;
  final _place = TextEditingController();

  @override
  void initState() {
    super.initState();
    final active = widget.events.where((event) => event.active);
    _event = active.isNotEmpty
        ? active.first
        : (widget.events.isEmpty ? null : widget.events.first);
  }

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  Future<void> _createEvent() async {
    final event = await showCreateEventDialog(
      context,
      plan: widget.plan,
      contentFiles: widget.contentFiles,
    );
    if (event == null || !mounted) return;
    widget.onCreateEvent(event);
    setState(() {
      _kind = LeadOriginKind.event;
      _event = event;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    final direct = _kind == LeadOriginKind.direct;
    return Scaffold(
      backgroundColor: palette.card,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Image.asset(
                  FolooBrand.logoFor(Theme.of(context).brightness),
                  width: 56,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                context.l10n.originTitle,
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 26),
              SegmentedBubble<LeadOriginKind>(
                key: const Key('originBubble'),
                selectedHorizontalPadding: 8,
                selected: _kind,
                onSelected: (value) => setState(() => _kind = value),
                options: [
                  SegmentedBubbleOption(
                    key: Key('originEventTab'),
                    value: LeadOriginKind.event,
                    label: context.l10n.event,
                    leading: const Icon(
                      Icons.calendar_today_outlined,
                      size: 15,
                    ),
                  ),
                  SegmentedBubbleOption(
                    key: Key('originDirectTab'),
                    value: LeadOriginKind.direct,
                    label: context.l10n.directLead,
                    leading: const Icon(Icons.person_outline, size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              if (direct)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.l10n.directLeadHelp,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.inkSecondary,
                        fontSize: 17,
                        height: 1.5,
                      ),
                    ),
                    if (widget.plan.isPro) ...[
                      const SizedBox(height: 24),
                      TextField(
                        key: const Key('originPlaceField'),
                        controller: _place,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: context.l10n.place,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        context.l10n.directPlacePersistentHelp('{lugar}'),
                        style: TextStyle(
                          color: palette.inkSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 80),
                  ],
                )
              else ...[
                Column(
                  children: [
                    for (
                      var index = 0;
                      index < widget.events.length;
                      index++
                    ) ...[
                      Builder(
                        builder: (context) {
                          final event = widget.events[index];
                          final selected = event.id == _event?.id;
                          return InkWell(
                            key: Key('originEvent-${event.id}'),
                            onTap: () => setState(() => _event = event),
                            borderRadius: BorderRadius.circular(FolooRadii.md),
                            child: Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: selected
                                    ? FolooColors.lime.withValues(alpha: .34)
                                    : palette.paper,
                                borderRadius: BorderRadius.circular(
                                  FolooRadii.md,
                                ),
                                border: Border.all(
                                  color: selected
                                      ? palette.ink
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          event.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          context.l10n.leadCount(
                                            event.demoLeadCount,
                                          ),
                                          style: TextStyle(
                                            color: palette.inkSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    selected
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    color: selected
                                        ? palette.ink
                                        : palette.inkMuted,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      if (index != widget.events.length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],
                ),
                TextButton.icon(
                  key: const Key('originManageEventsButton'),
                  onPressed: _createEvent,
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.createNewEvent),
                  style: TextButton.styleFrom(foregroundColor: palette.ink),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: palette.card,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: FilledButton(
            key: const Key('originContinueButton'),
            onPressed:
                (direct &&
                        (!widget.plan.isPro ||
                            _place.text.trim().isNotEmpty)) ||
                    (!direct && _event != null)
                ? () => widget.onContinue(
                    OriginSelection(
                      kind: _kind,
                      event: direct ? null : _event,
                      place: direct ? _place.text.trim() : null,
                    ),
                  )
                : null,
            child: Text(
              direct
                  ? context.l10n.captureConnection
                  : context.l10n.startCapture,
            ),
          ),
        ),
      ),
    );
  }
}
