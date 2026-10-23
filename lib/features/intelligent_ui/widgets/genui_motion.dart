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
