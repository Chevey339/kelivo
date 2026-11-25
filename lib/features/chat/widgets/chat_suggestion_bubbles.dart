import 'package:flutter/material.dart';

import '../../../shared/widgets/ios_tactile.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

class ChatSuggestionBubbles extends StatelessWidget {
  const ChatSuggestionBubbles({
    super.key,
    required this.suggestions,
    required this.onTap,
    this.maxSuggestions = 3,
    this.alignment = WrapAlignment.start,
  });

  final List<String> suggestions;
  final ValueChanged<String> onTap;
  final int maxSuggestions;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final visible = suggestions
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(maxSuggestions)
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark
        ? cs.onSurface.withValues(alpha: 0.08)
        : cs.primaryContainer.withValues(alpha: 0.42);
    final textColor = cs.onSurface.withValues(alpha: isDark ? 0.92 : 0.88);

    return Wrap(
      alignment: alignment,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final suggestion in visible)
          Semantics(
            button: true,
            label: suggestion,
            child: IosCardPress(
              onTap: () => onTap(suggestion),
              haptics: false,
              baseColor: baseColor,
              borderRadius: BorderRadius.circular(16),
              pressedScale: 0.98,
              pressedBlendStrength: isDark ? 0.16 : 0.10,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                suggestion,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: AppFontWeights.medium,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
