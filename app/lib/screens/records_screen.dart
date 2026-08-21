import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_destination.dart';
import '../models/lead_draft.dart';
import '../models/session_lead.dart';
import '../services/voice_note_service.dart';
import '../theme/foloo_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_screen_header.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({
    required this.records,
    required this.darkMode,
    required this.onDestinationSelected,
    required this.onAppearanceChanged,
    required this.onLogout,
    this.voiceNoteService,
    super.key,
  });

  final List<SessionLead> records;
  final bool darkMode;
  final ValueChanged<AppDestination> onDestinationSelected;
  final ValueChanged<bool> onAppearanceChanged;
  final VoidCallback onLogout;
  final VoiceNoteService? voiceNoteService;

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen>
    with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final VoiceNoteService _voiceNoteService;
  late final StreamSubscription<void> _playbackCompletedSubscription;
  String? _activeAudioPath;
  String? _busyAudioPath;
  bool _audioPlaying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voiceNoteService = widget.voiceNoteService ?? DeviceVoiceNoteService();
    _playbackCompletedSubscription = _voiceNoteService.playbackCompleted.listen(
      (_) {
        if (!mounted) return;
        setState(() {
          _activeAudioPath = null;
          _audioPlaying = false;
        });
      },
    );
  }

  @override
  void didUpdateWidget(covariant RecordsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final activePath = _activeAudioPath;
    if (activePath != null &&
        !widget.records.any(
          (record) => record.lead.audioLocalPath == activePath,
        )) {
      unawaited(_stopAudio());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached) &&
        _audioPlaying) {
      unawaited(_pauseAudio());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playbackCompletedSubscription.cancel();
    unawaited(_disposeAudio());
    super.dispose();
  }

  Future<void> _disposeAudio() async {
    try {
      await _voiceNoteService.stopPlayback();
    } catch (_) {
      // Best-effort teardown while the records screen is being disposed.
    }
    try {
      await _voiceNoteService.dispose();
    } catch (_) {
      // Native playback resources may already be unavailable at teardown.
    }
  }

  Future<void> _toggleAudio(SessionLead record) async {
    final path = record.lead.audioLocalPath;
    if (path == null || _busyAudioPath != null) return;
    setState(() => _busyAudioPath = path);
    try {
      if (_activeAudioPath == path) {
        if (_audioPlaying) {
          await _voiceNoteService.pausePlayback();
          if (mounted) setState(() => _audioPlaying = false);
        } else {
          await _voiceNoteService.resumePlayback();
          if (mounted) setState(() => _audioPlaying = true);
        }
      } else {
        await _voiceNoteService.stopPlayback();
        await _voiceNoteService.play(path);
        if (mounted) {
          setState(() {
            _activeAudioPath = path;
            _audioPlaying = true;
          });
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activeAudioPath = null;
        _audioPlaying = false;
      });
      _showUnavailable(
        'No se pudo reproducir esta nota de voz local. El registro sigue disponible.',
      );
    } finally {
      if (mounted) setState(() => _busyAudioPath = null);
    }
  }

  Future<void> _pauseAudio() async {
    try {
      await _voiceNoteService.pausePlayback();
      if (mounted) setState(() => _audioPlaying = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _activeAudioPath = null;
          _audioPlaying = false;
        });
      }
    }
  }

  Future<void> _stopAudio() async {
    try {
      await _voiceNoteService.stopPlayback();
    } catch (_) {
      // Navigation must continue even if native playback teardown fails.
    } finally {
      if (mounted) {
        setState(() {
          _activeAudioPath = null;
          _audioPlaying = false;
        });
      }
    }
  }

  Future<void> _selectDestination(AppDestination destination) async {
    await _stopAudio();
    if (mounted) widget.onDestinationSelected(destination);
  }

  Future<void> _logout() async {
    await _stopAudio();
    if (mounted) widget.onLogout();
  }

  void _showUnavailable(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.records
        .where((record) => record.uploadState == SessionUploadState.pending)
        .length;
    final theme = Theme.of(context);
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: AppDrawer(
        activeDestination: AppDestination.records,
        recordsCount: widget.records.length,
        darkMode: widget.darkMode,
        onDestinationSelected: (value) => unawaited(_selectDestination(value)),
        onAppearanceChanged: widget.onAppearanceChanged,
        onLogout: () => unawaited(_logout()),
      ),
      body: Column(
        children: [
          AppScreenHeader(
            title: 'Registros',
            subtitle:
                '${DemoEventData.eventCode} · ${widget.records.length} LEADS · $pending POR SUBIR',
            onMenuPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
          Expanded(
            child: widget.records.isEmpty
                ? const _EmptyRecords()
                : ListView.separated(
                    key: const Key('recordsList'),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: widget.records.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, index) => _RecordCard(
                      key: Key('record-${widget.records[index].folio}'),
                      record: widget.records[index],
                      audioPlaying:
                          _activeAudioPath ==
                              widget.records[index].lead.audioLocalPath &&
                          _audioPlaying,
                      audioBusy:
                          _busyAudioPath ==
                          widget.records[index].lead.audioLocalPath,
                      onToggleAudio: () => _toggleAudio(widget.records[index]),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.sync, size: 16),
                    const SizedBox(width: 7),
                    Text(
                      '$pending REGISTROS ESPERAN SEÑAL',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('exportCsvButton'),
                        // RF-23 remains deferred until the local data contract is approved.
                        onPressed: () => _showUnavailable(
                          'Exportar CSV todavía no está conectado en este prototipo.',
                        ),
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Exportar CSV'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        key: const Key('syncButton'),
                        // TODO(BACKEND): Implement real lead synchronization.
                        onPressed: () => _showUnavailable(
                          'Sincronización no conectada. Los registros siguen locales.',
                        ),
                        icon: const Icon(Icons.sync),
                        label: const Text('Sincronizar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords();

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: ink.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 14),
            const Text(
              'Aún no hay registros',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Los leads guardados aparecerán aquí durante esta sesión.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ink.withValues(alpha: 0.62), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.record,
    required this.audioPlaying,
    required this.audioBusy,
    required this.onToggleAudio,
    super.key,
  });

  final SessionLead record;
  final bool audioPlaying;
  final bool audioBusy;
  final VoidCallback onToggleAudio;

  Color _interestColor(InterestLevel interest) => switch (interest) {
    InterestLevel.low => FolooColors.success,
    InterestLevel.medium => FolooColors.warning,
    InterestLevel.high => FolooColors.error,
  };

  String _time(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final pending = record.uploadState == SessionUploadState.pending;
    // TODO(BACKEND): Replace demo upload state with real synchronization state.
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: ink.withValues(alpha: 0.5)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: _interestColor(record.lead.interest)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.folio,
                            style: TextStyle(
                              color: ink.withValues(alpha: 0.55),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Text(
                          _time(record.capturedAt),
                          style: TextStyle(
                            color: ink.withValues(alpha: 0.55),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      record.lead.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      record.lead.company,
                      style: TextStyle(
                        color: ink.withValues(alpha: 0.68),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _StatusPill(
                                label: record.lead.type.label.toUpperCase(),
                                outlined: true,
                              ),
                              _StatusPill(
                                label: record.uploadState.label.toUpperCase(),
                                icon: pending ? Icons.sync : Icons.check,
                                background: pending
                                    ? ink.withValues(alpha: 0.1)
                                    : FolooColors.success.withValues(
                                        alpha: 0.12,
                                      ),
                                foreground: pending ? ink : FolooColors.success,
                              ),
                              if (record.lead.hasVoiceNote)
                                _StatusPill(
                                  label:
                                      'VOZ ${_formatDuration(record.lead.audioSeconds)}',
                                  icon: Icons.graphic_eq,
                                  background: FolooColors.lime.withValues(
                                    alpha: 0.22,
                                  ),
                                  foreground: ink,
                                ),
                            ],
                          ),
                        ),
                        if (record.lead.hasVoiceNote) ...[
                          const SizedBox(width: 8),
                          Semantics(
                            button: true,
                            label: audioPlaying
                                ? 'Pausar nota de voz de ${record.lead.name}'
                                : 'Reproducir nota de voz de ${record.lead.name}',
                            child: IconButton.filledTonal(
                              key: Key('recordAudio-${record.folio}'),
                              tooltip: audioPlaying
                                  ? 'Pausar nota de voz'
                                  : 'Reproducir nota de voz',
                              onPressed: audioBusy ? null : onToggleAudio,
                              style: IconButton.styleFrom(
                                minimumSize: const Size(44, 44),
                                backgroundColor: audioPlaying
                                    ? FolooColors.lime
                                    : ink.withValues(alpha: 0.08),
                                foregroundColor: ink,
                              ),
                              icon: audioBusy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      audioPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    this.icon,
    this.background,
    this.foreground,
    this.outlined = false,
  });

  final String label;
  final IconData? icon;
  final Color? background;
  final Color? foreground;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return Container(
      constraints: const BoxConstraints(minHeight: 38),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background ?? Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: outlined ? Border.all(color: ink.withValues(alpha: 0.5)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground ?? ink),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground ?? ink.withValues(alpha: 0.72),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}
