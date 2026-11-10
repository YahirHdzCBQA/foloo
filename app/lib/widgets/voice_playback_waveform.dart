/// Shared animated waveform for recorded voice-note playback.
///
/// Capture and Records use the same visual state so play/pause is consistent
/// without coupling either screen to the device audio implementation (VOZ-02).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animates a compact waveform only while audio is recording or playing.
class VoicePlaybackWaveform extends StatefulWidget {
  const VoicePlaybackWaveform({required this.active, super.key});

  final bool active;

  @override
  State<VoicePlaybackWaveform> createState() => _VoicePlaybackWaveformState();
}

class _VoicePlaybackWaveformState extends State<VoicePlaybackWaveform>
    with SingleTickerProviderStateMixin {
  static const _heights = <double>[
    10,
    20,
    14,
    28,
    18,
    34,
    12,
    24,
    16,
    30,
    13,
    22,
  ];
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant VoicePlaybackWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (widget.active) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    final color = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: widget.active ? .68 : .18);
    return SizedBox(
      height: 34,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: _heights.indexed.map((entry) {
            final pulse = animationsDisabled || !widget.active
                ? .48
                : .58 +
                      .42 *
                          math
                              .sin(
                                _controller.value * math.pi * 2 +
                                    entry.$1 * .82,
                              )
                              .abs();
            return Container(
              width: 3,
              height: entry.$2 * pulse,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
