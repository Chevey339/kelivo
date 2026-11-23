import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/media_creation.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/animations/status_animation.dart';
import '../../../shared/widgets/thinking_sheen.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';

int creationFakeProgress(Duration elapsed) {
  final fraction = elapsed.inMilliseconds.clamp(0, 1 << 32) / 45000;
  if (fraction >= 1) {
    return math.min(
      99,
      (90 + 10 * (1 - math.exp(-1.5 * (fraction - 1)))).floor(),
    );
  }
  const knots = [(0.0, 3), (.1, 25), (.55, 58), (.85, 88), (1.0, 90)];
  for (var index = 1; index < knots.length; index++) {
    final (after, finish) = knots[index];
    if (fraction <= after) {
      final (before, start) = knots[index - 1];
      return (start + (finish - start) * (fraction - before) / (after - before))
          .floor();
    }
  }
  return 90;
}

class CreationWaitingCard extends StatefulWidget {
  const CreationWaitingCard({
    super.key,
    required this.batch,
    this.progress,
    this.queueAhead = 0,
  });

  final GenerationBatchRow batch;
  final double? progress;
  final int queueAhead;

  @override
  State<CreationWaitingCard> createState() => _CreationWaitingCardState();
}

class _CreationWaitingCardState extends State<CreationWaitingCard>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _visible = true;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncTimer();
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant CreationWaitingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  void _syncTimer() {
    final needsTick =
        _foreground &&
        _visible &&
        widget.batch.startedAt != null &&
        widget.progress == null;
    if (needsTick) {
      _timer ??= Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final started = widget.batch.startedAt;
    final percent =
        widget.progress ??
        (started == null
            ? .03
            : creationFakeProgress(DateTime.now().difference(started)) / 100);
    final label = switch (widget.batch.status) {
      GenerationStatus.queued => l10n.creationQueuePosition(widget.queueAhead),
      GenerationStatus.downloading => l10n.creationDownloading,
      _ =>
        widget.batch.mode == MediaMode.image
            ? l10n.creationWaitingImage
            : l10n.creationWaitingVideo,
    };
    final animated =
        _foreground && _visible && !MediaQuery.disableAnimationsOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.surfaceFill.withValues(alpha: .58),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CreationDotField(progress: percent, paused: !animated),
            Positioned(
              left: 12,
              right: 12,
              top: 10,
              child: ThinkingSheen(
                enabled: animated,
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ),
            ),
            if (started != null &&
                widget.batch.status != GenerationStatus.queued)
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  height: 26,
                  constraints: const BoxConstraints(minWidth: 50),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: context.appColors.surfaceCard.withValues(alpha: .8),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: .45),
                      width: .5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.progress != null) ...[
                        DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.primary,
                          ),
                          child: const SizedBox.square(dimension: 6),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        NumberFormat.percentPattern(
                          l10n.localeName,
                        ).format(percent),
                        style: TextStyle(
                          color: cs.primary,
                          fontSize: 12,
                          fontWeight: AppFontWeights.semibold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CreationDotField extends StatelessWidget {
  const CreationDotField({
    super.key,
    required this.progress,
    this.thumbnail = false,
    this.paused = false,
  });

  final double progress;
  final bool thumbnail, paused;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: StatusAnimation(
        paused: paused || thumbnail,
        duration: const Duration(milliseconds: 1750),
        initialValue: .4,
        builder: (context, animation) => CustomPaint(
          painter: _Dots(
            color: cs.primary,
            progress: progress,
            spacing: thumbnail ? 6 : 40 / 3,
            animation: animation,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _Dots extends CustomPainter {
  _Dots({
    required this.color,
    required this.progress,
    required this.spacing,
    required this.animation,
  }) : super(repaint: animation);

  final Color color;
  final double progress, spacing;
  final ValueListenable<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final cycle = math.sin(animation.value * math.pi * 2);
    final first = Offset(size.width * (.31 + cycle * .09), size.height * .59);
    final second = Offset(size.width * (.71 - cycle * .06), size.height * .45);
    final scale = size.shortestSide * (.34 + progress * .23);
    final paint = Paint();
    for (double x = spacing; x < size.width - spacing / 2; x += spacing) {
      for (double y = spacing; y < size.height - spacing / 2; y += spacing) {
        final point = Offset(x, y);
        final one = math.max(0.0, 1 - (point - first).distance / scale);
        final two = math.max(0.0, 1 - (point - second).distance / (scale * .8));
        final strength = (one * one + two * two).clamp(0.0, 1.0);
        paint.color = color.withValues(alpha: .12 + strength * .65);
        canvas.drawCircle(point, .7 + strength * (spacing / 7), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Dots old) =>
      old.color != color ||
      old.progress != progress ||
      old.spacing != spacing ||
      old.animation != animation;
}
