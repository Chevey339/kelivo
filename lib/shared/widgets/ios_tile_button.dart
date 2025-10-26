import 'package:flutter/material.dart';
import '../../core/services/haptics.dart';

class IosTileButton extends StatefulWidget {
  const IosTileButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.fontSize = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
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
        ? (isDark ? tint.withOpacity(0.20) : tint.withOpacity(0.12))
        : (isDark ? Colors.white10 : const Color(0xFFF2F3F5));
    final overlay = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);
    final pressedBg = Color.alphaBlend(overlay, baseBg);
    // Use primary (or provided foreground) for text/icon when tinted; otherwise neutral onSurface
    final Color defaultFg = widget.foregroundColor ?? (tinted ? (widget.backgroundColor ?? cs.primary) : cs.onSurface.withOpacity(0.9));
    final iconColor = defaultFg;
    final textColor = defaultFg;
    // Keep a subtle same-hue border when tinted; otherwise use neutral outline
    final Color effectiveBorder = widget.borderColor ?? (
      tinted
        ? tint.withOpacity(isDark ? 0.55 : 0.45)
        : cs.outlineVariant.withOpacity(0.35)
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
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
            color: _pressed ? pressedBg : baseBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: effectiveBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 2.0),
                child: Icon(widget.icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
