import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../../../desktop/window_title_bar.dart';
import '../widgets/browser_desktop_toolbar.dart';
import '../widgets/browser_glass.dart';

/// Tabs occupy the title row; the address and navigation sit immediately below.
/// Native inset support allows the fixed viewport to scroll behind the header.
class BrowserDesktopLayout extends StatelessWidget {
  const BrowserDesktopLayout({
    super.key,
    required this.tabBar,
    required this.toolbar,
    required this.content,
    this.agentStatus,
    this.findBar,
    this.tabActions,
    this.embedded = false,
    this.underlapHeader = false,
  });

  final Widget tabBar;
  final Widget toolbar;
  final Widget content;
  final Widget? agentStatus;
  final Widget? findBar;
  final Widget? tabActions;
  final bool embedded;

  /// Enable only after the native viewport supplies a matching obscured inset.
  /// Without it, reserve the header height so fixed website headers stay usable.
  final bool underlapHeader;

  static const double tabHeight = 44;
  static const double headerHeight = tabHeight + BrowserDesktopToolbar.height;

  @override
  Widget build(BuildContext context) {
    final windows = defaultTargetPlatform == TargetPlatform.windows;
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    final body = Column(
      children: [
        if (windows && !embedded) const WindowTitleBar(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  top: underlapHeader ? 0 : headerHeight,
                  child: content,
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: BrowserGlass(
                    key: const ValueKey('browserDesktopHeader'),
                    radius: 0,
                    clear: true,
                    elevated: false,
                    child: Column(
                      children: [
                        SizedBox(
                          height: tabHeight,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (!embedded && !windows)
                                const DragToMoveArea(
                                  key: ValueKey('browserWindowDragArea'),
                                  child: ColoredBox(color: Color(0x01000000)),
                                ),
                              Padding(
                                padding: EdgeInsets.only(
                                  left: mac && !embedded ? 96 : 0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(child: tabBar),
                                    if (tabActions != null) tabActions!,
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        toolbar,
                      ],
                    ),
                  ),
                ),
                if (agentStatus != null || findBar != null)
                  Positioned(
                    top: headerHeight + 12,
                    left: 14,
                    right: 14,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (agentStatus != null) agentStatus!,
                        if (agentStatus != null && findBar != null)
                          const SizedBox(height: 8),
                        if (findBar != null)
                          Align(
                            alignment: Alignment.topRight,
                            child: SizedBox(
                              width: math.min(
                                360,
                                math.max(0, constraints.maxWidth - 28),
                              ),
                              child: BrowserGlass(
                                key: const ValueKey(
                                  'browserDesktopFindSurface',
                                ),
                                radius: 12,
                                child: findBar!,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
    return embedded ? body : SafeArea(child: body);
  }
}
