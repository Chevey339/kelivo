import 'package:flutter/material.dart';

import '../animations/status_animation.dart';

class ThinkingSheenPalette {
  const ThinkingSheenPalette({required this.base, required this.highlight});

  final Color base;
  final Color highlight;

  factory ThinkingSheenPalette.fromColor(Color color, {required bool isDark}) {
    final opaque = _opaque(color);
    return ThinkingSheenPalette(
      base: opaque,
      // Light mode lifts toward white. Dark ink is already bright, so the
      // moving band has to go the other way or it disappears into the text.
      highlight: Color.lerp(
        opaque,
        isDark ? Colors.black : Colors.white,
        isDark ? 0.82 : 0.78,
      )!,
    );
  }

  factory ThinkingSheenPalette.fromTheme(BuildContext context) {
    final theme = Theme.of(context);
    return ThinkingSheenPalette.fromColor(
      theme.colorScheme.secondary,
      isDark: theme.brightness == Brightness.dark,
    );
  }
}

class ThinkingSheen extends StatelessWidget {
  const ThinkingSheen({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || MediaQuery.maybeDisableAnimationsOf(context) == true) {
      return child;
    }
    final palette = ThinkingSheenPalette.fromTheme(context);
    final base = palette.base;
    final peak = Color.lerp(base, palette.highlight, 0.8144)!;
    final mid = Color.lerp(base, peak, 0.5)!;
    final colors = [base, base, mid, peak, mid, base, base];

    // Keep the moving highlight on the label even inside a full-width row.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      heightFactor: 1,
      child: RepaintBoundary(
        child: StatusAnimation(
          duration: const Duration(milliseconds: 2286),
          initialValue: 0.42,
          builder: (context, progress) => AnimatedBuilder(
            animation: progress,
            builder: (context, child) => ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(
                begin: const Alignment(-1.0, -0.18),
                end: const Alignment(1.0, 0.18),
                colors: colors,
                stops: const [0, .24, .4116, .5, .5884, .76, 1],
                transform: _SlideGradientTransform(progress.value),
              ).createShader(bounds),
              child: child,
            ),
            child: child,
          ),
        ),
      ),
    );
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

Color _opaque(Color color) => color.withValues(alpha: 1);
