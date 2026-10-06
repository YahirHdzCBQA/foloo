/// Shared Foloo card gesture that reveals one contextual action per side.
///
/// The gesture only exposes a full-height surface; callers retain ownership of
/// confirmation, persistence and navigation behavior (REG-17/CON-13).
library;

import 'package:flutter/material.dart';

import '../theme/foloo_theme.dart';

/// Visual and semantic definition for one revealed card action.
class SwipeCardAction {
  const SwipeCardAction({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.color,
    required this.foregroundColor,
    required this.onTap,
  });

  final Key actionKey;
  final IconData icon;
  final String label;
  final Color color;
  final Color foregroundColor;
  final VoidCallback onTap;
}

/// Reveals [startAction] on a right swipe and [endAction] on a left swipe.
class SwipeActionCard extends StatefulWidget {
  const SwipeActionCard({
    required this.child,
    required this.open,
    required this.onOpened,
    required this.onClosed,
    required this.startAction,
    required this.endAction,
    this.extent = 92,
    this.revealThreshold = 34,
    super.key,
  });

  final Widget child;
  final bool open;
  final VoidCallback onOpened;
  final VoidCallback onClosed;
  final SwipeCardAction startAction;
  final SwipeCardAction endAction;
  final double extent;
  final double revealThreshold;

  @override
  State<SwipeActionCard> createState() => _SwipeActionCardState();
}

class _SwipeActionCardState extends State<SwipeActionCard> {
  double _offset = 0;

  @override
  void didUpdateWidget(covariant SwipeActionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.open && _offset != 0) _offset = 0;
  }

  void _finish() {
    final target = _offset.abs() >= widget.revealThreshold
        ? _offset.sign * widget.extent
        : 0.0;
    setState(() => _offset = target);
    if (target == 0) {
      widget.onClosed();
    } else {
      widget.onOpened();
    }
  }

  void _run(SwipeCardAction action) {
    setState(() => _offset = 0);
    widget.onClosed();
    action.onTap();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(FolooRadii.md),
    child: Stack(
      children: [
        if (_offset.abs() > .5)
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SwipeActionSurface(
                  action: widget.startAction,
                  width: widget.extent,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(FolooRadii.md),
                  ),
                  onTap: () => _run(widget.startAction),
                ),
                _SwipeActionSurface(
                  action: widget.endAction,
                  width: widget.extent,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(FolooRadii.md),
                  ),
                  onTap: () => _run(widget.endAction),
                ),
              ],
            ),
          ),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: (details) => setState(
            () => _offset = (_offset + details.delta.dx).clamp(
              -widget.extent,
              widget.extent,
            ),
          ),
          onHorizontalDragEnd: (_) => _finish(),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 160),
            transform: Matrix4.translationValues(_offset, 0, 0),
            child: widget.child,
          ),
        ),
      ],
    ),
  );
}

class _SwipeActionSurface extends StatelessWidget {
  const _SwipeActionSurface({
    required this.action,
    required this.width,
    required this.borderRadius,
    required this.onTap,
  });

  final SwipeCardAction action;
  final double width;
  final BorderRadius borderRadius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: action.actionKey,
    width: width,
    child: Material(
      color: action.color,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: action.label,
          child: Center(
            child: Tooltip(
              message: action.label,
              child: Icon(action.icon, color: action.foregroundColor),
            ),
          ),
        ),
      ),
    ),
  );
}
