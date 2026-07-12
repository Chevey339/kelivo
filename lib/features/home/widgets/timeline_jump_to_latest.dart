import 'package:flutter/material.dart';

class TimelineJumpToLatest extends StatelessWidget {
  const TimelineJumpToLatest({
    super.key,
    required this.label,
    required this.isGenerating,
    required this.onPressed,
    required this.bottomOffset,
  });

  final String label;
  final bool isGenerating;
  final VoidCallback onPressed;
  final double bottomOffset;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomOffset),
          child: Semantics(
            key: const ValueKey('timeline-jump-semantics'),
            excludeSemantics: true,
            button: true,
            enabled: true,
            label: label,
            liveRegion: true,
            onTap: onPressed,
            child: Material(
              color: colors.surfaceContainerHigh,
              elevation: 3,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                key: const ValueKey('timeline-jump-to-latest'),
                borderRadius: BorderRadius.circular(999),
                onTap: onPressed,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isGenerating) ...[
                        SizedBox.square(
                          dimension: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ] else ...[
                        Icon(
                          Icons.arrow_downward_rounded,
                          size: 16,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(label),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
