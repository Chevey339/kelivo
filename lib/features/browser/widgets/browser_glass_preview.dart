import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/browser_models.dart';
import 'browser_glass.dart';

/// Interaction/layout preview; optical fidelity is validated on native hosts,
/// because the web previewer's renderer cannot run Impeller image filters.
@Preview(name: 'Browser glass · light', group: 'Browser', size: Size(390, 844))
Widget browserGlassLightPreview() => const BrowserGlassPreview();

@Preview(name: 'Browser glass · dark', group: 'Browser', size: Size(390, 844))
Widget browserGlassDarkPreview() => const BrowserGlassPreview(dark: true);

class BrowserGlassPreview extends StatefulWidget {
  const BrowserGlassPreview({super.key, this.dark = false});

  final bool dark;

  @override
  State<BrowserGlassPreview> createState() => _BrowserGlassPreviewState();
}

class _BrowserGlassPreviewState extends State<BrowserGlassPreview> {
  bool _menu = false;

  Widget _button(IconData icon, String label, VoidCallback action) =>
      BrowserPress(
        semanticLabel: label,
        draggable: true,
        onTap: action,
        child: BrowserGlass(
          child: SizedBox(width: 48, height: 48, child: Icon(icon, size: 21)),
        ),
      );

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF384C61),
        brightness: widget.dark ? Brightness.dark : Brightness.light,
      ),
      useMaterial3: true,
    ),
    home: BrowserGlassScope(
      style: BrowserSurfaceStyle.liquid,
      child: Scaffold(
        body: BrowserWallpaper(
          child: SafeArea(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 16,
                  left: 20,
                  child: _button(LucideIcons.chevronDown, '关闭', () {}),
                ),
                Positioned(
                  top: 130,
                  left: 28,
                  right: 28,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '开始探索',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('搜索网页，或者让 Agent 帮你浏览。'),
                      const SizedBox(height: 46),
                      const Text(
                        '个人收藏',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final item in [
                            (LucideIcons.globe, 'Apple'),
                            (LucideIcons.gitBranch, 'GitHub'),
                            (LucideIcons.code, 'Flutter'),
                          ])
                            Column(
                              children: [
                                _button(item.$1, item.$2, () {}),
                                const SizedBox(height: 12),
                                Text(
                                  item.$2,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_menu)
                  Positioned(
                    right: 16,
                    bottom: 82,
                    width: 268,
                    child: BrowserGlass(
                      radius: 32,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final item in [
                            (LucideIcons.bookmark, '添加到书签'),
                            (LucideIcons.plus, '新建标签页'),
                            (LucideIcons.history, '历史记录'),
                            (LucideIcons.settings2, '浏览器设置'),
                          ])
                            BrowserPress(
                              onTap: () => setState(() => _menu = false),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 16,
                                ),
                                child: Row(
                                  children: [
                                    Icon(item.$1, size: 21),
                                    const SizedBox(width: 18),
                                    Text(
                                      item.$2,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Row(
                    children: [
                      _button(LucideIcons.chevronLeft, '后退', () {}),
                      const SizedBox(width: 8),
                      Expanded(
                        child: BrowserPress(
                          onTap: () {},
                          draggable: true,
                          child: BrowserGlass(
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 15,
                              ),
                              child: Row(
                                children: [
                                  Icon(LucideIcons.panelBottom, size: 19),
                                  Expanded(
                                    child: Text(
                                      '搜索或输入网址',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  Icon(LucideIcons.rotateCw, size: 19),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _button(
                        LucideIcons.ellipsis,
                        '更多',
                        () => setState(() => _menu = !_menu),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
