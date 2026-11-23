import 'package:flutter/material.dart';

import '../../core/services/haptics.dart';
import '../../theme/app_semantic_colors.dart';
import 'ios_tactile.dart';
import 'segmented_tabs.dart' show SegmentedTab;

export 'segmented_tabs.dart' show SegmentedTab;

const handoffCurve = Cubic(.32, .72, 0, 1);

Duration handoffDuration(BuildContext context, int milliseconds) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

/// A single raised thumb moves across the recessed track, including in RTL.
class SlidingSegmentedTabs extends StatelessWidget {
  const SlidingSegmentedTabs({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
    this.height = 36,
    this.compact = false,
    this.iconOnly = false,
    this.expand = true,
    this.allowReselect = false,
    this.backgroundColor,
    this.selectedColor,
    this.foregroundColor,
    this.selectedForegroundColor,
  });

  final List<SegmentedTab> tabs;
  final int index;
  final ValueChanged<int> onChanged;
  final double height;
  final bool compact, iconOnly, expand;
  final bool allowReselect;
  final Color? backgroundColor,
      selectedColor,
      foregroundColor,
      selectedForegroundColor;

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final inset = compact ? 2.0 : 3.0;
    final radius = compact ? 14.0 : 13.0;
    final count = tabs.length;
    final segmentRow = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, tab) in tabs.indexed)
          Expanded(
            child: Semantics(
              label: tab.label,
              checked: i == index,
              inMutuallyExclusiveGroup: true,
              child: IosCardPress(
                focusable: true,
                haptics: false,
                duration: handoffDuration(context, 140),
                baseColor: Colors.transparent,
                borderRadius: BorderRadius.circular(radius - inset),
                onTap: () {
                  if (i == index && !allowReselect) return;
                  Haptics.light();
                  onChanged(i);
                },
                child: ExcludeSemantics(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (tab.icon != null)
                          Icon(
                            tab.icon,
                            size: compact ? 14 : 16,
                            color: i == index
                                ? selectedForegroundColor ?? cs.onSurface
                                : foregroundColor ?? cs.onSurfaceVariant,
                          ),
                        if (tab.icon != null && !iconOnly)
                          const SizedBox(width: 5),
                        if (!iconOnly || tab.icon == null)
                          Flexible(
                            child: Text(
                              tab.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 12.5 : 13,
                                fontWeight: FontWeight.w600,
                                color: i == index
                                    ? selectedForegroundColor ?? cs.onSurface
                                    : foregroundColor ?? cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    final track = Container(
      height: height,
      padding: EdgeInsets.all(inset),
      decoration: BoxDecoration(
        color: backgroundColor ?? context.appColors.surfaceFill,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          if (index >= 0 && index < count)
            Positioned.fill(
              child: AnimatedAlign(
                alignment: AlignmentDirectional(
                  count == 1 ? 0 : (2 * index / (count - 1)) - 1,
                  0,
                ),
                duration: handoffDuration(context, 280),
                curve: handoffCurve,
                child: FractionallySizedBox(
                  widthFactor: 1 / count,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selectedColor ?? context.appColors.surfaceCard,
                      borderRadius: BorderRadius.circular(radius - inset),
                      border: Border.all(
                        color: cs.onSurface.withValues(alpha: .10),
                        width: .5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          offset: Offset(0, 1),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          segmentRow,
        ],
      ),
    );
    return expand
        ? track
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicWidth(child: track),
          );
  }
}
