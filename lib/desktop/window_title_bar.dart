import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import '../core/providers/settings_provider.dart';

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
    final sp = context.watch<SettingsProvider>();
    final isDark = brightness == Brightness.dark;
    final Color bg = sp.usePureBackground ? (isDark ? Colors.black : Colors.white) : cs.surfaceContainerHighest;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        // border: Border(
        //   bottom: BorderSide(
        //     color: cs.outlineVariant.withOpacity(0.25),
        //     width: 0.5,
        //   ),
        // ),
      ),
      child: DragToMoveArea(
        child: Row(
          children: [
            const SizedBox(width: 6),
            ...widget.leftChildren,
            const Spacer(),
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
      ),
    );
  }
}

