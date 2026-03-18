import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
  }) : assert(
         icon != null || builder != null,
         'Either icon or builder must be provided',
       );

  final IconData? icon;
  // Builder receives the current animated color to render custom child (e.g., SVG).
  final Widget Function(Color color)? builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double size;
  final EdgeInsets padding;
  final Color? color; // base color; defaults to theme onSurface
  final Color?
  pressedColor; // override pressed color; defaults to blend with primary
  final double? minSize; // min tap target (e.g., 44 for AppBar)
  final String? semanticLabel;
  final bool enabled;

  @override
  State<IosIconButton> createState() => _IosIconButtonState();
}

class _IosIconButtonState extends State<IosIconButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Respect provided color opacity when enabled; only dim when disabled.
    final Color base = () {
      if (widget.color != null) {
        final alpha = (widget.color!.a * 0.45).clamp(0.0, 1.0).toDouble();
        return widget.enabled
            ? widget.color!
            : widget.color!.withValues(alpha: alpha);
      }
      return theme.colorScheme.onSurface.withValues(
        alpha: widget.enabled ? 1 : 0.45,
      );
    }();
    // On press, shift icon color toward white (light theme) or black (dark theme)
    // to get a subtle lighter/gray look, unless overridden via pressedColor.
    final bool isDark = theme.brightness == Brightness.dark;
    final Color pressTarget =
        widget.pressedColor ??
        (Color.lerp(base, isDark ? Colors.black : Colors.white, 0.35) ?? base);
    final Color hoverTarget =
        Color.lerp(base, isDark ? Colors.black : Colors.white, 0.20) ?? base;
    final Color target = _pressed
        ? pressTarget
        : (_hovered ? hoverTarget : base);

    final child = TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      builder: (context, color, _) {
        final c = color ?? base;
        if (widget.builder != null) {
          return widget.builder!(c);
        }
        return Icon(
          widget.icon,
          size: widget.size,
          color: c,
          semanticLabel: widget.semanticLabel,
        );
      },
    );

    // Subtle hover background for desktop/web
    final Color bgTarget = _pressed
        ? (isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08))
        : (_hovered
              ? (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06))
              : Colors.transparent);

    final content = Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor:
            (widget.enabled &&
                (widget.onTap != null || widget.onLongPress != null))
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown:
              (widget.enabled &&
                  (widget.onTap != null || widget.onLongPress != null))
              ? (_) => setState(() => _pressed = true)
              : null,
          onTapUp:
              (widget.enabled &&
                  (widget.onTap != null || widget.onLongPress != null))
              ? (_) => setState(() => _pressed = false)
              : null,
          onTapCancel:
              (widget.enabled &&
                  (widget.onTap != null || widget.onLongPress != null))
              ? () => setState(() => _pressed = false)
              : null,
          onTap: widget.enabled ? widget.onTap : null,
          onLongPress: widget.enabled ? widget.onLongPress : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: bgTarget,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(padding: widget.padding, child: child),
          ),
        ),
      ),
    );

    if (widget.minSize != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: widget.minSize!,
          minHeight: widget.minSize!,
        ),
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
    this.longPressTimeout,
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
  final Duration? longPressTimeout;
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
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final Color base =
        widget.baseColor ?? (isDark ? Colors.white10 : cs.surface);
    final double k = widget.pressedBlendStrength ?? (isDark ? 0.14 : 0.12);
    final Color pressTarget =
        Color.lerp(base, isDark ? Colors.white : Colors.black, k) ?? base;
    final Color hoverTarget =
        Color.lerp(base, isDark ? Colors.white : Colors.black, k * 0.7) ?? base;
    final Color target = _pressed
        ? pressTarget
        : (_hovered ? hoverTarget : base);
    final double scale = _pressed ? (widget.pressedScale ?? 1.0) : 1.0;
    final Duration dur = widget.duration ?? const Duration(milliseconds: 200);

    final content = widget.padding == null
        ? widget.child
        : Padding(padding: widget.padding!, child: widget.child);

    return MouseRegion(
      cursor: (widget.onTap != null || widget.onLongPress != null)
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          TapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                TapGestureRecognizer.new,
                (recognizer) {
                  recognizer
                    ..onTapDown =
                        (widget.onTap != null || widget.onLongPress != null)
                        ? (_) => setState(() => _pressed = true)
                        : null
                    ..onTapUp =
                        (widget.onTap != null || widget.onLongPress != null)
                        ? (_) => setState(() => _pressed = false)
                        : null
                    ..onTapCancel =
                        (widget.onTap != null || widget.onLongPress != null)
                        ? () => setState(() => _pressed = false)
                        : null
                    ..onTap = widget.onTap == null
                        ? null
                        : () {
                            final sp = context.read<SettingsProvider>();
                            if (widget.haptics && sp.hapticsOnCardTap) {
                              Haptics.soft();
                            }
                            widget.onTap!.call();
                          };
                },
              ),
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(
                  duration: widget.longPressTimeout,
                ),
                (recognizer) {
                  recognizer
                    ..onLongPress = widget.onLongPress
                    ..onLongPressEnd = (widget.onLongPress != null)
                        ? (_) => setState(() => _pressed = false)
                        : null;
                },
              ),
        },
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
      ),
    );
  }
}
