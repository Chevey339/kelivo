import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../core/services/haptics.dart';
import '../../theme/app_font_weights.dart';

/// Discrete-step slider for reasoning effort presets.
///
/// Purely presentational: the parent owns [position] and animates it; this
/// widget reports raw drag positions and snap targets. Position changes repaint
/// the track and translate the thumb without rebuilding or laying out the group.
class EffortSlider extends StatelessWidget {
  const EffortSlider({
    super.key,
    required this.position,
    required this.stopCount,
    required this.stopKeys,
    required this.dragging,
    required this.onDragStart,
    required this.onDragCancel,
    required this.onPositionChanged,
    required this.onSnap,
    this.animatedTrack = false,
    this.compact = false,
  });

  final ValueListenable<double> position;
  final int stopCount;
  final List<String> stopKeys;
  final bool dragging;
  final VoidCallback onDragStart;
  final VoidCallback onDragCancel;
  final ValueChanged<double> onPositionChanged;
  final ValueChanged<int> onSnap;
  final bool animatedTrack;
  final bool compact;

  double get _height => compact ? 32 : 56;
  double get _thumbRadius => compact ? 14 : 19;
  // Stops sit exactly one thumb radius from each end, so at the extremes the
  // thumb is flush with the track edge and fully covers the fill — no
  // visible track/fill sliver beside the thumb.
  double get _stopInset => compact ? _thumbRadius - 1 : _thumbRadius;

  double _indexForDx(double dx, double width) {
    final span = width - 2 * _stopInset;
    if (span <= 0 || stopCount <= 1) return 0;
    return (((dx - _stopInset) / span) * (stopCount - 1))
        .clamp(0.0, (stopCount - 1).toDouble())
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) {
            onDragStart();
            onPositionChanged(_indexForDx(details.localPosition.dx, width));
          },
          onHorizontalDragUpdate: (details) =>
              onPositionChanged(_indexForDx(details.localPosition.dx, width)),
          onHorizontalDragEnd: (_) => onSnap(position.value.round()),
          onHorizontalDragCancel: onDragCancel,
          onTapUp: (details) {
            final index = _indexForDx(details.localPosition.dx, width).round();
            onSnap(index);
          },
          child: SizedBox(
            height: _height,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                _EffortTrack(
                  position: position,
                  stopCount: stopCount,
                  stopInset: _stopInset,
                  primary: cs.primary,
                  trackColor: cs.onSurface.withValues(alpha: 0.10),
                  upcomingDotColor: cs.onSurface.withValues(alpha: 0.25),
                  size: Size(width, _height),
                  compact: compact,
                  animated: animatedTrack,
                ),
                Positioned.fill(
                  child: Row(
                    children: [
                      for (final key in stopKeys)
                        Expanded(child: SizedBox(key: ValueKey(key))),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Flow(
                      clipBehavior: Clip.none,
                      delegate: _ThumbPosition(
                        position: position,
                        stopCount: stopCount,
                        radius: _thumbRadius,
                        inset: _stopInset,
                      ),
                      children: [
                        AnimatedScale(
                          scale: dragging ? 1.14 : 1.0,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutBack,
                          child: RepaintBoundary(
                            child: Container(
                              width: _thumbRadius * 2,
                              height: _thumbRadius * 2,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: compact
                                    ? Border.all(
                                        color: cs.onSurface.withValues(
                                          alpha: 0.12,
                                        ),
                                        width: 0.5,
                                      )
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: compact ? 0.1 : 0.25,
                                    ),
                                    blurRadius: compact ? 2 : 10,
                                    offset: compact
                                        ? Offset.zero
                                        : const Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
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
      },
    );
  }
}

/// Pointer movement changes the paint transform without a widget build/layout.
class _ThumbPosition extends FlowDelegate {
  _ThumbPosition({
    required this.position,
    required this.stopCount,
    required this.radius,
    required this.inset,
  }) : super(repaint: position);
  final ValueListenable<double> position;
  final int stopCount;
  final double radius;
  final double inset;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      BoxConstraints.tight(Size.square(radius * 2));

  @override
  void paintChildren(FlowPaintingContext context) {
    final fraction = stopCount <= 1 ? 0.0 : position.value / (stopCount - 1);
    context.paintChild(
      0,
      transform: Matrix4.translationValues(
        inset - radius + (context.size.width - inset * 2) * fraction,
        (context.size.height - radius * 2) / 2,
        0,
      ),
    );
  }

  @override
  bool shouldRepaint(_ThumbPosition old) =>
      old.position != position ||
      old.stopCount != stopCount ||
      old.radius != radius ||
      old.inset != inset;
}

class _EffortTrack extends StatefulWidget {
  const _EffortTrack({
    required this.position,
    required this.stopCount,
    required this.stopInset,
    required this.primary,
    required this.trackColor,
    required this.upcomingDotColor,
    required this.size,
    required this.animated,
    required this.compact,
  });
  final ValueListenable<double> position;
  final int stopCount;
  final double stopInset;
  final Color primary, trackColor, upcomingDotColor;
  final Size size;
  final bool animated, compact;

  @override
  State<_EffortTrack> createState() => _EffortTrackState();
}

class _EffortTrackState extends State<_EffortTrack> {
  late double _startFraction;
  bool _returning = false;
  // Mounting an already accelerated picker shows its settled state. Only an
  // off -> on change while mounted plays the tick-to-particle transition.
  bool _animateFastEntry = false;

  double get _fraction => widget.stopCount <= 1
      ? 0
      : widget.position.value / (widget.stopCount - 1);

  @override
  void initState() {
    super.initState();
    _startFraction = _fraction;
  }

  @override
  void didUpdateWidget(_EffortTrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated && !oldWidget.animated) {
      _startFraction = _fraction;
      _returning = false;
      _animateFastEntry = true;
    } else if (!widget.animated && oldWidget.animated) {
      _returning = true;
      _animateFastEntry = false;
    }
  }

  Widget _paint(AnimationController? clock, {bool returning = false}) =>
      CustomPaint(
        size: widget.size,
        painter: _SliderPainter(
          position: widget.position,
          stopCount: widget.stopCount,
          stopInset: widget.stopInset,
          primary: widget.primary,
          trackColor: widget.trackColor,
          upcomingDotColor: widget.upcomingDotColor,
          particleClock: clock,
          startFraction: _startFraction,
          animateFastEntry: _animateFastEntry,
          returning: returning,
          compact: widget.compact,
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _returning = false;
      _animateFastEntry = false;
      return _paint(null);
    }
    if (widget.animated) {
      return Animate(
        key: const ValueKey('fast-track-motion'),
        onPlay: (controller) => controller.repeat(),
        effects: [_ParticleTrackEffect((clock) => _paint(clock))],
        child: const SizedBox(),
      );
    }
    if (_returning) {
      return Animate(
        key: const ValueKey('fast-track-return'),
        onComplete: (_) {
          if (mounted) setState(() => _returning = false);
        },
        effects: [
          _ParticleTrackEffect(
            (clock) => _paint(clock, returning: true),
            returning: true,
          ),
        ],
        child: const SizedBox(),
      );
    }
    return _paint(null);
  }
}

/// flutter_animate owns the clock; only the painter listens to its ticks.
class _ParticleTrackEffect extends Effect<double> {
  _ParticleTrackEffect(this.builder, {bool returning = false})
    : super(
        duration: Duration(milliseconds: returning ? 350 : 1900),
        curve: Curves.linear,
      );
  final Widget Function(AnimationController) builder;

  @override
  Widget build(
    BuildContext context,
    Widget child,
    AnimationController controller,
    EffectEntry entry,
  ) => builder(controller);
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({
    required this.position,
    required this.stopCount,
    required this.stopInset,
    required this.primary,
    required this.trackColor,
    required this.upcomingDotColor,
    this.particleClock,
    required this.startFraction,
    required this.animateFastEntry,
    this.returning = false,
    required this.compact,
  }) : super(repaint: Listenable.merge([position, particleClock]));

  final ValueListenable<double> position;
  final int stopCount;
  final double stopInset;
  final Color primary;
  final Color trackColor;
  final Color upcomingDotColor;
  final AnimationController? particleClock;
  final double startFraction;
  final bool animateFastEntry;
  final bool returning;
  final bool compact;

  double get _trackHeight => compact ? 24 : 34;
  double get _dotRadius => compact ? 2 : 3.5;

  // Matched to the supplied fast-track-particles chunk: 14 fixed-height
  // paths, staggered over 1.9 s, independent speeds, opacity and size.
  static double _hash(int index, int salt) {
    final value = math.sin((index + 1) * 12.9898 + salt * 78.233) * 43758.5453;
    return value - value.floorToDouble();
  }

  static final _particles = List.generate(
    14,
    (i) => (
      duration: 1.9 / (1 + (_hash(i, 21) - 0.5) * 0.4),
      delay: i * 1.9 / 14,
      y: 0.12 + _hash(i, 23) * 0.76,
      opacity: 0.4 + _hash(i, 11) * 0.6,
      radius: 1.5 * (0.5 + _hash(i, 12) * 0.45),
    ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final value = position.value;
    final seconds =
        (particleClock?.lastElapsedDuration?.inMicroseconds ?? 0) /
        Duration.microsecondsPerSecond;
    final t = stopCount <= 1 ? 0.0 : value / (stopCount - 1);
    final thumbX = stopInset + (size.width - 2 * stopInset) * t;
    final cy = size.height / 2;
    final trackRect = Rect.fromLTWH(
      0,
      cy - _trackHeight / 2,
      size.width,
      _trackHeight,
    );
    final trackRRect = RRect.fromRectAndRadius(
      trackRect,
      Radius.circular(_trackHeight / 2),
    );

    canvas.drawRRect(trackRRect, Paint()..color = trackColor);

    if (thumbX > 0) {
      final fillRect = Rect.fromLTWH(
        0,
        cy - _trackHeight / 2,
        thumbX.clamp(0.0, size.width),
        _trackHeight,
      );
      final fillPaint = Paint()..color = primary;
      if (!compact) {
        fillPaint.shader = LinearGradient(
          colors: [primary.withValues(alpha: 0.5), primary],
        ).createShader(fillRect);
      }
      canvas.save();
      canvas.clipRRect(trackRRect);
      canvas.drawRect(fillRect, fillPaint);
      canvas.restore();
    }

    if (stopCount > 1) {
      final passedPaint = Paint()
        ..color = Colors.white.withValues(alpha: compact ? 0.38 : 0.9);
      final upcomingPaint = Paint()..color = upcomingDotColor;
      for (var i = 0; i < stopCount; i++) {
        final x =
            stopInset + (size.width - 2 * stopInset) * (i / (stopCount - 1));
        final passed = i <= value.round();
        var dotX = x;
        var scale = 1.0;
        var opacity = 1.0;
        if (passed && particleClock != null) {
          if (returning) {
            final progress = (seconds / 0.35).clamp(0.0, 1.0);
            dotX += 10 * (1 - Curves.easeOut.transform(progress));
            scale = 0.75 + 0.25 * Curves.easeInOut.transform(progress);
            opacity = (seconds / 0.2).clamp(0.0, 1.0);
          } else {
            if (!animateFastEntry || seconds >= 1.2) continue;
            final progress = ((seconds - 0.05) / 1.15).clamp(0.0, 1.0);
            dotX -= 85 * Curves.easeInOut.transform(progress);
            scale =
                1 -
                0.25 *
                    const Cubic(
                      0.23,
                      1,
                      0.32,
                      1,
                    ).transform((seconds / 0.8).clamp(0.0, 1.0));
            opacity =
                1 -
                Curves.easeInOut.transform(
                  ((seconds - 0.7) / 0.5).clamp(0.0, 1.0),
                );
          }
        }
        canvas.save();
        canvas.clipRRect(trackRRect);
        canvas.drawCircle(
          Offset(dotX, cy),
          _dotRadius * scale,
          passed
              ? (passedPaint
                  ..color = Colors.white.withValues(
                    alpha: (compact ? 0.3 : 0.9) * opacity,
                  ))
              : upcomingPaint,
        );
        canvas.restore();
      }
    }
    if (particleClock != null && !returning) {
      canvas.save();
      canvas.clipRRect(trackRRect);
      canvas.clipRect(
        Rect.fromLTRB(0, trackRect.top, thumbX, trackRect.bottom),
      );
      final dotPaint = Paint();
      final glowPaint = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      // Seed every staggered path on the first frame when reopening in Fast.
      // This advances only the particle clock, not an entry/return animation.
      final particleSeconds = seconds + (animateFastEntry ? 0 : 3);
      for (final particle in _particles) {
        final age =
            particleSeconds -
            particle.delay +
            particle.duration * (1 - startFraction);
        if (age < 0) continue;
        final progress = (age / particle.duration) % 1;
        final fade = math.min(
          1.0,
          math.min(progress / 0.08, (1 - progress) / 0.08),
        );
        final opacity = particle.opacity * fade;
        final point = Offset(
          (1 - progress) * size.width,
          trackRect.top + particle.y * _trackHeight,
        );
        glowPaint.color = Colors.white.withValues(alpha: 0.34 * opacity);
        dotPaint.color = Colors.white.withValues(alpha: 0.72 * opacity);
        canvas.drawCircle(point, particle.radius, glowPaint);
        canvas.drawCircle(point, particle.radius, dotPaint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SliderPainter old) =>
      old.compact != compact ||
      old.particleClock != particleClock ||
      old.startFraction != startFraction ||
      old.animateFastEntry != animateFastEntry ||
      old.returning != returning ||
      old.position != position ||
      old.stopCount != stopCount ||
      old.stopInset != stopInset ||
      old.primary != primary ||
      old.trackColor != trackColor ||
      old.upcomingDotColor != upcomingDotColor;
}

/// Text that crossfades between values while its width tweens smoothly.
class AnimatedWidthText extends StatelessWidget {
  const AnimatedWidthText({
    super.key,
    required this.text,
    required this.style,
    required this.switchKey,
  });

  final String text;
  final TextStyle style;
  final Key switchKey;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    final painter = TextPainter(
      text: TextSpan(text: text, style: effectiveStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: scaler,
    )..layout();
    final textWidth = painter.width;
    painter.dispose();
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: textWidth),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, width, child) => SizedBox(width: width, child: child),
      child: ClipRect(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => ClipRect(
            child: SlideTransition(
              position: animation.drive(
                Tween(begin: const Offset(0, 0.5), end: Offset.zero),
              ),
              child: FadeTransition(opacity: animation, child: child),
            ),
          ),
          child: Text(
            text,
            key: switchKey,
            style: style,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
          ),
        ),
      ),
    );
  }
}

class EffortSliderStop {
  const EffortSliderStop({
    required this.stopKey,
    required this.icon,
    required this.iconKey,
    required this.title,
    this.subtitle,
  });

  final String stopKey;
  final Widget icon;
  final Object iconKey;
  final String title;
  final String? subtitle;
}

class EffortSliderLabelPill extends StatelessWidget {
  const EffortSliderLabelPill({
    super.key,
    required this.icon,
    required this.iconKey,
    required this.title,
    this.subtitle,
    this.compact = false,
    this.action,
    this.titleStyle,
  });

  final Widget icon;
  final Object iconKey;
  final String title;
  final String? subtitle;
  final bool compact;
  final Widget? action;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveTitleStyle = TextStyle(
      fontSize: compact ? 14 : 17,
      fontWeight: compact ? AppFontWeights.medium : AppFontWeights.semibold,
      color: cs.primary,
      decoration: TextDecoration.none,
    ).merge(titleStyle);
    final subtitleStyle = TextStyle(
      fontSize: compact ? 11 : 12,
      color: cs.onSurface.withValues(alpha: 0.55),
      decoration: TextDecoration.none,
    );

    Widget iconSwitcher(Widget child) => AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => ClipRect(
        child: SlideTransition(
          position: animation.drive(
            Tween(begin: const Offset(0, 0.5), end: Offset.zero),
          ),
          child: FadeTransition(opacity: animation, child: child),
        ),
      ),
      child: child,
    );

    final Widget titleContent = compact
        ? SizedBox(
            height: 24,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  title,
                  key: ValueKey(title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: effectiveTitleStyle,
                ),
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconSwitcher(KeyedSubtree(key: ValueKey(iconKey), child: icon)),
              SizedBox(width: titleStyle == null ? 8 : 6),
              AnimatedWidthText(
                text: title,
                style: effectiveTitleStyle,
                switchKey: ValueKey('t:$title'),
              ),
            ],
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (action == null)
          Center(child: titleContent)
        else
          Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 32, height: 32, child: action),
                Expanded(child: Center(child: titleContent)),
                const SizedBox(width: 32),
              ],
            ),
          ),
        if (!compact) ...[
          const SizedBox(height: 2),
          AnimatedWidthText(
            text: subtitle ?? '',
            style: subtitleStyle,
            switchKey: ValueKey('s:${subtitle ?? ''}'),
          ),
        ],
      ],
    );
  }
}

class EffortSliderGroup extends StatefulWidget {
  const EffortSliderGroup({
    super.key,
    required this.stops,
    required this.selectedIndex,
    required this.onCommit,
    this.customSelected = false,
    this.customIcon,
    this.customIconKey,
    this.customTitle,
    this.customSubtitle,
    this.padding = const EdgeInsets.symmetric(horizontal: 28),
    this.headerAction,
    this.headerTitleStyle,
    this.headerSpacing,
    this.animatedTrack = false,
    this.compact = false,
  });

  final List<EffortSliderStop> stops;
  final int selectedIndex;
  final bool customSelected;
  final Widget? customIcon;
  final Object? customIconKey;
  final String? customTitle;
  final String? customSubtitle;
  final ValueChanged<int> onCommit;
  final EdgeInsets padding;
  final Widget? headerAction;
  final TextStyle? headerTitleStyle;
  final double? headerSpacing;
  final bool animatedTrack;
  final bool compact;

  @override
  State<EffortSliderGroup> createState() => _EffortSliderGroupState();
}

class _EffortSliderGroupState extends State<EffortSliderGroup>
    with SingleTickerProviderStateMixin {
  static const SpringDescription _spring = SpringDescription(
    mass: 1,
    stiffness: 320,
    damping: 28,
  );

  late final AnimationController _snap;
  late final ValueNotifier<double> _position;
  late final ValueNotifier<int> _visualIndex;
  bool _dragging = false;
  late int _committed;
  late bool _customSelected;

  int get _stopCount => widget.stops.length;
  int get _lastIndex => _stopCount <= 0 ? 0 : _stopCount - 1;

  @override
  void initState() {
    super.initState();
    _committed = widget.selectedIndex;
    _customSelected = widget.customSelected;
    _visualIndex = ValueNotifier(widget.selectedIndex.clamp(0, _lastIndex));
    _position = ValueNotifier(_visualIndex.value.toDouble());
    _snap = AnimationController.unbounded(vsync: this)
      ..addListener(() => _setPosition(_snap.value));
  }

  @override
  void didUpdateWidget(covariant EffortSliderGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    final stopsChanged = _stopCount != oldWidget.stops.length;
    if (stopsChanged) {
      _snap.stop();
      _setPosition(_position.value);
    }
    if (widget.selectedIndex != oldWidget.selectedIndex ||
        widget.customSelected != oldWidget.customSelected ||
        stopsChanged) {
      _committed = widget.selectedIndex;
      _customSelected = widget.customSelected;
      if (!_dragging) _animateTo(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _snap.dispose();
    _position.dispose();
    _visualIndex.dispose();
    super.dispose();
  }

  void _commitIndex(int index) {
    if (index < 0 || index >= _stopCount) return;
    if (index == _committed && !_customSelected) return;
    _committed = index;
    _customSelected = false;
    widget.onCommit(index);
  }

  void _animateTo(int index) {
    _snap.stop();
    final target = index.clamp(0, _lastIndex).toDouble();
    if (_position.value == target) return;
    _snap.value = _position.value;
    // ignore: discarded_futures
    _snap.animateWith(SpringSimulation(_spring, _position.value, target, 0));
  }

  void _setPosition(double position) {
    _position.value = position.clamp(0.0, _lastIndex.toDouble());
    final index = _position.value.round();
    // Labels and semantics only change when crossing a stop. Pointer movement
    // and spring ticks within a stop go directly to the slider's paint/transform.
    _visualIndex.value = index;
  }

  void _onDragPosition(double position) {
    final previousIndex = _visualIndex.value;
    _setPosition(position);
    if (_visualIndex.value != previousIndex) Haptics.soft();
  }

  void _onSnap(int index) {
    if (!_dragging && (index != _committed || _customSelected)) {
      Haptics.soft();
    }
    setState(() => _dragging = false);
    // Keep settings notifications and persistence out of the drag loop.
    _commitIndex(index);
    _animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    final custom =
        _customSelected &&
        !_dragging &&
        widget.customTitle != null &&
        widget.customIcon != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          child: ValueListenableBuilder<int>(
            valueListenable: _visualIndex,
            child: widget.headerAction,
            builder: (context, index, action) {
              final stop = widget.stops.isEmpty ? null : widget.stops[index];
              final label = EffortSliderLabelPill(
                icon: custom
                    ? widget.customIcon!
                    : (stop?.icon ?? const SizedBox()),
                iconKey: custom
                    ? (widget.customIconKey ?? 'custom')
                    : (stop?.iconKey ?? 'empty'),
                title: custom ? widget.customTitle! : (stop?.title ?? ''),
                subtitle: custom ? widget.customSubtitle : stop?.subtitle,
                compact: widget.compact,
                action: action,
                titleStyle: widget.headerTitleStyle,
              );
              return label;
            },
          ),
        ),
        SizedBox(height: widget.headerSpacing ?? (widget.compact ? 8 : 22)),
        Padding(
          padding: widget.padding,
          child: RepaintBoundary(
            child: ValueListenableBuilder<int>(
              valueListenable: _visualIndex,
              builder: (context, index, _) {
                // Announce the committed stop immediately while the thumb
                // animates toward it; drag previews still follow the pointer.
                final semanticsIndex = _dragging
                    ? index
                    : _committed.clamp(0, _lastIndex);
                final previousIndex = semanticsIndex > 0
                    ? semanticsIndex - 1
                    : custom && _stopCount > 0
                    ? 0
                    : null;
                final nextIndex = semanticsIndex < _lastIndex
                    ? semanticsIndex + 1
                    : custom && _stopCount > 0
                    ? _lastIndex
                    : null;
                return Semantics(
                  container: true,
                  slider: true,
                  value: custom
                      ? widget.customTitle!
                      : (widget.stops.isEmpty
                            ? ''
                            : widget.stops[semanticsIndex].title),
                  decreasedValue: previousIndex == null
                      ? null
                      : widget.stops[previousIndex].title,
                  increasedValue: nextIndex == null
                      ? null
                      : widget.stops[nextIndex].title,
                  onDecrease: previousIndex == null
                      ? null
                      : () => _onSnap(previousIndex),
                  onIncrease: nextIndex == null
                      ? null
                      : () => _onSnap(nextIndex),
                  child: EffortSlider(
                    position: _position,
                    animatedTrack: widget.animatedTrack,
                    compact: widget.compact,
                    stopCount: _stopCount,
                    stopKeys: [for (final stop in widget.stops) stop.stopKey],
                    dragging: _dragging,
                    onDragStart: () {
                      _snap.stop();
                      setState(() => _dragging = true);
                    },
                    onDragCancel: () {
                      if (_dragging) _onSnap(_position.value.round());
                    },
                    onPositionChanged: _onDragPosition,
                    onSnap: _onSnap,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
