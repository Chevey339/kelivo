import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart' as lucide;
import 'package:provider/provider.dart';

import '../../core/providers/tts_provider.dart';
import '../../core/services/tts/tts_playback_models.dart';
import '../../l10n/app_localizations.dart';
import 'ios_tactile.dart';

const Duration _ttsFloatingSurfaceAnimationDuration = Duration(
  milliseconds: 220,
);

class TtsFloatingPlayer extends StatefulWidget {
  const TtsFloatingPlayer({super.key});

  @override
  State<TtsFloatingPlayer> createState() => _TtsFloatingPlayerState();
}

class _TtsFloatingPlayerState extends State<TtsFloatingPlayer> {
  static const double _horizontalMargin = 12;
  static const double _topMargin = 12;
  static const double _initialTopOffset = 68;
  static const double _collapsedWidth = 120;
  static const double _expandedWidth = 232;
  static const double _surfaceHorizontalPadding = 3;
  static const double _collapsedContentWidth = 112;
  static const double _expandedControlsWidth = 112;

  Offset? _position;
  bool _expanded = false;
  bool _wasVisible = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();

    return Consumer<TtsProvider>(
      builder: (context, tts, _) {
        final state = tts.playbackState;
        final visible = state.isPlayerVisible;
        if (visible && !_wasVisible) {
          _expanded = false;
        }
        _wasVisible = visible;
        return IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            child: visible
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final safeTop = MediaQuery.paddingOf(context).top;
                      final availableWidth = math.max(
                        0.0,
                        constraints.maxWidth - _horizontalMargin * 2,
                      );
                      final targetWidth = math
                          .min(
                            _expanded ? _expandedWidth : _collapsedWidth,
                            availableWidth,
                          )
                          .toDouble();

                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: targetWidth),
                        duration: _ttsFloatingSurfaceAnimationDuration,
                        curve: Curves.easeOutCubic,
                        builder: (context, animatedWidth, _) {
                          final width = animatedWidth
                              .clamp(0.0, availableWidth)
                              .toDouble();
                          final height = constraints.maxHeight;
                          final fallback = Offset(
                            _horizontalMargin,
                            safeTop + _initialTopOffset,
                          );
                          final pos = _clampPosition(
                            _position ?? fallback,
                            constraints.maxWidth,
                            height,
                            width,
                            safeTop,
                          );

                          return Stack(
                            children: [
                              Positioned(
                                left: pos.dx,
                                top: pos.dy,
                                width: width,
                                child: _FloatingPlayerSurface(
                                  l10n: l10n,
                                  state: state,
                                  tts: tts,
                                  expanded: _expanded,
                                  onToggleExpanded: _toggleExpanded,
                                  onDrag: (delta) {
                                    setState(() {
                                      _position = _clampPosition(
                                        pos + delta,
                                        constraints.maxWidth,
                                        height,
                                        width,
                                        safeTop,
                                      );
                                    });
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  )
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  Offset _clampPosition(
    Offset position,
    double maxWidth,
    double maxHeight,
    double width,
    double safeTop,
  ) {
    final minY = safeTop + _topMargin;
    final maxX = math.max(
      _horizontalMargin,
      maxWidth - width - _horizontalMargin,
    );
    final maxY = math.max(minY, maxHeight - 64);
    return Offset(
      position.dx.clamp(_horizontalMargin, maxX).toDouble(),
      position.dy.clamp(minY, maxY).toDouble(),
    );
  }
}

class _FloatingPlayerSurface extends StatelessWidget {
  const _FloatingPlayerSurface({
    required this.l10n,
    required this.state,
    required this.tts,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onDrag,
  });

  final AppLocalizations l10n;
  final TtsPlaybackState state;
  final TtsProvider tts;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<Offset> onDrag;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        final showPlayIcon =
            state.status == TtsPlaybackStatus.paused ||
            state.status == TtsPlaybackStatus.ended;
        final playTooltip = state.status == TtsPlaybackStatus.ended
            ? l10n.ttsFloatingReplayTooltip
            : showPlayIcon
            ? l10n.ttsFloatingResumeTooltip
            : l10n.ttsFloatingPauseTooltip;
        final progress = state.progress;
        final chunkProgress = state.totalChunks > 0
            ? (state.currentChunkIndex / state.totalChunks)
                  .clamp(0.0, 1.0)
                  .toDouble()
            : 0.0;
        final expansion =
            ((constraints.maxWidth - _TtsFloatingPlayerState._collapsedWidth) /
                    (_TtsFloatingPlayerState._expandedWidth -
                        _TtsFloatingPlayerState._collapsedWidth))
                .clamp(0.0, 1.0)
                .toDouble();
        final controlsWidth = math
            .min(
              _TtsFloatingPlayerState._expandedControlsWidth * expansion,
              math.max(
                0.0,
                constraints.maxWidth -
                    _TtsFloatingPlayerState._surfaceHorizontalPadding * 2 -
                    _TtsFloatingPlayerState._collapsedContentWidth,
              ),
            )
            .toDouble();

        return Semantics(
          key: const ValueKey('ttsFloatingPlayerSurface'),
          container: true,
          label: l10n.ttsFloatingPlayerLabel,
          value:
              '${_formatDuration(state.position)} / '
              '${_formatDuration(state.duration)}',
          child: MouseRegion(
            cursor: SystemMouseCursors.move,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (details) => onDrag(details.delta),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.14),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal:
                          _TtsFloatingPlayerState._surfaceHorizontalPadding,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CircularPlayButton(
                          tooltip: playTooltip,
                          icon: showPlayIcon
                              ? lucide.LucideIcons.play
                              : lucide.LucideIcons.pause,
                          progress: progress,
                          chunkProgress: chunkProgress,
                          onTap: tts.togglePause,
                        ),
                        const SizedBox(width: 2),
                        _ToolIcon(
                          tooltip: l10n.ttsFloatingCloseTooltip,
                          icon: lucide.LucideIcons.x,
                          onTap: tts.stop,
                        ),
                        const SizedBox(width: 2),
                        _AnimatedControlSlot(
                          width: controlsWidth,
                          opacity: expansion,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ToolIcon(
                                tooltip: l10n.ttsFloatingRewind15Tooltip,
                                icon: lucide.LucideIcons.rewind,
                                onTap: tts.seekBackward,
                              ),
                              const SizedBox(width: 2),
                              _SpeedButton(
                                tooltip: l10n.ttsFloatingSpeedTooltip,
                                speed: state.speed,
                                onTap: tts.cyclePlaybackSpeed,
                              ),
                              const SizedBox(width: 2),
                              _ToolIcon(
                                tooltip: l10n.ttsFloatingForward15Tooltip,
                                icon: lucide.LucideIcons.fastForward,
                                onTap: tts.seekForward,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 2),
                        _ToolIcon(
                          tooltip: expanded
                              ? l10n.ttsFloatingCollapseTooltip
                              : l10n.ttsFloatingExpandTooltip,
                          icon: expanded
                              ? lucide.LucideIcons.chevronLeft
                              : lucide.LucideIcons.chevronRight,
                          onTap: onToggleExpanded,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration value) {
    final totalSeconds = value.inSeconds.clamp(0, 24 * 60 * 60);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _AnimatedControlSlot extends StatelessWidget {
  const _AnimatedControlSlot({
    required this.width,
    required this.opacity,
    required this.child,
  });

  final double width;
  final double opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (width <= 0.5 && opacity <= 0.01) {
      return SizedBox(width: width);
    }

    return IgnorePointer(
      ignoring: opacity < 0.98,
      child: SizedBox(
        width: width,
        height: 32,
        child: ClipRect(
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0).toDouble(),
            child: OverflowBox(
              alignment: Alignment.centerRight,
              minWidth: _TtsFloatingPlayerState._expandedControlsWidth,
              maxWidth: _TtsFloatingPlayerState._expandedControlsWidth,
              minHeight: 32,
              maxHeight: 32,
              child: SizedBox(
                width: _TtsFloatingPlayerState._expandedControlsWidth,
                height: 32,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({
    required this.tooltip,
    required this.speed,
    required this.onTap,
  });

  final String tooltip;
  final double speed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 44,
        height: 32,
        child: IosCardPress(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          baseColor: cs.primaryContainer.withValues(alpha: 0.44),
          pressedBlendStrength: 0.16,
          haptics: false,
          padding: EdgeInsets.zero,
          child: Center(
            child: Text(
              'x${speed.toStringAsFixed(1)}',
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  const _ToolIcon({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 32,
        child: IosCardPress(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          baseColor: cs.surfaceContainerHighest.withValues(alpha: 0.38),
          pressedBlendStrength: 0.18,
          haptics: false,
          padding: EdgeInsets.zero,
          child: Icon(
            icon,
            size: 18,
            color: cs.onSurface.withValues(alpha: 0.86),
            semanticLabel: tooltip,
          ),
        ),
      ),
    );
  }
}

class _CircularPlayButton extends StatelessWidget {
  const _CircularPlayButton({
    required this.tooltip,
    required this.icon,
    required this.progress,
    required this.chunkProgress,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final double progress;
  final double chunkProgress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        key: const ValueKey('ttsCircularProgressButton'),
        dimension: 42,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _TtsProgressRingPainter(
                  progress: progress,
                  chunkProgress: chunkProgress,
                  trackColor: cs.outlineVariant.withValues(alpha: 0.32),
                  progressColor: cs.primary,
                  chunkColor: cs.tertiary,
                ),
              ),
            ),
            SizedBox.square(
              dimension: 32,
              child: IosCardPress(
                onTap: onTap,
                borderRadius: BorderRadius.circular(999),
                baseColor: cs.primaryContainer.withValues(alpha: 0.72),
                pressedBlendStrength: 0.18,
                haptics: false,
                padding: EdgeInsets.zero,
                child: Icon(
                  icon,
                  size: 19,
                  color: cs.onPrimaryContainer,
                  semanticLabel: tooltip,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TtsProgressRingPainter extends CustomPainter {
  const _TtsProgressRingPainter({
    required this.progress,
    required this.chunkProgress,
    required this.trackColor,
    required this.progressColor,
    required this.chunkColor,
  });

  final double progress;
  final double chunkProgress;
  final Color trackColor;
  final Color progressColor;
  final Color chunkColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerRadius = (size.shortestSide - 4) / 2;
    final innerRadius = outerRadius - 5;
    final start = -math.pi / 2;
    final outerRect = Rect.fromCircle(center: center, radius: outerRadius);
    final innerRect = Rect.fromCircle(center: center, radius: innerRadius);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..color = progressColor;
    final chunkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = chunkColor.withValues(alpha: 0.82);

    canvas.drawCircle(center, outerRadius, trackPaint);
    canvas.drawArc(
      outerRect,
      start,
      progress.clamp(0.0, 1.0) * math.pi * 2,
      false,
      progressPaint,
    );
    canvas.drawArc(
      innerRect,
      start,
      chunkProgress.clamp(0.0, 1.0) * math.pi * 2,
      false,
      chunkPaint,
    );
  }

  @override
  bool shouldRepaint(_TtsProgressRingPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        chunkProgress != oldDelegate.chunkProgress ||
        trackColor != oldDelegate.trackColor ||
        progressColor != oldDelegate.progressColor ||
        chunkColor != oldDelegate.chunkColor;
  }
}
