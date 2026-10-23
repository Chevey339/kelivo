import 'package:flutter/material.dart';

import '../../core/services/haptics.dart';
import '../../theme/app_font_weights.dart';
import '../../theme/app_semantic_colors.dart';

class SegmentedTab {
  const SegmentedTab({required this.label, this.icon});

  final String label;
  final IconData? icon;
}

class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
    this.expand = true,
    this.height = 40,
    this.enabled = true,
    this.radioGroup = false,
    this.enableHaptics = true,
    this.backgroundColor,
    this.selectedColor,
    this.foregroundColor,
    this.selectedForegroundColor,
  });

  final List<SegmentedTab> tabs;
  final int index;
  final ValueChanged<int> onChanged;
  final bool expand;
  final double height;
  final bool enabled, radioGroup, enableHaptics;
  final Color? backgroundColor,
      selectedColor,
      foregroundColor,
      selectedForegroundColor;

  static const double _innerPadding = 4;
  static const double _gap = 6;
  static const double _shellRadius = 12;
  static const Duration _animDuration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final innerRadius = (_shellRadius - _innerPadding).clamp(0.0, _shellRadius);
    final segments = <Widget>[];
    for (var i = 0; i < tabs.length; i++) {
      if (i != 0) segments.add(const SizedBox(width: _gap));
      final segment = _segment(
        cs: cs,
        tab: tabs[i],
        selected: i == index,
        innerRadius: innerRadius,
        reducedMotion: MediaQuery.disableAnimationsOf(context),
        onTap: () {
          if (!enabled || i == index) return;
          if (enableHaptics) Haptics.light();
          onChanged(i);
        },
      );
      segments.add(expand ? Expanded(child: segment) : segment);
    }

    final row = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: segments,
    );

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? context.appColors.surfaceCard,
        borderRadius: BorderRadius.circular(_shellRadius),
      ),
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.all(_innerPadding),
        child: expand
            ? row
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: row,
              ),
      ),
    );
  }

  Widget _segment({
    required ColorScheme cs,
    required SegmentedTab tab,
    required bool selected,
    required double innerRadius,
    required VoidCallback onTap,
    required bool reducedMotion,
  }) {
    final color = selected
        ? (selectedForegroundColor ?? cs.primary)
        : (foregroundColor ?? cs.onSurface.withValues(alpha: 0.82));
    final label = Text(
      tab.label,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 13,
        fontWeight: selected ? AppFontWeights.semibold : AppFontWeights.medium,
      ),
    );
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (tab.icon != null) ...[
          Icon(tab.icon, size: 16, color: color),
          const SizedBox(width: 6),
        ],
        expand ? Flexible(child: label) : label,
      ],
    );

    return Semantics(
      button: !radioGroup,
      selected: radioGroup ? null : selected,
      checked: radioGroup ? selected : null,
      inMutuallyExclusiveGroup: radioGroup,
      enabled: enabled,
      label: tab.label,
      onTap: enabled ? onTap : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: reducedMotion ? Duration.zero : _animDuration,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: selected
                  ? (selectedColor ?? cs.primary.withValues(alpha: 0.14))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(innerRadius),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}
