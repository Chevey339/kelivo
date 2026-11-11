import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../features/chat/widgets/frosted/chat_frosted_backdrop.dart';
import 'widgets/desktop_pane_surface.dart';

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
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final titleBar = SizedBox(
      height: 40,
      child: Row(
        children: [
          const SizedBox(width: 6),
          ...widget.leftChildren,
          // https://github.com/leanflutter/window_manager/issues/136
          // Only the middle area should be draggable, not the buttons.
          Expanded(child: DragToMoveArea(child: const SizedBox.expand())),
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
    // Sample the shared desktop wallpaper just like the adjacent sidebars.
    // Keep the standalone window's solid surface when no wallpaper is present.
    final wallpaper =
        ChatFrostedBackdropScope.maybeOf(context)?.backgroundActive ?? false;
    return wallpaper
        ? DesktopPaneSurface(child: titleBar)
        : ColoredBox(color: theme.scaffoldBackgroundColor, child: titleBar);
  }
}
