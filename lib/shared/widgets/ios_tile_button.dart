import 'package:flutter/material.dart';
import '../../core/services/haptics.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

class IosTileButton extends StatefulWidget {
  const IosTileButton({
    super.key,
    required this.label,
    this.icon,
    this.leading,
    required this.onTap,
    this.enabled = true,
    this.fontSize = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
  }) : assert(
         (icon == null) != (leading == null),
         'Provide exactly one of icon or leading',
       );

  final String label;
  final IconData? icon;
  final Widget? leading;
  final VoidCallback onTap;
  final bool enabled;
  final double fontSize;
  final EdgeInsets padding;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;

  @override
  State<IosTileButton> createState() => _IosTileButtonState();
}

class _IosTileButtonState extends State<IosTileButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bool tinted = widget.backgroundColor != null;
    final Color tint = widget.backgroundColor ?? cs.primary;
    // Use a light primary-tinted background when tinted; otherwise the neutral grey tile
    final Color baseBg = tinted
        ? (isDark ? tint.withValues(alpha: 0.20) : tint.withValues(alpha: 0.12))
        : (context.appColors.surfaceFill);
    final overlay = cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.05);
    final pressedBg = Color.alphaBlend(overlay, baseBg);
    // Use primary (or provided foreground) for text/icon when tinted; otherwise neutral onSurface
    final Color defaultFg =
        widget.foregroundColor ??
        (tinted
            ? (widget.backgroundColor ?? cs.primary)
            : cs.onSurface.withValues(alpha: 0.9));
    final iconColor = defaultFg;
    final textColor = defaultFg;
    final slotColor = widget.enabled
        ? iconColor
        : iconColor.withValues(alpha: 0.45);
    // Keep a subtle same-hue border when tinted; otherwise use neutral outline
    final Color effectiveBorder =
        widget.borderColor ??
        (tinted
            ? tint.withValues(alpha: isDark ? 0.55 : 0.45)
            : cs.outlineVariant.withValues(alpha: 0.35));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: widget.enabled
          ? () => setState(() => _pressed = false)
          : null,
      onTap: () {
        if (!widget.enabled) return;
        Haptics.light();
        widget.onTap();
      },
      child: Material(
        type: MaterialType.transparency,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: _pressed && widget.enabled ? pressedBg : baseBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.enabled
                  ? effectiveBorder
                  : effectiveBorder.withValues(alpha: 0.45),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 2.0),
                  child: widget.leading != null
                      ? IconTheme.merge(
                          data: IconThemeData(size: 18, color: slotColor),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: Center(child: widget.leading),
                          ),
                        )
                      : Icon(widget.icon, size: 18, color: slotColor),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: widget.fontSize,
                    fontWeight: AppFontWeights.semibold,
                    color: widget.enabled
                        ? textColor
                        : textColor.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
