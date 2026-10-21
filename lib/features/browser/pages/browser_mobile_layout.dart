import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';

import '../widgets/browser_progressive_edge.dart';

/// The page continues behind the floating controls. Only the chrome animates;
/// its collapse never resizes or replaces the native WebView.
class BrowserMobileLayout extends StatelessWidget {
  const BrowserMobileLayout({
    super.key,
    required this.content,
    required this.toolbar,
    required this.viewPadding,
    this.agentStatus,
    this.transitionOverlay,
    this.findBar,
    this.onViewportHeight,
    this.keyboardInset = 0,
    this.viewportResizesForKeyboard = true,
    this.underlapStatusBar = false,
    this.fadeBehindToolbar = false,
  });
  final Widget content;
  final Widget toolbar;

  /// Tab-flight pixels use the route's full-screen coordinates, independently
  /// of the native viewport's asynchronously applied status-bar inset.
  final Widget? transitionOverlay;

  /// Read above Scaffold. Its resized body subtracts the keyboard from
  /// viewPadding, which must not change the dock's collapsed geometry.
  final EdgeInsets viewPadding;
  final Widget? agentStatus;
  final Widget? findBar;
  final ValueChanged<double>? onViewportHeight;
  final double keyboardInset;
  final bool viewportResizesForKeyboard;
  final bool underlapStatusBar;
  final bool fadeBehindToolbar;
  static const double expandedChromeHeight = 54;

  static double collapseDropFor(double bottomSafeInset) =>
      bottomSafeInset.clamp(
        0.0,
        defaultTargetPlatform == TargetPlatform.android ? 16.0 : 20.0,
      );

  static double get toolbarBottomGap =>
      defaultTargetPlatform == TargetPlatform.android ? 16 : 10;

  @override
  Widget build(BuildContext context) {
    final padding = viewPadding;
    // The keyboard already shortened a webpage-form viewport; address editing
    // keeps the full scene behind it. Both paths share the same screen-space
    // lower boundary and stop at the home-indicator inset during dismissal.
    final dockInset =
        math.max(padding.bottom, keyboardInset) -
        (viewportResizesForKeyboard ? keyboardInset : 0);
    return LayoutBuilder(
      builder: (context, constraints) {
        onViewportHeight?.call(
          constraints.maxHeight - (underlapStatusBar ? 0 : padding.top),
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              key: const ValueKey('browserMobileViewportSlot'),
              top: underlapStatusBar ? 0 : padding.top,
              child: content,
            ),
            if (transitionOverlay != null)
              Positioned.fill(
                key: const ValueKey('browserTabReturnCoverSlot'),
                child: transitionOverlay!,
              ),
            if (underlapStatusBar && padding.top > 0)
              Positioned(
                key: const ValueKey('browserMobileTopEdge'),
                top: 0,
                left: 0,
                right: 0,
                height: padding.top + 24,
                child: const BrowserProgressiveEdge(
                  top: true,
                  filterBackdrop: false,
                ),
              ),
            if (keyboardInset == 0)
              Positioned(
                key: const ValueKey('browserMobileBottomEdge'),
                bottom: 0,
                left: 0,
                right: 0,
                height: padding.bottom + expandedChromeHeight + 20,
                child: BrowserProgressiveEdge(
                  top: false,
                  filterBackdrop: false,
                  fadeBehindToolbar: fadeBehindToolbar,
                ),
              ),
            if (agentStatus != null)
              Positioned(
                key: const ValueKey('browserMobileOverlaySlot'),
                top: padding.top + 8,
                left: 12,
                right: 12,
                child: agentStatus!,
              ),
            AnimatedPositioned(
              key: const ValueKey('browserMobileToolbarSlot'),
              duration: Duration(
                milliseconds:
                    defaultTargetPlatform == TargetPlatform.android &&
                        !MediaQuery.disableAnimationsOf(context)
                    ? 240
                    : 0,
              ),
              curve: Curves.easeOutCubic,
              left: 16,
              right: 16,
              // Reserve the whole travel inside the hit-test area, including the
              // lower position of the collapsed capsule above the home indicator.
              bottom:
                  dockInset +
                  toolbarBottomGap -
                  collapseDropFor(padding.bottom),
              child: toolbar,
            ),
            if (findBar != null)
              Positioned(
                key: const ValueKey('browserMobileFindSlot'),
                left: 16,
                right: 16,
                bottom: dockInset + 10,
                child: findBar!,
              ),
          ],
        );
      },
    );
  }
}

/// Direction changes retarget a critically damped spring from its current
/// position and velocity. Coalesced native events cannot jump the geometry.
class BrowserChromeTransition extends StatefulWidget {
  const BrowserChromeTransition({
    super.key,
    required this.progress,
    this.animate = false,
    required this.reducedMotion,
    required this.builder,
    this.onProgress,
  }) : assert(progress >= 0 && progress <= 1);

  final double progress;
  final bool animate;
  final bool reducedMotion;
  final Widget Function(BuildContext, double) builder;
  final ValueChanged<double>? onProgress;

  @override
  State<BrowserChromeTransition> createState() =>
      _BrowserChromeTransitionState();
}

class _BrowserChromeTransitionState extends State<BrowserChromeTransition>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController.unbounded(
    vsync: this,
    value: widget.progress,
  )..addListener(_reportProgress);

  void _reportProgress() =>
      widget.onProgress?.call(_motion.value.clamp(0.0, 1.0));

  @override
  void didUpdateWidget(BrowserChromeTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress == oldWidget.progress &&
        widget.animate == oldWidget.animate &&
        widget.reducedMotion == oldWidget.reducedMotion) {
      return;
    }
    final target = widget.progress;
    if (!widget.animate || widget.reducedMotion) {
      _motion.value = target;
    } else {
      _motion.animateWith(
        SpringSimulation(
          SpringDescription.withDampingRatio(mass: 1, stiffness: 400, ratio: 1),
          _motion.value,
          target,
          _motion.velocity,
          tolerance: const Tolerance(distance: .0005, velocity: .005),
          snapToEnd: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    builder: (context, _) => widget.builder(context, _motion.value.clamp(0, 1)),
  );
}
