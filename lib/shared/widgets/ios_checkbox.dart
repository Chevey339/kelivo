import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IosCheckbox extends StatefulWidget {
  const IosCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 22,
    this.activeColor,
    this.borderColor,
    this.checkmarkColor = CupertinoColors.white,
    this.semanticLabel,
    this.enableHaptics = true,
    this.hitTestSize = 32,
    this.borderWidth = 2.0,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  // Visual configuration
  final double size; // visual circle diameter
  final double hitTestSize; // tap target size
  final double borderWidth;
  final Color? activeColor;
  final Color? borderColor;
  final Color checkmarkColor;

  // Accessibility
  final String? semanticLabel;

  // UX
  final bool enableHaptics;

  @override
  State<IosCheckbox> createState() => _IosCheckboxState();
}

class _IosCheckboxState extends State<IosCheckbox> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);
    final materialTheme = Theme.of(context);
    final cs = materialTheme.colorScheme;
    final activeColor = widget.activeColor ?? CupertinoTheme.of(context).primaryColor;
    final borderColor = widget.borderColor ?? (brightness == Brightness.dark
        ? CupertinoColors.systemGrey3
        : CupertinoColors.systemGrey4);

    final bool enabled = widget.onChanged != null;
    final Color bgColor = widget.value ? activeColor : CupertinoColors.transparent;
    final Color effectiveBorderColor = widget.value ? activeColor : borderColor;
    // Dynamically compute check color similar to providers multi-select:
    // - If using theme primary, use `onPrimary` for best contrast.
    // - If a custom activeColor is provided, compute contrast by brightness.
    Color _contrastOn(Color bg) {
      final b = ThemeData.estimateBrightnessForColor(bg);
      return b == Brightness.dark ? CupertinoColors.white : CupertinoColors.black;
    }
    final bool usesThemePrimary = widget.activeColor == null;
    final Color computedOnPrimary = cs.onPrimary;
    final Color dynamicCheck = usesThemePrimary ? computedOnPrimary : _contrastOn(activeColor);
    final Color effectiveCheckColor = dynamicCheck.withOpacity((widget.onChanged != null) ? 1.0 : 0.5);

    final double visualSize = widget.size;
    final double tapSize = math.max(widget.hitTestSize, visualSize);

    // Smooth press feedback scale
    final double pressScale = _pressed && enabled ? 0.95 : 1.0;

    return Semantics(
      label: widget.semanticLabel,
      checked: widget.value,
      button: false,
      enabled: enabled,
      onTap: enabled ? _handleTap : null,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: enabled ? _handleTap : null,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        child: SizedBox(
          width: tapSize,
          height: tapSize,
          child: Center(
            child: AnimatedScale(
              scale: pressScale,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: visualSize,
                height: visualSize,
                decoration: BoxDecoration(
                  color: enabled ? bgColor : bgColor.withOpacity(0.5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: enabled ? effectiveBorderColor : effectiveBorderColor.withOpacity(0.5),
                    width: widget.borderWidth,
                  ),
                ),
                child: _AnimatedCheck(
                  show: widget.value,
                  color: effectiveCheckColor,
                  strokeWidth: math.max(2.0, widget.borderWidth + 0.5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap() {
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    widget.onChanged?.call(!widget.value);
  }
}

class _AnimatedCheck extends StatelessWidget {
  const _AnimatedCheck({
    required this.show,
    required this.color,
    required this.strokeWidth,
  });

  final bool show;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      tween: Tween<double>(begin: 0, end: show ? 1 : 0),
      builder: (context, t, child) {
        // Slight scale pop as it appears
        final scale = 0.9 + 0.1 * t;
        return Transform.scale(
          scale: scale,
          child: CustomPaint(
            painter: _CheckPainter(progress: t, color: color, strokeWidth: strokeWidth),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress, required this.color, required this.strokeWidth});

  final double progress; // 0..1
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Define a clean iOS-like check path
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0.28 * w, 0.52 * h)
      ..lineTo(0.46 * w, 0.70 * h)
      ..lineTo(0.75 * w, 0.34 * h);

    // Draw partial path based on progress
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final first = metrics.first;
    final extractLen = first.length * progress;
    final animated = first.extractPath(0, extractLen);
    canvas.drawPath(animated, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
