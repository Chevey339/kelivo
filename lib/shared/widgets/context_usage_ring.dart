import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../features/home/services/context_usage_service.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_font_weights.dart';
import '../../core/utils/token_format.dart';
import 'ios_tactile.dart';

Color contextUsageColor(ColorScheme cs, ContextUsageSnapshot? snapshot) {
  final grey = cs.outline;
  if (snapshot == null || snapshot.state == ContextUsageState.none) {
    return grey;
  }

  final ratio = snapshot.ratio;
  final Color base;
  if (ratio == null) {
    base = grey;
  } else if (ratio > 0.95) {
    base = cs.error;
  } else if (ratio >= 0.8) {
    base = cs.tertiary;
  } else {
    base = cs.primary;
  }

  return switch (snapshot.state) {
    ContextUsageState.stale => base.withValues(alpha: 0.55),
    ContextUsageState.computing => base.withValues(alpha: 0.5),
    ContextUsageState.exact ||
    ContextUsageState.estimated ||
    ContextUsageState.none => base,
  };
}

class ContextUsageRingPainter extends CustomPainter {
  const ContextUsageRingPainter({
    required this.trackColor,
    required this.progressColor,
    required this.ratio,
    this.strokeWidth = 2.6,
  });

  final Color trackColor;
  final Color progressColor;
  final double? ratio;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);
    if (ratio == null) return;
    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = progressColor;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      ratio!.clamp(0.0, 1.0) * math.pi * 2,
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(ContextUsageRingPainter oldDelegate) {
    return trackColor != oldDelegate.trackColor ||
        progressColor != oldDelegate.progressColor ||
        ratio != oldDelegate.ratio ||
        strokeWidth != oldDelegate.strokeWidth;
  }
}

class ContextUsageRing extends StatelessWidget {
  const ContextUsageRing({
    super.key,
    required this.snapshot,
    required this.onTap,
    this.size = 28,
  });

  final ContextUsageSnapshot? snapshot;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final progressColor = contextUsageColor(cs, snapshot);
    final ratio = snapshot?.ratio;
    final hasArc = ratio != null && snapshot?.state != ContextUsageState.none;
    final showLabel = size >= 28 && hasArc;
    final tooltip = _tooltip(l10n, snapshot);
    final painter = ContextUsageRingPainter(
      trackColor: cs.outline.withValues(alpha: 0.35),
      progressColor: progressColor,
      ratio: hasArc ? ratio : null,
    );

    Widget ring = CustomPaint(painter: painter, size: Size.square(size));
    if (snapshot?.state == ContextUsageState.computing) {
      ring = ring
          .animate(onPlay: (controller) => controller.repeat())
          .rotate(duration: 1400.ms)
          .fade(begin: 0.55, end: 1, duration: 800.ms);
    }

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: IosCardPress(
        onTap: onTap,
        haptics: false,
        borderRadius: BorderRadius.circular(999),
        padding: EdgeInsets.zero,
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ring,
              if (showLabel)
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${(ratio * 100).round()}%',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: AppFontWeights.semibold,
                        height: 1,
                        color: progressColor,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _tooltip(
    AppLocalizations l10n,
    ContextUsageSnapshot? snapshot,
  ) {
    final window = snapshot?.contextWindow;
    if (snapshot == null || window == null || window <= 0) {
      return l10n.contextUsageNoWindow;
    }
    final percent = ((snapshot.ratio ?? 0) * 100).round();
    return l10n.contextUsageUsedWindow(
      formatTokenCount(snapshot.usedTokens),
      formatTokenCount(window),
      percent,
    );
  }
}
