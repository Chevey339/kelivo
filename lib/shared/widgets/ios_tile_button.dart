import 'package:flutter/material.dart';
import '../../core/services/haptics.dart';

class IosTileButton extends StatefulWidget {
  const IosTileButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = true,
    this.fontSize = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
  });

  final String label;
  final IconData icon;
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
        : (isDark ? Colors.white10 : const Color(0xFFF2F3F5));
    final overlay = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);
    final pressedBg = Color.alphaBlend(overlay, baseBg);
    // Use primary (or provided foreground) for text/icon when tinted; otherwise neutral onSurface
    final Color defaultFg =
        widget.foregroundColor ??
        (tinted
            ? (widget.backgroundColor ?? cs.primary)
            : cs.onSurface.withValues(alpha: 0.9));
    final iconColor = defaultFg;
    final textColor = defaultFg;
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 2.0),
                child: Icon(
                  widget.icon,
                  size: 18,
                  color: widget.enabled
                      ? iconColor
                      : iconColor.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w600,
                  color: widget.enabled
                      ? textColor
                      : textColor.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
