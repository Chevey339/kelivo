import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// A custom Windows title bar implemented in Flutter.
///
/// - Provides a drag area for moving the window
/// - Renders minimize / maximize / restore / close buttons
/// - Accepts optional left-side children (e.g., app icon, menu toggle)
class WindowTitleBar extends StatefulWidget {
  const WindowTitleBar({super.key, this.leftChildren = const <Widget>[]});

  final List<Widget> leftChildren;

  @override
  State<WindowTitleBar> createState() => _WindowTitleBarState();
}

class _WindowTitleBarState extends State<WindowTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final maximized = await windowManager.isMaximized();
      if (mounted) setState(() => _isMaximized = maximized);
    } catch (_) {}
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withOpacity(0.25),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          // Draggable area on the left side
          Expanded(
            child: DragToMoveArea(
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  ...widget.leftChildren,
                ],
              ),
            ),
          ),
          // Window control buttons (not draggable)
          WindowCaptionButton.minimize(
            brightness: brightness,
            onPressed: () => windowManager.minimize(),
          ),
          if (_isMaximized)
            WindowCaptionButton.unmaximize(
              brightness: brightness,
              onPressed: () => windowManager.unmaximize(),
            )
          else
            WindowCaptionButton.maximize(
              brightness: brightness,
              onPressed: () => windowManager.maximize(),
            ),
          WindowCaptionButton.close(
            brightness: brightness,
            onPressed: () => windowManager.close(),
          ),
        ],
      ),
    );
  }
}

