/// Searchable session records and read-only connection detail.
///
/// Provides local demo filtering, export choices, sync affordances and voice
/// playback while keeping Basic and Pro detail fields capability-aware.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_destination.dart';
import '../models/app_event.dart';
import '../models/app_plan.dart';
import '../models/pro_demo_data.dart';
import '../models/lead_draft.dart';
import '../models/session_lead.dart';
import '../services/voice_note_service.dart';
import '../theme/foloo_theme.dart';
import '../l10n/l10n.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_screen_header.dart';

const _allEventsFilterId = '__all_events__';

String _leadTypeLabel(BuildContext context, LeadType type) => switch (type) {
  LeadType.supplier => context.l10n.supplier,
  LeadType.partner => context.l10n.partner,
  LeadType.customer => context.l10n.client,
};

String _uploadStateLabel(BuildContext context, SessionUploadState state) =>
    switch (state) {
      SessionUploadState.local => context.l10n.pendingUpload,
      SessionUploadState.pending => context.l10n.pendingUpload,
      SessionUploadState.inSheet => context.l10n.inSheet,
    };

/// Lists leads loaded from durable local persistence (REG-01–REG-08).
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({
    required this.records,
    required this.darkMode,
    required this.onDestinationSelected,
    required this.onAppearanceChanged,
    required this.onLogout,
    this.plan = AppPlan.basic,
    this.contentFiles = const [],
    this.events = const [],
    this.profile = DemoBasicData.profile,
    this.voiceNoteService,
    super.key,
  });

  final List<SessionLead> records;
  final bool darkMode;
  final ValueChanged<AppDestination> onDestinationSelected;
  final ValueChanged<bool> onAppearanceChanged;
  final VoidCallback onLogout;
  final DemoProfile profile;
  final VoiceNoteService? voiceNoteService;
  final AppPlan plan;
  final List<ContentFile> contentFiles;
  final List<AppEvent> events;

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen>
    with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _search = TextEditingController();
  late final VoiceNoteService _voice;
  late final StreamSubscription<void> _completed;
  LeadType? _filter;
  String? _activeAudioPath;
  String? _busyAudioPath;
  bool _audioPlaying = false;
  String _eventId = _allEventsFilterId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voice = widget.voiceNoteService ?? DeviceVoiceNoteService();
    _eventId = _initialEventId();
    _completed = _voice.playbackCompleted.listen((_) {
      if (mounted) {
        setState(() {
          _activeAudioPath = null;
          _audioPlaying = false;
        });
      }
    });
    _search.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant RecordsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_eventId != _allEventsFilterId &&
        !widget.events.any((event) => event.id == _eventId)) {
      _eventId = _initialEventId();
    }
  }

  String _initialEventId() {
    if (widget.events.isEmpty) return _allEventsFilterId;
    return widget.events
        .firstWhere((event) => event.active, orElse: () => widget.events.first)
        .id;
  }

  AppEvent? get _selectedEvent {
    if (_eventId == _allEventsFilterId) return null;
    for (final event in widget.events) {
      if (event.id == _eventId) return event;
    }
    return null;
  }

  List<SessionLead> get _eventRecords {
    final event = _selectedEvent;
    if (event == null) return widget.records;
    return widget.records
        .where(
          (record) =>
              record.lead.eventLocalId == event.id ||
              (record.lead.eventLocalId == null &&
                  record.lead.eventName == event.name),
        )
        .toList();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused) &&
        _audioPlaying) {
      unawaited(_pauseAudio());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    _completed.cancel();
    unawaited(_disposeAudio());
    super.dispose();
  }

  Future<void> _disposeAudio() async {
    try {
      await _voice.stopPlayback();
    } catch (_) {}
    try {
      await _voice.dispose();
    } catch (_) {}
  }

  Future<void> _pauseAudio() async {
    try {
      await _voice.pausePlayback();
    } finally {
      if (mounted) setState(() => _audioPlaying = false);
    }
  }

  Future<void> _stopAudio() async {
    try {
      await _voice.stopPlayback();
    } finally {
      if (mounted) {
        setState(() {
          _activeAudioPath = null;
          _audioPlaying = false;
        });
      }
    }
  }

  /// Ensures only one record audio file is active and keeps lifecycle state
  /// synchronized with the shared device player.
  Future<void> _toggleAudio(SessionLead record) async {
    final path = record.lead.audioLocalPath;
    if (path == null || _busyAudioPath != null) {
      return;
    }
    setState(() => _busyAudioPath = path);
    try {
      if (_activeAudioPath == path) {
        if (_audioPlaying) {
          await _voice.pausePlayback();
          if (mounted) {
            setState(() => _audioPlaying = false);
          }
        } else {
          await _voice.resumePlayback();
          if (mounted) {
            setState(() => _audioPlaying = true);
          }
        }
      } else {
        await _voice.stopPlayback();
        await _voice.play(path);
        if (mounted) {
          setState(() {
            _activeAudioPath = path;
            _audioPlaying = true;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.audioPlaybackError)),
        );
      }
    } finally {
      if (mounted) setState(() => _busyAudioPath = null);
    }
  }

  /// Applies local event, query and type filters without mutating source data.
  List<SessionLead> get _visibleRecords {
    final query = _search.text.trim().toLowerCase();
    return _eventRecords.where((record) {
      final typeMatches = _filter == null || record.lead.type == _filter;
      final queryMatches =
          query.isEmpty ||
          record.lead.fullName.toLowerCase().contains(query) ||
          record.lead.company.toLowerCase().contains(query);
      return typeMatches && queryMatches;
    }).toList();
  }

  Future<void> _openDetail(SessionLead record) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConnectionDetailScreen(
          record: record,
          audioPlaying:
              _activeAudioPath == record.lead.audioLocalPath && _audioPlaying,
          onToggleAudio: () => _toggleAudio(record),
          plan: widget.plan,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  /// Presents the specified XLS/CSV choice without performing real file export.
  ///
  /// DEMO: REG-09–REG-12 still require a production exporter and share sheet.
  Future<void> _showExportDialog() async {
    String format = 'XLS';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.exportRecords,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    context.l10n.exportLeadSummary(
                      context.l10n.leadCount(_eventRecords.length),
                      _selectedEvent?.name ?? DemoEventData.eventName,
                    ),
                    style: TextStyle(
                      color: FolooPalette.of(context).inkSecondary,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ExportFormatOption(
                    key: const Key('exportXlsOption'),
                    icon: Icons.grid_on_outlined,
                    title: 'XLS',
                    subtitle: context.l10n.xlsHelp,
                    selected: format == 'XLS',
                    onTap: () => setDialogState(() => format = 'XLS'),
                  ),
                  const SizedBox(height: 8),
                  _ExportFormatOption(
                    key: const Key('exportCsvOption'),
                    icon: Icons.description_outlined,
                    title: 'CSV',
                    subtitle: context.l10n.csvHelp,
                    selected: format == 'CSV',
                    onTap: () => setDialogState(() => format = 'CSV'),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: FilledButton.styleFrom(
                            backgroundColor: FolooPalette.of(context).paper,
                            foregroundColor: FolooPalette.of(context).ink,
                          ),
                          child: Text(context.l10n.cancel),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          key: const Key('confirmExportButton'),
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.l10n.exportDemoMessage(format),
                                ),
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: FolooPalette.of(context).ink,
                            foregroundColor: FolooPalette.of(context).card,
                          ),
                          icon: const Icon(Icons.download_outlined, size: 17),
                          label: Text(context.l10n.export),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    final records = _visibleRecords;
    final pending = records
        .where((record) => record.uploadState != SessionUploadState.inSheet)
        .length;
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: AppDrawer(
        plan: widget.plan,
        contentCount: widget.contentFiles.length,
        profile: widget.profile,
        activeDestination: AppDestination.records,
        recordsCount: widget.records.length,
        darkMode: widget.darkMode,
        onDestinationSelected: (destination) {
          unawaited(_stopAudio());
          widget.onDestinationSelected(destination);
        },
        onAppearanceChanged: widget.onAppearanceChanged,
        onLogout: widget.onLogout,
      ),
      body: Column(
        children: [
          AppScreenHeader(
            title: context.l10n.recordsTitle,
            subtitle:
                '${context.l10n.leadCount(records.length)} · ${context.l10n.pendingCount(pending)}',
            badgeWidget: widget.events.isEmpty
                ? null
                : _RecordsEventSelector(
                    events: widget.events,
                    selectedEventId: _eventId,
                    onChanged: (value) {
                      if (value == null) return;
                      unawaited(_stopAudio());
                      setState(() => _eventId = value);
                    },
                  ),
            onLogoPressed: () =>
                widget.onDestinationSelected(AppDestination.home),
            onMenuPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          Container(
            color: palette.card,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Column(
              children: [
                TextField(
                  key: const Key('recordsSearchField'),
                  controller: _search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: context.l10n.searchRecords,
                    border: FolooBorders.borderlessField,
                    enabledBorder: FolooBorders.borderlessField,
                    focusedBorder: FolooBorders.borderlessField,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: context.l10n.all,
                        selected: _filter == null,
                        onTap: () => setState(() => _filter = null),
                      ),
                      _FilterChip(
                        label: context.l10n.clients,
                        selected: _filter == LeadType.customer,
                        onTap: () =>
                            setState(() => _filter = LeadType.customer),
                      ),
                      _FilterChip(
                        label: context.l10n.partners,
                        selected: _filter == LeadType.partner,
                        onTap: () => setState(() => _filter = LeadType.partner),
                      ),
                      _FilterChip(
                        label: context.l10n.suppliers,
                        selected: _filter == LeadType.supplier,
                        onTap: () =>
                            setState(() => _filter = LeadType.supplier),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.line),
          Expanded(
            child: records.isEmpty
                ? const _EmptyRecords()
                : ListView.separated(
                    key: const Key('recordsList'),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    itemCount: records.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final record = records[index];
                      return _RecordRow(
                        record: record,
                        audioPlaying:
                            _activeAudioPath == record.lead.audioLocalPath &&
                            _audioPlaying,
                        audioBusy: _busyAudioPath == record.lead.audioLocalPath,
                        onToggleAudio: () => _toggleAudio(record),
                        onOpen: () => _openDetail(record),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: palette.card,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sync, size: 14, color: palette.ink),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      context.l10n.waitingForSignal(pending),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('exportButton'),
                      onPressed: _showExportDialog,
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: Text(context.l10n.export),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('syncButton'),
                      // TODO(PRODUCTION): Implement SYN-* lead synchronization.
                      onPressed: () => ScaffoldMessenger.of(context)
                          .showSnackBar(
                            SnackBar(
                              content: Text(context.l10n.syncDemoMessage),
                            ),
                          ),
                      icon: const Icon(Icons.sync, size: 18),
                      label: Text(context.l10n.sync),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordsEventSelector extends StatelessWidget {
  const _RecordsEventSelector({
    required this.events,
    required this.selectedEventId,
    required this.onChanged,
  });

  final List<AppEvent> events;
  final String selectedEventId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    return Container(
      height: 44,
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.only(left: 13, right: 7),
      decoration: BoxDecoration(
        color: palette.paper,
        borderRadius: BorderRadius.circular(99),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: const Key('recordsEventFilter'),
          value: selectedEventId,
          isExpanded: true,
          borderRadius: BorderRadius.circular(FolooRadii.md),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 19),
          style: TextStyle(
            color: palette.ink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          items:
              events
                  .map<DropdownMenuItem<String>>(
                    (event) => DropdownMenuItem<String>(
                      value: event.id,
                      child: Row(
                        children: [
                          if (event.active) ...[
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                color: FolooColors.lime,
                                shape: BoxShape.circle,
                              ),
                              child: SizedBox.square(dimension: 7),
                            ),
                            const SizedBox(width: 7),
                          ],
                          Expanded(
                            child: Text(
                              event.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList()
                ..insert(
                  0,
                  DropdownMenuItem<String>(
                    value: _allEventsFilterId,
                    child: Text(context.l10n.allEvents),
                  ),
                ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ExportFormatOption extends StatelessWidget {
  const _ExportFormatOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    return Material(
      color: selected ? FolooSelection.surface(context) : palette.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FolooRadii.md),
        side: BorderSide(color: selected ? palette.ink : Colors.transparent),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FolooRadii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(icon, size: 19),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: palette.inkSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected ? palette.ink : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? palette.ink : palette.inkMuted,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: FolooColors.lime)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: FolooPalette.of(context).ink,
      labelStyle: TextStyle(
        color: selected
            ? FolooPalette.of(context).card
            : FolooPalette.of(context).inkSecondary,
        fontSize: 11,
      ),
    ),
  );
}

class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline, size: 44),
          const SizedBox(height: 14),
          Text(
            context.l10n.emptyRecords,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.emptyRecordsHelp,
            textAlign: TextAlign.center,
            style: TextStyle(color: FolooPalette.of(context).inkSecondary),
          ),
        ],
      ),
    ),
  );
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.record,
    required this.audioPlaying,
    required this.audioBusy,
    required this.onToggleAudio,
    required this.onOpen,
  });
  final SessionLead record;
  final bool audioPlaying;
  final bool audioBusy;
  final VoidCallback onToggleAudio;
  final VoidCallback onOpen;

  Color _interest(BuildContext context) => switch (record.lead.interest) {
    InterestLevel.low => FolooColors.interestLow,
    InterestLevel.medium => FolooColors.interestMedium,
    InterestLevel.high => FolooColors.interestHigh,
  };

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    final pending = record.uploadState != SessionUploadState.inSheet;
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(FolooRadii.md),
      child: InkWell(
        key: Key('record-${record.uiKey}'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(FolooRadii.md),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: _interest(context),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(FolooRadii.md),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.lead.fullName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${record.lead.company}  ·  ${_leadTypeLabel(context, record.lead.type)}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.inkSecondary,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (record.lead.hasVoiceNote)
                        IconButton(
                          key: Key('recordAudio-${record.uiKey}'),
                          tooltip: audioPlaying
                              ? context.l10n.pauseVoiceNote
                              : context.l10n.playVoiceNote,
                          onPressed: audioBusy ? null : onToggleAudio,
                          icon: Icon(
                            audioPlaying ? Icons.pause : Icons.play_arrow,
                            size: 18,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: palette.paper,
                            minimumSize: const Size(44, 44),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: pending
                              ? FolooColors.uploadPendingTint
                              : palette.successTint,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          pending ? Icons.sync : Icons.check,
                          size: 15,
                          color: pending ? palette.ink : palette.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only detail for one captured connection (REG-07).
///
/// Voice playback is shared; transcription and delivery status remain Pro-only.
class ConnectionDetailScreen extends StatelessWidget {
  const ConnectionDetailScreen({
    required this.record,
    required this.audioPlaying,
    required this.onToggleAudio,
    required this.plan,
    super.key,
  });
  final SessionLead record;
  final bool audioPlaying;
  final VoidCallback onToggleAudio;
  final AppPlan plan;

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    final lead = record.lead;
    final interestColor = switch (lead.interest) {
      InterestLevel.low => FolooColors.interestLow,
      InterestLevel.medium => FolooColors.interestMedium,
      InterestLevel.high => FolooColors.interestHigh,
    };
    final interestTint = Theme.of(context).brightness == Brightness.dark
        ? interestColor.withValues(alpha: .24)
        : interestColor.withValues(alpha: .20);
    final pendingTint = Theme.of(context).brightness == Brightness.dark
        ? palette.lineStrong
        : FolooColors.uploadPendingTint;
    return Scaffold(
      backgroundColor: palette.card,
      appBar: AppBar(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        leading: IconButton.filled(
          key: const Key('detailBackButton'),
          onPressed: () => Navigator.pop(context),
          style: IconButton.styleFrom(
            backgroundColor: FolooColors.lime,
            foregroundColor: FolooColors.ink,
          ),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lead.fullName,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            Text(
              lead.company,
              style: TextStyle(color: palette.inkSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DetailPill(
                  label: _leadTypeLabel(context, lead.type),
                  color: palette.ink,
                  tint: palette.paper,
                ),
                _DetailPill(
                  key: const Key('detailInterestPill'),
                  label: context.l10n.interest(
                    switch (lead.interest) {
                      InterestLevel.low => context.l10n.interestLow,
                      InterestLevel.medium => context.l10n.interestMedium,
                      InterestLevel.high => context.l10n.interestHigh,
                    }.toLowerCase(),
                  ),
                  color: palette.ink,
                  tint: interestTint,
                  accentColor: interestColor,
                ),
                _DetailPill(
                  key: const Key('detailUploadStatePill'),
                  label: _uploadStateLabel(context, record.uploadState),
                  color: record.uploadState != SessionUploadState.inSheet
                      ? palette.ink
                      : palette.success,
                  tint: record.uploadState != SessionUploadState.inSheet
                      ? pendingTint
                      : palette.successTint,
                  icon: record.uploadState != SessionUploadState.inSheet
                      ? Icons.sync
                      : Icons.check,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: palette.paper,
                borderRadius: BorderRadius.circular(FolooRadii.md),
              ),
              child: lead.cardImageLocalPath == null
                  ? Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported_outlined,
                            color: palette.inkSecondary,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              context.l10n.noCardPhotoDetail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: palette.inkSecondary),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Semantics(
                      button: true,
                      label: context.l10n.preview,
                      child: InkWell(
                        key: const Key('detailCardImageButton'),
                        borderRadius: BorderRadius.circular(FolooRadii.md),
                        onTap: () =>
                            _showCardImage(context, lead.cardImageLocalPath!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(FolooRadii.md),
                          child: Image.file(
                            File(lead.cardImageLocalPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Center(
                              child: Text(
                                context.l10n.noCardPhotoDetail,
                                style: TextStyle(color: palette.inkSecondary),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 22),
            Text(
              context.l10n.contact,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            _ReadOnlyValue(
              label: context.l10n.contactEmail,
              value: lead.email.isEmpty ? '—' : lead.email,
            ),
            _ReadOnlyValue(
              label: context.l10n.contactPhone,
              value: lead.phone.isEmpty ? '—' : lead.phone,
            ),
            _ReadOnlyValue(
              label: context.l10n.contactRole,
              value: lead.role.isEmpty ? '—' : lead.role,
            ),
            if (lead.hasVoiceNote) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.paper,
                  borderRadius: BorderRadius.circular(FolooRadii.md),
                ),
                child: Row(
                  children: [
                    IconButton.filled(
                      key: const Key('detailAudioButton'),
                      onPressed: onToggleAudio,
                      style: IconButton.styleFrom(
                        backgroundColor: FolooColors.lime,
                        foregroundColor: FolooColors.ink,
                      ),
                      icon: Icon(audioPlaying ? Icons.pause : Icons.play_arrow),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.voiceNote,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            _duration(lead.audioSeconds),
                            style: TextStyle(color: palette.inkSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.graphic_eq),
                  ],
                ),
              ),
            ],
            if (lead.note.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                context.l10n.writtenNote,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.paper,
                  borderRadius: BorderRadius.circular(FolooRadii.md),
                ),
                child: Text(
                  lead.note,
                  style: const TextStyle(fontSize: 15, height: 1.45),
                ),
              ),
            ],
            if (plan.isPro) ...[
              const SizedBox(height: 20),
              Text(
                context.l10n.transcription,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Container(
                key: const Key('detailTranscription'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.paper,
                  borderRadius: BorderRadius.circular(FolooRadii.md),
                ),
                child: Text(
                  lead.transcription ??
                      (lead.hasVoiceNote
                          ? context.l10n.processingDemo
                          : context.l10n.voiceUnavailable),
                ),
              ),
              if (lead.contentNames.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  context.l10n.sentContentDemo,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                ...lead.contentNames.map(
                  (name) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.picture_as_pdf_outlined),
                    title: Text(name),
                    subtitle: Text(context.l10n.frozenAttachment),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                context.l10n.emailStatusDemo,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              _ReadOnlyValue(
                label: context.l10n.leadEmail,
                value: lead.email.isEmpty
                    ? context.l10n.queued
                    : context.l10n.sentDemo,
              ),
              _ReadOnlyValue(
                label: context.l10n.adminCopy,
                value: context.l10n.sentDemo,
              ),
              // TODO(PRODUCTION): Replace Pro demo states with backend truth.
            ],
            const SizedBox(height: 22),
            Text(
              context.l10n.recordDetails,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            _ReadOnlyValue(
              label: context.l10n.dateAndTime,
              value: _capturedAt(context, record.capturedAt),
            ),
            _ReadOnlyValue(
              label: context.l10n.origin,
              value: lead.originKind == LeadOriginKind.event
                  ? (lead.eventName ?? context.l10n.event)
                  : context.l10n.directLead,
            ),
            _ReadOnlyValue(
              label: context.l10n.capturedBy,
              value: DemoEventData.capturePerson,
            ),
          ],
        ),
      ),
    );
  }

  static String _duration(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  static String _capturedAt(BuildContext context, DateTime value) => DateFormat(
    'd MMM y · HH:mm',
    Localizations.localeOf(context).toLanguageTag(),
  ).format(value.toLocal());

  static Future<void> _showCardImage(BuildContext context, String imagePath) =>
      showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .82),
        builder: (dialogContext) => Dialog(
          key: const Key('detailCardImageDialog'),
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: double.infinity,
            height: MediaQuery.sizeOf(dialogContext).height * .76,
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Center(
                  child: Text(
                    dialogContext.l10n.noCardPhotoDetail,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _ReadOnlyValue extends StatelessWidget {
  const _ReadOnlyValue({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: FolooPalette.of(context).inkSecondary,
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 3),
        SelectableText(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({
    required this.label,
    required this.color,
    required this.tint,
    this.icon,
    this.accentColor,
    super.key,
  });
  final String label;
  final Color color;
  final Color tint;
  final IconData? icon;
  final Color? accentColor;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (accentColor != null) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: .18)),
            ),
            child: const SizedBox.square(dimension: 8),
          ),
          const SizedBox(width: 5),
        ],
        if (icon != null) ...[
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
        ],
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
