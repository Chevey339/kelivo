import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'sidebar_resize_capture.dart';
import '../theme/surface_ladder.dart';

/// Sidebar resize handle widget for desktop
class SidebarResizeHandle extends StatefulWidget {
  const SidebarResizeHandle({
    super.key,
    required this.visible,
    required this.onDrag,
    this.onDragEnd,
    this.hitWidth = 6,
  });

  final double hitWidth;
  final bool visible;
  final ValueChanged<double> onDrag;
  final VoidCallback? onDragEnd;

  @override
  State<SidebarResizeHandle> createState() => _SidebarResizeHandleState();
}

class _SidebarResizeHandleState extends State<SidebarResizeHandle>
    with WidgetsBindingObserver {
  bool _hovered = false;
  bool _appActive = true;
  int? _pointer;
  double _lastX = 0;
  late final _capture = SidebarResizeCapture(onEnd: _finish);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(SidebarResizeHandle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.visible) {
      _finish();
      _capture.updateCursor(null);
    } else if (_hovered || _pointer != null) {
      _scheduleCursorBounds();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    if (!_appActive) {
      _finish();
      _capture.updateCursor(null);
    } else if (_hovered) {
      _scheduleCursorBounds();
    }
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null || event.buttons != kPrimaryButton) return;
    setState(() => _pointer = event.pointer);
    _lastX = event.position.dx;
    if (event.kind == PointerDeviceKind.mouse &&
        defaultTargetPlatform == TargetPlatform.macOS) {
      // Capture only reroutes AppKit events back to Flutter's controller.
      // The same pointer stream works before and after the async acknowledgement.
      unawaited(_capture.begin(event.timeStamp));
    }
  }

  void _pointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    if (event.buttons & kPrimaryButton == 0) {
      _finish();
      return;
    }
    _move(event.position.dx);
  }

  void _move(double x) {
    if (_pointer == null) return;
    final delta = x - _lastX;
    _lastX = x;
    if (delta != 0) widget.onDrag(delta);
  }

  void _finish() {
    if (_pointer == null || !mounted) return;
    setState(() => _pointer = null);
    _capture.cancel();
    widget.onDragEnd?.call();
    _scheduleCursorBounds();
  }

  void _scheduleCursorBounds() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject();
      _capture.updateCursor(
        widget.visible &&
                _appActive &&
                (_hovered || _pointer != null) &&
                box is RenderBox &&
                box.hasSize
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pointer = null;
    _capture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!widget.visible) return const SizedBox.shrink();
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: _pointerMove,
      onPointerUp: (event) {
        if (event.pointer == _pointer) _finish();
      },
      onPointerCancel: (event) {
        if (event.pointer == _pointer) _finish();
      },
      onPointerHover: (_) => _finish(),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        onEnter: (_) {
          setState(() => _hovered = true);
          _scheduleCursorBounds();
        },
        onExit: (_) {
          setState(() => _hovered = false);
          _scheduleCursorBounds();
        },
        child: Container(
          width: widget.hitWidth,
          height: double.infinity,
          // Native overlay hit testing follows painted bounds, not Flutter's
          // opaque listener. Paint the entire grip without a visible fill.
          color: const Color(0x01000000),
          alignment: Alignment.center,
          child: Container(
            width: 1,
            height: double.infinity,
            color: _hovered || _pointer != null
                ? SurfaceLadder.fromScheme(cs).hairlineStrong
                : SurfaceLadder.fromScheme(
                    cs,
                  ).hairlineStrong.withValues(alpha: .12),
          ),
        ),
      ),
    );
  }
}
