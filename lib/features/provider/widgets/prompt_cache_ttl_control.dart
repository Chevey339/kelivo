import 'package:flutter/material.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../theme/app_font_weights.dart';

class PromptCachingTtlSegmentedControl extends StatelessWidget {
  const PromptCachingTtlSegmentedControl({
    super.key,
    required this.value,
    required this.fiveMinuteLabel,
    required this.oneHourLabel,
    required this.semanticLabel,
    required this.onChanged,
  });

  final String value;
  final String fiveMinuteLabel;
  final String oneHourLabel;
  final String semanticLabel;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = cs.onSurface.withValues(alpha: isDark ? 0.08 : 0.05);

    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PromptCachingTtlSegment(
              label: fiveMinuteLabel,
              selected: value == ProviderConfig.claudePromptCachingTtl5m,
              selectedColor: cs.primary,
              onTap: () => onChanged(ProviderConfig.claudePromptCachingTtl5m),
            ),
            _PromptCachingTtlSegment(
              label: oneHourLabel,
              selected: value == ProviderConfig.claudePromptCachingTtl1h,
              selectedColor: cs.primary,
              onTap: () => onChanged(ProviderConfig.claudePromptCachingTtl1h),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptCachingTtlSegment extends StatelessWidget {
  const _PromptCachingTtlSegment({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          style: TextStyle(
            fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            fontSize: 13,
            fontWeight: AppFontWeights.semibold,
            color: selected
                ? cs.onPrimary
                : cs.onSurface.withValues(alpha: 0.7),
          ),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
