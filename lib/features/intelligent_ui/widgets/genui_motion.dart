import 'package:flutter/widgets.dart';

/// All streaming indicators in one surface repaint from one stopped/resumed
/// clock. Nodes do not create tickers or rebuild the message on animation frames.
class GenUiMotion extends InheritedWidget {
  const GenUiMotion({super.key, required this.animation, required super.child});
  final Animation<double> animation;
  static Animation<double> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GenUiMotion>()?.animation ??
      const AlwaysStoppedAnimation(0);
  @override
  bool updateShouldNotify(GenUiMotion oldWidget) =>
      animation != oldWidget.animation;
}

/// Only result nodes whose values changed while expanded receive a brief
/// reveal on return. The same elements and editing controllers stay mounted.
class GenUiReturnMotion extends InheritedWidget {
  const GenUiReturnMotion({
    super.key,
    required this.animation,
    required this.changed,
    required super.child,
  });
  final Animation<double> animation;
  final Set<String> changed;
  static GenUiReturnMotion? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GenUiReturnMotion>();
  @override
  bool updateShouldNotify(GenUiReturnMotion oldWidget) =>
      changed != oldWidget.changed || animation != oldWidget.animation;
}
