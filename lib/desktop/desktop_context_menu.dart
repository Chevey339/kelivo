import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../shared/widgets/ios_tactile.dart';
import '../core/services/haptics.dart';

/// Simple anchored context menu for desktop.
/// Shows a Material menu near the cursor or an anchor widget with a subtle animation.
class DesktopContextMenuItem {
  final IconData? icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  const DesktopContextMenuItem({
    this.icon,
    required this.label,
    this.onTap,
    this.danger = false,
  });
}

/// Show a context menu at the given global offset (e.g. from a right-click pointer position).
Future<void> showDesktopContextMenuAt(
  BuildContext context, {
  required Offset globalPosition,
  required List<DesktopContextMenuItem> items,
}) async {
  final overlay = Overlay.of(context);
  final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
  if (overlay == null || overlayBox == null) return;

  const double minMenuWidth = 160;
  const double maxMenuWidth = 360;
  final double menuWidth = _estimateMenuWidth(context, items, minMenuWidth, maxMenuWidth);
  final screen = overlayBox.size;
  final double menuMaxHeight = screen.height * 0.5; // scroll if exceeds
  final double estMenuHeight = (items.length * 44.0).clamp(44.0, menuMaxHeight);
  const double gap = 8; // offset from cursor
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final padding = MediaQuery.of(context).padding;
  final minX = padding.left + 8;
  final maxX = screen.width - padding.right - menuWidth - 8;
  final minY = padding.top + 8;
  final maxY = screen.height - padding.bottom - estMenuHeight - 8;

  final local = overlayBox.globalToLocal(globalPosition);
  double x = (local.dx + gap).clamp(minX, maxX);
  // Decide above/below based on available space
  final availableBelow = screen.height - padding.bottom - local.dy - 8;
  final availableAbove = local.dy - padding.top - 8;
  final placeAbove = availableBelow < estMenuHeight && availableAbove > availableBelow;
  double y = placeAbove
      ? (local.dy - gap - estMenuHeight).clamp(minY, maxY)
      : (local.dy + gap).clamp(minY, maxY);

  await showGeneralDialog<void>(
    context: context,
    barrierLabel: 'context-menu',
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.06),
    pageBuilder: (ctx, _, __) {
      return Material(
        type: MaterialType.transparency,
        child: Stack(children: [
          Positioned(
            left: x,
            top: y,
            child: _AnimatedFade(
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: menuWidth, maxWidth: menuWidth),
                child: IntrinsicWidth(
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isDark ? Colors.white.withOpacity(0.08) : cs.outlineVariant.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1C1C1E).withOpacity(0.66) : Colors.white.withOpacity(0.66),
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: menuMaxHeight),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final it in items)
                                    _GlassMenuItem(
                                      icon: it.icon,
                                      label: it.label,
                                      danger: it.danger,
                                      onTap: () {
                                        Navigator.of(ctx).pop();
                                        it.onTap?.call();
                                      },
                                    ),
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
        ]),
      );
    },
  );
}

double _estimateMenuWidth(
  BuildContext context,
  List<DesktopContextMenuItem> items,
  double minW,
  double maxW,
) {
  // Base paddings: 12 left/right; icon 18 + spacing 10 if present
  double maxText = 0;
  final textStyle = TextStyle(
    fontSize: 14.5,
    color: Theme.of(context).colorScheme.onSurface,
    decoration: TextDecoration.none,
    fontWeight: FontWeight.w500,
  );
  for (final it in items) {
    final tp = TextPainter(
      text: TextSpan(text: it.label, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxW);
    double width = 12 /*left*/ + tp.width + 12 /*right*/;
    if (it.icon != null) {
      width += 18 /*icon*/ + 10 /*gap*/;
    }
    if (width > maxText) maxText = width;
  }
  return maxText.clamp(minW, maxW);
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
  final double menuWidth = _estimateMenuWidth(context, items, minMenuWidth, maxMenuWidth);
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

class _GlassMenuItem extends StatelessWidget {
  const _GlassMenuItem({this.icon, required this.label, this.onTap, this.danger = false});
  final IconData? icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = danger ? Colors.red.shade600 : cs.onSurface;
    final ic = danger ? Colors.red.shade600 : cs.onSurface.withOpacity(0.9);
    return IosCardPress(
      borderRadius: BorderRadius.zero,
      baseColor: Colors.transparent,
      onTap: () {
        try { Haptics.light(); } catch (_) {}
        onTap?.call();
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: ic),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(label, style: TextStyle(fontSize: 14.5, color: fg, decoration: TextDecoration.none))),
          ],
        ),
      ),
    );
  }
}
