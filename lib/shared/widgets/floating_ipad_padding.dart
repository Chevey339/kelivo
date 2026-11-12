import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Reserves space for the window controls above a floating iPad window.
class FloatingIpadPadding extends StatelessWidget {
  const FloatingIpadPadding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Only iPad window controls need display metrics. On Windows the view's
    // display mapping can be unavailable when the window is restored.
    if (defaultTargetPlatform != TargetPlatform.iOS) return child;

    final mq = MediaQuery.of(context);
    final display = View.of(context).display;
    final displaySize = display.size / display.devicePixelRatio;
    final isFloatingIpad =
        displaySize.shortestSide >= 600 &&
        (mq.size.shortestSide < displaySize.shortestSide - 1 ||
            mq.size.longestSide < displaySize.longestSide - 1);
    final systemTop = mq.viewPadding.top;
    final controlsTop = systemTop < 56 ? 56.0 : systemTop;
    return MediaQuery(
      data: isFloatingIpad
          ? mq.copyWith(
              padding: mq.padding.copyWith(top: controlsTop),
              viewPadding: mq.viewPadding.copyWith(top: controlsTop),
            )
          : mq,
      child: child,
    );
  }
}
