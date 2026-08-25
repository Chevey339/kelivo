import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/haptics.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

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
        (Color.lerp(base, theme.colorScheme.onSurface, 0.35) ?? base);
    final Color hoverTarget =
        Color.lerp(base, theme.colorScheme.onSurface, 0.20) ?? base;
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
        ? (Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: isDark ? 0.12 : 0.08))
        : (_hovered
              ? (Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06))
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
    this.border,
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
  final BoxBorder? border;
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
  late Map<Type, GestureRecognizerFactory> _gestures;

  @override
  void initState() {
    super.initState();
    _gestures = {
      TapGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
            TapGestureRecognizer.new,
            _configureTap,
          ),
      LongPressGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(duration: widget.longPressTimeout),
            _configureLongPress,
          ),
    };
  }

  @override
  void didUpdateWidget(covariant IosCardPress oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasInteractive =
        oldWidget.onTap != null || oldWidget.onLongPress != null;
    if (wasInteractive && !_interactive) {
      _hovered = false;
      _pressed = false;
    }
    if (oldWidget.onTap != widget.onTap ||
        oldWidget.onLongPress != widget.onLongPress ||
        oldWidget.longPressTimeout != widget.longPressTimeout) {
      _gestures = {
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              TapGestureRecognizer.new,
              _configureTap,
            ),
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () =>
                  LongPressGestureRecognizer(duration: widget.longPressTimeout),
              _configureLongPress,
            ),
      };
    }
  }

  bool get _interactive => widget.onTap != null || widget.onLongPress != null;

  void _configureTap(TapGestureRecognizer recognizer) {
    if (!_interactive) {
      recognizer.onTapDown = null;
      recognizer.onTapUp = null;
      recognizer.onTapCancel = null;
      recognizer.onTap = null;
      return;
    }
    recognizer.onTapDown = (_) {
      setState(() => _pressed = true);
    };
    recognizer.onTapUp = (_) {
      setState(() => _pressed = false);
    };
    recognizer.onTapCancel = () {
      setState(() => _pressed = false);
    };
    recognizer.onTap = widget.onTap == null ? null : _handleTap;
  }

  void _configureLongPress(LongPressGestureRecognizer recognizer) {
    if (widget.onLongPress == null) {
      recognizer.onLongPress = null;
      recognizer.onLongPressEnd = null;
      return;
    }
    recognizer.onLongPress = () {
      widget.onLongPress?.call();
    };
    recognizer.onLongPressEnd = (_) {
      if (mounted) setState(() => _pressed = false);
    };
  }

  void _handleTap() {
    if (widget.onTap == null) return;
    if (widget.haptics && context.read<SettingsProvider>().hapticsOnCardTap) {
      Haptics.soft();
    }
    widget.onTap!.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color base = widget.baseColor ?? (context.appColors.surfaceCard);
    final double k = widget.pressedBlendStrength ?? (isDark ? 0.14 : 0.12);
    final Color pressTarget = _pressWash(base, theme.colorScheme.onSurface, k);
    final Color hoverTarget = _pressWash(
      base,
      theme.colorScheme.onSurface,
      k * 0.7,
    );
    final Color target = _pressed
        ? pressTarget
        : (_hovered ? hoverTarget : base);
    final double scale = _pressed ? (widget.pressedScale ?? 1.0) : 1.0;
    final Duration dur = widget.duration ?? const Duration(milliseconds: 200);
    final omitScale = (widget.pressedScale ?? 1.0) == 1.0;
    final omitColor = widget.pressedBlendStrength == 0;

    final padding = widget.padding;
    final content = padding == null || padding == EdgeInsets.zero
        ? widget.child
        : Padding(padding: padding, child: widget.child);

    Widget painted = content;
    if (omitColor) {
      painted = DecoratedBox(
        decoration: BoxDecoration(
          color: base,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          border: widget.border,
        ),
        child: content,
      );
    } else {
      painted = AnimatedContainer(
        duration: dur,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: target,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          border: widget.border,
        ),
        child: content,
      );
    }
    if (!omitScale) {
      painted = AnimatedScale(
        scale: scale,
        duration: dur,
        curve: Curves.easeOutCubic,
        child: painted,
      );
    }

    return MouseRegion(
      cursor: _interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) {
        if (!_interactive) return;
        setState(() => _hovered = true);
      },
      onExit: (_) {
        if (!_hovered) return;
        setState(() => _hovered = false);
      },
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: _gestures,
        child: painted,
      ),
    );
  }

  /// Overlay a wash onto [base]. Lerping from [Colors.transparent] can keep
  /// alpha at 0 in the wide-gamut color space; tint the destination instead.
  static Color _pressWash(Color base, Color onSurface, double strength) {
    if (base == Colors.transparent) {
      return onSurface.withValues(alpha: strength);
    }
    return Color.lerp(base, onSurface, strength) ?? base;
  }
}
