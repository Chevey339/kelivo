import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import '../shared/responsive/breakpoints.dart';
import 'desktop_nav_rail.dart';
import 'desktop_chat_page.dart';
import 'window_title_bar.dart';
import 'desktop_settings_page.dart';

/// Desktop home screen: left compact rail + main content.
/// Phase 1 focuses on structure and platform-appropriate interactions/hover.
class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({super.key});

  @override
  State<DesktopHomePage> createState() => _DesktopHomePageState();
}

class _DesktopHomePageState extends State<DesktopHomePage> {
  int _tabIndex = 0; // 0=Chat, 1=Translate, 2=Settings

  @override
  Widget build(BuildContext context) {
    // Ensure a reasonable min size to avoid overflow on aggressive resize.
    const minWidth = 960.0;
    const minHeight = 640.0;

    final isWindows = defaultTargetPlatform == TargetPlatform.windows;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final needsWidthPad = w < minWidth;
        final needsHeightPad = h < minHeight;

        Widget body = Row(
          children: [
            DesktopNavRail(
              activeIndex: _tabIndex,
              onTapChat: () => setState(() => _tabIndex = 0),
              onTapTranslate: () => setState(() => _tabIndex = 1),
              onTapSettings: () {
                setState(() => _tabIndex = 2);
              },
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: () {
                  if (_tabIndex == 0) return const DesktopChatPage();
                  if (_tabIndex == 1) return _TranslatePlaceholder(key: const ValueKey('translate_placeholder'));
                  return const DesktopSettingsPage(key: ValueKey('settings_page'));
                }(),
              ),
            ),
          ],
        );

        // Wrap with Windows custom title bar when on Windows platform.
        final content = isWindows
            ? Column(
                children: [
                  const WindowTitleBar(),
                  Expanded(child: body),
                ],
              )
            : body;

        if (!needsWidthPad && !needsHeightPad) return content;

        // Center a constrained area if window is smaller than our minimum
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: minWidth, minHeight: minHeight),
            child: SizedBox(
              width: needsWidthPad ? minWidth : w,
              height: needsHeightPad ? minHeight : h,
              child: content,
            ),
          ),
        );
      },
    );
  }
}

class _TranslatePlaceholder extends StatelessWidget {
  const _TranslatePlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.25)),
        ),
        child: Text(
          '翻译（占位）',
          style: TextStyle(fontSize: 16, color: cs.onSurface.withOpacity(0.7), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// No extra router/shim; we import DesktopSettingsPage directly above.
