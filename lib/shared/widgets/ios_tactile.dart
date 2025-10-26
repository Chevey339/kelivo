import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/haptics.dart';

/// iOS-style icon button: no ripple, color tween on press, no scale.
class IosIconButton extends StatefulWidget {
  const IosIconButton({
    super.key,
    this.icon,
    this.builder,
    this.onTap,
    this.onLongPress,
    this.size = 20,
    this.padding = const EdgeInsets.all(6),
    this.color,
    this.pressedColor,
    this.minSize,
    this.semanticLabel,
    this.enabled = true,
  }) : assert(icon != null || builder != null, 'Either icon or builder must be provided');

  final IconData? icon;
  // Builder receives the current animated color to render custom child (e.g., SVG).
  final Widget Function(Color color)? builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double size;
  final EdgeInsets padding;
  final Color? color; // base color; defaults to theme onSurface
  final Color? pressedColor; // override pressed color; defaults to blend with primary
  final double? minSize; // min tap target (e.g., 44 for AppBar)
  final String? semanticLabel;
  final bool enabled;

  @override
  State<IosIconButton> createState() => _IosIconButtonState();
}

class _IosIconButtonState extends State<IosIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Respect provided color opacity when enabled; only dim when disabled.
    final Color base = () {
      if (widget.color != null) {
        return widget.enabled
            ? widget.color!
            : widget.color!.withOpacity(widget.color!.opacity * 0.45);
      }
      return theme.colorScheme.onSurface.withOpacity(widget.enabled ? 1 : 0.45);
    }();
    // On press, shift icon color toward white (light theme) or black (dark theme)
    // to get a subtle lighter/gray look, unless overridden via pressedColor.
    final bool isDark = theme.brightness == Brightness.dark;
    final Color pressTarget = widget.pressedColor ?? (Color.lerp(base, isDark ? Colors.black : Colors.white, 0.35) ?? base);
    final Color target = _pressed ? pressTarget : base;

    final child = TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      builder: (context, color, _) {
        final c = color ?? base;
        if (widget.builder != null) {
          return widget.builder!(c);
        }
        return Icon(widget.icon, size: widget.size, color: c, semanticLabel: widget.semanticLabel);
      },
    );

    final content = Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (widget.enabled && (widget.onTap != null || widget.onLongPress != null)) ? (_) => setState(() => _pressed = true) : null,
        onTapUp: (widget.enabled && (widget.onTap != null || widget.onLongPress != null)) ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: (widget.enabled && (widget.onTap != null || widget.onLongPress != null)) ? () => setState(() => _pressed = false) : null,
        onTap: widget.enabled ? widget.onTap : null,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        child: Padding(
          padding: widget.padding,
          child: child,
        ),
      ),
    );

    if (widget.minSize != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(minWidth: widget.minSize!, minHeight: widget.minSize!),
        child: Center(child: content),
      );
    }
    return content;
  }
}

/// iOS-style card press effect: background color tween on press, no ripple, no scale.
class IosCardPress extends StatefulWidget {
  const IosCardPress({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.baseColor,
    this.pressedBlendStrength,
    this.padding,
    this.pressedScale,
    this.duration,
    this.haptics = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final Color? baseColor;
  // 0..1; how much to blend towards surface tint on press
  final double? pressedBlendStrength;
  final EdgeInsetsGeometry? padding;
  // Optional subtle scale when pressed (e.g., 0.98). Defaults to 1.0 (no scale).
  final double? pressedScale;
  // Optional custom animation duration for color/scale tween.
  final Duration? duration;
  // Whether to perform a soft haptic on tap (also gated by settings/global toggles)
  final bool haptics;

  @override
  State<IosCardPress> createState() => _IosCardPressState();
}

class _IosCardPressState extends State<IosCardPress> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final Color base = widget.baseColor ?? (isDark ? Colors.white10 : cs.surface);
    final double k = widget.pressedBlendStrength ?? (isDark ? 0.14 : 0.12);
    final Color pressTarget = Color.lerp(base, isDark ? Colors.white : Colors.black, k) ?? base;
    final Color target = _pressed ? pressTarget : base;
    final double scale = _pressed ? (widget.pressedScale ?? 1.0) : 1.0;
    final Duration dur = widget.duration ?? const Duration(milliseconds: 200);

    final content = widget.padding == null ? widget.child : Padding(padding: widget.padding!, child: widget.child);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (widget.onTap != null || widget.onLongPress != null) ? (_) => setState(() => _pressed = true) : null,
      onTapUp: (widget.onTap != null || widget.onLongPress != null) ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: (widget.onTap != null || widget.onLongPress != null) ? () => setState(() => _pressed = false) : null,
      onTap: widget.onTap == null
          ? null
          : () {
              final sp = context.read<SettingsProvider>();
              if (widget.haptics && sp.hapticsOnCardTap) Haptics.soft();
              widget.onTap!.call();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: scale,
        duration: dur,
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: dur,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: target,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          ),
          child: content,
        ),
      ),
    );
  }
}
