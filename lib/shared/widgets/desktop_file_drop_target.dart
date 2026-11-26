import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Desktop drop events are broadcast to every registered target in the window.
/// Accept them only on the surface that would receive a pointer at that point.
class DesktopFileDropTarget extends StatefulWidget {
  const DesktopFileDropTarget({
    super.key,
    required this.onFiles,
    required this.overlay,
    required this.child,
  });

  final ValueChanged<List<DropItem>> onFiles;
  final Widget overlay, child;

  @override
  State<DesktopFileDropTarget> createState() => _DesktopFileDropTargetState();
}

class _DesktopFileDropTargetState extends State<DesktopFileDropTarget> {
  bool _enabled = false;
  bool _hover = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    if (!_enabled) _hover = false;
  }

  bool _hit(Offset global) {
    final result = HitTestResult();
    RendererBinding.instance.hitTestInView(
      result,
      global,
      View.of(context).viewId,
    );
    final surface = context.findRenderObject();
    return result.path.any((entry) => identical(entry.target, surface));
  }

  void _setHover(bool hover) {
    if (_hover != hover) setState(() => _hover = hover);
  }

  void _update(DropEventDetails event) => _setHover(_hit(event.globalPosition));

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    child: DropTarget(
      enable: _enabled,
      onDragEntered: _update,
      onDragUpdated: _update,
      onDragExited: _enabled ? (_) => _setHover(false) : null,
      onDragDone: (event) {
        if (_hit(event.globalPosition)) widget.onFiles(event.files);
      },
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          if (_hover)
            Positioned.fill(child: IgnorePointer(child: widget.overlay)),
        ],
      ),
    ),
  );
}
