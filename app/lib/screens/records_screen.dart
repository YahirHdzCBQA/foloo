/// Searchable session records, structured editing and per-event export.
///
/// Provides local filtering, export choices, sync affordances and voice
/// playback for the unified V1 product.
library;

import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_destination.dart';
import '../models/app_event.dart';
import '../models/content_file.dart';
import '../models/lead_draft.dart';
import '../models/records_filter_state.dart';
import '../models/session_lead.dart';
import '../data/local/app_database.dart';
import '../data/repositories/local_repositories.dart';
import '../models/email_delivery_error.dart';
import '../models/email_review.dart';
import '../services/voice_note_service.dart';
import '../services/camera_access_service.dart';
import '../services/contact_image_picker_service.dart';
import '../services/records_export_service.dart';
import '../theme/foloo_theme.dart';
import '../l10n/l10n.dart';
import '../widgets/app_drawer.dart';
import '../widgets/module_header.dart';
import '../widgets/swipe_action_card.dart';
import '../widgets/camera_access_dialog.dart';
import '../widgets/voice_playback_waveform.dart';
import '../widgets/voice_note_recorder_surface.dart';
import '../widgets/records_filter_sheet.dart';
import 'email_review_screen.dart';

enum _ExportDelivery { share, saveToDevice }

class _RecordedVoiceDraft {
  const _RecordedVoiceDraft(this.path, this.durationSeconds);

  final String path;
  final int durationSeconds;
}

/// Owns one uncommitted voice-note draft in the Records detail flow.
///
/// It mirrors capture's explicit record, review, discard/re-record and save
/// lifecycle without persisting audio until the user confirms it (VOZ-01–04).
class _VoiceNoteRecorderSheet extends StatefulWidget {
  const _VoiceNoteRecorderSheet({required this.service});

  final VoiceNoteService service;

  @override
  State<_VoiceNoteRecorderSheet> createState() =>
      _VoiceNoteRecorderSheetState();
}

class _VoiceNoteRecorderSheetState extends State<_VoiceNoteRecorderSheet> {
  Timer? _timer;
  StreamSubscription<void>? _playbackCompleted;
  String? _path;
  var _elapsed = Duration.zero;
  var _recording = false;
  var _playing = false;
  var _busy = false;
  var _committed = false;

  @override
  void initState() {
    super.initState();
    _playbackCompleted = widget.service.playbackCompleted.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  Future<void> _start({bool replace = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final previous = replace ? _path : null;
    try {
      await widget.service.stopPlayback();
      final next = await widget.service.startRecording();
      if (previous != null) await widget.service.deleteFile(previous);
      _timer?.cancel();
      if (!mounted) return;
      setState(() {
        _path = next;
        _elapsed = Duration.zero;
        _recording = true;
        _playing = false;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
      });
    } on VoiceNotePermissionDeniedException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.microphoneDenied)));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.recordStartError)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    if (!_recording || _busy) return;
    setState(() => _busy = true);
    try {
      final path = await widget.service.stopRecording();
      _timer?.cancel();
      if (!mounted) return;
      setState(() {
        _path = path ?? _path;
        _recording = false;
      });
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.recordStopError)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _togglePlayback() async {
    final path = _path;
    if (path == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (_playing) {
        await widget.service.pausePlayback();
      } else {
        await widget.service.play(path);
      }
      if (mounted) setState(() => _playing = !_playing);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.audioPlayError)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discard() async {
    final path = _path;
    if (path == null || _busy) return;
    setState(() => _busy = true);
    await widget.service.stopPlayback();
    await widget.service.deleteFile(path);
    if (!mounted) return;
    setState(() {
      _path = null;
      _elapsed = Duration.zero;
      _playing = false;
      _busy = false;
    });
  }

  void _save() {
    final path = _path;
    if (path == null || _recording || _busy) return;
    _committed = true;
    Navigator.pop(context, _RecordedVoiceDraft(path, _elapsed.inSeconds));
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_playbackCompleted?.cancel());
    if (_recording) unawaited(widget.service.cancelRecording());
    unawaited(widget.service.stopPlayback());
    if (!_committed && _path != null) {
      unawaited(widget.service.deleteFile(_path!));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.addVoiceNote,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 18),
          VoiceNoteRecorderSurface(
            keyPrefix: 'detailVoice',
            recordKey: const Key('detailVoiceRecordButton'),
            discardKey: const Key('detailVoiceDiscardButton'),
            rerecordKey: const Key('detailVoiceRerecordButton'),
            playKey: const Key('detailVoicePlayButton'),
            waveformKey: const Key('detailVoicePlaybackWaveform'),
            durationKey: const Key('detailVoiceRecordingDuration'),
            recording: _recording,
            hasRecording: _path != null && !_recording,
            playing: _playing,
            busy: _busy,
            elapsed: _elapsed,
            onToggleRecording: _recording ? _stop : _start,
            onDelete: _discard,
            onRerecord: () => _start(replace: true),
            onTogglePlayback: _togglePlayback,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('detailVoiceSaveButton'),
            onPressed: !_recording && _path != null && !_busy ? _save : null,
            child: Text(context.l10n.save),
          ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
        ],
      ),
    ),
  );
}

String _leadTypeLabel(BuildContext context, LeadType type) => switch (type) {
  LeadType.supplier => context.l10n.supplier,
  LeadType.partner => context.l10n.partner,
  LeadType.customer => context.l10n.client,
};

String _uploadStateLabel(BuildContext context, SessionUploadState state) =>
    switch (state) {
      SessionUploadState.local => context.l10n.pendingUpload,
      SessionUploadState.pending => context.l10n.pendingUpload,
      SessionUploadState.retryable => context.l10n.retryScheduledState,
      SessionUploadState.syncing => context.l10n.syncingState,
      SessionUploadState.synced => context.l10n.synced,
      SessionUploadState.syncedWithMediaPending => context.l10n.mediaPending,
      SessionUploadState.syncedWithMediaError => context.l10n.mediaSyncError,
      SessionUploadState.failed => context.l10n.syncFailed,
      SessionUploadState.conflict => context.l10n.revisionConflict,
    };

IconData _uploadStateIcon(SessionUploadState state) => switch (state) {
  SessionUploadState.synced => Icons.check,
  SessionUploadState.failed ||
  SessionUploadState.conflict ||
  SessionUploadState.syncedWithMediaError => Icons.warning_amber_rounded,
  SessionUploadState.retryable => Icons.schedule,
  _ => Icons.sync,
};

bool _isFailed(SessionUploadState state) =>
    state == SessionUploadState.failed ||
    state == SessionUploadState.conflict ||
    state == SessionUploadState.syncedWithMediaError;

String _voiceDuration(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

/// Lists leads loaded from durable local persistence (REG-01–REG-08).
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({
    required this.records,
    required this.darkMode,
    required this.onDestinationSelected,
    required this.onAppearanceChanged,
    required this.onLogout,
    this.contentFiles = const [],
    this.events = const [],
    this.eventNameForId,
    this.profile = DemoProfile.empty,
    this.voiceNoteService,
    this.onSync,
    this.syncing = false,
    this.onLeadUpdated,
    this.onReferenceImageAdded,
    this.onVoiceNoteAdded,
    this.onVoiceNoteDeleted,
    this.contactImagePickerService,
    this.cameraAccessCoordinator,
    this.exportService = const RecordsExportService(),
    this.fileSharer = const DeviceRecordsFileSharer(),
    this.fileSaver = const DeviceRecordsFileSaver(),
    this.deviceSaveAvailable,
    this.ownerSub,
    this.deliveryRepository,
    this.isEmailConnectionMissing,
    this.onSendQueued,
    this.onDelete,
    this.onEmailReviewRequested,
    this.onEmailReviewConfirmed,
    this.onEmailReviewUpdated,
    super.key,
  });

  final List<SessionLead> records;
  final bool darkMode;
  final ValueChanged<AppDestination> onDestinationSelected;
  final ValueChanged<bool> onAppearanceChanged;
  final VoidCallback onLogout;
  final DemoProfile profile;
  final VoiceNoteService? voiceNoteService;
  final List<ContentFile> contentFiles;
  final List<AppEvent> events;
  final Future<String?> Function(String eventId)? eventNameForId;
  final Future<void> Function()? onSync;
  final bool syncing;
  final Future<SessionLead> Function(SessionLead record, LeadDraft updated)?
  onLeadUpdated;
  final Future<SessionLead> Function(SessionLead record, String sourcePath)?
  onReferenceImageAdded;
  final Future<SessionLead> Function(
    SessionLead record,
    String sourcePath,
    int durationSeconds,
  )?
  onVoiceNoteAdded;
  final Future<SessionLead> Function(SessionLead record, LeadVoiceNote note)?
  onVoiceNoteDeleted;
  final ContactImagePickerService? contactImagePickerService;
  final CameraAccessCoordinator? cameraAccessCoordinator;
  final RecordsExportService exportService;
  final RecordsFileSharer fileSharer;
  final RecordsFileSaver fileSaver;
  final bool? deviceSaveAvailable;
  final String? ownerSub;
  final EmailDeliveryRepository? deliveryRepository;

  /// Checks the authenticated sender state before interpreting an ambiguous 404.
  final Future<bool> Function(StoredEmailSendIntent? intent)?
  isEmailConnectionMissing;
  final VoidCallback? onSendQueued;
  final Future<void> Function(SessionLead record)? onDelete;
  final Future<EmailReviewDraft?> Function(SessionLead record)?
  onEmailReviewRequested;
  final Future<EmailReviewOutcome> Function(EmailReviewDraft draft)?
  onEmailReviewConfirmed;
  final Future<void> Function(EmailReviewDraft draft, LeadDraft lead)?
  onEmailReviewUpdated;

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen>
    with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final VoiceNoteService _voice;
  late final StreamSubscription<void> _completed;
  RecordsFilterState _filters = const RecordsFilterState();
  String? _activeAudioPath;
  String? _busyAudioPath;
  bool _audioPlaying = false;
  final ValueNotifier<bool> _detailAudioPlaying = ValueNotifier(false);
  String? _openSwipeLeadId;
  List<StoredEmailFollowUp> _followUps = const [];

  bool get _canSaveExportToDevice =>
      widget.deviceSaveAvailable ?? Platform.isAndroid;
  List<StoredEmailSendIntent> _emailIntents = const [];
  StreamSubscription<List<StoredEmailFollowUp>>? _followUpsSubscription;
  StreamSubscription<List<StoredEmailSendIntent>>? _intentsSubscription;

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
          _detailAudioPlaying.value = false;
        });
      }
    });
    _watchEmailDelivery();
  }

  @override
  void didUpdateWidget(covariant RecordsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final validEvents = widget.events.map((event) => event.id).toSet();
    final retainedEvents = _filters.eventIds.intersection(validEvents);
    if (retainedEvents.length != _filters.eventIds.length) {
      _filters = _filters.copyWith(eventIds: retainedEvents);
    }
    if (oldWidget.ownerSub != widget.ownerSub ||
        oldWidget.deliveryRepository != widget.deliveryRepository) {
      _watchEmailDelivery();
    }
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
    _completed.cancel();
    unawaited(_followUpsSubscription?.cancel());
    unawaited(_intentsSubscription?.cancel());
    unawaited(_disposeAudio());
    _detailAudioPlaying.dispose();
    super.dispose();
  }

  void _watchEmailDelivery() {
    unawaited(_followUpsSubscription?.cancel());
    unawaited(_intentsSubscription?.cancel());
    final owner = widget.ownerSub;
    final repository = widget.deliveryRepository;
    if (owner == null || repository == null) return;
    _followUpsSubscription = repository.watchFollowUps(owner).listen((value) {
      if (mounted && owner == widget.ownerSub) {
        setState(() => _followUps = value);
      }
    });
    _intentsSubscription = repository.watchIntents(owner).listen((value) {
      if (mounted && owner == widget.ownerSub) {
        setState(() => _emailIntents = value);
      }
    });
  }

  StoredEmailFollowUp? _followUpForLead(String leadId) {
    final matches = _followUps.where((item) => item.leadLocalId == leadId);
    return matches.isEmpty ? null : matches.first;
  }

  StoredEmailSendIntent? _intentFor(StoredEmailFollowUp? followUp) {
    if (followUp == null) return null;
    final matches = _emailIntents.where(
      (item) => item.followUpLocalId == followUp.localId,
    );
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> _retryEmail(StoredEmailSendIntent intent) async {
    final owner = widget.ownerSub;
    if (owner == null) return;
    var missingConnection = false;
    try {
      missingConnection =
          await widget.isEmailConnectionMissing?.call(intent) ??
          (emailDeliveryErrorCode(intent.errorCode) ==
              'email_connection_required');
    } on Object {
      // The durable retry retains its original failure when status is unavailable.
    }
    if (!mounted || owner != widget.ownerSub) return;
    if (missingConnection) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.emailNoConnectedAccount)),
      );
      return;
    }
    await widget.deliveryRepository?.retry(owner: owner, intent: intent);
    widget.onSendQueued?.call();
  }

  Future<void> _resendEmail(
    StoredEmailFollowUp followUp,
    StoredEmailSendIntent intent,
  ) async {
    final owner = widget.ownerSub;
    if (owner == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.emailResendQuestion),
        content: Text(context.l10n.emailResendWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.emailResend),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.deliveryRepository?.confirm(
      owner: owner,
      followUpId: followUp.localId,
      parentIntentId: intent.localId,
    );
    widget.onSendQueued?.call();
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
      if (mounted) {
        setState(() => _audioPlaying = false);
        _detailAudioPlaying.value = false;
      }
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
          _detailAudioPlaying.value = false;
        });
      }
    }
  }

  /// Ensures only one record audio file is active and keeps lifecycle state
  /// synchronized with the shared device player.
  Future<void> _toggleAudioPath(String? path) async {
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
            _detailAudioPlaying.value = false;
          }
        } else {
          await _voice.resumePlayback();
          if (mounted) {
            setState(() => _audioPlaying = true);
            _detailAudioPlaying.value = true;
          }
        }
      } else {
        await _voice.stopPlayback();
        await _voice.play(path);
        if (mounted) {
          setState(() {
            _activeAudioPath = path;
            _audioPlaying = true;
            _detailAudioPlaying.value = true;
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

  /// Applies the complete QA-20 criteria to the owner-scoped local dataset.
  List<SessionLead> get _visibleRecords => _filters.apply(widget.records);

  Future<void> _openFilters(RecordsFilterCategory category) async {
    final result = await showRecordsFilterSheet(
      context,
      filters: _filters,
      initialCategory: category,
      records: widget.records,
      events: widget.events,
      contentFiles: widget.contentFiles,
    );
    if (result == null || !mounted) return;
    unawaited(_stopAudio());
    setState(() {
      _filters = result;
      _openSwipeLeadId = null;
    });
  }

  Future<void> _openDetail(SessionLead record) async {
    String? currentEventName;
    final eventId = record.lead.eventLocalId;
    if (record.lead.originKind == LeadOriginKind.event && eventId != null) {
      try {
        currentEventName = await widget.eventNameForId?.call(eventId);
      } catch (_) {
        // A failed lookup must not hide an otherwise durable Lead detail.
      }
      currentEventName ??= widget.events
          .where((event) => event.id == eventId)
          .firstOrNull
          ?.name;
    }
    if (!mounted) return;
    _detailAudioPlaying.value =
        _activeAudioPath == record.lead.audioLocalPath && _audioPlaying;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConnectionDetailScreen(
          record: record,
          contentFiles: widget.contentFiles,
          currentEventName: currentEventName,
          audioPlayingListenable: _detailAudioPlaying,
          onToggleAudio: (note) => _toggleAudioPath(note.localPath),
          onEdit: widget.onLeadUpdated,
          events: widget.events,
          onAddReferenceImage: widget.onReferenceImageAdded == null
              ? null
              : () => _addReferenceImage(record),
          onAddVoiceNote: widget.onVoiceNoteAdded == null
              ? null
              : () => _addVoiceNote(record),
          onDeleteVoiceNote: widget.onVoiceNoteDeleted == null
              ? null
              : (note) => widget.onVoiceNoteDeleted!(record, note),
          followUp: _followUpForLead(record.localId),
          emailIntent: _intentFor(_followUpForLead(record.localId)),
          ownerSub: widget.ownerSub,
          deliveryRepository: widget.deliveryRepository,
          onRetryEmail: _retryEmail,
          isEmailConnectionMissing: widget.isEmailConnectionMissing,
          onResendEmail: _resendEmail,
          onEmail: _openEmailReview,
          onDelete: () => _confirmDelete(record, closeDetail: true),
        ),
      ),
    );
    await _stopAudio();
    if (mounted) setState(() {});
  }

  Future<SessionLead?> _addReferenceImage(SessionLead record) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('detailReferenceImageCamera'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(context.l10n.takePhoto),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              key: const Key('detailReferenceImageGallery'),
              leading: const Icon(Icons.photo_outlined),
              title: Text(context.l10n.chooseGallery),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return null;
    final camera = widget.cameraAccessCoordinator ?? CameraAccessCoordinator();
    if (source == ImageSource.camera &&
        !await ensureCameraAccess(context, camera)) {
      return null;
    }
    try {
      final picker =
          widget.contactImagePickerService ?? DeviceContactImagePickerService();
      final image = await picker.pick(source);
      if (image == null || !mounted) return null;
      return await widget.onReferenceImageAdded!(record, image.path);
    } on Object {
      if (!mounted) return null;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.imageOpenError)));
      return null;
    }
  }

  Future<SessionLead?> _addVoiceNote(SessionLead record) async {
    if (record.effectiveVoiceNotes.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.voiceNoteLimitReached)),
      );
      return null;
    }
    await _stopAudio();
    if (!mounted) return null;
    final draft = await showModalBottomSheet<_RecordedVoiceDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _VoiceNoteRecorderSheet(service: _voice),
    );
    if (draft == null) return null;
    try {
      final refreshed = await widget.onVoiceNoteAdded!(
        record,
        draft.path,
        draft.durationSeconds,
      );
      await _voice.deleteFile(draft.path);
      return refreshed;
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.localSaveError)));
      }
      return null;
    }
  }

  Future<void> _openEmailReview(SessionLead record) async {
    final request = widget.onEmailReviewRequested;
    final confirm = widget.onEmailReviewConfirmed;
    if (request == null || confirm == null) return;
    late final EmailReviewDraft? draft;
    try {
      draft = await request(record);
    } on EmailAttachmentResolutionException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.emailAttachmentsUnavailable)),
      );
      return;
    }
    if (!mounted) return;
    if (draft == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.leadEmailRequired)));
      return;
    }
    final resolvedDraft = draft;
    setState(() => _openSwipeLeadId = null);
    var reviewRecord = record;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EmailReviewScreen(
          record: record,
          draft: resolvedDraft,
          onConfirm: confirm,
          onConnectionRequired: () =>
              widget.onDestinationSelected(AppDestination.email),
          onCaptureAnother: () => Navigator.of(context).pop(),
          onDraftSaved: widget.onEmailReviewUpdated == null
              ? null
              : (updated) =>
                    widget.onEmailReviewUpdated!(updated, reviewRecord.lead),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    SessionLead record, {
    bool closeDetail = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.deleteLeadQuestion),
        content: Text(context.l10n.deleteLeadWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const Key('confirmDeleteLead'),
            style: FilledButton.styleFrom(
              backgroundColor: FolooPalette.of(context).error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.onDelete?.call(record);
    if (!mounted) return;
    setState(() => _openSwipeLeadId = null);
    if (closeDetail && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showExportDialog() async {
    final records = _visibleRecords;
    if (records.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.noFilteredRecords)));
      return;
    }
    var format = RecordsExportFormat.xlsx;
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.l10n.exportRecords,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      key: const Key('exportLeadSummary'),
                      context.l10n.exportLeadSummary(
                        context.l10n.leadCount(records.length),
                        context.l10n.exportFilteredRecords,
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
                      title: 'XLSX',
                      subtitle: context.l10n.xlsHelp,
                      selected: format == RecordsExportFormat.xlsx,
                      onTap: () => setDialogState(
                        () => format = RecordsExportFormat.xlsx,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ExportFormatOption(
                      key: const Key('exportCsvOption'),
                      icon: Icons.description_outlined,
                      title: 'CSV',
                      subtitle: context.l10n.csvHelp,
                      selected: format == RecordsExportFormat.csv,
                      onTap: () => setDialogState(
                        () => format = RecordsExportFormat.csv,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_canSaveExportToDevice) ...[
                      OutlinedButton.icon(
                        key: const Key('saveExportToDeviceButton'),
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          await _export(
                            format,
                            _ExportDelivery.saveToDevice,
                            records: records,
                          );
                        },
                        icon: const Icon(Icons.save_alt_outlined, size: 17),
                        label: Text(context.l10n.saveExportToDevice),
                      ),
                      const SizedBox(height: 8),
                    ],
                    FilledButton.icon(
                      key: const Key('confirmExportButton'),
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        await _export(
                          format,
                          _ExportDelivery.share,
                          records: records,
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: FolooPalette.of(context).ink,
                        foregroundColor: FolooPalette.of(context).card,
                      ),
                      icon: const Icon(Icons.ios_share_outlined, size: 17),
                      label: Text(context.l10n.shareExport),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(context.l10n.cancel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _export(
    RecordsExportFormat format,
    _ExportDelivery delivery, {
    required List<SessionLead> records,
  }) async {
    final l10n = context.l10n;
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    try {
      final labels = RecordsExportLabels(
        headers: [
          l10n.dateAndTime,
          l10n.exportFirstName,
          l10n.exportLastName,
          l10n.exportPosition,
          l10n.company,
          l10n.contactEmail,
          l10n.contactPhone,
          l10n.exportType,
          l10n.exportInterest,
          l10n.origin,
          l10n.event,
          l10n.place,
          l10n.writtenNote,
          l10n.exportSharedContent,
          l10n.exportOriginalFile,
        ],
        customer: l10n.client,
        partner: l10n.partner,
        supplier: l10n.supplier,
        low: l10n.interestLow,
        medium: l10n.interestMedium,
        high: l10n.interestHigh,
        event: l10n.event,
        direct: l10n.directLead,
      );
      final file = widget.exportService.buildFiltered(
        scopeName: l10n.exportFilteredRecords,
        records: records,
        format: format,
        labels: labels,
        contentFiles: widget.contentFiles,
      );
      if (delivery == _ExportDelivery.saveToDevice) {
        final outcome = await widget.fileSaver.save(file);
        if (!mounted) return;
        final message = outcome == RecordsFileSaveOutcome.saved
            ? context.l10n.exportSavedToDevice
            : context.l10n.exportSaveCancelled;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
        return;
      }
      await widget.fileSharer.share(file, origin: origin);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.exportCompleted)));
    } on Object {
      if (!mounted) return;
      final message = delivery == _ExportDelivery.saveToDevice
          ? context.l10n.exportSaveFailed
          : context.l10n.exportFailed;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    final records = _visibleRecords;
    final pending = records
        .where((record) => record.uploadState != SessionUploadState.synced)
        .length;
    final failed = records
        .where((record) => _isFailed(record.uploadState))
        .length;
    final syncing = records
        .where((record) => record.uploadState == SessionUploadState.syncing)
        .length;
    final retryable = records
        .where((record) => record.uploadState == SessionUploadState.retryable)
        .length;
    final merelyPending = pending - failed - syncing - retryable;
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: AppDrawer(
        contentCount: widget.contentFiles.length,
        profile: widget.profile,
        activeDestination: AppDestination.records,
        recordsCount: widget.records.length,
        darkMode: widget.darkMode,
        onDestinationSelected: widget.onDestinationSelected,
        onAppearanceChanged: widget.onAppearanceChanged,
        onLogout: widget.onLogout,
      ),
      body: Column(
        children: [
          ModuleHeader(
            title: context.l10n.recordsTitle,
            subtitle:
                '${context.l10n.leadCount(records.length)} · ${context.l10n.pendingCount(pending)}',
            onMenuPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            onBackToHome: () =>
                widget.onDestinationSelected(AppDestination.home),
          ),
          Container(
            color: palette.card,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: _RecordsFilterBar(filters: _filters, onOpen: _openFilters),
          ),
          Divider(height: 1, color: palette.line),
          Expanded(
            child: records.isEmpty
                ? _EmptyRecords(
                    filtered: _filters.isActive,
                    onClear: _filters.isActive
                        ? () => setState(
                            () => _filters = const RecordsFilterState(),
                          )
                        : null,
                  )
                : ListView.separated(
                    key: const Key('recordsList'),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    itemCount: records.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final record = records[index];
                      final followUp = _followUpForLead(record.localId);
                      final emailIntent = _intentFor(followUp);
                      return SwipeActionCard(
                        key: Key('recordSwipe-${record.uiKey}'),
                        open: _openSwipeLeadId == record.localId,
                        onOpened: () =>
                            setState(() => _openSwipeLeadId = record.localId),
                        onClosed: () {
                          if (_openSwipeLeadId == record.localId) {
                            setState(() => _openSwipeLeadId = null);
                          }
                        },
                        startAction: SwipeCardAction(
                          actionKey: const Key('recordSwipeEmailAction'),
                          icon: Icons.outgoing_mail,
                          label: emailIntent == null
                              ? context.l10n.sendEmail
                              : context.l10n.resendEmail,
                          color: FolooColors.lime.withValues(alpha: .32),
                          foregroundColor: palette.ink,
                          onTap: () => _openEmailReview(record),
                        ),
                        endAction: SwipeCardAction(
                          actionKey: const Key('recordSwipeDeleteAction'),
                          icon: Icons.delete_outline,
                          label: context.l10n.delete,
                          color: palette.error,
                          foregroundColor: Colors.white,
                          onTap: () => _confirmDelete(record),
                        ),
                        child: _RecordRow(
                          record: record,
                          audioPlaying:
                              _activeAudioPath == record.lead.audioLocalPath &&
                              _audioPlaying,
                          audioBusy:
                              _busyAudioPath == record.lead.audioLocalPath,
                          onToggleAudio: () =>
                              _toggleAudioPath(record.lead.audioLocalPath),
                          onOpen: () => _openDetail(record),
                          emailIntent: emailIntent,
                          hasPreparedEmail: followUp != null,
                        ),
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
                      failed > 0
                          ? context.l10n.syncNeedsAttention(failed)
                          : syncing > 0
                          ? context.l10n.syncingRecords(syncing)
                          : retryable > 0
                          ? context.l10n.retryScheduledRecords(retryable)
                          : context.l10n.pendingSyncRecords(merelyPending),
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
                      onPressed: widget.syncing || widget.onSync == null
                          ? null
                          : widget.onSync,
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

class _RecordsFilterBar extends StatelessWidget {
  const _RecordsFilterBar({required this.filters, required this.onOpen});

  final RecordsFilterState filters;
  final ValueChanged<RecordsFilterCategory> onOpen;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const Key('recordsFilterBar'),
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        _FilterButton(
          key: const Key('recordsEventsFilter'),
          label: context.l10n.eventsFilter,
          count: filters.eventIds.length,
          icon: Icons.event_outlined,
          onTap: () => onOpen(RecordsFilterCategory.events),
        ),
        _FilterButton(
          key: const Key('recordsDirectFilter'),
          label: context.l10n.directLeads,
          count: filters.directPlaces.length + (filters.onlyDirect ? 1 : 0),
          icon: Icons.person_add_alt_1_outlined,
          onTap: () => onOpen(RecordsFilterCategory.direct),
        ),
        _FilterButton(
          key: const Key('recordsTypeFilter'),
          label: context.l10n.leadType,
          count: filters.leadTypes.length,
          icon: Icons.people_outline,
          onTap: () => onOpen(RecordsFilterCategory.type),
        ),
        _FilterButton(
          key: const Key('recordsAllFilters'),
          label: context.l10n.recordsFilters,
          count: filters.activeCategoryCount,
          icon: Icons.tune,
          onTap: () => onOpen(RecordsFilterCategory.interest),
        ),
      ],
    ),
  );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.count,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String label;
  final int count;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      avatar: Icon(icon, size: 17),
      label: Text(count == 0 ? label : '$label · $count'),
      selected: count > 0,
      showCheckmark: false,
      onSelected: (_) => onTap(),
    ),
  );
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
                key: const Key('exportOptionSelectionIndicator'),
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

class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords({required this.filtered, this.onClear});

  final bool filtered;
  final VoidCallback? onClear;

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
            filtered
                ? context.l10n.noFilteredRecords
                : context.l10n.emptyRecords,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          if (filtered) ...[
            const SizedBox(height: 10),
            TextButton(
              key: const Key('clearEmptyRecordsFilters'),
              onPressed: onClear,
              child: Text(context.l10n.clearAppliedFilters),
            ),
          ],
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
    required this.emailIntent,
    required this.hasPreparedEmail,
  });
  final SessionLead record;
  final bool audioPlaying;
  final bool audioBusy;
  final VoidCallback onToggleAudio;
  final VoidCallback onOpen;
  final StoredEmailSendIntent? emailIntent;
  final bool hasPreparedEmail;

  String _emailLabel(BuildContext context) => switch (emailIntent?.status) {
    'sent' => context.l10n.emailFollowUpSent,
    'pending' => context.l10n.emailFollowUpPending,
    'sending' => context.l10n.emailFollowUpSending,
    'error' => context.l10n.emailFollowUpError,
    'confirmation_required' => context.l10n.emailFollowUpConfirmation,
    _ when hasPreparedEmail => context.l10n.emailFollowUpReady,
    _ => context.l10n.emailNotSent,
  };

  IconData get _emailIcon => switch (emailIntent?.status) {
    'sent' => Icons.mark_email_read_outlined,
    'pending' => Icons.schedule_send_outlined,
    'sending' => Icons.outgoing_mail,
    'error' => Icons.mark_email_unread_outlined,
    'confirmation_required' => Icons.help_outline,
    _ when hasPreparedEmail => Icons.drafts_outlined,
    _ => Icons.mail_outline,
  };

  Color _interest(BuildContext context) => switch (record.lead.interest) {
    InterestLevel.low => FolooColors.interestLow,
    InterestLevel.medium => FolooColors.interestMedium,
    InterestLevel.high => FolooColors.interestHigh,
  };

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    final pending = record.uploadState != SessionUploadState.synced;
    final failed = _isFailed(record.uploadState);
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
                      Tooltip(
                        message: _emailLabel(context),
                        child: Semantics(
                          label: _emailLabel(context),
                          child: Container(
                            key: Key('recordEmail-${record.uiKey}'),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: palette.paper,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_emailIcon, size: 15),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: failed
                              ? palette.errorTint
                              : pending
                              ? FolooColors.uploadPendingTint
                              : palette.successTint,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _uploadStateIcon(record.uploadState),
                          size: 15,
                          color: failed
                              ? palette.error
                              : pending
                              ? palette.ink
                              : palette.success,
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

/// Detail for one captured connection with REG-07 structured editing.
///
/// Media and identity fields remain read-only; automatic transcription is not
/// exposed in V1.
class ConnectionDetailScreen extends StatefulWidget {
  const ConnectionDetailScreen({
    required this.record,
    required this.audioPlayingListenable,
    required this.onToggleAudio,
    this.contentFiles = const [],
    this.currentEventName,
    this.events = const [],
    this.onEdit,
    this.onAddReferenceImage,
    this.onAddVoiceNote,
    this.onDeleteVoiceNote,
    this.followUp,
    this.emailIntent,
    this.ownerSub,
    this.deliveryRepository,
    this.isEmailConnectionMissing,
    this.onRetryEmail,
    this.onResendEmail,
    this.onEmail,
    this.onDelete,
    super.key,
  });
  final SessionLead record;
  final List<ContentFile> contentFiles;
  final ValueListenable<bool> audioPlayingListenable;
  final Future<void> Function(LeadVoiceNote note) onToggleAudio;
  final String? currentEventName;
  final List<AppEvent> events;
  final Future<SessionLead> Function(SessionLead record, LeadDraft updated)?
  onEdit;
  final Future<SessionLead?> Function()? onAddReferenceImage;
  final Future<SessionLead?> Function()? onAddVoiceNote;
  final Future<SessionLead> Function(LeadVoiceNote note)? onDeleteVoiceNote;
  final StoredEmailFollowUp? followUp;
  final StoredEmailSendIntent? emailIntent;
  final String? ownerSub;
  final EmailDeliveryRepository? deliveryRepository;

  /// Checks the authenticated sender state before interpreting an ambiguous 404.
  final Future<bool> Function(StoredEmailSendIntent? intent)?
  isEmailConnectionMissing;
  final Future<void> Function(StoredEmailSendIntent intent)? onRetryEmail;
  final Future<void> Function(
    StoredEmailFollowUp followUp,
    StoredEmailSendIntent intent,
  )?
  onResendEmail;
  final ValueChanged<SessionLead>? onEmail;
  final VoidCallback? onDelete;

  @override
  State<ConnectionDetailScreen> createState() => _ConnectionDetailScreenState();
}

class _ConnectionDetailScreenState extends State<ConnectionDetailScreen> {
  late SessionLead _record;
  late String? _currentEventName;
  String? _activeVoiceId;

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    _currentEventName = widget.currentEventName;
  }

  List<ContentFile> get _availableContent {
    final lead = _record.lead;
    if (lead.originKind == LeadOriginKind.direct) return widget.contentFiles;
    final eventId = lead.eventLocalId;
    final eventContentIds = widget.events
        .where((event) => event.id == eventId)
        .expand((event) => event.contentFileIds)
        .toSet();
    return widget.contentFiles
        .where(
          (file) =>
              file.allEvents ||
              (eventId != null && file.eventIds.contains(eventId)) ||
              eventContentIds.contains(file.id),
        )
        .toList();
  }

  Future<void> _saveContentSelection(Set<String> selected) async {
    final save = widget.onEdit;
    if (save == null) return;
    final availableById = {
      for (final file in widget.contentFiles) file.id: file,
    };
    final orderedIds = <String>{
      for (final id in _record.lead.contentFileIds)
        if (selected.contains(id)) id,
      for (final file in _availableContent)
        if (selected.contains(file.id) &&
            !_record.lead.contentFileIds.contains(file.id))
          file.id,
    }.toList();
    final oldNames = <String, String>{
      for (var index = 0; index < _record.lead.contentFileIds.length; index++)
        if (index < _record.lead.contentNames.length)
          _record.lead.contentFileIds[index]: _record.lead.contentNames[index],
    };
    final updated = _record.lead.copyWith(
      contentFileIds: orderedIds,
      contentNames: [
        for (final id in orderedIds)
          availableById[id]?.displayName ?? oldNames[id] ?? '',
      ],
    );
    try {
      final refreshed = await save(_record, updated);
      if (mounted) setState(() => _record = refreshed);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.localSaveError)));
    }
  }

  Future<void> _chooseContent() async {
    final selected = _record.lead.contentFileIds.toSet();
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.selectLeadContent,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: _availableContent.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(context.l10n.exportNoContentAvailable),
                        )
                      : ListView(
                          shrinkWrap: true,
                          children: [
                            for (final file in _availableContent)
                              CheckboxListTile(
                                key: Key('leadContentOption-${file.id}'),
                                contentPadding: EdgeInsets.zero,
                                value: selected.contains(file.id),
                                title: Text(file.displayName),
                                subtitle: file.fileName.isEmpty
                                    ? null
                                    : Text(file.fileName),
                                onChanged: (value) => setSheetState(() {
                                  value == true
                                      ? selected.add(file.id)
                                      : selected.remove(file.id);
                                }),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('saveLeadContentSelection'),
                  onPressed: () => Navigator.pop(sheetContext, selected),
                  child: Text(context.l10n.saveChanges),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted) await _saveContentSelection(result);
  }

  Widget _contentSection(FolooPalette palette) {
    final lead = _record.lead;
    final filesById = {for (final file in widget.contentFiles) file.id: file};
    return Column(
      key: const Key('leadContentSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.contentForLead,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (widget.onEdit != null)
              IconButton(
                key: const Key('detailAddContent'),
                tooltip: context.l10n.addLeadContent,
                onPressed: _chooseContent,
                icon: const Icon(Icons.create_new_folder_outlined),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (lead.contentFileIds.isEmpty)
          Text(
            context.l10n.noLeadContent,
            style: TextStyle(color: palette.inkSecondary),
          ),
        for (var index = 0; index < lead.contentFileIds.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Dismissible(
              key: Key('leadContentCard-${lead.contentFileIds[index]}'),
              direction: widget.onEdit == null
                  ? DismissDirection.none
                  : DismissDirection.startToEnd,
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20),
                decoration: BoxDecoration(
                  color: palette.error,
                  borderRadius: BorderRadius.circular(FolooRadii.md),
                ),
                child: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.white,
                ),
              ),
              confirmDismiss: (_) async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(context.l10n.removeLeadContentQuestion),
                    content: Text(context.l10n.removeLeadContentHelp),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: Text(context.l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: Text(context.l10n.remove),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  final selected = lead.contentFileIds.toSet()
                    ..remove(lead.contentFileIds[index]);
                  await _saveContentSelection(selected);
                }
                return false;
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.paper,
                  borderRadius: BorderRadius.circular(FolooRadii.md),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            filesById[lead.contentFileIds[index]]
                                    ?.displayName ??
                                (index < lead.contentNames.length
                                    ? lead.contentNames[index]
                                    : lead.contentFileIds[index]),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (filesById[lead.contentFileIds[index]]
                              case final file?)
                            Text(
                              [
                                file.fileName,
                                file.sizeLabel,
                              ].where((value) => value.isNotEmpty).join(' · '),
                              style: TextStyle(
                                color: palette.inkSecondary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    final currentEventName = _currentEventName;
    final audioPlayingListenable = widget.audioPlayingListenable;
    final onToggleAudio = widget.onToggleAudio;
    final events = widget.events;
    final onEdit = widget.onEdit;
    final onAddReferenceImage = widget.onAddReferenceImage;
    final onAddVoiceNote = widget.onAddVoiceNote;
    final onDeleteVoiceNote = widget.onDeleteVoiceNote;
    final followUp = widget.followUp;
    final emailIntent = widget.emailIntent;
    final ownerSub = widget.ownerSub;
    final deliveryRepository = widget.deliveryRepository;
    final isEmailConnectionMissing = widget.isEmailConnectionMissing;
    final onRetryEmail = widget.onRetryEmail;
    final onResendEmail = widget.onResendEmail;
    final onEmail = widget.onEmail;
    final onDelete = widget.onDelete;
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
            if (lead.company.isNotEmpty)
              Text(
                lead.company,
                style: TextStyle(color: palette.inkSecondary, fontSize: 12),
              ),
          ],
        ),
        actions: [
          if (onEdit != null)
            IconButton(
              key: const Key('editLeadButton'),
              tooltip: context.l10n.editLead,
              onPressed: () async {
                final saved = await Navigator.of(context).push<SessionLead>(
                  MaterialPageRoute<SessionLead>(
                    builder: (_) => _LeadEditScreen(
                      lead: lead,
                      events: events,
                      onSave: (updated) => onEdit(record, updated),
                    ),
                  ),
                );
                if (saved != null && context.mounted) {
                  setState(() {
                    _record = saved;
                    _currentEventName = events
                        .where((event) => event.id == saved.lead.eventLocalId)
                        .map((event) => event.name)
                        .firstOrNull;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.leadChangesSaved)),
                  );
                }
              },
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
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
                  color: _isFailed(record.uploadState)
                      ? palette.error
                      : record.uploadState != SessionUploadState.synced
                      ? palette.ink
                      : palette.success,
                  tint: _isFailed(record.uploadState)
                      ? palette.errorTint
                      : record.uploadState != SessionUploadState.synced
                      ? pendingTint
                      : palette.successTint,
                  icon: _uploadStateIcon(record.uploadState),
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
            if (record.effectiveVoiceNotes.isNotEmpty ||
                onAddVoiceNote != null) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.voiceNote,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (onAddVoiceNote != null)
                    IconButton(
                      key: const Key('detailAddVoiceNote'),
                      tooltip: context.l10n.addVoiceNote,
                      onPressed: () async {
                        if (record.effectiveVoiceNotes.length >= 3) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.l10n.voiceNoteLimitReached),
                            ),
                          );
                          return;
                        }
                        final refreshed = await onAddVoiceNote();
                        if (refreshed != null && mounted) {
                          setState(() => _record = refreshed);
                        }
                      },
                      icon: const Icon(Icons.mic_none_outlined),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ...record.effectiveVoiceNotes.asMap().entries.map((entry) {
                final index = entry.key;
                final note = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Dismissible(
                    key: Key('detailVoiceNote-${note.id}'),
                    direction: onDeleteVoiceNote == null
                        ? DismissDirection.none
                        : DismissDirection.startToEnd,
                    background: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 20),
                      decoration: BoxDecoration(
                        color: palette.error,
                        borderRadius: BorderRadius.circular(FolooRadii.md),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                      ),
                    ),
                    confirmDismiss: (_) async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: Text(context.l10n.deleteVoiceNoteQuestion),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: Text(context.l10n.cancel),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: Text(context.l10n.delete),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true || onDeleteVoiceNote == null) {
                        return false;
                      }
                      try {
                        final refreshed = await onDeleteVoiceNote(note);
                        if (mounted) {
                          setState(() {
                            _record = refreshed;
                            if (_activeVoiceId == note.id) {
                              _activeVoiceId = null;
                            }
                          });
                        }
                        return false;
                      } on Object {
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(this.context.l10n.localSaveError),
                            ),
                          );
                        }
                        return false;
                      }
                    },
                    child: ValueListenableBuilder<bool>(
                      valueListenable: audioPlayingListenable,
                      builder: (context, playing, _) {
                        final active = playing && _activeVoiceId == note.id;
                        return Container(
                          key: index == 0
                              ? const Key('detailVoiceNoteCard')
                              : null,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: palette.paper,
                            borderRadius: BorderRadius.circular(FolooRadii.md),
                          ),
                          child: Row(
                            children: [
                              IconButton.filled(
                                key: index == 0
                                    ? const Key('detailAudioButton')
                                    : Key('detailAudioButton-$index'),
                                tooltip: active
                                    ? context.l10n.pauseVoiceNote
                                    : context.l10n.playVoiceNote,
                                onPressed: () async {
                                  setState(() => _activeVoiceId = note.id);
                                  await onToggleAudio(note);
                                },
                                style: IconButton.styleFrom(
                                  backgroundColor: FolooColors.lime,
                                  foregroundColor: FolooColors.ink,
                                ),
                                icon: Icon(
                                  active
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: VoicePlaybackWaveform(
                                  key: index == 0
                                      ? const Key('detailAudioWaveform')
                                      : Key('detailAudioWaveform-$index'),
                                  active: active,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _voiceDuration(note.durationSeconds),
                                style: TextStyle(color: palette.inkSecondary),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              }),
            ],
            if (lead.referenceImageLocalPaths.isNotEmpty ||
                onAddReferenceImage != null) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.referenceImagesDetail,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (onAddReferenceImage != null)
                    IconButton(
                      key: const Key('detailAddReferenceImage'),
                      onPressed: () async {
                        if (lead.referenceImageLocalPaths.length >= 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.l10n.referenceImageLimitReached,
                              ),
                            ),
                          );
                          return;
                        }
                        final refreshed = await onAddReferenceImage();
                        if (refreshed != null && mounted) {
                          setState(() => _record = refreshed);
                        }
                      },
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      tooltip: context.l10n.referenceImagePickerTitle,
                    ),
                ],
              ),
              if (lead.referenceImageLocalPaths.isNotEmpty) ...[
                const SizedBox(height: 10),
                GridView.builder(
                  key: const Key('detailReferenceImages'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: lead.referenceImageLocalPaths.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {
                    final path = lead.referenceImageLocalPaths[index];
                    return Semantics(
                      button: true,
                      label: context.l10n.referenceImagePreview,
                      child: InkWell(
                        key: Key('detailReferenceImage-$index'),
                        onTap: () => _showReferenceImage(context, path),
                        borderRadius: BorderRadius.circular(FolooRadii.sm),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(FolooRadii.sm),
                          child: Image.file(
                            File(path),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: palette.paper,
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: palette.inkSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
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
            _contentSection(palette),
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
                  ? (currentEventName ?? lead.eventName ?? context.l10n.event)
                  : lead.place?.trim().isNotEmpty == true
                  ? '${context.l10n.directLead} · ${lead.place!.trim()}'
                  : context.l10n.directLead,
            ),
            _ReadOnlyValue(
              label: context.l10n.capturedBy,
              value: record.capturedBy,
            ),
            const SizedBox(height: 10),
            _LiveLeadFollowUpSection(
              leadId: record.localId,
              leadName: lead.fullName,
              ownerSub: ownerSub,
              repository: deliveryRepository,
              isEmailConnectionMissing: isEmailConnectionMissing,
              initialFollowUp: followUp,
              initialIntent: emailIntent,
              onRetry: onRetryEmail,
              onResend: onResendEmail,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('detailEmailAction'),
              onPressed: onEmail == null ? null : () => onEmail(record),
              icon: const Icon(Icons.outgoing_mail),
              label: Text(
                emailIntent == null
                    ? context.l10n.sendEmail
                    : context.l10n.resendEmail,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('detailDeleteAction'),
              onPressed: onDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.error,
                side: BorderSide(color: palette.error),
              ),
              icon: const Icon(Icons.delete_outline),
              label: Text(context.l10n.delete),
            ),
          ],
        ),
      ),
    );
  }

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

  static Future<void> _showReferenceImage(
    BuildContext context,
    String imagePath,
  ) => showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .82),
    builder: (dialogContext) => Dialog(
      key: const Key('detailReferenceImageDialog'),
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
            errorBuilder: (_, _, _) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _LeadEditScreen extends StatefulWidget {
  const _LeadEditScreen({
    required this.lead,
    required this.events,
    required this.onSave,
  });

  final LeadDraft lead;
  final List<AppEvent> events;
  final Future<SessionLead> Function(LeadDraft updated) onSave;

  @override
  State<_LeadEditScreen> createState() => _LeadEditScreenState();
}

class _LeadEditScreenState extends State<_LeadEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _lastName;
  late final TextEditingController _role;
  late final TextEditingController _company;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _note;
  late final TextEditingController _place;
  late LeadType _type;
  late InterestLevel _interest;
  String? _eventId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final lead = widget.lead;
    _name = TextEditingController(text: lead.name);
    _lastName = TextEditingController(text: lead.lastName);
    _role = TextEditingController(text: lead.role);
    _company = TextEditingController(text: lead.company);
    _email = TextEditingController(text: lead.email);
    _phone = TextEditingController(text: lead.phone);
    _note = TextEditingController(text: lead.note);
    _place = TextEditingController(text: lead.place);
    _type = lead.type;
    _interest = lead.interest;
    _eventId = lead.eventLocalId;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _lastName,
      _role,
      _company,
      _email,
      _phone,
      _note,
      _place,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final refreshed = await widget.onSave(
        widget.lead.copyWith(
          name: _name.text.trim(),
          lastName: _lastName.text.trim(),
          role: _role.text.trim(),
          company: _company.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          type: _type,
          interest: _interest,
          note: _note.text.trim(),
          place: _place.text.trim(),
          eventLocalId: _eventId,
          eventName: widget.events
              .where((event) => event.id == _eventId)
              .map((event) => event.name)
              .firstOrNull,
        ),
      );
      if (mounted) Navigator.pop(context, refreshed);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.editLeadFailed)));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.editLead)),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          _field(_name, context.l10n.exportFirstName, isRequired: true),
          _field(_lastName, context.l10n.exportLastName),
          _field(_role, context.l10n.exportPosition),
          _field(_company, context.l10n.company),
          _field(_email, context.l10n.contactEmail, email: true),
          _field(_phone, context.l10n.contactPhone),
          DropdownButtonFormField<LeadType>(
            initialValue: _type,
            decoration: InputDecoration(labelText: context.l10n.exportType),
            items: LeadType.values
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(_leadTypeLabel(context, type)),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _type = value ?? _type),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<InterestLevel>(
            initialValue: _interest,
            decoration: InputDecoration(labelText: context.l10n.exportInterest),
            items: InterestLevel.values
                .map(
                  (interest) => DropdownMenuItem(
                    value: interest,
                    child: Text(switch (interest) {
                      InterestLevel.low => context.l10n.interestLow,
                      InterestLevel.medium => context.l10n.interestMedium,
                      InterestLevel.high => context.l10n.interestHigh,
                    }),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => _interest = value ?? _interest),
          ),
          if (widget.lead.originKind == LeadOriginKind.direct) ...[
            const SizedBox(height: 12),
            _field(_place, context.l10n.place, isRequired: true),
          ] else ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('editLeadEvent'),
              initialValue: _eventId,
              decoration: InputDecoration(labelText: context.l10n.event),
              items: widget.events
                  .map(
                    (event) => DropdownMenuItem(
                      value: event.id,
                      child: Text(event.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _eventId = value),
              validator: (value) =>
                  value == null ? context.l10n.requiredField : null,
            ),
          ],
          const SizedBox(height: 12),
          _field(_note, context.l10n.writtenNote, lines: 5),
        ],
      ),
    ),
    bottomNavigationBar: AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: FilledButton(
            key: const Key('saveLeadEditButton'),
            onPressed: _saving ? null : _save,
            child: Text(context.l10n.saveChanges),
          ),
        ),
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool isRequired = false,
    bool email = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      maxLines: lines,
      textInputAction: lines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      keyboardType: email ? TextInputType.emailAddress : null,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (isRequired && text.isEmpty) return context.l10n.requiredField;
        if (email &&
            text.isNotEmpty &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
          return context.l10n.invalidEmail;
        }
        if (identical(controller, _email) &&
            text.isEmpty &&
            _phone.text.trim().isEmpty) {
          return context.l10n.emailOrPhoneRequired;
        }
        return null;
      },
    ),
  );
}

/// Keeps the open Lead detail bound to the same Drift streams as Records.
class _LiveLeadFollowUpSection extends StatelessWidget {
  const _LiveLeadFollowUpSection({
    required this.leadId,
    required this.leadName,
    required this.ownerSub,
    required this.repository,
    required this.initialFollowUp,
    required this.initialIntent,
    required this.onRetry,
    required this.isEmailConnectionMissing,
    required this.onResend,
  });

  final String leadId;
  final String leadName;
  final String? ownerSub;
  final EmailDeliveryRepository? repository;
  final StoredEmailFollowUp? initialFollowUp;
  final StoredEmailSendIntent? initialIntent;
  final Future<void> Function(StoredEmailSendIntent intent)? onRetry;
  final Future<bool> Function(StoredEmailSendIntent? intent)?
  isEmailConnectionMissing;
  final Future<void> Function(
    StoredEmailFollowUp followUp,
    StoredEmailSendIntent intent,
  )?
  onResend;

  @override
  Widget build(BuildContext context) {
    final owner = ownerSub;
    final source = repository;
    if (owner == null || source == null) {
      return _LeadFollowUpSection(
        leadName: leadName,
        followUp: initialFollowUp,
        intent: initialIntent,
        onRetry: onRetry,
        isEmailConnectionMissing: isEmailConnectionMissing,
        onResend: onResend,
      );
    }
    return StreamBuilder<List<StoredEmailFollowUp>>(
      stream: source.watchFollowUps(owner),
      initialData: initialFollowUp == null ? const [] : [initialFollowUp!],
      builder: (context, followUpSnapshot) {
        final matches = (followUpSnapshot.data ?? const []).where(
          (item) => item.leadLocalId == leadId,
        );
        final followUp = matches.isEmpty ? null : matches.first;
        return StreamBuilder<List<StoredEmailSendIntent>>(
          stream: source.watchIntents(owner),
          initialData: initialIntent == null ? const [] : [initialIntent!],
          builder: (context, intentSnapshot) {
            final intents = (intentSnapshot.data ?? const []).where(
              (item) => item.followUpLocalId == followUp?.localId,
            );
            return _LeadFollowUpSection(
              leadName: leadName,
              followUp: followUp,
              intent: intents.isEmpty ? null : intents.first,
              onRetry: onRetry,
              isEmailConnectionMissing: isEmailConnectionMissing,
              onResend: onResend,
            );
          },
        );
      },
    );
  }
}

class _LeadFollowUpSection extends StatelessWidget {
  const _LeadFollowUpSection({
    required this.leadName,
    required this.followUp,
    required this.intent,
    required this.onRetry,
    required this.isEmailConnectionMissing,
    required this.onResend,
  });

  final String leadName;
  final StoredEmailFollowUp? followUp;
  final StoredEmailSendIntent? intent;
  final Future<void> Function(StoredEmailSendIntent intent)? onRetry;
  final Future<bool> Function(StoredEmailSendIntent? intent)?
  isEmailConnectionMissing;
  final Future<void> Function(
    StoredEmailFollowUp followUp,
    StoredEmailSendIntent intent,
  )?
  onResend;

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    final current = followUp;
    final status = switch (intent?.status) {
      'sent' => context.l10n.emailFollowUpSent,
      'pending' => context.l10n.emailFollowUpPending,
      'sending' => context.l10n.emailFollowUpSending,
      'error' => context.l10n.emailFollowUpError,
      'confirmation_required' => context.l10n.emailFollowUpConfirmation,
      _ when current != null => context.l10n.emailFollowUpReady,
      _ => context.l10n.emailNotSent,
    };
    final names = current == null
        ? const <String>[]
        : (jsonDecode(current.contentNamesJson) as List)
              .whereType<String>()
              .toList();
    final visual = switch (intent?.status) {
      'sent' => (Icons.mark_email_read_outlined, palette.success),
      'sending' => (Icons.outgoing_mail, palette.pending),
      'error' => (Icons.mark_email_unread_outlined, palette.error),
      'confirmation_required' => (Icons.help_outline, palette.pending),
      'pending' => (Icons.schedule_send_outlined, palette.pending),
      _ => (Icons.drafts_outlined, palette.inkSecondary),
    };
    Future<void> showDetails() async {
      var missingConnection =
          emailDeliveryErrorCode(intent?.errorCode) ==
          'email_connection_required';
      if (intent?.errorCode == 'http_404_not_found' || intent == null) {
        try {
          missingConnection =
              await isEmailConnectionMissing?.call(intent) ?? false;
        } on Object {
          // Retain the original error when sender state cannot be verified.
        }
      }
      if (!context.mounted) return;
      final errorCode = emailDeliveryErrorCode(intent?.errorCode);
      final errorMessage = missingConnection
          ? context.l10n.emailNoConnectedAccount
          : errorCode == 'sender_confirmation_required'
          ? context.l10n.emailSenderChangedDetail
          : errorCode == 'email_retry_not_allowed'
          ? context.l10n.emailNotRetryableStatus
          : context.l10n.emailErrorDetail;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const Key('leadFollowUpDetailsDialog'),
          title: Text(leadName),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current!.recipientAddress,
                  style: TextStyle(color: palette.inkSecondary),
                ),
                if (intent?.senderAddress case final sender?) ...[
                  const SizedBox(height: 4),
                  Text(sender, style: TextStyle(color: palette.inkSecondary)),
                ],
                const SizedBox(height: 16),
                Text(
                  context.l10n.subject,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(current.subject, key: const Key('leadFollowUpSubject')),
                const SizedBox(height: 16),
                Text(
                  context.l10n.emailReviewMessage,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(current.plainBody, key: const Key('leadFollowUpBody')),
                if (names.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ...names.map(
                    (name) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.picture_as_pdf_outlined, size: 17),
                          const SizedBox(width: 6),
                          Expanded(child: Text(name)),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  DateFormat.yMMMd(
                    Localizations.localeOf(context).toLanguageTag(),
                  ).add_Hm().format(current.preparedAt.toLocal()),
                  style: TextStyle(color: palette.inkSecondary, fontSize: 12),
                ),
                if (missingConnection && intent?.errorCode == null) ...[
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.emailNoConnectedAccount,
                    style: TextStyle(color: palette.error),
                  ),
                ],
                if (intent?.errorCode != null) ...[
                  const SizedBox(height: 6),
                  Text(errorMessage, style: TextStyle(color: palette.error)),
                ],
              ],
            ),
          ),
          actions: [
            if (intent case final emailIntent?)
              if (emailIntent.status == 'error' &&
                  requiresManualEmailResend(emailIntent.errorCode))
                TextButton.icon(
                  key: const Key('leadFollowUpResend'),
                  onPressed: onResend == null
                      ? null
                      : () async {
                          Navigator.pop(dialogContext);
                          await onResend!(current, emailIntent);
                        },
                  icon: const Icon(Icons.forward_to_inbox_outlined),
                  label: Text(context.l10n.emailResend),
                )
              else if (emailIntent.status == 'error' &&
                  !isTerminalEmailDeliveryError(emailIntent.errorCode))
                TextButton.icon(
                  key: const Key('leadFollowUpRetry'),
                  onPressed: onRetry == null
                      ? null
                      : () async {
                          Navigator.pop(dialogContext);
                          await onRetry!(emailIntent);
                        },
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.retry),
                )
              else if (emailIntent.status == 'sent' ||
                  emailIntent.status == 'confirmation_required')
                TextButton.icon(
                  key: const Key('leadFollowUpResend'),
                  onPressed: onResend == null
                      ? null
                      : () async {
                          Navigator.pop(dialogContext);
                          await onResend!(current, emailIntent);
                        },
                  icon: const Icon(Icons.forward_to_inbox_outlined),
                  label: Text(context.l10n.emailResend),
                ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(MaterialLocalizations.of(context).closeButtonLabel),
            ),
          ],
        ),
      );
    }

    return Column(
      key: const Key('leadFollowUpSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.emailFollowUps,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Card(
          key: const Key('leadFollowUpCard'),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: current == null ? null : showDetails,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(visual.$1, color: visual.$2, semanticLabel: status),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          current == null ? status : leadName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (current != null)
                          Text(
                            current.recipientAddress,
                            style: TextStyle(
                              color: palette.inkSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (current != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: visual.$2.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: visual.$2,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
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
