import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_destination.dart';
import '../models/app_event.dart';
import '../models/app_plan.dart';
import '../models/pro_demo_data.dart';
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
    this.plan = AppPlan.basic,
    this.contentFiles = const [],
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voice = widget.voiceNoteService ?? DeviceVoiceNoteService();
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
          const SnackBar(
            content: Text('No se pudo reproducir esta nota local.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyAudioPath = null);
    }
  }

  List<SessionLead> get _visibleRecords {
    final query = _search.text.trim().toLowerCase();
    return widget.records.where((record) {
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

  Future<void> _showExportDialog() async {
    String format = 'XLS';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Exportar registros'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.records.length} leads de Expo Alimentaria México, con notas y datos de contacto.',
              ),
              const SizedBox(height: 18),
              ListTile(
                key: const Key('exportXlsOption'),
                onTap: () => setDialogState(() => format = 'XLS'),
                title: const Text('XLS'),
                subtitle: const Text('Hoja de Excel, listo para abrir'),
                trailing: Icon(
                  format == 'XLS'
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
              ),
              ListTile(
                key: const Key('exportCsvOption'),
                onTap: () => setDialogState(() => format = 'CSV'),
                title: const Text('CSV'),
                subtitle: const Text('Texto plano, para otro sistema'),
                trailing: Icon(
                  format == 'CSV'
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Exportación $format es solo una vista demo.',
                    ),
                  ),
                );
              },
              child: const Text('Exportar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    final pending = widget.records
        .where((record) => record.uploadState == SessionUploadState.pending)
        .length;
    final records = _visibleRecords;
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
            title: 'Registros',
            subtitle: '${widget.records.length} LEADS · $pending POR SUBIR',
            badge: 'Expo Alimentaria',
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
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Buscar por nombre o empresa',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Todos',
                        selected: _filter == null,
                        onTap: () => setState(() => _filter = null),
                      ),
                      _FilterChip(
                        label: 'Clientes',
                        selected: _filter == LeadType.customer,
                        onTap: () =>
                            setState(() => _filter = LeadType.customer),
                      ),
                      _FilterChip(
                        label: 'Partners',
                        selected: _filter == LeadType.partner,
                        onTap: () => setState(() => _filter = LeadType.partner),
                      ),
                      _FilterChip(
                        label: 'Proveedores',
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
                  Text(
                    '$pending registros esperan señal',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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
                      label: const Text('Exportar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('syncButton'),
                      // TODO(BACKEND): Implement real lead synchronization.
                      onPressed: () => ScaffoldMessenger.of(context)
                          .showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Sincronización demo: no se enviaron datos.',
                              ),
                            ),
                          ),
                      icon: const Icon(Icons.sync, size: 18),
                      label: const Text('Sincronizar'),
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
          const Text(
            'Aún no hay registros',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Las conexiones guardadas aparecerán aquí.',
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
    final pending = record.uploadState == SessionUploadState.pending;
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(FolooRadii.md),
      child: InkWell(
        key: Key('record-${record.folio}'),
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
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    record.lead.fullName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  record.folio,
                                  style: TextStyle(
                                    color: palette.inkMuted,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${record.lead.company}  ·  ${record.lead.type.label}',
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
                          key: Key('recordAudio-${record.folio}'),
                          tooltip: audioPlaying
                              ? 'Pausar nota de voz'
                              : 'Reproducir nota de voz',
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
                  label: lead.type.label,
                  color: palette.ink,
                  tint: palette.paper,
                ),
                _DetailPill(
                  label: 'Interés ${lead.interest.label.toLowerCase()}',
                  color: interestColor,
                  tint: interestColor.withValues(alpha: .13),
                ),
                _DetailPill(
                  label: record.uploadState.label,
                  color: record.uploadState == SessionUploadState.pending
                      ? palette.ink
                      : palette.success,
                  tint: record.uploadState == SessionUploadState.pending
                      ? FolooColors.uploadPendingTint
                      : palette.successTint,
                  icon: record.uploadState == SessionUploadState.pending
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
              child: Center(
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
                        'Sin foto de la tarjeta',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.inkSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Contacto',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            _ReadOnlyValue(
              label: 'Correo',
              value: lead.email.isEmpty ? '—' : lead.email,
            ),
            _ReadOnlyValue(
              label: 'Teléfono',
              value: lead.phone.isEmpty ? '—' : lead.phone,
            ),
            _ReadOnlyValue(
              label: 'Puesto',
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
                          const Text(
                            'Nota de voz',
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
              const Text(
                'Nota escrita',
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
              const Text(
                'Transcripción',
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
                          ? 'Procesando · demo'
                          : 'No disponible · no hay nota de voz'),
                ),
              ),
              if (lead.contentNames.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text(
                  'Contenido enviado · demo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                ...lead.contentNames.map(
                  (name) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.picture_as_pdf_outlined),
                    title: Text(name),
                    subtitle: const Text('Adjunto congelado al guardar'),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const Text(
                'Estado de correo · demo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              _ReadOnlyValue(
                label: 'Correo al lead',
                value: lead.email.isEmpty ? 'En cola' : 'Enviado · demo',
              ),
              const _ReadOnlyValue(
                label: 'Copia Admin',
                value: 'Enviado · demo',
              ),
              // TODO(BACKEND): Replace demo email/transcription state with real backend state.
            ],
            const SizedBox(height: 22),
            const Text(
              'Registro',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            _ReadOnlyValue(label: 'Folio', value: record.folio),
            _ReadOnlyValue(label: 'Origen', value: lead.originLabel),
            const _ReadOnlyValue(
              label: 'Capturó',
              value: DemoEventData.capturePerson,
            ),
          ],
        ),
      ),
    );
  }

  static String _duration(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
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
  });
  final String label;
  final Color color;
  final Color tint;
  final IconData? icon;
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
