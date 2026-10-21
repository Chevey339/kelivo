import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'widgets/browser_transition_snapshot.dart';

PageRoute<T> browserManagementRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => Theme.of(context).platform == TargetPlatform.iOS
    ? BrowserManagementRoute<T>(builder: builder)
    : _BrowserMaterialManagementRoute<T>(builder: builder);

/// Keep the Android foreground transition, but do not scale the native WebView
/// and its backdrop filters behind it on every transition frame.
class _BrowserMaterialManagementRoute<T> extends MaterialPageRoute<T> {
  _BrowserMaterialManagementRoute({required super.builder});

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => false;
}

/// Cupertino management navigation above the browser's native page.
class BrowserManagementRoute<T> extends CupertinoPageRoute<T> {
  BrowserManagementRoute({required super.builder, super.settings, super.title});

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) {
    // Flutter's iOS view_slicer splits Flutter painting at a platform view's
    // edge. Cupertino's secondary parallax moves the underlying WKWebView edge
    // through our glass during back swipes, giving each half a different
    // backdrop. Keep that page stationary. The inherited foreground transition
    // and interactive back gesture still run normally, including cancellation.
    return false;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => super.buildTransitions(
    context,
    kAlwaysCompleteAnimation,
    kAlwaysDismissedAnimation,
    _ManagementSnapshotTransition(
      animation: animation,
      isGestureInProgress: () => popGestureInProgress,
      child: child,
    ),
  );
}

/// Keep the inherited Cupertino back detector attached to the real route
/// controller, but make its ancestor SlideTransitions identity transforms.
/// The opaque page is captured at viewport origin; only its image moves. This
/// avoids both per-frame backdrop passes and translated shader capture UVs.
class _ManagementSnapshotTransition extends StatefulWidget {
  const _ManagementSnapshotTransition({
    required this.animation,
    required this.isGestureInProgress,
    required this.child,
  });
  final Animation<double> animation;
  final bool Function() isGestureInProgress;
  final Widget child;

  @override
  State<_ManagementSnapshotTransition> createState() =>
      _ManagementSnapshotTransitionState();
}

class _ManagementSnapshotTransitionState
    extends State<_ManagementSnapshotTransition> {
  late _ManagementSnapshotPainter _painter;

  @override
  void initState() {
    super.initState();
    _createPainter();
  }

  void _createPainter() {
    _painter = _ManagementSnapshotPainter(
      animation: widget.animation,
      isGestureInProgress: () => widget.isGestureInProgress(),
    );
  }

  @override
  void didUpdateWidget(_ManagementSnapshotTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _painter.dispose();
      _createPainter();
    }
  }

  @override
  Widget build(BuildContext context) {
    _painter.textDirection = Directionality.of(context);
    return BrowserTransitionSnapshot(
      animation: widget.animation,
      painter: _painter,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _painter.dispose();
    super.dispose();
  }
}

class _ManagementSnapshotPainter extends SnapshotPainter {
  _ManagementSnapshotPainter({
    required this.animation,
    required this.isGestureInProgress,
  }) {
    animation.addListener(notifyListeners);
  }
  final Animation<double> animation;
  final bool Function() isGestureInProgress;
  TextDirection _textDirection = TextDirection.ltr;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    notifyListeners();
  }

  late final _curve = CurvedAnimation(
    parent: animation,
    curve: Curves.fastEaseInToSlowEaseOut,
    reverseCurve: Curves.fastEaseInToSlowEaseOut.flipped,
  );
  final _imagePaint = Paint()..filterQuality = FilterQuality.medium;

  double _translation(Size size) {
    final progress = isGestureInProgress() ? animation.value : _curve.value;
    return size.width *
        (1 - progress) *
        (textDirection == TextDirection.rtl ? -1 : 1);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset,
    Size size,
    PaintingContextCallback painter,
  ) {
    // Live paint is used only at the resting endpoints. Avoid composing an
    // off-screen live backdrop on the fully dismissed entry/exit frame.
    if (animation.value <= 0) return;
    painter(context, offset);
  }

  @override
  void paintSnapshot(
    PaintingContext context,
    Offset offset,
    Size size,
    ui.Image image,
    Size sourceSize,
    double pixelRatio,
  ) {
    final destination = (offset + Offset(_translation(size), 0)) & size;
    context.canvas.drawShadow(
      Path()..addRect(destination),
      const Color(0x33000000),
      6,
      true,
    );
    context.canvas.drawImageRect(
      image,
      Offset.zero & sourceSize,
      destination,
      _imagePaint,
    );
  }

  @override
  bool shouldRepaint(_ManagementSnapshotPainter oldPainter) =>
      oldPainter.animation != animation ||
      oldPainter.textDirection != textDirection;

  @override
  void dispose() {
    animation.removeListener(notifyListeners);
    _curve.dispose();
    super.dispose();
  }
}
