import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme/app_font_weights.dart';
import '../../diagnostic_service.dart';

/// iOS-Storage-style ring chart for cache hit rate.
///
/// Cached share is drawn in [CacheDiagnosticService.kCached] and uncached
/// in [CacheDiagnosticService.kUncached]. The percentage in the centre
/// shows the hit rate (0-100%).
class CacheRingChart extends StatelessWidget {
  const CacheRingChart({
    super.key,
    required this.hitRate,
    required this.totalTokens,
    required this.cachedTokens,
    this.size = 180,
    this.strokeWidth = 18,
  });

  /// 0..1
  final double hitRate;
  final int totalTokens;
  final int cachedTokens;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = (hitRate.clamp(0, 1) * 100).round();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring (uncached)
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: 1,
              color: CacheDiagnosticService.kUncached,
              background: cs.onSurface.withValues(alpha: 0.06),
              strokeWidth: strokeWidth,
              drawBackground: true,
            ),
          ),
          // Foreground cached arc
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: hitRate.clamp(0, 1),
              color: CacheDiagnosticService.kCached,
              background: Colors.transparent,
              strokeWidth: strokeWidth,
              drawBackground: false,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: size * 0.22,
                  fontWeight: AppFontWeights.strong,
                  color: cs.onSurface,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '命中率',
                style: TextStyle(
                  fontSize: size * 0.075,
                  color: cs.onSurface.withValues(alpha: 0.6),
                  fontWeight: AppFontWeights.medium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.background,
    required this.strokeWidth,
    required this.drawBackground,
  });

  final double progress;
  final Color color;
  final Color background;
  final double strokeWidth;
  final bool drawBackground;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (drawBackground) {
      final bgPaint = Paint()
        ..color = background
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, radius, bgPaint);
    }

    if (progress <= 0) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, progress * 2 * math.pi, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.background != background ||
      old.strokeWidth != strokeWidth;
}
