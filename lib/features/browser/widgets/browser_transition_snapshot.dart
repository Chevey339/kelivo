import 'package:flutter/widgets.dart';

/// Retains one resolved image of an opaque, Flutter-only page during motion.
/// Native browser views must remain outside this subtree. The original widgets
/// stay mounted, and resume live painting when motion completes or is cancelled.
class BrowserTransitionSnapshot extends StatefulWidget {
  const BrowserTransitionSnapshot({
    super.key,
    required this.animation,
    required this.child,
    this.painter,
  });

  final Animation<double> animation;
  final Widget child;
  final SnapshotPainter? painter;

  @override
  State<BrowserTransitionSnapshot> createState() =>
      _BrowserTransitionSnapshotState();
}

class _BrowserTransitionSnapshotState extends State<BrowserTransitionSnapshot> {
  final _controller = SnapshotController();
  bool _interactive = false;

  bool get _moving => switch (widget.animation.status) {
    AnimationStatus.forward || AnimationStatus.reverse => true,
    _ => false,
  };

  @override
  void initState() {
    super.initState();
    _controller.allowSnapshotting = _moving;
    _interactive = widget.animation.status == AnimationStatus.completed;
    widget.animation.addListener(_motionChanged);
    widget.animation.addStatusListener(_statusChanged);
  }

  @override
  void didUpdateWidget(BrowserTransitionSnapshot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeListener(_motionChanged);
      oldWidget.animation.removeStatusListener(_statusChanged);
      widget.animation.addListener(_motionChanged);
      widget.animation.addStatusListener(_statusChanged);
      _controller.allowSnapshotting = _moving;
      _interactive = widget.animation.status == AnimationStatus.completed;
    }
  }

  void _statusChanged(AnimationStatus _) => _motionChanged();

  void _motionChanged() {
    final moving = _moving;
    final interactive = widget.animation.status == AnimationStatus.completed;
    if (_controller.allowSnapshotting == moving &&
        _interactive == interactive) {
      return;
    }
    setState(() {
      _controller.allowSnapshotting = moving;
      _interactive = interactive;
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = TickerMode(enabled: _interactive, child: widget.child);
    return IgnorePointer(
      ignoring: !_interactive,
      child: ExcludeSemantics(
        excluding: !_interactive,
        child: widget.painter == null
            ? SnapshotWidget(
                controller: _controller,
                autoresize: true,
                child: child,
              )
            : SnapshotWidget(
                controller: _controller,
                painter: widget.painter!,
                autoresize: true,
                child: child,
              ),
      ),
    );
  }

  @override
  void dispose() {
    widget.animation.removeListener(_motionChanged);
    widget.animation.removeStatusListener(_statusChanged);
    _controller.dispose();
    super.dispose();
  }
}
