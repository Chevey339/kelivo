import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import '../icons/lucide_adapter.dart' as lucide;
import '../l10n/app_localizations.dart';
import '../theme/palettes.dart';
import '../core/providers/settings_provider.dart';
import '../shared/widgets/ios_switch.dart';

/// Desktop settings layout: left menu + vertical divider + right content.
/// For now, only the left menu and the Display Settings content are implemented.
class DesktopSettingsPage extends StatefulWidget {
  const DesktopSettingsPage({super.key});

  @override
  State<DesktopSettingsPage> createState() => _DesktopSettingsPageState();
}

enum _SettingsMenuItem {
  display,
  assistant,
  providers,
  defaultModel,
  search,
  mcp,
  quickPhrases,
  tts,
  backup,
  about,
}

class _DesktopSettingsPageState extends State<DesktopSettingsPage> {
  _SettingsMenuItem _selected = _SettingsMenuItem.display;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    String titleFor(_SettingsMenuItem it) {
      switch (it) {
        case _SettingsMenuItem.assistant:
          return l10n.settingsPageAssistant;
        case _SettingsMenuItem.providers:
          return l10n.settingsPageProviders;
        case _SettingsMenuItem.display:
          return l10n.settingsPageDisplay;
        case _SettingsMenuItem.defaultModel:
          return l10n.settingsPageDefaultModel;
        case _SettingsMenuItem.search:
          return l10n.settingsPageSearch;
        case _SettingsMenuItem.mcp:
          return l10n.settingsPageMcp;
        case _SettingsMenuItem.quickPhrases:
          return l10n.settingsPageQuickPhrase;
        case _SettingsMenuItem.tts:
          return l10n.settingsPageTts;
        case _SettingsMenuItem.backup:
          return l10n.settingsPageBackup;
        case _SettingsMenuItem.about:
          return l10n.settingsPageAbout;
      }
    }

    const double menuWidth = 256;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topBar = SizedBox(
      height: 36,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, top: 8),
          child: Text(
            l10n.settingsPageTitle, // 固定显示“设置”
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          topBar,
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SettingsMenu(
                  width: 256,
                  selected: _selected,
                  onSelect: (it) => setState(() => _selected = it),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 0.5,
                  color: cs.outlineVariant.withOpacity(0.12),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOutCubic,
                    child: _selected == _SettingsMenuItem.display
                        ? const _DisplaySettingsBody(key: ValueKey('display'))
                        : _ComingSoonBody(selected: _selected),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsMenu extends StatelessWidget {
  const _SettingsMenu({
    required this.width,
    required this.selected,
    required this.onSelect,
  });
  final double width;
  final _SettingsMenuItem selected;
  final ValueChanged<_SettingsMenuItem> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = [
      (_SettingsMenuItem.display, lucide.Lucide.Monitor, l10n.settingsPageDisplay),
      (_SettingsMenuItem.assistant, lucide.Lucide.Bot, l10n.settingsPageAssistant),
      (_SettingsMenuItem.providers, lucide.Lucide.Boxes, l10n.settingsPageProviders),
      (_SettingsMenuItem.defaultModel, lucide.Lucide.Heart, l10n.settingsPageDefaultModel),
      (_SettingsMenuItem.search, lucide.Lucide.Earth, l10n.settingsPageSearch),
      (_SettingsMenuItem.mcp, lucide.Lucide.Terminal, l10n.settingsPageMcp),
      (_SettingsMenuItem.quickPhrases, lucide.Lucide.Zap, l10n.settingsPageQuickPhrase),
      (_SettingsMenuItem.tts, lucide.Lucide.Volume2, l10n.settingsPageTts),
      (_SettingsMenuItem.backup, lucide.Lucide.Database, l10n.settingsPageBackup),
      (_SettingsMenuItem.about, lucide.Lucide.BadgeInfo, l10n.settingsPageAbout),
    ];
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: width,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _MenuItem(
              icon: items[i].$2,
              label: items[i].$3,
              selected: selected == items[i].$1,
              onTap: () => onSelect(items[i].$1),
              color: cs.onSurface.withOpacity(0.9),
              selectedColor: cs.primary,
              hoverBg: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
            ),
            if (i != items.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatefulWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
    required this.selectedColor,
    required this.hoverBg,
  });

    final IconData icon;
    final String label;
    final bool selected;
    final VoidCallback onTap;
    final Color color;
    final Color selectedColor;
    final Color hoverBg;

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = widget.selected
        ? cs.primary.withOpacity(0.10)
        : _hover
            ? widget.hoverBg
            : Colors.transparent;
    final fg = widget.selected ? widget.selectedColor : widget.color;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 18, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w400, color: fg, decoration: TextDecoration.none),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoonBody extends StatelessWidget {
  const _ComingSoonBody({required this.selected});
  final _SettingsMenuItem selected;
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
          'Coming soon',
          style: TextStyle(fontSize: 16, color: cs.onSurface.withOpacity(0.7), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ===== Display Settings Body =====

class _DisplaySettingsBody extends StatelessWidget {
  const _DisplaySettingsBody({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SettingsCard(
                title: l10n.settingsPageDisplay,
                children: const [
                  _ColorModeRow(),
                  _RowDivider(),
                  _ThemeColorRow(),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                title: l10n.desktopSettingsFontsTitle,
                children: const [
                  _AppLanguageRow(),
                  _RowDivider(),
                  _ChatFontSizeRow(),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                title: l10n.displaySettingsPageChatItemDisplayTitle,
                children: const [
                  _ToggleRowShowUserAvatar(),
                  _RowDivider(),
                  _ToggleRowShowUserNameTs(),
                  _RowDivider(),
                  _ToggleRowShowUserMsgActions(),
                  _RowDivider(),
                  _ToggleRowShowModelIcon(),
                  _RowDivider(),
                  _ToggleRowShowModelNameTs(),
                  _RowDivider(),
                  _ToggleRowShowTokenStats(),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                title: l10n.displaySettingsPageRenderingSettingsTitle,
                children: const [
                  _ToggleRowDollarLatex(),
                  _RowDivider(),
                  _ToggleRowMathRendering(),
                  _RowDivider(),
                  _ToggleRowUserMarkdown(),
                  _RowDivider(),
                  _ToggleRowReasoningMarkdown(),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                title: l10n.displaySettingsPageBehaviorStartupTitle,
                children: const [
                  _ToggleRowAutoCollapseThinking(),
                  _RowDivider(),
                  _ToggleRowShowUpdates(),
                  _RowDivider(),
                  _ToggleRowMsgNavButtons(),
                  _RowDivider(),
                  _ToggleRowShowChatListDate(),
                  _RowDivider(),
                  _ToggleRowNewChatOnLaunch(),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                title: l10n.displaySettingsPageOtherSettingsTitle,
                children: const [
                  _AutoScrollDelayRow(),
                  _RowDivider(),
                  _BackgroundMaskRow(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          width: 0.5,
          color: isDark ? Colors.white.withOpacity(0.06) : cs.outlineVariant.withOpacity(0.12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
              child: Text(
                title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Divider(
        height: 1,
        thickness: 0.5,
        indent: 8,
        endIndent: 8,
        color: cs.outlineVariant.withOpacity(0.12),
      ),
    );
  }
}

class _LabeledRow extends StatelessWidget {
  const _LabeledRow({required this.label, required this.trailing});
  final String label;
  final Widget trailing;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: cs.onSurface, decoration: TextDecoration.none),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: trailing,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Color Mode ---
class _ColorModeRow extends StatelessWidget {
  const _ColorModeRow();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _LabeledRow(
      label: l10n.settingsPageColorMode,
      trailing: const _ThemeModeSegmented(),
    );
  }
}

class _ThemeModeSegmented extends StatefulWidget {
  const _ThemeModeSegmented();
  @override
  State<_ThemeModeSegmented> createState() => _ThemeModeSegmentedState();
}

class _ThemeModeSegmentedState extends State<_ThemeModeSegmented> {
  int _hover = -1;
  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final mode = sp.themeMode;
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = [
      (ThemeMode.light, l10n.settingsPageLightMode, lucide.Lucide.Sun),
      (ThemeMode.dark, l10n.settingsPageDarkMode, lucide.Lucide.Moon),
      (ThemeMode.system, l10n.settingsPageSystemMode, lucide.Lucide.Monitor),
    ];

    final trackBg = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04);
    return Container(
      decoration: BoxDecoration(color: trackBg, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            MouseRegion(
              onEnter: (_) => setState(() => _hover = i),
              onExit: (_) => setState(() => _hover = -1),
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => context.read<SettingsProvider>().setThemeMode(items[i].$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: () {
                      final selected = mode == items[i].$1;
                      if (selected) return cs.primary.withOpacity(isDark ? 0.18 : 0.14);
                      if (_hover == i) return isDark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06);
                      return Colors.transparent;
                    }(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[i].$3,
                        size: 16,
                        color: (mode == items[i].$1)
                            ? cs.primary
                            : cs.onSurface.withOpacity(0.74),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        items[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: (mode == items[i].$1)
                              ? cs.primary
                              : cs.onSurface.withOpacity(0.82),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (i != items.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _HoverPill extends StatelessWidget {
  const _HoverPill({
    required this.hovered,
    required this.selected,
    required this.onHover,
    required this.onTap,
    required this.label,
    required this.icon,
  });
  final bool hovered;
  final bool selected;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = selected
        ? cs.primary.withOpacity(0.12)
        : hovered
            ? (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04))
            : Colors.transparent;
    final fg = selected ? cs.primary : cs.onSurface.withOpacity(0.86);
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? cs.primary.withOpacity(0.35) : cs.outlineVariant.withOpacity(0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: fg, decoration: TextDecoration.none)),
              const SizedBox(width: 8),
              Icon(icon, size: 16, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Theme Color ---
class _ThemeColorRow extends StatelessWidget {
  const _ThemeColorRow();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _LabeledRow(
      label: l10n.displaySettingsPageThemeColorTitle,
      trailing: const _ThemeDots(),
    );
  }
}

class _ThemeDots extends StatelessWidget {
  const _ThemeDots();
  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final selected = sp.themePaletteId;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final p in ThemePalettes.all)
          _ThemeDot(
            color: p.light.primary,
            selected: selected == p.id,
            onTap: () => context.read<SettingsProvider>().setThemePalette(p.id),
          ),
      ],
    );
  }
}

class _ThemeDot extends StatefulWidget {
  const _ThemeDot({required this.color, required this.selected, required this.onTap});
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  @override
  State<_ThemeDot> createState() => _ThemeDotState();
}

class _ThemeDotState extends State<_ThemeDot> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: _hover
                ? [BoxShadow(color: widget.color.withOpacity(0.45), blurRadius: 14, spreadRadius: 1)]
                : [],
            border: Border.all(
              color: widget.selected ? cs.onSurface.withOpacity(0.85) : Colors.white,
              width: widget.selected ? 2 : 2,
            ),
          ),
        ),
      ),
    );
  }
}

// --- Fonts: language + chat font size ---
class _AppLanguageRow extends StatefulWidget {
  const _AppLanguageRow();
  @override
  State<_AppLanguageRow> createState() => _AppLanguageRowState();
}

class _AppLanguageRowState extends State<_AppLanguageRow> {
  bool _hover = false;
  bool _open = false;
  final GlobalKey _key = GlobalKey();
  OverlayEntry? _entry;
  final LayerLink _link = LayerLink();

  void _openDropdownOverlay() {
    if (_entry != null) return;
    final rb = _key.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox = Overlay.of(context)?.context.findRenderObject() as RenderBox?;
    if (rb == null || overlayBox == null) return;
    final size = rb.size;
    final triggerW = size.width;
    final maxW = 280.0;
    final minW = triggerW;
    _entry = OverlayEntry(builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      // measure desired content width for centering under trigger
      double measureContentWidth() {
        final style = const TextStyle(fontSize: 16);
        final labels = <String>[
          '🖥️ ${AppLocalizations.of(ctx)!.settingsPageSystemMode}',
          '🇨🇳 ${AppLocalizations.of(ctx)!.displaySettingsPageLanguageChineseLabel}',
          '🇨🇳 ${AppLocalizations.of(ctx)!.languageDisplayTraditionalChinese}',
          '🇺🇸 ${AppLocalizations.of(ctx)!.displaySettingsPageLanguageEnglishLabel}',
        ];
        double maxText = 0;
        for (final s in labels) {
          final tp = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr, maxLines: 1)..layout();
          if (tp.width > maxText) maxText = tp.width;
        }
        // item padding (12*2) + check icon (16) + gap (10) + list padding (8*2)
        return maxText + 12 * 2 + 16 + 10 + 8 * 2;
      }
      final contentW = measureContentWidth();
      final width = contentW.clamp(minW, maxW);
      final dx = (triggerW - width) / 2;
      return Stack(children: [
        // tap outside to close
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _closeDropdownOverlay,
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          offset: Offset(dx, size.height + 6),
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: width, maxWidth: width),
              child: _LanguageDropdown(onClose: _closeDropdownOverlay),
            ),
          ),
        ),
      ]);
    });
    Overlay.of(context)?.insert(_entry!);
    setState(() => _open = true);
  }

  void _closeDropdownOverlay() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    String labelFor(Locale l) {
      if (l.languageCode == 'zh') {
        if ((l.scriptCode ?? '').toLowerCase() == 'hant') return l10n.languageDisplayTraditionalChinese;
        return l10n.displaySettingsPageLanguageChineseLabel;
      }
      return l10n.displaySettingsPageLanguageEnglishLabel;
    }
    final current = sp.isFollowingSystemLocale ? l10n.settingsPageSystemMode : labelFor(sp.appLocale);
    return _LabeledRow(
      label: l10n.displaySettingsPageLanguageTitle,
      trailing: CompositedTransformTarget(
        link: _link,
        child: _HoverDropdownButton(
          key: _key,
          hovered: _hover,
          open: _open,
          label: current,
          onHover: (v) => setState(() => _hover = v),
          onTap: () {
            if (_open) {
              _closeDropdownOverlay();
            } else {
              _openDropdownOverlay();
            }
          },
        ),
      ),
    );
  }
}

class _HoverDropdownButton extends StatelessWidget {
  const _HoverDropdownButton({super.key, required this.hovered, required this.open, required this.label, required this.onHover, required this.onTap});
  final bool hovered;
  final bool open;
  final String label;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = hovered || open ? (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)) : Colors.transparent;
    final angle = open ? 3.1415926 : 0.0;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.2), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 16, color: cs.onSurface.withOpacity(0.9), fontWeight: FontWeight.w400)),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: angle / (2 * 3.1415926),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: Icon(lucide.Lucide.ChevronDown, size: 16, color: cs.onSurface.withOpacity(0.8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageDropdown extends StatefulWidget {
  const _LanguageDropdown({required this.onClose});
  final VoidCallback onClose;
  @override
  State<_LanguageDropdown> createState() => _LanguageDropdownState();
}

class _LanguageDropdownState extends State<_LanguageDropdown> {
  double _opacity = 0;
  Offset _slide = const Offset(0, -0.02);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() { _opacity = 1; _slide = Offset.zero; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    final items = <(_LangItem, bool)>[
      (_LangItem(flag: '🖥️', label: l10n.settingsPageSystemMode, tag: 'system'), sp.isFollowingSystemLocale),
      (_LangItem(flag: '🇨🇳', label: l10n.displaySettingsPageLanguageChineseLabel, tag: 'zh_CN'), (!sp.isFollowingSystemLocale && sp.appLocale.languageCode == 'zh' && (sp.appLocale.scriptCode ?? '').isEmpty)),
      (_LangItem(flag: '🇨🇳', label: l10n.languageDisplayTraditionalChinese, tag: 'zh_Hant'), (!sp.isFollowingSystemLocale && sp.appLocale.languageCode == 'zh' && (sp.appLocale.scriptCode ?? '').toLowerCase() == 'hant')),
      (_LangItem(flag: '🇺🇸', label: l10n.displaySettingsPageLanguageEnglishLabel, tag: 'en_US'), (!sp.isFollowingSystemLocale && sp.appLocale.languageCode == 'en')),
    ];
    final maxH = MediaQuery.of(context).size.height * 0.5;
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _slide,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.12), width: 0.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 6)),
              ],
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final ent in items)
                      _LanguageDropdownItem(
                        item: ent.$1,
                        checked: ent.$2,
                        onTap: () async {
                          switch (ent.$1.tag) {
                            case 'system':
                              await context.read<SettingsProvider>().setAppLocaleFollowSystem();
                              break;
                            case 'zh_CN':
                              await context.read<SettingsProvider>().setAppLocale(const Locale('zh', 'CN'));
                              break;
                            case 'zh_Hant':
                              await context.read<SettingsProvider>().setAppLocale(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'));
                              break;
                            case 'en_US':
                            default:
                              await context.read<SettingsProvider>().setAppLocale(const Locale('en', 'US'));
                          }
                          if (!mounted) return;
                          widget.onClose();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LangItem {
  final String flag;
  final String label;
  final String tag; // 'system' | 'zh_CN' | 'zh_Hant' | 'en_US'
  const _LangItem({required this.flag, required this.label, required this.tag});
}

class _LanguageDropdownItem extends StatefulWidget {
  const _LanguageDropdownItem({required this.item, this.checked = false, required this.onTap});
  final _LangItem item;
  final bool checked;
  final VoidCallback onTap;
  @override
  State<_LanguageDropdownItem> createState() => _LanguageDropdownItemState();
}

class _LanguageDropdownItemState extends State<_LanguageDropdownItem> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _hover ? (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Text(widget.item.flag, style: const TextStyle(fontSize: 16, decoration: TextDecoration.none)),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.item.label, style: TextStyle(fontSize: 14, color: cs.onSurface, decoration: TextDecoration.none))),
              if (widget.checked) ...[
                const SizedBox(width: 10),
                Icon(lucide.Lucide.Check, size: 16, color: cs.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatFontSizeRow extends StatefulWidget {
  const _ChatFontSizeRow();
  @override
  State<_ChatFontSizeRow> createState() => _ChatFontSizeRowState();
}

class _ChatFontSizeRowState extends State<_ChatFontSizeRow> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    final scale = context.read<SettingsProvider>().chatFontScale;
    _controller = TextEditingController(text: '${(scale * 100).round()}');
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit(String text) {
    final v = text.trim();
    final n = double.tryParse(v);
    if (n == null) return;
    final clamped = (n / 100.0).clamp(0.8, 1.5);
    context.read<SettingsProvider>().setChatFontScale(clamped);
    _controller.text = '${(clamped * 100).round()}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return _LabeledRow(
      label: l10n.displaySettingsPageChatFontSizeTitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IntrinsicWidth(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 36, maxWidth: 72),
              child: _BorderInput(
                controller: _controller,
                onSubmitted: _commit,
                onFocusLost: _commit,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('%', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14, decoration: TextDecoration.none)),
        ],
      ),
    );
  }
}

class _BorderInput extends StatefulWidget {
  const _BorderInput({required this.controller, required this.onSubmitted, required this.onFocusLost});
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onFocusLost;
  @override
  State<_BorderInput> createState() => _BorderInputState();
}

class _BorderInputState extends State<_BorderInput> {
  late FocusNode _focus;
  bool _hover = false;
  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _focus.addListener(() {
      // Rebuild border color on focus change
      if (mounted) setState(() {});
      if (!_focus.hasFocus) widget.onFocusLost(widget.controller.text);
    });
  }
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // hover to change border color (not background)
    final active = _focus.hasFocus || _hover;
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.28), width: 0.8),
    );
    final hoverBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.38), width: 0.9),
    );
    final focusBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: cs.primary, width: 1.0),
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: isDark ? Colors.white10 : Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          border: baseBorder,
          enabledBorder: _focus.hasFocus ? focusBorder : (_hover ? hoverBorder : baseBorder),
          focusedBorder: focusBorder,
          hoverColor: Colors.transparent,
        ),
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}

// --- Toggles Groups ---
class _ToggleRowShowUserAvatar extends StatelessWidget {
  const _ToggleRowShowUserAvatar();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageShowUserAvatarTitle,
      value: sp.showUserAvatar,
      onChanged: (v) => context.read<SettingsProvider>().setShowUserAvatar(v),
    );
  }
}

class _ToggleRowShowUserNameTs extends StatelessWidget {
  const _ToggleRowShowUserNameTs();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageShowUserNameTimestampTitle,
      value: sp.showUserNameTimestamp,
      onChanged: (v) => context.read<SettingsProvider>().setShowUserNameTimestamp(v),
    );
  }
}

class _ToggleRowShowUserMsgActions extends StatelessWidget {
  const _ToggleRowShowUserMsgActions();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageShowUserMessageActionsTitle,
      value: sp.showUserMessageActions,
      onChanged: (v) => context.read<SettingsProvider>().setShowUserMessageActions(v),
    );
  }
}

class _ToggleRowShowModelIcon extends StatelessWidget {
  const _ToggleRowShowModelIcon();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageChatModelIconTitle,
      value: sp.showModelIcon,
      onChanged: (v) => context.read<SettingsProvider>().setShowModelIcon(v),
    );
  }
}

class _ToggleRowShowModelNameTs extends StatelessWidget {
  const _ToggleRowShowModelNameTs();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageShowModelNameTimestampTitle,
      value: sp.showModelNameTimestamp,
      onChanged: (v) => context.read<SettingsProvider>().setShowModelNameTimestamp(v),
    );
  }
}

class _ToggleRowShowTokenStats extends StatelessWidget {
  const _ToggleRowShowTokenStats();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageShowTokenStatsTitle,
      value: sp.showTokenStats,
      onChanged: (v) => context.read<SettingsProvider>().setShowTokenStats(v),
    );
  }
}

class _ToggleRowDollarLatex extends StatelessWidget {
  const _ToggleRowDollarLatex();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageEnableDollarLatexTitle,
      value: sp.enableDollarLatex,
      onChanged: (v) => context.read<SettingsProvider>().setEnableDollarLatex(v),
    );
  }
}

class _ToggleRowMathRendering extends StatelessWidget {
  const _ToggleRowMathRendering();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageEnableMathTitle,
      value: sp.enableMathRendering,
      onChanged: (v) => context.read<SettingsProvider>().setEnableMathRendering(v),
    );
  }
}

class _ToggleRowUserMarkdown extends StatelessWidget {
  const _ToggleRowUserMarkdown();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageEnableUserMarkdownTitle,
      value: sp.enableUserMarkdown,
      onChanged: (v) => context.read<SettingsProvider>().setEnableUserMarkdown(v),
    );
  }
}

class _ToggleRowReasoningMarkdown extends StatelessWidget {
  const _ToggleRowReasoningMarkdown();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageEnableReasoningMarkdownTitle,
      value: sp.enableReasoningMarkdown,
      onChanged: (v) => context.read<SettingsProvider>().setEnableReasoningMarkdown(v),
    );
  }
}

class _ToggleRowAutoCollapseThinking extends StatelessWidget {
  const _ToggleRowAutoCollapseThinking();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageAutoCollapseThinkingTitle,
      value: sp.autoCollapseThinking,
      onChanged: (v) => context.read<SettingsProvider>().setAutoCollapseThinking(v),
    );
  }
}

class _ToggleRowShowUpdates extends StatelessWidget {
  const _ToggleRowShowUpdates();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageShowUpdatesTitle,
      value: sp.showAppUpdates,
      onChanged: (v) => context.read<SettingsProvider>().setShowAppUpdates(v),
    );
  }
}

class _ToggleRowMsgNavButtons extends StatelessWidget {
  const _ToggleRowMsgNavButtons();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageMessageNavButtonsTitle,
      value: sp.showMessageNavButtons,
      onChanged: (v) => context.read<SettingsProvider>().setShowMessageNavButtons(v),
    );
  }
}

class _ToggleRowShowChatListDate extends StatelessWidget {
  const _ToggleRowShowChatListDate();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageShowChatListDateTitle,
      value: sp.showChatListDate,
      onChanged: (v) => context.read<SettingsProvider>().setShowChatListDate(v),
    );
  }
}

class _ToggleRowNewChatOnLaunch extends StatelessWidget {
  const _ToggleRowNewChatOnLaunch();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageNewChatOnLaunchTitle,
      value: sp.newChatOnLaunch,
      onChanged: (v) => context.read<SettingsProvider>().setNewChatOnLaunch(v),
    );
  }
}

class _ToggleRowHapticsGlobal extends StatelessWidget {
  const _ToggleRowHapticsGlobal();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageHapticsGlobalTitle,
      value: sp.hapticsGlobalEnabled,
      onChanged: (v) => context.read<SettingsProvider>().setHapticsGlobalEnabled(v),
    );
  }
}

class _ToggleRowHapticsSwitch extends StatelessWidget {
  const _ToggleRowHapticsSwitch();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageHapticsIosSwitchTitle,
      value: sp.hapticsIosSwitch,
      onChanged: (v) => context.read<SettingsProvider>().setHapticsIosSwitch(v),
    );
  }
}

class _ToggleRowHapticsSidebar extends StatelessWidget {
  const _ToggleRowHapticsSidebar();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageHapticsOnSidebarTitle,
      value: sp.hapticsOnDrawer,
      onChanged: (v) => context.read<SettingsProvider>().setHapticsOnDrawer(v),
    );
  }
}

class _ToggleRowHapticsListItem extends StatelessWidget {
  const _ToggleRowHapticsListItem();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageHapticsOnListItemTapTitle,
      value: sp.hapticsOnListItemTap,
      onChanged: (v) => context.read<SettingsProvider>().setHapticsOnListItemTap(v),
    );
  }
}

class _ToggleRowHapticsCardTap extends StatelessWidget {
  const _ToggleRowHapticsCardTap();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageHapticsOnCardTapTitle,
      value: sp.hapticsOnCardTap,
      onChanged: (v) => context.read<SettingsProvider>().setHapticsOnCardTap(v),
    );
  }
}

class _ToggleRowHapticsGenerate extends StatelessWidget {
  const _ToggleRowHapticsGenerate();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageHapticsOnGenerateTitle,
      value: sp.hapticsOnGenerate,
      onChanged: (v) => context.read<SettingsProvider>().setHapticsOnGenerate(v),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: cs.onSurface.withOpacity(0.96), decoration: TextDecoration.none),
            ),
          ),
          IosSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// --- Others: inputs ---
class _AutoScrollDelayRow extends StatefulWidget {
  const _AutoScrollDelayRow();
  @override
  State<_AutoScrollDelayRow> createState() => _AutoScrollDelayRowState();
}

class _AutoScrollDelayRowState extends State<_AutoScrollDelayRow> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    final seconds = context.read<SettingsProvider>().autoScrollIdleSeconds;
    _controller = TextEditingController(text: '${seconds.round()}');
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  void _commit(String text) {
    final v = text.trim();
    final n = int.tryParse(v);
    if (n == null) return;
    final clamped = n.clamp(2, 64);
    context.read<SettingsProvider>().setAutoScrollIdleSeconds(clamped);
    _controller.text = '$clamped';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _LabeledRow(
      label: l10n.displaySettingsPageAutoScrollIdleTitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IntrinsicWidth(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 36, maxWidth: 72),
              child: _BorderInput(controller: _controller, onSubmitted: _commit, onFocusLost: _commit),
            ),
          ),
          const SizedBox(width: 8),
          Text('s', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14, decoration: TextDecoration.none)),
        ],
      ),
    );
  }
}

class _BackgroundMaskRow extends StatefulWidget {
  const _BackgroundMaskRow();
  @override
  State<_BackgroundMaskRow> createState() => _BackgroundMaskRowState();
}

class _BackgroundMaskRowState extends State<_BackgroundMaskRow> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    final v = context.read<SettingsProvider>().chatBackgroundMaskStrength;
    _controller = TextEditingController(text: '${(v * 100).round()}');
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  void _commit(String text) {
    final v = text.trim();
    final n = double.tryParse(v);
    if (n == null) return;
    final clamped = (n / 100.0).clamp(0.0, 1.0);
    context.read<SettingsProvider>().setChatBackgroundMaskStrength(clamped);
    _controller.text = '${(clamped * 100).round()}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _LabeledRow(
      label: l10n.displaySettingsPageChatBackgroundMaskTitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IntrinsicWidth(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 36, maxWidth: 72),
              child: _BorderInput(controller: _controller, onSubmitted: _commit, onFocusLost: _commit),
            ),
          ),
          const SizedBox(width: 8),
          Text('%', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14, decoration: TextDecoration.none)),
        ],
      ),
    );
  }
}
