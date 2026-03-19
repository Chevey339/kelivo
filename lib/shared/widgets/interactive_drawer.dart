import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Drawer placement side.
enum DrawerSide { left, right }

/// Controller to programmatically control the drawer.
class InteractiveDrawerController extends ChangeNotifier {
  InteractiveDrawerController({double initialValue = 0.0})
    : _valueOffline = initialValue.clamp(0.0, 1.0);

  AnimationController? _controller;
  double _valueOffline;

  /// Current progress in [0.0, 1.0].
  double get value => _controller?.value ?? _valueOffline;
  bool get isOpen => value >= 1.0 - 1e-6;
  bool get isClosed => value <= 1e-6;

  void _attach(AnimationController c) {
    _controller = c;
    if (c.value != _valueOffline) c.value = _valueOffline;
    c.addListener(notifyListeners);
  }

  void _detach() {
    _controller?.removeListener(notifyListeners);
    _controller = null;
  }

  AnimationController _requireAttached() {
    final c = _controller;
    if (c == null) {
      throw FlutterError(
        'InteractiveDrawerController is not attached to any InteractiveDrawer.\n'
        'Pass this controller to InteractiveDrawer(controller: ...) first.',
      );
    }
    return c;
  }

  /// Open with fling-like motion (positive velocity).
  Future<void> open({double velocity = 2.0}) async {
    _requireAttached().fling(velocity: velocity.abs());
  }

  /// Close with fling-like motion (negative velocity).
  Future<void> close({double velocity = -2.0}) async {
    _requireAttached().fling(velocity: -velocity.abs());
  }

  /// Toggle open/close with fling-like motion.
  Future<void> toggle({double velocity = 2.0}) async {
    if (isOpen) {
      await close(velocity: velocity);
    } else {
      await open(velocity: velocity);
    }
  }

  /// Animate to a specific progress.
  Future<void> animateTo(
    double target, {
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.easeOutCubic,
  }) async {
    assert(target >= 0.0 && target <= 1.0);
    await _requireAttached().animateTo(
      target,
      duration: duration,
      curve: curve,
    );
  }

  /// Jump to a specific progress without animation.
  void jumpTo(double target) {
    assert(target >= 0.0 && target <= 1.0);
    if (_controller != null) {
      _controller!.value = target;
    } else {
      _valueOffline = target;
      notifyListeners();
    }
  }
}

/// Interactive drawer where:
/// - child is full-screen draggable with in-child scrim
/// - drawer slides in/out following the progress and is also draggable
class InteractiveDrawer extends StatefulWidget {
  const InteractiveDrawer({
    super.key,
    required this.child,
    required this.drawer,
    this.controller,
    this.side = DrawerSide.left,
    this.drawerWidth,
    this.duration = const Duration(milliseconds: 250),
    this.curve = Curves.easeOutCubic,
    this.scrimColor = Colors.black,
    this.maxScrimOpacity = 0.5,
    this.barrierDismissible = true,
    this.elevation = 0.0,
    this.semanticLabel,
    this.enableDrawerTapToClose = false,
    this.tabletMode = false,
    this.onScrimTap,
  });

  /// The main content; it will translate horizontally with the drawer progress.
  final Widget child;

  /// The drawer content with a fixed width.
  final Widget drawer;

  /// External controller. If null, an internal one is created.
  final InteractiveDrawerController? controller;

  /// Left or right side.
  final DrawerSide side;

  /// Drawer width. Default: min(360, screenWidth * 0.86).
  final double? drawerWidth;

  /// Default duration for programmatic animations (not for drag).
  final Duration duration;

  /// Default curve for programmatic animations (drag is always linear).
  final Curve curve;

  /// Scrim base color (applied INSIDE the child only).
  final Color scrimColor;

  /// Maximum scrim opacity (0 ~ 1).
  final double maxScrimOpacity;

  /// Tap on scrim to close.
  final bool barrierDismissible;

  /// Whether tapping blank area inside the drawer closes it.
  final bool enableDrawerTapToClose;

  /// Tablet mode: persistent sidebar with slide+fade.
  final bool tabletMode;

  /// Material elevation for the drawer.
  final double elevation;

  /// A11y label.
  final String? semanticLabel;

  /// Optional callback fired when the user taps the right-side scrim
  /// to dismiss the drawer (only when [barrierDismissible] and drawer is open).
  final VoidCallback? onScrimTap;

  @override
  State<InteractiveDrawer> createState() => _InteractiveDrawerState();
}

class _InteractiveDrawerState extends State<InteractiveDrawer>
    with SingleTickerProviderStateMixin {
  static const double _kMinFlingVelocityPxPerSec = 365.0;

  late final AnimationController _anim;
  late InteractiveDrawerController _controllerProxy;
  double _drawerWidth = 0.0;

  bool get _isLeft => widget.side == DrawerSide.left;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      value: widget.controller?.value ?? 0.0,
      duration: widget.duration,
    );
    _controllerProxy = widget.controller ?? InteractiveDrawerController();
    _controllerProxy._attach(_anim);
  }

  @override
  void didUpdateWidget(covariant InteractiveDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      _controllerProxy = widget.controller ?? InteractiveDrawerController();
      _controllerProxy._attach(_anim);
    }
    if (oldWidget.duration != widget.duration) {
      _anim.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _anim.dispose();
    super.dispose();
  }

  // -------- Shared drag handlers (used by both child and drawer) --------

  void _onDragStart(DragStartDetails details) {
    _anim.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_drawerWidth <= 0) return;
    final double deltaPx = details.primaryDelta ?? 0.0;
    final double signedDelta =
        (_isLeft ? deltaPx : -deltaPx) / _drawerWidth; // positive => opening
    _anim.value = (_anim.value + signedDelta).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_drawerWidth <= 0) return;
    final double vxPx = details.velocity.pixelsPerSecond.dx;
    final double signedVxPx = _isLeft ? vxPx : -vxPx; // positive => opening

    // Velocity-based fling if fast enough.
    if (signedVxPx.abs() >= _kMinFlingVelocityPxPerSec) {
      final double visualVelocity = (signedVxPx / _drawerWidth).clamp(
        -2.0,
        2.0,
      ); // progress/sec
      _anim.fling(velocity: visualVelocity);
      return;
    }

    // Otherwise settle to the nearest state.
    if (_anim.value >= 0.5) {
      _controllerProxy.open();
    } else {
      _controllerProxy.close();
    }
  }

  /// Draggable child with an in-child scrim (does not cover the drawer).
  Widget _buildDraggableChild() {
    if (widget.tabletMode) {
      // In tablet mode the child is static (no translation, no scrim).
      return widget.child;
    }
    final double dx = (_isLeft ? 1 : -1) * _drawerWidth * _anim.value;
    final double scrimOpacity = (widget.maxScrimOpacity * _anim.value).clamp(
      0.0,
      1.0,
    );

    return Transform.translate(
      offset: Offset(dx, 0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        onTap: widget.barrierDismissible && _controllerProxy.isOpen
            ? () {
                // Haptic or other side effects can be hooked by parent.
                widget.onScrimTap?.call();
                _controllerProxy.close();
              }
            : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (_anim.value > 0.0)
              IgnorePointer(
                ignoring: !widget.barrierDismissible,
                child: Container(
                  color: widget.scrimColor.withValues(alpha: scrimOpacity),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Draggable drawer that follows progress (slides from offscreen to edge).
  Widget _buildDraggableDrawer() {
    if (widget.tabletMode) {
      // Slide + fade (width fixed to configured _drawerWidth). When closed: translated fully offscreen.
      final targetWidth = _drawerWidth; // already resolved in build()
      final double translateX =
          (_isLeft ? -1 : 1) * (1 - _anim.value) * targetWidth;
      final drawerBody = Material(
        elevation: widget.elevation,
        clipBehavior: Clip.none,
        child: Semantics(
          label: widget.semanticLabel,
          container: true,
          child: widget.drawer,
        ),
      );
      return Align(
        alignment: _isLeft ? Alignment.centerLeft : Alignment.centerRight,
        child: SizedBox(
          width: targetWidth,
          child: Opacity(
            opacity: _anim.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(translateX, 0),
              child: IgnorePointer(
                // Only interactive when sufficiently open.
                ignoring: _anim.value < 0.95,
                child: drawerBody,
              ),
            ),
          ),
        ),
      );
    }
    // When closed (value=0), drawer is fully offscreen.
    // It moves toward 0 offset as it opens.
    final double hiddenOffset = _isLeft ? -_drawerWidth : _drawerWidth;
    final double dx =
        hiddenOffset * (1.0 - _anim.value); // 1->hidden, 0->onscreen

    final drawerBody = Material(
      elevation: widget.elevation,
      clipBehavior: Clip.none,
      child: Semantics(
        label: widget.semanticLabel,
        container: true,
        child: widget.drawer,
      ),
    );

    return Transform.translate(
      offset: Offset(dx, 0),
      child: Align(
        alignment: _isLeft ? Alignment.centerLeft : Alignment.centerRight,
        child: SizedBox(
          width: _drawerWidth,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            onTap: widget.enableDrawerTapToClose
                ? (_controllerProxy.isOpen ? _controllerProxy.close : null)
                : null,
            child: drawerBody,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (widget.tabletMode) {
            _drawerWidth = widget.drawerWidth ?? 250.0; // tablet default 250
          } else {
            _drawerWidth =
                widget.drawerWidth ??
                math.max(300.0, constraints.maxWidth * 0.80);
          }

          return PopScope(
            canPop: !_controllerProxy.isOpen,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (_controllerProxy.isOpen) {
                _controllerProxy.close();
              }
            },
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, _) {
                if (widget.tabletMode) {
                  // Stack: main content with dynamic padding + sliding drawer on top alignment.
                  final sidePadding = _drawerWidth * _anim.value;
                  EdgeInsets mainPadding;
                  if (_isLeft) {
                    mainPadding = EdgeInsets.only(left: sidePadding);
                  } else {
                    mainPadding = EdgeInsets.only(right: sidePadding);
                  }
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Main content shifts via padding to make space as drawer reveals.
                      AnimatedContainer(
                        duration: const Duration(
                          milliseconds: 16,
                        ), // near-frame for smoothness
                        curve: Curves.linear,
                        padding: mainPadding,
                        child: _buildDraggableChild(),
                      ),
                      _buildDraggableDrawer(),
                    ],
                  );
                }
                return Stack(
                  fit: StackFit.expand,
                  children: [_buildDraggableChild(), _buildDraggableDrawer()],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
