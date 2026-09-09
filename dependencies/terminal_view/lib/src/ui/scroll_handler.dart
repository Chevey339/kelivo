import 'package:flutter/widgets.dart';
import 'package:terminal_view/core.dart';
import 'package:terminal_view/src/ui/infinite_scroll_view.dart';

/// Handles scrolling gestures in the alternate screen buffer. In alternate
/// screen buffer, the terminal don't have a scrollback buffer, instead, the
/// scroll gestures are converted to escape sequences based on the current
/// report mode declared by the application.
class TerminalScrollGestureHandler extends StatefulWidget {
  const TerminalScrollGestureHandler({
    super.key,
    required this.terminal,
    required this.getCellOffset,
    required this.getLineHeight,
    this.simulateScroll = true,
    this.forceAppScrollMode = false,
    required this.child,
  });

  final Terminal terminal;

  /// Returns the cell offset for the pixel offset.
  final CellOffset Function(Offset) getCellOffset;

  /// Returns the pixel height of lines in the terminal.
  final double Function() getLineHeight;

  /// Whether to simulate scroll events in the terminal when the application
  /// doesn't declare it supports mouse wheel events. true by default as it
  /// is the default behavior of most terminals.
  final bool simulateScroll;

  final bool forceAppScrollMode;

  final Widget child;

  @override
  State<TerminalScrollGestureHandler> createState() =>
      _TerminalScrollGestureHandlerState();
}

class _TerminalScrollGestureHandlerState
    extends State<TerminalScrollGestureHandler> {
  /// Whether the application currently owns scroll gestures. If false, then
  /// this widget does nothing.
  var appOwnsScroll = false;

  /// The variable that tracks the line offset in last scroll event. Used to
  /// determine how many the scroll events should be sent to the terminal.
  var lastLineOffset = 0;

  /// This variable tracks the last offset where the scroll gesture started.
  /// Used to calculate the cell offset of the terminal mouse event.
  var lastPointerPosition = Offset.zero;

  @override
  void initState() {
    widget.terminal.addListener(_onTerminalUpdated);
    appOwnsScroll = _appOwnsScroll;
    super.initState();
  }

  bool get _appOwnsScroll =>
      terminalOwnsScroll(widget.terminal, widget.forceAppScrollMode);

  @override
  void dispose() {
    widget.terminal.removeListener(_onTerminalUpdated);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TerminalScrollGestureHandler oldWidget) {
    if (oldWidget.terminal != widget.terminal) {
      oldWidget.terminal.removeListener(_onTerminalUpdated);
      widget.terminal.addListener(_onTerminalUpdated);
    }
    appOwnsScroll = _appOwnsScroll;
    super.didUpdateWidget(oldWidget);
  }

  void _onTerminalUpdated() {
    if (appOwnsScroll == _appOwnsScroll) return;
    setState(() => appOwnsScroll = _appOwnsScroll);
  }

  /// Send a single scroll event to the terminal. If [simulateScroll] is true,
  /// then if the application doesn't recognize mouse wheel events, this method
  /// will simulate scroll events by sending up/down arrow keys.
  void _sendScrollEvent(bool up) {
    final position = widget.getCellOffset(lastPointerPosition);

    final handled = widget.terminal.mouseInput(
      up ? TerminalMouseButton.wheelUp : TerminalMouseButton.wheelDown,
      TerminalMouseButtonState.down,
      position,
    );

    if (!handled && widget.simulateScroll) {
      widget.terminal.keyInput(
        up ? TerminalKey.arrowUp : TerminalKey.arrowDown,
      );
    }
  }

  void _onScroll(double offset) {
    final currentLineOffset = offset ~/ widget.getLineHeight();

    final delta = currentLineOffset - lastLineOffset;

    for (var i = 0; i < delta.abs(); i++) {
      _sendScrollEvent(delta < 0);
    }

    lastLineOffset = currentLineOffset;
  }

  @override
  Widget build(BuildContext context) {
    if (!terminalOwnsScroll(widget.terminal, widget.forceAppScrollMode)) {
      return widget.child;
    }

    // The pointer position is reported to the application as a cell offset, so
    // it has to be local to this widget - which shares its coordinate space
    // with the render object. Feeding global coordinates makes the reported
    // row land far below the touch, usually clamped to the last row, and the
    // application then scrolls whatever sits there instead of the pane under
    // the finger.
    return Listener(
      onPointerSignal: (event) {
        lastPointerPosition = event.localPosition;
      },
      onPointerDown: (event) {
        lastPointerPosition = event.localPosition;
      },
      onPointerMove: (event) {
        lastPointerPosition = event.localPosition;
      },
      child: InfiniteScrollView(
        onScroll: _onScroll,
        child: widget.child,
      ),
    );
  }
}

/// Whether scroll gestures belong to the application running in [terminal]
/// rather than to the scrollback.
///
/// This is the case in the alternate screen buffer, which has no scrollback,
/// and whenever the application turned on mouse reporting - a full screen UI
/// expects wheel events even if it never switched buffers.
bool terminalOwnsScroll(Terminal terminal, bool forceAppScrollMode) {
  return forceAppScrollMode ||
      terminal.isUsingAltBuffer ||
      terminal.mouseMode != MouseMode.none;
}
