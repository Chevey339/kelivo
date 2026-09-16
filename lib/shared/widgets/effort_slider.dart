import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../core/services/haptics.dart';
import '../../theme/app_font_weights.dart';

/// Discrete-step slider for reasoning effort presets.
///
/// Purely presentational: the parent owns [position] and animates it; this
/// widget reports raw drag positions and snap targets.
class EffortSlider extends StatelessWidget {
  const EffortSlider({
    super.key,
    required this.position,
    required this.stopCount,
    required this.stopKeys,
    required this.dragging,
    required this.semanticsValue,
    required this.onDragStart,
    required this.onDragEnd,
    required this.onPositionChanged,
    required this.onSnap,
  });

  final double position;
  final int stopCount;
  final List<String> stopKeys;
  final bool dragging;
  final String semanticsValue;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;
  final ValueChanged<double> onPositionChanged;
  final ValueChanged<int> onSnap;

  static const double _height = 56;
  static const double _thumbRadius = 19;
  // Stops sit exactly one thumb radius from each end, so at the extremes the
  // thumb is flush with the track edge and fully covers the fill — no
  // visible track/fill sliver beside the thumb.
  static const double _stopInset = _thumbRadius;

  double _indexForDx(double dx, double width) {
    final span = width - 2 * _stopInset;
    if (span <= 0 || stopCount <= 1) return 0;
    return (((dx - _stopInset) / span) * (stopCount - 1))
        .clamp(0.0, (stopCount - 1).toDouble())
        .toDouble();
  }

  double _thumbX(double width) {
    final span = width - 2 * _stopInset;
    final t = stopCount <= 1 ? 0.0 : position / (stopCount - 1);
    return _stopInset + span * t;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      slider: true,
      value: semanticsValue,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => onDragStart(),
            onHorizontalDragUpdate: (details) =>
                onPositionChanged(_indexForDx(details.localPosition.dx, width)),
            onHorizontalDragEnd: (_) {
              onDragEnd();
              onSnap(position.round());
            },
            onHorizontalDragCancel: () {
              onDragEnd();
              onSnap(position.round());
            },
            onTapDown: (details) {
              final index = _indexForDx(
                details.localPosition.dx,
                width,
              ).round();
              onSnap(index);
            },
            child: SizedBox(
              height: _height,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(width, _height),
                    painter: _SliderPainter(
                      position: position,
                      stopCount: stopCount,
                      thumbX: _thumbX(width),
                      stopInset: _stopInset,
                      primary: cs.primary,
                      trackColor: cs.onSurface.withValues(alpha: 0.10),
                      upcomingDotColor: cs.onSurface.withValues(alpha: 0.25),
                    ),
                  ),
                  Positioned.fill(
                    child: Row(
                      children: [
                        for (final key in stopKeys)
                          Expanded(child: SizedBox(key: ValueKey(key))),
                      ],
                    ),
                  ),
                  Positioned(
                    left: _thumbX(width) - _thumbRadius,
                    top: (_height - _thumbRadius * 2) / 2,
                    child: IgnorePointer(
                      child: AnimatedScale(
                        scale: dragging ? 1.14 : 1.0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutBack,
                        child: Container(
                          width: _thumbRadius * 2,
                          height: _thumbRadius * 2,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({
    required this.position,
    required this.stopCount,
    required this.thumbX,
    required this.stopInset,
    required this.primary,
    required this.trackColor,
    required this.upcomingDotColor,
  });

  final double position;
  final int stopCount;
  final double thumbX;
  final double stopInset;
  final Color primary;
  final Color trackColor;
  final Color upcomingDotColor;

  static const double _trackHeight = 34;
  static const double _dotRadius = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final trackRect = Rect.fromLTWH(
      0,
      cy - _trackHeight / 2,
      size.width,
      _trackHeight,
    );
    final trackRRect = RRect.fromRectAndRadius(
      trackRect,
      const Radius.circular(_trackHeight / 2),
    );

    canvas.drawRRect(trackRRect, Paint()..color = trackColor);

    if (thumbX > 0) {
      final fillRect = Rect.fromLTWH(
        0,
        cy - _trackHeight / 2,
        thumbX.clamp(0.0, size.width),
        _trackHeight,
      );
      final fillPaint = Paint()
        ..shader = LinearGradient(
          colors: [primary.withValues(alpha: 0.5), primary],
        ).createShader(fillRect);
      canvas.save();
      canvas.clipRRect(trackRRect);
      canvas.drawRect(fillRect, fillPaint);
      canvas.restore();
    }

    if (stopCount > 1) {
      final passedPaint = Paint()..color = Colors.white.withValues(alpha: 0.9);
      final upcomingPaint = Paint()..color = upcomingDotColor;
      for (var i = 0; i < stopCount; i++) {
        final x =
            stopInset + (size.width - 2 * stopInset) * (i / (stopCount - 1));
        final passed = i <= position.round();
        canvas.drawCircle(
          Offset(x, cy),
          _dotRadius,
          passed ? passedPaint : upcomingPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SliderPainter old) =>
      old.position != position ||
      old.stopCount != stopCount ||
      old.thumbX != thumbX ||
      old.primary != primary ||
      old.trackColor != trackColor;
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
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: painter.width),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, width, _) => SizedBox(
        width: width,
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
  });

  final Widget icon;
  final Object iconKey;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final titleStyle = TextStyle(
      fontSize: 17,
      fontWeight: AppFontWeights.semibold,
      color: cs.primary,
      decoration: TextDecoration.none,
    );
    final subtitleStyle = TextStyle(
      fontSize: 12,
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconSwitcher(KeyedSubtree(key: ValueKey(iconKey), child: icon)),
            const SizedBox(width: 8),
            AnimatedWidthText(
              text: title,
              style: titleStyle,
              switchKey: ValueKey('t:$title'),
            ),
          ],
        ),
        const SizedBox(height: 2),
        AnimatedWidthText(
          text: subtitle ?? '',
          style: subtitleStyle,
          switchKey: ValueKey('s:${subtitle ?? ''}'),
        ),
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
  late double _position;
  bool _dragging = false;
  late int _committed;

  int get _stopCount => widget.stops.length;

  @override
  void initState() {
    super.initState();
    _committed = widget.selectedIndex;
    _position = widget.selectedIndex.toDouble();
    _snap = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        final last = (_stopCount - 1).toDouble().clamp(0.0, double.infinity);
        setState(() => _position = _snap.value.clamp(0.0, last).toDouble());
      });
  }

  @override
  void didUpdateWidget(covariant EffortSliderGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_stopCount != oldWidget.stops.length && _stopCount > 0) {
      final last = (_stopCount - 1).toDouble();
      if (_position > last) _position = last;
    }
    if (widget.selectedIndex != oldWidget.selectedIndex && !_dragging) {
      _committed = widget.selectedIndex;
      _animateTo(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _snap.dispose();
    super.dispose();
  }

  void _commitIndex(int index) {
    if (index < 0 || index >= _stopCount) return;
    if (index == _committed && !widget.customSelected) return;
    _committed = index;
    Haptics.soft();
    widget.onCommit(index);
  }

  void _animateTo(int index) {
    _snap.stop();
    _snap.value = _position;
    // ignore: discarded_futures
    _snap.animateWith(
      SpringSimulation(_spring, _position, index.toDouble(), 0),
    );
  }

  void _onDragPosition(double position) {
    setState(() => _position = position);
    _commitIndex(position.round());
  }

  void _onSnap(int index) {
    _commitIndex(index);
    _animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    final last = _stopCount <= 0 ? 0 : _stopCount - 1;
    final visualIndex = _position.round().clamp(0, last).toInt();
    final custom =
        widget.customSelected &&
        widget.customTitle != null &&
        widget.customIcon != null;
    final stop = widget.stops.isEmpty
        ? null
        : widget.stops[visualIndex.clamp(0, widget.stops.length - 1)];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: EffortSliderLabelPill(
            icon: custom
                ? widget.customIcon!
                : (stop?.icon ?? const SizedBox()),
            iconKey: custom
                ? (widget.customIconKey ?? 'custom')
                : (stop?.iconKey ?? 'empty'),
            title: custom ? widget.customTitle! : (stop?.title ?? ''),
            subtitle: custom ? widget.customSubtitle : stop?.subtitle,
          ),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: widget.padding,
          child: EffortSlider(
            position: _position,
            stopCount: _stopCount,
            stopKeys: [for (final stop in widget.stops) stop.stopKey],
            dragging: _dragging,
            semanticsValue: custom ? widget.customTitle! : (stop?.title ?? ''),
            onDragStart: () {
              _snap.stop();
              setState(() => _dragging = true);
            },
            onDragEnd: () => setState(() => _dragging = false),
            onPositionChanged: _onDragPosition,
            onSnap: _onSnap,
          ),
        ),
      ],
    );
  }
}
