import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../icons/lucide_adapter.dart';
import '../shared/widgets/ios_tactile.dart';
import '../core/services/haptics.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'desktop_overlay_backdrop.dart';

/// Simple anchored context menu for desktop.
/// Shows a Material menu near the cursor or an anchor widget with a subtle animation.
class DesktopContextMenuItem {
  final IconData? icon;
  final String? svgAsset;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;
  final bool checked;
  final bool startsGroup;

  const DesktopContextMenuItem({
    this.icon,
    this.svgAsset,
    required this.label,
    this.subtitle,
    this.onTap,
    this.danger = false,
    this.checked = false,
    this.startsGroup = false,
  });
}

/// Show a context menu at the given global offset (e.g. from a right-click pointer position).
Future<void> showDesktopContextMenuAt(
  BuildContext context, {
  required Offset globalPosition,
  required List<DesktopContextMenuItem> items,
  Color? backgroundColor,
  bool compact = false,
}) async {
  // Match the navigator used by showGeneralDialog, including nested panes.
  final overlay = Navigator.of(context, rootNavigator: true).overlay;
  if (overlay == null) return;
  final overlayBox = overlay.context.findRenderObject() as RenderBox?;
  if (overlayBox == null) return;

  final cs = Theme.of(context).colorScheme;
  final local = overlayBox.globalToLocal(globalPosition);

  await showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierLabel: 'context-menu',
    barrierDismissible: true,
    barrierColor: cs.scrim.withValues(alpha: 0.06),
    pageBuilder: (ctx, _, __) {
      const double minMenuWidth = 160;
      const double maxMenuWidth = 360;
      final double estimatedWidth = _estimateMenuWidth(
        ctx,
        items,
        minMenuWidth,
        maxMenuWidth,
      );
      final screen = MediaQuery.sizeOf(ctx);
      final padding = MediaQuery.paddingOf(ctx);
      final menuWidth = math.min(
        estimatedWidth,
        math.max(0.0, screen.width - padding.horizontal - 16),
      );
      final double menuMaxHeight = screen.height * 0.5; // scroll if exceeds
      final double estMenuHeight = items
          .fold<double>(
            0,
            (sum, item) =>
                sum +
                _menuItemHeight(
                  ctx,
                  subtitle: item.subtitle,
                  compact: compact,
                ) +
                (item.startsGroup ? 9 : 0),
          )
          .clamp(44.0, menuMaxHeight);
      const double gap = 8; // offset from cursor
      final cs = Theme.of(ctx).colorScheme;
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final minX = padding.left + 8;
      final maxX = screen.width - padding.right - menuWidth - 8;
      final minY = padding.top + 8;
      final maxY = screen.height - padding.bottom - estMenuHeight - 8;

      double x = (local.dx + gap).clamp(minX, maxX);
      // Decide above/below based on available space
      final availableBelow = screen.height - padding.bottom - local.dy - 8;
      final availableAbove = local.dy - padding.top - 8;
      final placeAbove =
          availableBelow < estMenuHeight && availableAbove > availableBelow;
      double y = placeAbove
          ? (local.dy - gap - estMenuHeight).clamp(minY, maxY)
          : (local.dy + gap).clamp(minY, maxY);

      return Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned(
              left: x,
              top: y,
              child: _AnimatedFade(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: menuWidth,
                    maxWidth: menuWidth,
                  ),
                  child: IntrinsicWidth(
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isDark
                                ? cs.onSurface.withValues(alpha: 0.08)
                                : cs.outlineVariant.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: DesktopOverlayBackdrop(
                          sigma: 14,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color:
                                  backgroundColor ??
                                  cs.surface.withValues(alpha: 0.66),
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: menuMaxHeight,
                              ),
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final it in items) ...[
                                      if (it.startsGroup)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Divider(
                                            height: 9,
                                            thickness: 0.5,
                                            color: cs.outlineVariant.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                        ),
                                      _GlassMenuItem(
                                        compact: compact,
                                        icon: it.icon,
                                        svgAsset: it.svgAsset,
                                        label: it.label,
                                        subtitle: it.subtitle,
                                        danger: it.danger,
                                        checked: it.checked,
                                        onTap: it.onTap == null
                                            ? null
                                            : () {
                                                Navigator.of(ctx).pop();
                                                it.onTap!();
                                              },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

double _menuItemHeight(
  BuildContext context, {
  String? subtitle,
  required bool compact,
}) {
  if (subtitle != null) return 60;
  if (!compact) return 44;
  return math.max(36, MediaQuery.textScalerOf(context).scale(20) + 12);
}

double _estimateMenuWidth(
  BuildContext context,
  List<DesktopContextMenuItem> items,
  double minW,
  double maxW,
) {
  // Base paddings: 12 left/right; icon 18 + spacing 10 if present
  double maxText = 0;
  final textStyle = Theme.of(context).textTheme.bodyMedium!.copyWith(
    fontSize: 14.5,
    color: Theme.of(context).colorScheme.onSurface,
    decoration: TextDecoration.none,
    fontWeight: AppFontWeights.medium,
  );
  for (final it in items) {
    final tp = TextPainter(
      text: TextSpan(
        text: it.label,
        style: textStyle,
        children: [
          if (it.subtitle != null)
            TextSpan(
              text: '\n${it.subtitle}',
              style: textStyle.copyWith(fontSize: 11.5),
            ),
        ],
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: it.subtitle == null ? 1 : 2,
    )..layout(maxWidth: maxW);
    double width = 12 /*left*/ + tp.width + 12 /*right*/;
    if (it.icon != null || it.svgAsset != null) {
      width += 18 /*icon*/ + 10 /*gap*/;
    }
    if (it.checked) {
      width += 8 /*gap*/ + 16 /*check*/;
    }
    if (width > maxText) maxText = width;
  }
  return (maxText.ceilToDouble() + 4).clamp(minW, maxW);
}

/// Show a menu anchored to a widget key (appears above/below the widget depending on space).
Future<void> showDesktopAnchoredMenu(
  BuildContext context, {
  required GlobalKey anchorKey,
  required List<DesktopContextMenuItem> items,
  Offset offset = Offset.zero,
}) async {
  final rb = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  if (rb == null) return;
  final topLeft = rb.localToGlobal(Offset.zero);
  final size = rb.size;
  // Center the menu horizontally under the avatar (neutralize internal gap)
  const double minMenuWidth = 160;
  const double maxMenuWidth = 360;
  const double gap = 8; // should match showDesktopContextMenuAt gap
  final double menuWidth = _estimateMenuWidth(
    context,
    items,
    minMenuWidth,
    maxMenuWidth,
  );
  final anchorBottomCenter = topLeft + Offset(size.width / 2, size.height);
  final adjusted = anchorBottomCenter - Offset(menuWidth / 2 + gap, 0);
  await showDesktopContextMenuAt(
    context,
    globalPosition: adjusted + offset,
    items: items,
  );
}

class _AnimatedFade extends StatefulWidget {
  const _AnimatedFade({required this.child});
  final Widget child;
  @override
  State<_AnimatedFade> createState() => _AnimatedFadeState();
}

class _AnimatedFadeState extends State<_AnimatedFade> {
  double _opacity = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      opacity: _opacity,
      child: widget.child,
    );
  }
}

class _GlassMenuItem extends StatefulWidget {
  const _GlassMenuItem({
    this.icon,
    this.svgAsset,
    required this.label,
    this.subtitle,
    this.onTap,
    this.danger = false,
    this.checked = false,
    this.compact = false,
  });
  final IconData? icon;
  final String? svgAsset;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;
  final bool checked;
  final bool compact;

  @override
  State<_GlassMenuItem> createState() => _GlassMenuItemState();
}

class _GlassMenuItemState extends State<_GlassMenuItem> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = widget.danger
        ? Theme.of(context).colorScheme.error
        : cs.onSurface;
    final ic = widget.danger
        ? Theme.of(context).colorScheme.error
        : cs.onSurface.withValues(alpha: 0.9);
    final bg = _hover && widget.onTap != null
        ? (cs.onSurface.withValues(alpha: isDark ? 0.08 : 0.05))
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      child: IosCardPress(
        focusable: true,
        borderRadius: BorderRadius.zero,
        baseColor: Colors.transparent,
        onTap: widget.onTap == null
            ? null
            : () {
                try {
                  Haptics.light();
                } catch (_) {}
                widget.onTap?.call();
              },
        child: Container(
          height: _menuItemHeight(
            context,
            subtitle: widget.subtitle,
            compact: widget.compact,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(color: bg),
          child: Row(
            children: [
              if (widget.icon != null || widget.svgAsset != null) ...[
                if (widget.icon != null)
                  Icon(widget.icon, size: 18, color: ic)
                else
                  SvgPicture.asset(
                    widget.svgAsset!,
                    width: 18,
                    height: 18,
                    colorFilter: ColorFilter.mode(ic, BlendMode.srcIn),
                  ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontWeight: AppFontWeights.medium,
                        fontSize: 14.5,
                        color: fg,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11.5,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.checked) ...[
                const SizedBox(width: 8),
                Icon(Lucide.Check, size: 16, color: cs.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
