import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/home/services/context_usage_service.dart';
import '../../l10n/app_localizations.dart';
import '../../core/utils/token_format.dart';
import '../../theme/app_semantic_colors.dart';
import 'ios_tactile.dart';

const double kContextUsageRingSize = 16;
const double kContextUsageRingStroke = 2;
const double kContextUsageRingHitSize = 32;

Color contextUsageColor(
  ColorScheme cs,
  ContextUsageSnapshot? snapshot, {
  Color? warning,
}) {
  final grey = cs.outline;
  if (snapshot == null || snapshot.state == ContextUsageState.none) {
    return grey;
  }

  final ratio = snapshot.ratio;
  final Color base;
  if (ratio == null) {
    base = grey;
  } else if (ratio > 0.90) {
    base = cs.error;
  } else if (ratio > 0.75) {
    base = warning ?? const Color(0xFFF57C00);
  } else {
    base = cs.onSurface.withValues(alpha: 0.70);
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
    this.strokeWidth = kContextUsageRingStroke,
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
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);
    if (ratio == null) return;
    final progress = Paint()
      ..isAntiAlias = true
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
    this.size = kContextUsageRingSize,
    this.hitSize = kContextUsageRingHitSize,
    this.strokeWidth = kContextUsageRingStroke,
  });

  final ContextUsageSnapshot? snapshot;
  final VoidCallback onTap;
  final double size;
  final double hitSize;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final progressColor = contextUsageColor(
      cs,
      snapshot,
      warning: context.appColors.warning,
    );
    final ratio = snapshot?.ratio;
    final hasArc = ratio != null && snapshot?.state != ContextUsageState.none;
    final tooltip = _tooltip(l10n, snapshot);
    final targetRatio = (ratio ?? 0).clamp(0.0, 1.0);

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: IosCardPress(
        onTap: onTap,
        haptics: false,
        borderRadius: BorderRadius.circular(999),
        padding: EdgeInsets.zero,
        baseColor: Colors.transparent,
        pressedBlendStrength: 0,
        child: SizedBox.square(
          dimension: hitSize,
          child: Center(
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(begin: 0, end: targetRatio),
              builder: (context, animatedRatio, _) {
                return CustomPaint(
                  size: Size.square(size),
                  painter: ContextUsageRingPainter(
                    trackColor: cs.onSurface.withValues(alpha: 0.18),
                    progressColor: progressColor,
                    ratio: hasArc ? animatedRatio : null,
                    strokeWidth: strokeWidth,
                  ),
                );
              },
            ),
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
