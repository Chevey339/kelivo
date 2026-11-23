import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/services/media/adapters/native_image_size.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/sliding_segmented_tabs.dart';
import '../../../theme/app_semantic_colors.dart';

class CreationRatioGlyph extends StatelessWidget {
  const CreationRatioGlyph(this.value, {super.key, this.size = 24, this.color});
  final String value;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final ink = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    if (value == 'auto') {
      return Icon(LucideIcons.proportions, size: size * .8, color: ink);
    }
    final dimensions = imageDimensions(value, 1024);
    final ratio = dimensions.width / dimensions.height;
    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: Container(
        width: size * math.min(ratio, 1),
        height: size * math.min(1 / ratio, 1),
        decoration: BoxDecoration(
          border: Border.all(color: ink, width: 1.4),
          borderRadius: BorderRadius.circular(size * .12),
        ),
      ),
    );
  }
}

class CreationRatioGrid extends StatelessWidget {
  const CreationRatioGrid({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
  });
  final List<String> values;
  final String selected;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final cols = math.min(4, values.length);
    final index = values.indexOf(selected);
    final rowHeight = math.max(
      66.0,
      MediaQuery.textScalerOf(context).scale(12.5) + 44,
    );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.appColors.surfaceFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final cell = box.maxWidth / cols;
          return SizedBox(
            height: (values.length / cols).ceil() * rowHeight,
            child: Stack(
              children: [
                if (index >= 0)
                  AnimatedPositionedDirectional(
                    duration: handoffDuration(context, 280),
                    curve: handoffCurve,
                    start: (index % cols) * cell,
                    top: (index ~/ cols) * rowHeight,
                    width: cell,
                    height: rowHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: context.appColors.surfaceCard,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: cs.onSurface.withValues(alpha: .11),
                          width: .5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                for (final (i, value) in values.indexed)
                  PositionedDirectional(
                    start: (i % cols) * cell,
                    top: (i ~/ cols) * rowHeight,
                    width: cell,
                    height: rowHeight,
                    child: Semantics(
                      checked: i == index,
                      inMutuallyExclusiveGroup: true,
                      child: IosCardPress(
                        focusable: true,
                        onTap: () => onChanged(value),
                        baseColor: Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        duration: handoffDuration(context, 140),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox.square(
                              dimension: 24,
                              child: Center(
                                child: CreationRatioGlyph(
                                  value,
                                  color: i == index
                                      ? cs.onSurface
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              value == 'auto'
                                  ? AppLocalizations.of(context)!.creationAuto
                                  : value,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: i == index
                                    ? cs.onSurface
                                    : cs.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
