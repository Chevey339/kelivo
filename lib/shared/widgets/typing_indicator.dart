import 'package:flutter/material.dart';

/// A smooth 3-dots typing indicator with staggered bounce and fade.
///
/// Designed to be subtle but lively compared to a single breathing dot.
class DotsTypingIndicator extends StatefulWidget {
  const DotsTypingIndicator({
    super.key,
    this.color,
    this.dotSize = 10,
    this.gap = 4,
    this.duration = const Duration(milliseconds: 1200),
  });

  final Color? color;
  final double dotSize;
  final double gap;
  final Duration duration;

  @override
  State<DotsTypingIndicator> createState() => _DotsTypingIndicatorState();
}

class _DotsTypingIndicatorState extends State<DotsTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration)..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color base = widget.color ?? Theme.of(context).colorScheme.primary;

    Widget dot(Interval interval) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = interval.transform((_controller.value));
          final double dy = -4 * Curves.easeInOut.transform(t); // bounce up
          final double opacity = 0.35 + 0.65 * Curves.easeInOut.transform(t);
          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, dy),
              child: child,
            ),
          );
        },
        child: Container(
          width: widget.dotSize,
          height: widget.dotSize,
          decoration: BoxDecoration(
            color: base,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: base.withOpacity(0.25),
                blurRadius: 8,
                spreadRadius: 0.5,
              ),
            ],
          ),
        ),
      );
    }

    // Staggered intervals for 3 dots (all within 0..1)
    const double segment = 0.6; // each dot animates for 60% of the cycle
    const double shift = 0.2;   // start offset between dots
    final i1 = const Interval(0.0, segment);
    final i2 = const Interval(shift, shift + segment);
    final i3 = const Interval(shift * 2, 1.0); // cap at 1.0 to satisfy assertions

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot(i1),
        SizedBox(width: widget.gap),
        dot(i2),
        SizedBox(width: widget.gap),
        dot(i3),
      ],
    );
  }
}


