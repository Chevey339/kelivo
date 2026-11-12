import 'package:flutter/material.dart';

/// Fade between the two browser presentations without transforming a native
/// WebView. Its destination is laid out once at its final size underneath.
class BrowserDesktopRoute extends PageRouteBuilder<void> {
  BrowserDesktopRoute({
    required WidgetBuilder builder,
    required bool reduceMotion,
  }) : super(
         allowSnapshotting: false,
         transitionDuration: reduceMotion
             ? Duration.zero
             : const Duration(milliseconds: 180),
         reverseTransitionDuration: reduceMotion
             ? Duration.zero
             : const Duration(milliseconds: 150),
         pageBuilder: (context, _, _) => builder(context),
         transitionsBuilder: (context, animation, _, child) => FadeTransition(
           opacity: animation.drive(CurveTween(curve: Curves.easeInOut)),
           child: IgnorePointer(
             ignoring: animation.status != AnimationStatus.completed,
             child: child,
           ),
         ),
       );
}
