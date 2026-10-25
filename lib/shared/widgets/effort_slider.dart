import 'package:flutter/foundation.dart';
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
    required this.semanticsValue,
    required this.onDragStart,
    required this.onDragCancel,
    required this.onPositionChanged,
    required this.onSnap,
  });

  final ValueListenable<double> position;
  final int stopCount;
  final List<String> stopKeys;
  final bool dragging;
  final String semanticsValue;
  final VoidCallback onDragStart;
  final VoidCallback onDragCancel;
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
    final t = stopCount <= 1 ? 0.0 : position.value / (stopCount - 1);
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
            onHorizontalDragStart: (details) {
              onDragStart();
              onPositionChanged(_indexForDx(details.localPosition.dx, width));
            },
            onHorizontalDragUpdate: (details) =>
                onPositionChanged(_indexForDx(details.localPosition.dx, width)),
            onHorizontalDragEnd: (_) => onSnap(position.value.round()),
            onHorizontalDragCancel: onDragCancel,
            onTapUp: (details) {
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
                    left: 0,
                    top: (_height - _thumbRadius * 2) / 2,
                    child: IgnorePointer(
                      child: ListenableBuilder(
                        listenable: position,
                        builder: (context, child) => Transform.translate(
                          offset: Offset(_thumbX(width) - _thumbRadius, 0),
                          child: child,
                        ),
                        child: AnimatedScale(
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
    required this.stopInset,
    required this.primary,
    required this.trackColor,
    required this.upcomingDotColor,
  }) : super(repaint: position);

  final ValueListenable<double> position;
  final int stopCount;
  final double stopInset;
  final Color primary;
  final Color trackColor;
  final Color upcomingDotColor;

  static const double _trackHeight = 34;
  static const double _dotRadius = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    final value = position.value;
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
        final passed = i <= value.round();
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
  late final ValueNotifier<double> _position;
  late int _visualIndex;
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
    _visualIndex = widget.selectedIndex.clamp(0, _lastIndex);
    _position = ValueNotifier(_visualIndex.toDouble());
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
    if (index != _visualIndex) setState(() => _visualIndex = index);
  }

  void _onDragPosition(double position) {
    final previousIndex = _visualIndex;
    _setPosition(position);
    if (_visualIndex != previousIndex) Haptics.soft();
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
    final stop = widget.stops.isEmpty ? null : widget.stops[_visualIndex];
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
          child: RepaintBoundary(
            child: EffortSlider(
              position: _position,
              stopCount: _stopCount,
              stopKeys: [for (final stop in widget.stops) stop.stopKey],
              dragging: _dragging,
              semanticsValue: custom
                  ? widget.customTitle!
                  : (stop?.title ?? ''),
              onDragStart: () {
                _snap.stop();
                setState(() => _dragging = true);
              },
              onDragCancel: () {
                // A tap or vertical sheet swipe also rejects the horizontal
                // recognizer; only finish gestures that actually began dragging.
                if (_dragging) _onSnap(_position.value.round());
              },
              onPositionChanged: _onDragPosition,
              onSnap: _onSnap,
            ),
          ),
        ),
      ],
    );
  }
}
