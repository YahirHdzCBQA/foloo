import 'package:flutter/material.dart';

import '../theme/foloo_theme.dart';

class SegmentedBubbleOption<T> {
  const SegmentedBubbleOption({
    required this.value,
    required this.label,
    required this.leading,
    this.key,
  });

  final T value;
  final String label;
  final Widget leading;
  final Key? key;
}

class SegmentedBubble<T> extends StatelessWidget {
  const SegmentedBubble({
    required this.options,
    required this.selected,
    required this.onSelected,
    this.height = 56,
    super.key,
  });

  final List<SegmentedBubbleOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    return Container(
      height: height,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: palette.paper,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Row(
        children: options.map((option) {
          final isSelected = option.value == selected;
          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              child: InkWell(
                key: option.key,
                onTap: () => onSelected(option.value),
                borderRadius: BorderRadius.circular((height - 14) / 2),
                child: AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected ? palette.card : Colors.transparent,
                    borderRadius: BorderRadius.circular((height - 14) / 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      option.leading,
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          option.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.ink,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
