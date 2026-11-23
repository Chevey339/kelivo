import 'dart:math' as math;

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
    this.fitLabels = false,
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

  /// Give longer labels their intrinsic width before sharing the remaining space.
  final bool fitLabels;
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
    Widget segment(int i, SegmentedTab tab, {bool wrapped = false}) =>
        Semantics(
          label: tab.label,
          checked: i == index,
          inMutuallyExclusiveGroup: true,
          child: IosCardPress(
            focusable: true,
            haptics: false,
            duration: handoffDuration(context, 140),
            baseColor: wrapped && i == index
                ? selectedColor ?? context.appColors.surfaceCard
                : Colors.transparent,
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
                    if (tab.icon != null && !iconOnly) const SizedBox(width: 5),
                    if (!iconOnly || tab.icon == null)
                      Flexible(
                        child: Text(
                          tab.label,
                          maxLines: wrapped ? null : 1,
                          overflow: wrapped
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
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
        );
    Widget buildTrack({List<double>? widths, double? trackHeight}) {
      final segmentRow = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, tab) in tabs.indexed)
            if (widths == null)
              Expanded(child: segment(i, tab))
            else
              SizedBox(width: widths[i], child: segment(i, tab)),
        ],
      );
      final selected = index >= 0 && index < count;
      final thumb = DecoratedBox(
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
      );
      return Container(
        height: trackHeight ?? height,
        padding: EdgeInsets.all(inset),
        decoration: BoxDecoration(
          color: backgroundColor ?? context.appColors.surfaceFill,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            if (selected && widths != null)
              AnimatedPositionedDirectional(
                duration: handoffDuration(context, 280),
                curve: handoffCurve,
                start: widths.take(index).fold<double>(0, (a, b) => a + b),
                width: widths[index],
                top: 0,
                bottom: 0,
                child: thumb,
              )
            else if (selected)
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
                    child: thumb,
                  ),
                ),
              ),
            segmentRow,
          ],
        ),
      );
    }

    if (!fitLabels) {
      return expand
          ? buildTrack()
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: IntrinsicWidth(child: buildTrack()),
            );
    }
    final style = DefaultTextStyle.of(context).style.merge(
      TextStyle(fontSize: compact ? 12.5 : 13, fontWeight: FontWeight.w600),
    );
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    );
    var trackHeight = height;
    final minimum = <double>[];
    for (final tab in tabs) {
      painter.text = TextSpan(text: tab.label, style: style);
      painter.layout();
      final hasLabel = !iconOnly || tab.icon == null;
      final labelWidth = hasLabel ? painter.width.ceilToDouble() : 0.0;
      final iconWidth = tab.icon == null
          ? 0.0
          : (compact ? 14.0 : 16.0) + (hasLabel ? 5.0 : 0.0);
      minimum.add(math.max(30, labelWidth + iconWidth + (compact ? 8 : 12)));
      if (hasLabel) {
        trackHeight = math.max(trackHeight, painter.height + 2 * inset + 4);
      }
    }
    painter.dispose();
    final total = minimum.reduce((a, b) => a + b);
    return LayoutBuilder(
      builder: (context, constraints) {
        final inner = math.max(0.0, constraints.maxWidth - 2 * inset);
        final share = inner / count;
        final extra = math.max(0.0, (inner - total) / count);
        final equal = minimum.every((w) => w <= share);
        final widths = [for (final w in minimum) equal ? share : w + extra];
        if (total <= inner) {
          return buildTrack(widths: widths, trackHeight: trackHeight);
        }
        const gap = 4.0;
        final widest = minimum.reduce(math.max);
        final columns = ((inner + gap) / (widest + gap)).floor().clamp(
          1,
          count,
        );
        final cellWidth = (inner - (columns - 1) * gap) / columns;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor ?? context.appColors.surfaceFill,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Padding(
            padding: EdgeInsets.all(inset),
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final (i, tab) in tabs.indexed)
                  SizedBox(
                    width: cellWidth,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: trackHeight - 2 * inset,
                      ),
                      child: segment(i, tab, wrapped: true),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
