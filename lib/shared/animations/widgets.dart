import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Common durations
const Duration kAnimFast = Duration(milliseconds: 180);
const Duration kAnim = Duration(milliseconds: 240);
const Duration kAnimSlow = Duration(milliseconds: 320);

// A compact AnimatedSwitcher for icon glyph/state changes.
class AnimatedIconSwap extends StatelessWidget {
  const AnimatedIconSwap({
    super.key,
    required this.child,
    this.duration = kAnim,
  });
  final Widget child;
  final Duration duration;
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, anim) =>
          FadeScaleTransition(animation: anim, child: child),
      child: child,
    );
  }
}

// A simple text switcher: fade + slide up on change.
class AnimatedTextSwap extends StatelessWidget {
  const AnimatedTextSwap({
    super.key,
    required this.text,
    this.style,
    this.duration = kAnim,
    this.maxLines,
    this.overflow,
    this.textScaler,
  });
  final String text;
  final TextStyle? style;
  final Duration duration;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.centerLeft,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, anim) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(anim);
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: Text(
        text,
        key: ValueKey(text),
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textScaler: textScaler,
      ),
    );
  }
}

// Handy appear animation using flutter_animate (fade + slight Y move)
extension Appear on Widget {
  Widget appear({
    Duration duration = kAnim,
    double dy = 0.02,
    double begin = 0,
  }) {
    return animate()
        .fadeIn(duration: duration, begin: begin)
        .moveY(
          begin: dy,
          end: 0,
          duration: duration,
          curve: Curves.easeOutCubic,
        );
  }
}
