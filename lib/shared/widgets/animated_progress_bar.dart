import 'package:flutter/material.dart';

import '../animations/widgets.dart';

class AnimatedProgressBar extends StatelessWidget {
  const AnimatedProgressBar({
    super.key,
    this.fraction,
    this.height = 6,
  });

  static const fillKey = Key('animated_progress_bar_fill');
  static const indeterminateKey = Key('animated_progress_bar_indeterminate');

  /// `null` renders the indeterminate sweep.
  final double? fraction;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (fraction == null) {
              return _IndeterminateSweep(
                width: constraints.maxWidth,
                color: cs.primary,
                trackColor: cs.onSurface.withValues(alpha: 0.08),
              );
            }
            final clamped = fraction!.clamp(0.0, 1.0);
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: cs.onSurface.withValues(alpha: 0.08)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    key: fillKey,
                    duration: kAnimFast,
                    curve: Curves.easeOutCubic,
                    width: constraints.maxWidth * clamped,
                    color: cs.primary,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _IndeterminateSweep extends StatefulWidget {
  const _IndeterminateSweep({
    required this.width,
    required this.color,
    required this.trackColor,
  });

  final double width;
  final Color color;
  final Color trackColor;

  @override
  State<_IndeterminateSweep> createState() => _IndeterminateSweepState();
}

class _IndeterminateSweepState extends State<_IndeterminateSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final highlightWidth = widget.width * 0.3;
    final travel = (widget.width - highlightWidth).clamp(0.0, widget.width);
    return Stack(
      key: AnimatedProgressBar.indeterminateKey,
      fit: StackFit.expand,
      children: [
        ColoredBox(color: widget.trackColor),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = Curves.easeInOutCubic.transform(_controller.value);
            return Align(
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: Offset(travel * t, 0),
                child: child,
              ),
            );
          },
          child: SizedBox(
            width: highlightWidth,
            child: ColoredBox(color: widget.color),
          ),
        ),
      ],
    );
  }
}
