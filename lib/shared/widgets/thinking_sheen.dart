import 'dart:math' as math;

import 'package:flutter/material.dart';

class ThinkingSheenParams {
  const ThinkingSheenParams({
    required this.speed,
    required this.spread,
    required this.intensity,
  });

  final double speed;
  final double spread;
  final double intensity;
}

const thinkingSheenDefaults = ThinkingSheenParams(
  speed: 1.05,
  spread: 0.52,
  intensity: 0.68,
);

class ThinkingSheenPalette {
  const ThinkingSheenPalette({required this.base, required this.highlight});

  final Color base;
  final Color highlight;

  factory ThinkingSheenPalette.fromColor(Color color, {required bool isDark}) {
    final opaque = _opaque(color);
    return ThinkingSheenPalette(
      base: opaque,
      highlight: Color.lerp(opaque, Colors.white, isDark ? 0.82 : 0.78)!,
    );
  }

  factory ThinkingSheenPalette.fromTheme(BuildContext context, {Color? color}) {
    final theme = Theme.of(context);
    return ThinkingSheenPalette.fromColor(
      color ?? theme.colorScheme.secondary,
      isDark: theme.brightness == Brightness.dark,
    );
  }
}

class ThinkingSheen extends StatelessWidget {
  const ThinkingSheen({
    super.key,
    required this.child,
    this.enabled = true,
    this.color,
    this.params = thinkingSheenDefaults,
    this.palette,
    this.paused = false,
  });

  final Widget child;
  final bool enabled;
  final Color? color;
  final ThinkingSheenParams params;
  final ThinkingSheenPalette? palette;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return _ThinkingSheenAnimation(
      params: params,
      palette: palette ?? ThinkingSheenPalette.fromTheme(context, color: color),
      paused: paused || reduceMotion,
      child: child,
    );
  }
}

class _ThinkingSheenAnimation extends StatefulWidget {
  const _ThinkingSheenAnimation({
    required this.params,
    required this.palette,
    required this.paused,
    required this.child,
  });

  final ThinkingSheenParams params;
  final ThinkingSheenPalette palette;
  final bool paused;
  final Widget child;

  @override
  State<_ThinkingSheenAnimation> createState() =>
      _ThinkingSheenAnimationState();
}

class _ThinkingSheenAnimationState extends State<_ThinkingSheenAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _scaledDuration(
        const Duration(milliseconds: 2400),
        widget.params.speed,
      ),
    );
    _syncPlayback();
  }

  @override
  void didUpdateWidget(covariant _ThinkingSheenAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.params.speed != widget.params.speed) {
      _controller.duration = _scaledDuration(
        const Duration(milliseconds: 2400),
        widget.params.speed,
      );
      if (!widget.paused) {
        _controller.repeat();
      }
    }
    if (oldWidget.paused != widget.paused) {
      _syncPlayback();
    }
  }

  void _syncPlayback() {
    if (widget.paused) {
      _controller.stop();
      if (_controller.value == 0) {
        _controller.value = 0.42;
      }
    } else {
      _controller.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = _opaque(widget.palette.base);
    final peak = _opaque(
      Color.lerp(
        base,
        widget.palette.highlight,
        0.42 + widget.params.intensity * 0.58,
      )!,
    );
    final mid = _opaque(Color.lerp(base, peak, 0.5)!);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: const Alignment(-1.0, -0.18),
                end: const Alignment(1.0, 0.18),
                colors: [base, base, mid, peak, mid, base, base],
                stops: _sheenStops(widget.params.spread),
                transform: _SlideGradientTransform(_controller.value),
              ).createShader(bounds);
            },
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _SlideGradientTransform extends GradientTransform {
  const _SlideGradientTransform(this.progress);

  final double progress;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (progress * 2.0 - 1.0),
      0,
      0,
    );
  }
}

List<double> _sheenStops(double spread) {
  final outer = spread.clamp(0.2, 0.9) / 2;
  final inner = outer * 0.34;
  return [
    0,
    (0.5 - outer).clamp(0.02, 0.42),
    (0.5 - inner).clamp(0.16, 0.48),
    0.5,
    (0.5 + inner).clamp(0.52, 0.84),
    (0.5 + outer).clamp(0.58, 0.98),
    1,
  ];
}

Duration _scaledDuration(Duration base, double speed) {
  final millis = (base.inMilliseconds / speed.clamp(0.35, 3)).round();
  return Duration(milliseconds: math.max(420, millis));
}

Color _opaque(Color color) => color.withValues(alpha: 1);
