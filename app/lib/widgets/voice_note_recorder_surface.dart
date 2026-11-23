/// Shared visual surface for recording and reviewing one voice-note draft.
///
/// Capture and saved-lead detail provide their own durable lifecycle while
/// this component keeps the Foloo interaction and accessibility consistent.
library;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/foloo_theme.dart';
import 'voice_playback_waveform.dart';

class VoiceNoteRecorderSurface extends StatelessWidget {
  const VoiceNoteRecorderSurface({
    required this.recording,
    required this.hasRecording,
    required this.playing,
    required this.busy,
    required this.elapsed,
    required this.onToggleRecording,
    required this.onDelete,
    required this.onRerecord,
    required this.onTogglePlayback,
    this.keyPrefix = 'voice',
    this.showOfflineHelp = true,
    this.recordKey,
    this.discardKey,
    this.rerecordKey,
    this.playKey,
    this.waveformKey,
    this.durationKey,
    super.key,
  });

  final bool recording;
  final bool hasRecording;
  final bool playing;
  final bool busy;
  final Duration elapsed;
  final VoidCallback? onToggleRecording;
  final VoidCallback? onDelete;
  final VoidCallback? onRerecord;
  final VoidCallback? onTogglePlayback;
  final String keyPrefix;
  final bool showOfflineHelp;
  final Key? recordKey;
  final Key? discardKey;
  final Key? rerecordKey;
  final Key? playKey;
  final Key? waveformKey;
  final Key? durationKey;

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.paper,
            borderRadius: BorderRadius.circular(FolooRadii.md),
          ),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: recording
                    ? context.l10n.stopRecording
                    : hasRecording
                    ? context.l10n.recordAgain
                    : context.l10n.startRecording,
                child: IconButton.filled(
                  key: recordKey ?? Key('${keyPrefix}RecordButton'),
                  onPressed: busy ? null : onToggleRecording,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(52, 52),
                    backgroundColor: FolooColors.ink,
                    foregroundColor: recording
                        ? FolooColors.lime
                        : FolooColors.white,
                  ),
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          recording
                              ? Icons.stop_rounded
                              : Icons.mic_none_rounded,
                          size: recording ? 23 : 24,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: VoicePlaybackWaveform(
                  key: waveformKey ?? Key('${keyPrefix}Waveform'),
                  active: recording || playing,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _duration(elapsed),
                key: durationKey ?? Key('${keyPrefix}Duration'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        if (showOfflineHelp) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.mic_none_rounded,
                size: 14,
                color: palette.inkSecondary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  context.l10n.offlineSaveHelp,
                  style: TextStyle(color: palette.inkSecondary, fontSize: 10.5),
                ),
              ),
            ],
          ),
        ],
        if (hasRecording) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  key: discardKey ?? Key('${keyPrefix}DiscardButton'),
                  tooltip: context.l10n.deleteAudio,
                  icon: Icons.delete_outline_rounded,
                  onPressed: busy ? null : onDelete,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  key: rerecordKey ?? Key('${keyPrefix}RerecordButton'),
                  tooltip: context.l10n.recordAgain,
                  icon: Icons.replay_rounded,
                  onPressed: busy ? null : onRerecord,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  key: playKey ?? Key('${keyPrefix}PlayButton'),
                  tooltip: playing
                      ? context.l10n.pauseAudio
                      : context.l10n.playAudio,
                  icon: playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  onPressed: busy ? null : onTogglePlayback,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FolooRadii.sm),
        ),
      ),
      child: Icon(icon),
    ),
  );
}

String _duration(Duration value) {
  final seconds = value.inSeconds;
  return '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';
}
