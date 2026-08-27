import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

/// Action-tile fill inside sheets. Transparent when layered sheet tiles
/// are off so frosted/translucent sheets stay correct.
Color sheetTileColor(BuildContext context) {
  var layered = false;
  try {
    layered = context.watch<SettingsProvider>().useLayeredSheetTiles;
  } catch (_) {}
  return layered ? context.appColors.surfaceCardFill : Colors.transparent;
}

bool showSheetTileDividers(BuildContext context) {
  try {
    return context.watch<SettingsProvider>().useLayeredSheetTiles;
  } catch (_) {
    return false;
  }
}

enum SectionCardVariant { standard, emphasized }

/// Shared iOS-style section card: one step above the page surface.
///
/// Use [children] for stacked rows or [child] for a single body. Optional
/// [padding], [radius], and [shadow] override the defaults.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.children,
    this.child,
    this.padding,
    this.radius,
    this.variant = SectionCardVariant.standard,
    this.shadow,
    this.dividers = false,
  }) : assert(
         children != null || child != null,
         'Provide either children or child',
       );

  final List<Widget>? children;
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final double? radius;
  final SectionCardVariant variant;
  final List<BoxShadow>? shadow;
  final bool dividers;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final cs = Theme.of(context).colorScheme;
    final emphasized = variant == SectionCardVariant.emphasized;
    final resolvedRadius = radius ?? (emphasized ? 18.0 : 12.0);
    final borderColor = emphasized ? colors.hairlineStrong : colors.hairline;
    final resolvedPadding =
        padding ??
        (child != null && children == null
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(vertical: 4));
    final body = children != null
        ? Column(
            children: [
              for (int i = 0; i < children!.length; i++) ...[
                if (dividers && i > 0)
                  Divider(
                    height: 10,
                    thickness: 0.6,
                    color: cs.outlineVariant.withValues(alpha: 0.18),
                  ),
                children![i],
              ],
            ],
          )
        : child!;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(resolvedRadius),
        border: Border.all(color: borderColor, width: 0.6),
        boxShadow: shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: resolvedPadding, child: body),
    );
  }
}
