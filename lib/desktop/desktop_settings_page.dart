import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:convert';

import '../icons/lucide_adapter.dart' as lucide;
import '../l10n/app_localizations.dart';
import '../theme/palettes.dart';
import '../core/providers/settings_provider.dart';
import '../core/providers/model_provider.dart';
import 'model_fetch_dialog.dart' show showModelFetchDialog;
import '../shared/widgets/ios_switch.dart';
// Desktop assistants panel dependencies
import '../features/assistant/pages/assistant_settings_edit_page.dart' show showAssistantDesktopDialog; // dialog opener only
import '../core/providers/assistant_provider.dart';
import '../core/models/assistant.dart';
import '../utils/avatar_cache.dart';
import '../utils/sandbox_path_resolver.dart';
import 'dart:io' show File;
import 'package:characters/characters.dart';
import '../features/provider/pages/multi_key_manager_page.dart';
import '../features/model/widgets/model_detail_sheet.dart';
import 'add_provider_dialog.dart' show showDesktopAddProviderDialog;
import 'model_edit_dialog.dart' show showDesktopCreateModelDialog, showDesktopModelEditDialog;
// Use the unified model selector (desktop dialog on desktop platforms)
import '../features/model/widgets/model_select_sheet.dart' show showModelSelector;
import '../utils/brand_assets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/models/api_keys.dart';
import 'package:file_picker/file_picker.dart';
import 'desktop_context_menu.dart';
import 'setting/default_model_pane.dart';
import 'setting/search_services_pane.dart';
import 'setting/mcp_pane.dart';
import 'setting/tts_services_pane.dart';
import 'setting/quick_phrases_pane.dart';
import 'setting/backup_pane.dart';
import 'setting/about_pane.dart';

/// Desktop settings layout: left menu + vertical divider + right content.
/// For now, only the left menu and the Display Settings content are implemented.
class DesktopSettingsPage extends StatefulWidget {
  const DesktopSettingsPage({super.key, this.initialProviderKey});

  // Optional: when provided, jump to Providers tab and preselect this provider
  final String? initialProviderKey;

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
  void initState() {
    super.initState();
    if (widget.initialProviderKey != null) {
      // Deep link into Providers tab when a provider is specified
      _selected = _SettingsMenuItem.providers;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                    child: () {
                      switch (_selected) {
                        case _SettingsMenuItem.display:
                          return const _DisplaySettingsBody(key: ValueKey('display'));
                        case _SettingsMenuItem.assistant:
                          return const _DesktopAssistantsBody(key: ValueKey('assistants'));
                        case _SettingsMenuItem.providers:
                          return _DesktopProvidersBody(key: const ValueKey('providers'), initialSelectedKey: widget.initialProviderKey);
                        case _SettingsMenuItem.defaultModel:
                          return const DesktopDefaultModelPane(key: ValueKey('defaultModel'));
                        case _SettingsMenuItem.search:
                          return const DesktopSearchServicesPane(key: ValueKey('search'));
                        case _SettingsMenuItem.mcp:
                          return const DesktopMcpPane(key: ValueKey('mcp'));
                        case _SettingsMenuItem.backup:
                          return const DesktopBackupPane(key: ValueKey('backup'));
                        case _SettingsMenuItem.quickPhrases:
                          return const DesktopQuickPhrasesPane(key: ValueKey('quickPhrases'));
                        case _SettingsMenuItem.tts:
                          return const DesktopTtsServicesPane(key: ValueKey('tts'));
                        case _SettingsMenuItem.about:
                          return const DesktopAboutPane(key: ValueKey('about'));
                        default:
                          return _ComingSoonBody(selected: _selected);
                      }
                    }(),
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

// ===== Assistants (Desktop right content) =====

class _DesktopAssistantsBody extends StatelessWidget {
  const _DesktopAssistantsBody({super.key});
  @override
  Widget build(BuildContext context) {
    final assistants = context.watch<AssistantProvider>().assistants;
    final cs = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              SizedBox(
                height: 36,
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          AppLocalizations.of(context)!.desktopAssistantsListTitle,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: cs.onSurface.withOpacity(0.9)),
                        ),
                      ),
                    ),
                    _AddAssistantButton(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withOpacity(0.0),
                  ),
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: EdgeInsets.zero,
                    itemCount: assistants.length,
                    onReorder: (oldIndex, newIndex) async {
                      if (newIndex > oldIndex) newIndex -= 1;
                      await context.read<AssistantProvider>().reorderAssistants(oldIndex, newIndex);
                    },
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, _) {
                          final t = Curves.easeOutCubic.transform(animation.value);
                          return Transform.scale(
                            scale: 0.98 + 0.02 * t,
                            child: Material(
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              child: child,
                            ),
                          );
                        },
                      );
                    },
                    itemBuilder: (context, index) {
                      final item = assistants[index];
                      return KeyedSubtree(
                        key: ValueKey('desktop-assistant-${item.id}'),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ReorderableDragStartListener(
                            index: index,
                            child: _DesktopAssistantCard(
                              item: item,
                              onTap: () => showAssistantDesktopDialog(context, assistantId: item.id),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddAssistantButton extends StatefulWidget {
  @override
  State<_AddAssistantButton> createState() => _AddAssistantButtonState();
}

class _AddAssistantButtonState extends State<_AddAssistantButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover ? (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)) : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          final name = await _showAddAssistantDesktopDialog(context);
          if (name == null || name.trim().isEmpty) return;
          await context.read<AssistantProvider>().addAssistant(name: name.trim(), context: context);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Icon(lucide.Lucide.Plus, size: 16, color: cs.primary),
        ),
      ),
    );
  }
}

Future<String?> _showAddAssistantDesktopDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final cs = Theme.of(context).colorScheme;
  final controller = TextEditingController();
  String? result;
  await showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(l10n.assistantSettingsAddSheetTitle, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip,
                        icon: const Icon(lucide.Lucide.X, size: 18),
                        color: cs.onSurface,
                        onPressed: () => Navigator.of(ctx).maybePop(),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: l10n.assistantSettingsAddSheetHint,
                        filled: true,
                        fillColor: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF7F7F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.primary.withOpacity(0.4)),
                        ),
                      ),
                      onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _DeskIosButton(
                          label: l10n.assistantSettingsAddSheetCancel,
                          filled: false,
                          dense: true,
                          onTap: () => Navigator.of(ctx).pop(),
                        ),
                        const SizedBox(width: 8),
                        _DeskIosButton(
                          label: l10n.assistantSettingsAddSheetSave,
                          filled: true,
                          dense: true,
                          onTap: () => Navigator.of(ctx).pop(controller.text.trim()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  ).then((v) => result = v);
  final s = (result ?? '').trim();
  if (s.isEmpty) return null;
  return s;
}

class _DeleteAssistantIcon extends StatefulWidget {
  const _DeleteAssistantIcon({required this.onConfirm});
  final Future<void> Function() onConfirm;
  @override
  State<_DeleteAssistantIcon> createState() => _DeleteAssistantIconState();
}

class _DeleteAssistantIconState extends State<_DeleteAssistantIcon> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover ? (isDark ? cs.error.withOpacity(0.18) : cs.error.withOpacity(0.14)) : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onConfirm(),
        child: Container(
          margin: const EdgeInsets.only(left: 8),
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(lucide.Lucide.Trash2, size: 15, color: cs.error),
        ),
      ),
    );
  }
}

Future<bool?> _confirmDeleteDesktop(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final cs = Theme.of(context).colorScheme;
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'assistant-delete',
    barrierColor: Colors.black.withOpacity(0.15),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (ctx, _, __) {
      // Positioned small dialog at bottom-right
      final dialog = Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 18, bottom: 18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: cs.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Theme.of(ctx).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.08)
                          : cs.outlineVariant.withOpacity(0.25)),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 40,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.assistantSettingsDeleteDialogTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip,
                                icon: const Icon(lucide.Lucide.X, size: 18),
                                color: cs.onSurface,
                                onPressed: () => Navigator.of(ctx).maybePop(false),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(height: 1, thickness: 0.5, color: cs.outlineVariant.withOpacity(0.12)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l10n.assistantSettingsDeleteDialogContent,
                              style: TextStyle(color: cs.onSurface.withOpacity(0.9), fontSize: 13.5),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _DeskIosButton(
                                  label: l10n.assistantSettingsDeleteDialogCancel,
                                  filled: false,
                                  dense: true,
                                  onTap: () => Navigator.of(ctx).pop(false),
                                ),
                                const SizedBox(width: 8),
                                _DeskIosButton(
                                  label: l10n.assistantSettingsDeleteDialogConfirm,
                                  filled: true,
                                  danger: true,
                                  dense: true,
                                  onTap: () => Navigator.of(ctx).pop(true),
                                ),
                              ],
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
        ),
      );
      return dialog;
    },
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.05, 0.05), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _DeskIosButton extends StatefulWidget {
  const _DeskIosButton({required this.label, required this.onTap, this.filled = false, this.danger = false, this.dense = false});
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool danger;
  final bool dense;
  @override
  State<_DeskIosButton> createState() => _DeskIosButtonState();
}

class _DeskIosButtonState extends State<_DeskIosButton> {
  bool _pressed = false;
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = widget.danger ? cs.error : cs.primary;
    final textColor = widget.filled ? (widget.danger ? cs.onError : cs.onPrimary) : baseColor;
    final baseBg = widget.filled ? baseColor : (isDark ? Colors.white10 : Colors.transparent);
    final hoverBg = widget.filled
        ? baseColor.withOpacity(0.92)
        : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04));
    final bg = _hover ? hoverBg : baseBg;
    final borderColor = widget.filled ? Colors.transparent : baseColor.withOpacity(isDark ? 0.6 : 0.5);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: widget.dense ? 8 : 12, horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Text(widget.label, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: widget.dense ? 13 : 14)),
        ),
      ),
      ),
    );
  }
}

class _DesktopAssistantCard extends StatefulWidget {
  const _DesktopAssistantCard({required this.item, required this.onTap});
  final Assistant item;
  final VoidCallback onTap;
  @override
  State<_DesktopAssistantCard> createState() => _DesktopAssistantCardState();
}

class _DesktopAssistantCardState extends State<_DesktopAssistantCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);
    final borderColor = _hover ? cs.primary.withOpacity(isDark ? 0.35 : 0.45) : cs.outlineVariant.withOpacity(isDark ? 0.12 : 0.08);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: _CardPress(
        onTap: widget.onTap,
        pressedScale: 1.0,
        builder: (pressed, overlay) => Container(
          decoration: BoxDecoration(
            color: Color.alphaBlend(overlay, baseBg),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _AssistantAvatarDesktop(item: widget.item, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (!widget.item.deletable)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: cs.primary.withOpacity(0.35)),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.assistantSettingsDefaultTag,
                                style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w700),
                              ),
                            )
                          else
                            _DeleteAssistantIcon(
                              onConfirm: () async {
                                final ok = await _confirmDeleteDesktop(context);
                                if (ok == true) {
                                  await context.read<AssistantProvider>().deleteAssistant(widget.item.id);
                                }
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (widget.item.systemPrompt.trim().isEmpty
                            ? AppLocalizations.of(context)!.assistantSettingsNoPromptPlaceholder
                            : widget.item.systemPrompt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.7), height: 1.25),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantAvatarDesktop extends StatelessWidget {
  const _AssistantAvatarDesktop({required this.item, this.size = 40});
  final Assistant item;
  final double size;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final av = (item.avatar ?? '').trim();
    if (av.isNotEmpty) {
      if (av.startsWith('http')) {
        return FutureBuilder<String?>(
          future: AvatarCache.getPath(av),
          builder: (ctx, snap) {
            final p = snap.data;
            if (p != null && File(p).existsSync()) {
              return ClipOval(child: Image(image: FileImage(File(p)), width: size, height: size, fit: BoxFit.cover));
            }
            return ClipOval(
              child: Image.network(av, width: size, height: size, fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => _initial(cs)),
            );
          },
        );
      } else if (av.startsWith('/') || av.contains(':')) {
        final fixed = SandboxPathResolver.fix(av);
        return ClipOval(child: Image(image: FileImage(File(fixed)), width: size, height: size, fit: BoxFit.cover));
      } else {
        return _emoji(cs, av);
      }
    }
    return _initial(cs);
  }

  Widget _initial(ColorScheme cs) {
    final letter = item.name.isNotEmpty ? item.name.characters.first : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: cs.primary.withOpacity(0.15), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: size * 0.42),
      ),
    );
  }

  Widget _emoji(ColorScheme cs, String emoji) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: cs.primary.withOpacity(0.15), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(emoji.characters.take(1).toString(), style: TextStyle(fontSize: size * 0.5)),
    );
  }
}

// ===== Providers (Desktop right content) =====

class _DesktopProvidersBody extends StatefulWidget {
  const _DesktopProvidersBody({super.key, this.initialSelectedKey});
  final String? initialSelectedKey;
  @override
  State<_DesktopProvidersBody> createState() => _DesktopProvidersBodyState();
}

class _DesktopProvidersBodyState extends State<_DesktopProvidersBody> {
  String? _selectedKey;
  final GlobalKey<_DesktopProviderDetailPaneState> _detailKey = GlobalKey<_DesktopProviderDetailPaneState>();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();

    // Base providers (same as mobile list)
    List<({String name, String key})> base() => [
          (name: 'OpenAI', key: 'OpenAI'),
          (name: l10n.providersPageSiliconFlowName, key: 'SiliconFlow'),
          (name: 'Gemini', key: 'Gemini'),
          (name: 'OpenRouter', key: 'OpenRouter'),
          (name: 'KelivoIN', key: 'KelivoIN'),
          (name: 'Tensdaq', key: 'Tensdaq'),
          (name: 'DeepSeek', key: 'DeepSeek'),
          (name: l10n.providersPageAliyunName, key: 'Aliyun'),
          (name: l10n.providersPageZhipuName, key: 'Zhipu AI'),
          (name: 'Claude', key: 'Claude'),
          (name: 'Grok', key: 'Grok'),
          (name: l10n.providersPageByteDanceName, key: 'ByteDance'),
        ];

    final cfgs = settings.providerConfigs;
    final baseKeys = {for (final p in base()) p.key};
    final dynamicItems = <({String name, String key})>[];
    cfgs.forEach((key, cfg) {
      if (!baseKeys.contains(key)) {
        dynamicItems.add((name: (cfg.name.isNotEmpty ? cfg.name : key), key: key));
      }
    });
    // Apply saved order
    final merged = <({String name, String key})>[...base(), ...dynamicItems];
    final order = settings.providersOrder;
    final map = {for (final p in merged) p.key: p};
    final ordered = <({String name, String key})>[];
    for (final k in order) {
      final v = map.remove(k);
      if (v != null) ordered.add(v);
    }
    ordered.addAll(map.values);

    _selectedKey ??= (widget.initialSelectedKey ?? (ordered.isNotEmpty ? ordered.first.key : null));
    final selectedKey = _selectedKey;
    final rightPane = selectedKey == null
        ? const SizedBox()
        : _DesktopProviderDetailPane(key: _detailKey, providerKey: selectedKey, displayName: settings.getProviderConfig(selectedKey).name.isNotEmpty
            ? settings.getProviderConfig(selectedKey).name
            : selectedKey);

    return Container(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            children: [
              // Left providers list
              SizedBox(
                width: 256,
                child: Column(
                  children: [
                    Expanded(
                      child: ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        padding: EdgeInsets.zero,
                        itemCount: ordered.length,
                        onReorder: (oldIndex, newIndex) async {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final list = List<({String name, String key})>.from(ordered);
                          final item = list.removeAt(oldIndex);
                          list.insert(newIndex, item);
                          final newOrder = [for (final e in list) e.key];
                          await settings.setProvidersOrder(newOrder);
                          if (mounted) setState(() {});
                        },
                        proxyDecorator: (child, index, animation) {
                          // No shadow; clip to rounded corners to avoid white outside of the grey card
                          return AnimatedBuilder(
                            animation: animation,
                            builder: (context, _) => ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: child,
                            ),
                          );
                        },
                        itemBuilder: (ctx, i) {
                          final item = ordered[i];
                          final cfg = settings.getProviderConfig(item.key, defaultName: item.name);
                          final enabled = cfg.enabled;
                          final selected = item.key == _selectedKey;
                          final bg = selected ? cs.primary.withOpacity(0.08) : Colors.transparent;
                          final row = _ProviderListRow(
                            name: item.name,
                            enabled: enabled,
                            selected: selected,
                            background: bg,
                            onTap: () => setState(() => _selectedKey = item.key),
                            onEdit: () {
                              setState(() => _selectedKey = item.key);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _detailKey.currentState?._showProviderSettingsDialog(context);
                              });
                            },
                            onDelete: baseKeys.contains(item.key)
                                ? null
                                : () async {
                                    final l10n = AppLocalizations.of(context)!;
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text(l10n.providerDetailPageDeleteProviderTitle),
                                        content: Text(l10n.providerDetailPageDeleteProviderContent),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.providerDetailPageCancelButton)),
                                          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l10n.providerDetailPageDeleteButton, style: const TextStyle(color: Colors.red))),
                                        ],
                                      ),
                                    );
                                    if (ok == true) {
                                      await settings.removeProviderConfig(item.key);
                                      if (mounted) setState(() {
                                        if (_selectedKey == item.key) {
                                          _selectedKey = ordered.isNotEmpty ? ordered.first.key : null;
                                        }
                                      });
                                    }
                                  },
                          );
                          return KeyedSubtree(
                            key: ValueKey('desktop-prov-${item.key}'),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ReorderableDragStartListener(index: i, child: row),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Bottom add button
                    _AddFullWidthButton(height: 36, label: l10n.addProviderSheetAddButton, onTap: () async {
                      final created = await showDesktopAddProviderDialog(context);
                      if (!mounted) return;
                      if (created != null && created.isNotEmpty) {
                        setState(() { _selectedKey = created; });
                      }
                    }),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              VerticalDivider(width: 1, thickness: 0.5, color: cs.outlineVariant.withOpacity(0.12)),
              // Right detail pane
              Expanded(child: rightPane),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopProviderDetailPane extends StatefulWidget {
  const _DesktopProviderDetailPane({super.key, required this.providerKey, required this.displayName});
  final String providerKey;
  final String displayName;
  @override
  State<_DesktopProviderDetailPane> createState() => _DesktopProviderDetailPaneState();
}

class _DesktopProviderDetailPaneState extends State<_DesktopProviderDetailPane> {
  bool _showSearch = false;
  final TextEditingController _filterCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _showApiKey = false;
  bool _eyeHover = false;
  
  // Connection test state for inline dialog
  // Keep local to this file to avoid cross-file coupling
  

  @override
  void dispose() {
    _filterCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<String?> _inputDialog(BuildContext context, {required String title, required String hint}) async {
    final cs = Theme.of(context).colorScheme;
    final ctrl = TextEditingController();
    String? result;
    await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                  _IconBtn(icon: lucide.Lucide.X, onTap: () => Navigator.of(ctx).maybePop()),
                ]),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  style: const TextStyle(fontSize: 13),
                  decoration: _inputDecoration(ctx).copyWith(hintText: hint),
                  onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: _DeskIosButton(label: AppLocalizations.of(context)!.assistantEditEmojiDialogSave, filled: true, dense: true, onTap: () => Navigator.of(ctx).pop(ctrl.text.trim())),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((v) => result = v);
    return (result ?? '').trim().isEmpty ? null : result!.trim();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    final cfg = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
    final kind = ProviderConfig.classify(widget.providerKey, explicitType: cfg.providerType);

    final models = List<String>.from(cfg.models);
    final filtered = _applyFilter(models, _filterCtrl.text.trim());
    final groups = _groupModels(filtered);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // Title + Settings button grouped at left, per request
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Text(
                        cfg.name.isNotEmpty ? cfg.name : widget.providerKey,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _IconBtn(
                      icon: lucide.Lucide.Settings,
                      onTap: () => _showProviderSettingsDialog(context),
                    ),
                  ],
                ),
                const Spacer(),
                IosSwitch(
                  value: cfg.enabled,
                  onChanged: (v) async {
                    final old = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
                    await sp.setProviderConfig(widget.providerKey, old.copyWith(enabled: v));
                  },
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Divider(height: 1, thickness: 0.5, color: cs.outlineVariant.withOpacity(0.12)),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              // API Key (hidden when Google Vertex)
              if (!(kind == ProviderKind.google && (cfg.vertexAI == true))) ...[
              _sectionLabel(context, AppLocalizations.of(context)!.multiKeyPageKey, bold: true),
              const SizedBox(height: 6),
              if (cfg.multiKeyEnabled == true)
                Row(
                  children: [
                    Expanded(
                      child: AbsorbPointer(
                        child: Opacity(
                          opacity: 0.6,
                          child: TextField(
                            controller: TextEditingController(text: '••••••••'),
                            readOnly: true,
                            style: const TextStyle(fontSize: 14),
                            decoration: _inputDecoration(context),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _DeskIosButton(label: l10n.providerDetailPageManageKeysButton, filled: false, dense: true, onTap: () => _showMultiKeyDialog(context)),
                  ],
                )
              else
                TextField(
                  controller: TextEditingController(text: cfg.apiKey),
                  obscureText: !_showApiKey ? true : false,
                  onChanged: (v) async {
                    final old = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
                    await sp.setProviderConfig(widget.providerKey, old.copyWith(apiKey: v));
                  },
                  style: const TextStyle(fontSize: 14),
                  decoration: _inputDecoration(context).copyWith(
                    hintText: l10n.providerDetailPageApiKeyHint,
                    suffixIcon: MouseRegion(
                      onEnter: (_) => setState(() => _eyeHover = true),
                      onExit: (_) => setState(() => _eyeHover = false),
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => setState(() => _showApiKey = !_showApiKey),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _eyeHover
                                ? (Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withOpacity(0.06)
                                    : Colors.black.withOpacity(0.04))
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                            child: AnimatedRotation(
                              key: ValueKey(_showApiKey),
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              turns: _showApiKey ? 0.5 : 0.0,
                              child: Icon(
                                _showApiKey ? lucide.Lucide.EyeOff : lucide.Lucide.Eye,
                                size: 18,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 20),
                  ),
                ),
              const SizedBox(height: 14),
              ],

              // API Base URL or Vertex AI fields
              if (!(kind == ProviderKind.google && (cfg.vertexAI == true))) ...[
                _sectionLabel(context, AppLocalizations.of(context)!.providerDetailPageApiBaseUrlLabel, bold: true),
                const SizedBox(height: 6),
                TextField(
                  controller: TextEditingController(text: cfg.baseUrl),
                  onChanged: (v) async {
                    final old = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
                    await sp.setProviderConfig(widget.providerKey, old.copyWith(baseUrl: v));
                  },
                  style: const TextStyle(fontSize: 14),
                  decoration: _inputDecoration(context).copyWith(hintText: ProviderConfig.defaultsFor(widget.providerKey, displayName: widget.displayName).baseUrl),
                ),
              ] else ...[
                _sectionLabel(context, l10n.providerDetailPageLocationLabel, bold: true),
                const SizedBox(height: 6),
                TextField(
                  controller: TextEditingController(text: cfg.location ?? ''),
                  onChanged: (v) async {
                    final old = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
                    await sp.setProviderConfig(widget.providerKey, old.copyWith(location: v.trim()));
                  },
                  style: const TextStyle(fontSize: 14),
                  decoration: _inputDecoration(context).copyWith(hintText: 'us-central1'),
                ),
                const SizedBox(height: 14),
                _sectionLabel(context, l10n.providerDetailPageProjectIdLabel, bold: true),
                const SizedBox(height: 6),
                TextField(
                  controller: TextEditingController(text: cfg.projectId ?? ''),
                  onChanged: (v) async {
                    final old = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
                    await sp.setProviderConfig(widget.providerKey, old.copyWith(projectId: v.trim()));
                  },
                  style: const TextStyle(fontSize: 14),
                  decoration: _inputDecoration(context).copyWith(hintText: 'my-project-id'),
                ),
                const SizedBox(height: 14),
                _sectionLabel(context, l10n.providerDetailPageServiceAccountJsonLabel, bold: true),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 120),
                  child: TextField(
                    controller: TextEditingController(text: cfg.serviceAccountJson ?? ''),
                    maxLines: null,
                    minLines: 6,
                    onChanged: (v) async {
                      final old = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
                      await sp.setProviderConfig(widget.providerKey, old.copyWith(serviceAccountJson: v));
                    },
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputDecoration(context).copyWith(hintText: '{\n  "type": "service_account", ...\n}'),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _DeskIosButton(
                    label: l10n.providerDetailPageImportJsonButton,
                    filled: false,
                    dense: true,
                    onTap: () async {
                      final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
                      if (res != null && res.files.isNotEmpty) {
                        final file = res.files.first;
                        final content = String.fromCharCodes(file.bytes ?? []);
                        String projectId = cfg.projectId ?? '';
                        try {
                          final obj = jsonDecode(content);
                          projectId = (obj['project_id'] as String?)?.trim() ?? projectId;
                        } catch (_) {}
                        final old = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
                        await sp.setProviderConfig(widget.providerKey, old.copyWith(
                          serviceAccountJson: content,
                          projectId: projectId,
                        ));
                      }
                    },
                  ),
                ),
              ],

              // API Path (OpenAI chat)
              if (kind == ProviderKind.openai && (cfg.useResponseApi != true)) ...[
                const SizedBox(height: 14),
                _sectionLabel(context, l10n.providerDetailPageApiPathLabel, bold: true),
                const SizedBox(height: 6),
                TextField(
                  controller: TextEditingController(text: cfg.chatPath ?? '/chat/completions'),
                  onChanged: (v) async {
                    final old = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
                    await sp.setProviderConfig(widget.providerKey, old.copyWith(chatPath: v));
                  },
                  style: const TextStyle(fontSize: 14),
                  decoration: _inputDecoration(context).copyWith(hintText: '/chat/completions'),
                ),
              ],

              const SizedBox(height: 18),
              // Models header with count + search + detect icon
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(AppLocalizations.of(context)!.providerDetailPageModelsTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        _GreyCapsule(label: '${models.length}'),
                      ],
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) => SizeTransition(sizeFactor: anim, axis: Axis.horizontal, child: FadeTransition(opacity: anim, child: child)),
                    child: _showSearch
                        ? SizedBox(
                            key: const ValueKey('search-field'),
                            width: 240,
                            child: TextField(
                              controller: _filterCtrl,
                              focusNode: _searchFocus,
                              autofocus: true,
                              style: const TextStyle(fontSize: 14),
                              decoration: _inputDecoration(context).copyWith(
                                hintText: l10n.providerDetailPageFilterHint,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          )
                        : _IconBtn(
                            key: const ValueKey('search-icon'),
                            icon: lucide.Lucide.Search,
                            onTap: () => setState(() {
                              _showSearch = true;
                              _searchFocus.addListener(() {
                                if (!_searchFocus.hasFocus) setState(() => _showSearch = false);
                              });
                            }),
                          ),
                  ),
                  _IconBtn(icon: lucide.Lucide.HeartPulse, onTap: () => _showTestConnectionDialog(context)),
                ],
              ),

              const SizedBox(height: 6),
              // Accordion groups
              for (final entry in groups.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ModelGroupAccordion(
                    group: entry.key,
                    modelIds: entry.value,
                    providerKey: widget.providerKey,
                  ),
                ),

              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _DeskIosButton(
                    label: AppLocalizations.of(context)!.providerModelsGetButton,
                    filled: true,
                    dense: true,
                    onTap: () async {
                      final providerName = widget.displayName;
                      await showModelFetchDialog(context, providerKey: widget.providerKey, providerDisplayName: providerName);
                    },
                  ),
                  const SizedBox(width: 8),
                  _DeskIosButton(label: l10n.addProviderSheetAddButton, filled: false, dense: true, onTap: () => _createModel(context)),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Map<String, List<String>> _groupModels(List<String> models) {
    final map = <String, List<String>>{};
    for (final m in models) {
      var g = m;
      if (m.contains('/')) g = m.split('/').first;
      else if (m.contains(':')) g = m.split(':').first;
      else if (m.contains('-')) g = m.split('-').first;
      (map[g] ??= <String>[])..add(m);
    }
    // Keep stable order by key
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    return {for (final e in entries) e.key: e.value};
  }

  List<String> _applyFilter(List<String> src, String q) {
    if (q.isEmpty) return src;
    final k = q.toLowerCase();
    return [for (final m in src) if (m.toLowerCase().contains(k)) m];
  }

  InputDecoration _inputDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: isDark ? Colors.white10 : const Color(0xFFF7F7F9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.12), width: 0.6)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.12), width: 0.6)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.primary.withOpacity(0.35), width: 0.8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Future<void> _showProviderSettingsDialog(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final sp = context.read<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    ProviderConfig cfg = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
    ProviderKind kind = ProviderConfig.classify(widget.providerKey, explicitType: cfg.providerType);
    bool multi = cfg.multiKeyEnabled ?? false;
    bool openaiResp = cfg.useResponseApi ?? false;
    bool googleVertex = cfg.vertexAI ?? false;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final nameCtrl = TextEditingController(text: cfg.name);
        final proxyHostCtrl = TextEditingController(text: cfg.proxyHost ?? '');
        final proxyPortCtrl = TextEditingController(text: cfg.proxyPort ?? '8080');
        final proxyUserCtrl = TextEditingController(text: cfg.proxyUsername ?? '');
        final proxyPassCtrl = TextEditingController(text: cfg.proxyPassword ?? '');
        ProviderKind tmpKind = kind;
        bool tmpMulti = multi;
        bool tmpResp = openaiResp;
        bool tmpVertex = googleVertex;
        return Dialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Consumer<SettingsProvider>(builder: (c, spWatch, _) {
              final cfgNow = spWatch.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
              // sync controllers when external changes
              if ((nameCtrl.text) != cfgNow.name) nameCtrl.text = cfgNow.name;
              if ((proxyHostCtrl.text) != (cfgNow.proxyHost ?? '')) proxyHostCtrl.text = cfgNow.proxyHost ?? '';
              if ((proxyPortCtrl.text) != (cfgNow.proxyPort ?? '8080')) proxyPortCtrl.text = cfgNow.proxyPort ?? '8080';
              if ((proxyUserCtrl.text) != (cfgNow.proxyUsername ?? '')) proxyUserCtrl.text = cfgNow.proxyUsername ?? '';
              if ((proxyPassCtrl.text) != (cfgNow.proxyPassword ?? '')) proxyPassCtrl.text = cfgNow.proxyPassword ?? '';
              final kindNow = cfgNow.providerType ?? ProviderConfig.classify(cfgNow.id, explicitType: cfgNow.providerType);
              final multiNow = cfgNow.multiKeyEnabled ?? false;
              final respNow = cfgNow.useResponseApi ?? false;
              final vertexNow = cfgNow.vertexAI ?? false;
              final proxyEnabledNow = cfgNow.proxyEnabled ?? false;
              Widget row(String label, Widget trailing) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: cs.onSurface.withOpacity(0.9)))),
                  const SizedBox(width: 10),
                  SizedBox(width: 260, child: trailing),
                ]),
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(child: Text(cfgNow.name.isNotEmpty ? cfgNow.name : widget.providerKey, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                          _IconBtn(icon: lucide.Lucide.X, onTap: () => Navigator.of(ctx).maybePop()),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Divider(height: 1, thickness: 0.5, color: cs.outlineVariant.withOpacity(0.12)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      // 1) Name
                      row(l10n.providerDetailPageNameLabel, TextField(
                        controller: nameCtrl,
                        style: const TextStyle(fontSize: 14),
                        decoration: _inputDecoration(ctx),
                        onChanged: (_) async {
                          final old = spWatch.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
                          await spWatch.setProviderConfig(widget.providerKey, old.copyWith(name: nameCtrl.text.trim().isEmpty ? widget.displayName : nameCtrl.text.trim()));
                        },
                      )),
                      const SizedBox(height: 4),
                      // 2) Provider type
                      row(l10n.providerDetailPageProviderTypeTitle, _ProviderTypeDropdown(value: kindNow, onChanged: (k) async {
                        final old = spWatch.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
                        await spWatch.setProviderConfig(widget.providerKey, old.copyWith(providerType: k));
                      })),
                      const SizedBox(height: 4),
                      // 3) Multi-Key
                      row(l10n.providerDetailPageMultiKeyModeTitle, Align(alignment: Alignment.centerRight, child: IosSwitch(value: multiNow, onChanged: (v) async {
                        final old = spWatch.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
                        await spWatch.setProviderConfig(widget.providerKey, old.copyWith(multiKeyEnabled: v));
                      }))),
                      const SizedBox(height: 4),
                      // 4) Response (OpenAI) or Vertex (Google). Hide for Claude, with animation.
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: () {
                          if (kindNow == ProviderKind.openai) {
                            return KeyedSubtree(
                              key: const ValueKey('openai-resp'),
                              child: row(l10n.providerDetailPageResponseApiTitle, Align(alignment: Alignment.centerRight, child: IosSwitch(value: respNow, onChanged: (v) async {
                                final old = spWatch.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
                                await spWatch.setProviderConfig(widget.providerKey, old.copyWith(useResponseApi: v));
                              }))),
                            );
                          }
                          if (kindNow == ProviderKind.google) {
                            return KeyedSubtree(
                              key: const ValueKey('google-vertex'),
                              child: row(l10n.providerDetailPageVertexAiTitle, Align(alignment: Alignment.centerRight, child: IosSwitch(value: vertexNow, onChanged: (v) async {
                                final old = spWatch.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
                                await spWatch.setProviderConfig(widget.providerKey, old.copyWith(vertexAI: v));
                              }))),
                            );
                          }
                          return const SizedBox.shrink(key: ValueKey('none'));
                        }(),
                      ),
                      const SizedBox(height: 4),
                      // 5) Network proxy inline
                      row(l10n.providerDetailPageNetworkTab, Align(alignment: Alignment.centerRight, child: IosSwitch(value: proxyEnabledNow, onChanged: (v) async {
                        final old = spWatch.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
                        await spWatch.setProviderConfig(widget.providerKey, old.copyWith(proxyEnabled: v));
                      }))),
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            row(l10n.providerDetailPageHostLabel, TextField(controller: proxyHostCtrl, style: const TextStyle(fontSize: 13), decoration: _inputDecoration(ctx).copyWith(hintText: '127.0.0.1'), onChanged: (_) async {
                              final old = spWatch.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
                              await spWatch.setProviderConfig(widget.providerKey, old.copyWith(proxyHost: proxyHostCtrl.text.trim()));
                            })),
                            const SizedBox(height: 4),
                            row(l10n.providerDetailPagePortLabel, TextField(controller: proxyPortCtrl, style: const TextStyle(fontSize: 13), decoration: _inputDecoration(ctx).copyWith(hintText: '8080'), onChanged: (_) async {
                              final old = spWatch.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
                              await spWatch.setProviderConfig(widget.providerKey, old.copyWith(proxyPort: proxyPortCtrl.text.trim()));
                            })),
                            const SizedBox(height: 4),
                            row(l10n.providerDetailPageUsernameOptionalLabel, TextField(controller: proxyUserCtrl, style: const TextStyle(fontSize: 13), decoration: _inputDecoration(ctx), onChanged: (_) async {
                              final old = spWatch.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
                              await spWatch.setProviderConfig(widget.providerKey, old.copyWith(proxyUsername: proxyUserCtrl.text.trim()));
                            })),
                            const SizedBox(height: 4),
                            row(l10n.providerDetailPagePasswordOptionalLabel, TextField(controller: proxyPassCtrl, style: const TextStyle(fontSize: 13), obscureText: true, decoration: _inputDecoration(ctx), onChanged: (_) async {
                              final old = spWatch.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
                              await spWatch.setProviderConfig(widget.providerKey, old.copyWith(proxyPassword: proxyPassCtrl.text.trim()));
                            })),
                          ]),
                        ),
                        crossFadeState: proxyEnabledNow ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 180),
                        sizeCurve: Curves.easeOutCubic,
                      ),
                    ]),
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  Future<void> _showNetworkDialog(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final sp = context.read<SettingsProvider>();
    final cfg = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
    bool enabled = cfg.proxyEnabled ?? false;
    final host = TextEditingController(text: cfg.proxyHost ?? '');
    final port = TextEditingController(text: cfg.proxyPort ?? '8080');
    final user = TextEditingController(text: cfg.proxyUsername ?? '');
    final pass = TextEditingController(text: cfg.proxyPassword ?? '');
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: StatefulBuilder(builder: (ctx, setSt) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 44,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(child: Text(AppLocalizations.of(ctx)!.providerDetailPageNetworkTab, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                        IconButton(
                          icon: const Icon(lucide.Lucide.X, size: 18),
                          color: cs.onSurface,
                          onPressed: () => Navigator.of(ctx).maybePop(),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Divider(height: 1, thickness: 0.5, color: cs.outlineVariant.withOpacity(0.12)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _rowSwitch(ctx, label: AppLocalizations.of(ctx)!.providerDetailPageEnableProxyTitle, value: enabled, onChanged: (v) async {
                        setSt(() => enabled = v);
                        final old = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
                        await sp.setProviderConfig(widget.providerKey, old.copyWith(proxyEnabled: v));
                      }),
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 12),
                            _sectionLabel(ctx, AppLocalizations.of(ctx)!.providerDetailPageHostLabel),
                            const SizedBox(height: 6),
                            TextField(controller: host, style: const TextStyle(fontSize: 13), decoration: _inputDecoration(ctx).copyWith(hintText: '127.0.0.1'), onChanged: (_) async { final old = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName); await sp.setProviderConfig(widget.providerKey, old.copyWith(proxyHost: host.text.trim())); }),
                            const SizedBox(height: 12),
                            _sectionLabel(ctx, AppLocalizations.of(ctx)!.providerDetailPagePortLabel),
                            const SizedBox(height: 6),
                            TextField(controller: port, style: const TextStyle(fontSize: 13), decoration: _inputDecoration(ctx).copyWith(hintText: '8080'), onChanged: (_) async { final old = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName); await sp.setProviderConfig(widget.providerKey, old.copyWith(proxyPort: port.text.trim())); }),
                            const SizedBox(height: 12),
                            _sectionLabel(ctx, AppLocalizations.of(ctx)!.providerDetailPageUsernameOptionalLabel),
                            const SizedBox(height: 6),
                            TextField(controller: user, style: const TextStyle(fontSize: 13), decoration: _inputDecoration(ctx), onChanged: (_) async { final old = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName); await sp.setProviderConfig(widget.providerKey, old.copyWith(proxyUsername: user.text.trim())); }),
                            const SizedBox(height: 12),
                            _sectionLabel(ctx, AppLocalizations.of(ctx)!.providerDetailPagePasswordOptionalLabel),
                            const SizedBox(height: 6),
                            TextField(controller: pass, style: const TextStyle(fontSize: 13), obscureText: true, decoration: _inputDecoration(ctx), onChanged: (_) async { final old = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName); await sp.setProviderConfig(widget.providerKey, old.copyWith(proxyPassword: pass.text.trim())); }),
                          ],
                        ),
                        crossFadeState: enabled ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 180),
                        sizeCurve: Curves.easeOutCubic,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Future<void> _showMultiKeyDialog(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final sp = context.read<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        ProviderConfig cfg = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
        LoadBalanceStrategy strat = cfg.keyManagement?.strategy ?? LoadBalanceStrategy.roundRobin;
        final keys = List<ApiKeyConfig>.from(cfg.apiKeys ?? const <ApiKeyConfig>[]);
        final listCtrl = ScrollController();
        Future<void> saveStrategy(LoadBalanceStrategy s) async {
          final old = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
          final km = (old.keyManagement ?? const KeyManagementConfig()).copyWith(strategy: s);
          await sp.setProviderConfig(widget.providerKey, old.copyWith(keyManagement: km));
        }
        Future<void> addKeys(BuildContext c) async {
          final text = await _inputDialog(c, title: l10n.multiKeyPageAdd, hint: l10n.multiKeyPageAddHint);
          if (text == null || text.trim().isEmpty) return;
          final parts = text.split(RegExp(r'[\s,]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
          if (parts.isEmpty) return;
          final existing = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName).apiKeys ?? const <ApiKeyConfig>[];
          final existingSet = existing.map((e) => e.key).toSet();
          final list = List<ApiKeyConfig>.from(existing);
          for (final k in parts) {
            if (!existingSet.contains(k)) list.add(ApiKeyConfig.create(k));
          }
          final old = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
          await sp.setProviderConfig(widget.providerKey, old.copyWith(apiKeys: list));
        }
        return Dialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
            child: StatefulBuilder(builder: (dctx, setD) {
              ProviderConfig cfg2 = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
              final keyList = List<ApiKeyConfig>.from(cfg2.apiKeys ?? const <ApiKeyConfig>[]);
              final currentStrat = cfg2.keyManagement?.strategy ?? LoadBalanceStrategy.roundRobin;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(child: Text(l10n.multiKeyPageTitle, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                          _IconBtn(icon: lucide.Lucide.X, onTap: () => Navigator.of(ctx).maybePop()),
                        ],
                      ),
                    ),
                  ),
                  Divider(height: 1, thickness: 0.5, color: cs.outlineVariant.withOpacity(0.12)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        Expanded(child: Text(l10n.multiKeyPageStrategyTitle, style: TextStyle(fontSize: 14, color: cs.onSurface.withOpacity(0.9), fontWeight: FontWeight.w600))),
                        SizedBox(width: 220, child: _StrategyDropdown(value: currentStrat, onChanged: (s) async { await saveStrategy(s); setD(() {}); })),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Scrollbar(
                      thumbVisibility: true,
                      controller: listCtrl,
                      child: ListView.separated(
                        controller: listCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemBuilder: (c, i) {
                          final ak = keyList[i];
                          return _ApiKeyRow(
                            keyConfig: ak,
                            onToggle: (v) async {
                              final old = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
                              final list = List<ApiKeyConfig>.from(old.apiKeys ?? const <ApiKeyConfig>[]);
                              final idx = list.indexWhere((e) => e.id == ak.id);
                              if (idx >= 0) list[idx] = ak.copyWith(isEnabled: v, updatedAt: DateTime.now().millisecondsSinceEpoch);
                              await sp.setProviderConfig(widget.providerKey, old.copyWith(apiKeys: list));
                              setD(() {});
                            },
                            onDelete: () async {
                              final old = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
                              final list = List<ApiKeyConfig>.from(old.apiKeys ?? const <ApiKeyConfig>[]);
                              list.removeWhere((e) => e.id == ak.id);
                              await sp.setProviderConfig(widget.providerKey, old.copyWith(apiKeys: list));
                              setD(() {});
                            },
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemCount: keyList.length,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _DeskIosButton(label: l10n.multiKeyPageAdd, filled: false, onTap: () => addKeys(dctx)),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  // Replaced with desktop centered dialog: showModelFetchDialog

  // Future<void> _showGetModelsDialog(BuildContext context) async {
  //   // For now this acts similar to Detect, but kept separate per spec.
  //   return _showDetectModelsDialog(context);
  // }

  Future<void> _createModel(BuildContext context) async {
    final res = await showDesktopCreateModelDialog(context, providerKey: widget.providerKey);
    if (res == true && mounted) setState(() {});
  }

  Future<void> _showTestConnectionDialog(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    String? selectedModelId;
    _TestState state = _TestState.idle;
    String errorMessage = '';
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        Future<void> pickModel() async {
          // Use the desktop model selector dialog and limit to current provider
          final sel = await showModelSelector(ctx, limitProviderKey: widget.providerKey);
          if (sel != null) {
            selectedModelId = sel.modelId;
            (ctx as Element).markNeedsBuild();
          }
        }
        Future<void> doTest() async {
          if (selectedModelId == null) return;
          state = _TestState.loading;
          errorMessage = '';
          (ctx as Element).markNeedsBuild();
          try {
            final sp = context.read<SettingsProvider>();
            final cfg = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
            await ProviderManager.testConnection(cfg, selectedModelId!);
            state = _TestState.success;
          } catch (e) {
            state = _TestState.error;
            errorMessage = e.toString();
          }
          (ctx as Element).markNeedsBuild();
        }
        final l10n = AppLocalizations.of(ctx)!;
        final canTest = selectedModelId != null && state != _TestState.loading;
        String message;
        Color color;
        switch (state) {
          case _TestState.idle:
            message = selectedModelId == null ? l10n.modelSelectSheetSearchHint : l10n.providerDetailPageTestingMessage;
            color = cs.onSurface.withOpacity(0.8);
            break;
          case _TestState.loading:
            message = l10n.providerDetailPageTestingMessage;
            color = cs.primary;
            break;
          case _TestState.success:
            message = l10n.providerDetailPageTestSuccessMessage;
            color = Colors.green;
            break;
          case _TestState.error:
            message = errorMessage.isNotEmpty ? errorMessage : 'Error';
            color = cs.error;
            break;
        }
        return Dialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Text(l10n.providerDetailPageTestConnectionTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: pickModel,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF7F7F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.12), width: 0.6),
                      ),
                      child: Row(
                        children: [
                          if (selectedModelId != null) _BrandCircle(name: selectedModelId!, size: 22),
                          if (selectedModelId != null) const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedModelId ?? l10n.providerDetailPageSelectModelButton,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (state == _TestState.loading)
                    Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)))
                  else if (state != _TestState.idle)
                    Center(child: Text(message, textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 14, fontWeight: state == _TestState.success ? FontWeight.w700 : FontWeight.w600))),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _DeskIosButton(label: l10n.providerDetailPageCancelButton, filled: false, dense: true, onTap: () => Navigator.of(ctx).maybePop()),
                      const SizedBox(width: 8),
                      _DeskIosButton(label: l10n.providerDetailPageTestButton, filled: true, dense: true, onTap: canTest ? doTest : () {}),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _TestState { idle, loading, success, error }

class _ProviderTypeDropdown extends StatefulWidget {
  const _ProviderTypeDropdown({required this.value, required this.onChanged});
  final ProviderKind value;
  final ValueChanged<ProviderKind> onChanged;
  @override
  State<_ProviderTypeDropdown> createState() => _ProviderTypeDropdownState();
}

class _ProviderTypeDropdownState extends State<_ProviderTypeDropdown> {
  bool _hover = false;
  bool _open = false;
  final GlobalKey _key = GlobalKey();
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() => _open = false);
  }

  void _openMenu() {
    if (_entry != null) return;
    final rb = _key.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox = Overlay.of(context)?.context.findRenderObject() as RenderBox?;
    if (rb == null || overlayBox == null) return;
    final size = rb.size;
    final triggerW = size.width;
    const maxW = 280.0; // unused after width sync, kept for reference
    final items = const [
      (ProviderKind.openai, 'OpenAI'),
      (ProviderKind.google, 'Google'),
      (ProviderKind.claude, 'Claude'),
    ];
    _entry = OverlayEntry(builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final content = Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: (Provider.of<SettingsProvider>(ctx, listen: false).usePureBackground)
                ? (isDark ? Colors.black : Colors.white)
                : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.12), width: 0.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 2),
            itemBuilder: (c, i) {
              final k = items[i].$1;
              final label = items[i].$2;
              final selected = widget.value == k;
              return _OverlayMenuItem(
                label: label,
                selected: selected,
                onTap: () { widget.onChanged(k); _close(); },
              );
            },
          ),
        ),
      );
      final width = triggerW; // menu width equals trigger width
      final dx = 0.0; // align left edges
      return Stack(children: [
        Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _close, child: const SizedBox.expand())),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          offset: Offset(dx, size.height + 6),
          child: ConstrainedBox(constraints: BoxConstraints(minWidth: width, maxWidth: width), child: content),
        ),
      ]);
    });
    Overlay.of(context)?.insert(_entry!);
    setState(() => _open = true);
  }

  @override
  Widget build(BuildContext context) {
    final label = switch (widget.value) {
      ProviderKind.openai => 'OpenAI',
      ProviderKind.google => 'Google',
      ProviderKind.claude => 'Claude',
    };
    return CompositedTransformTarget(
      link: _link,
      child: _HoverDropdownButton(
        key: _key,
        hovered: _hover,
        open: _open,
        label: label,
        fontSize: 14,
        verticalPadding: 10,
        borderRadius: 10,
        rightAlignArrow: true,
        onHover: (v) => setState(() => _hover = v),
        onTap: () => _open ? _close() : _openMenu(),
      ),
    );
  }
}

class _StrategyDropdown extends StatefulWidget {
  const _StrategyDropdown({required this.value, required this.onChanged});
  final LoadBalanceStrategy value;
  final ValueChanged<LoadBalanceStrategy> onChanged;
  @override
  State<_StrategyDropdown> createState() => _StrategyDropdownState();
}

class _StrategyDropdownState extends State<_StrategyDropdown> {
  bool _hover = false;
  bool _open = false;
  final GlobalKey _key = GlobalKey();
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _close() { _entry?.remove(); _entry = null; if (mounted) setState(() => _open = false); }
  void _openMenu() {
    if (_entry != null) return;
    final rb = _key.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final size = rb.size;
    final triggerW = size.width;
    final labelFor = (LoadBalanceStrategy s) => s == LoadBalanceStrategy.roundRobin
        ? AppLocalizations.of(context)!.multiKeyPageStrategyRoundRobin
        : AppLocalizations.of(context)!.multiKeyPageStrategyRandom;
    final entries = [LoadBalanceStrategy.roundRobin, LoadBalanceStrategy.random];
    _entry = OverlayEntry(builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return Stack(children: [
        Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _close, child: const SizedBox.expand())),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 6),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(minWidth: triggerW, maxWidth: triggerW),
              decoration: BoxDecoration(
                color: (Provider.of<SettingsProvider>(ctx, listen: false).usePureBackground)
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.12), width: 0.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 6))],
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                shrinkWrap: true,
                itemCount: entries.length,
                itemBuilder: (c, i) {
                  final s = entries[i];
                  final selected = widget.value == s;
              return _OverlayMenuItem(
                label: labelFor(s),
                selected: selected,
                onTap: () { widget.onChanged(s); _close(); },
              );
                },
              ),
            ),
          ),
        ),
      ]);
    });
    Overlay.of(context)?.insert(_entry!);
    setState(() => _open = true);
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.value == LoadBalanceStrategy.roundRobin
        ? AppLocalizations.of(context)!.multiKeyPageStrategyRoundRobin
        : AppLocalizations.of(context)!.multiKeyPageStrategyRandom;
    return CompositedTransformTarget(
      link: _link,
      child: _HoverDropdownButton(
        key: _key,
        hovered: _hover,
        open: _open,
        label: label,
        fontSize: 14,
        verticalPadding: 10,
        borderRadius: 10,
        rightAlignArrow: true,
        onHover: (v) => setState(() => _hover = v),
        onTap: () => _open ? _close() : _openMenu(),
      ),
    );
  }
}

Widget _rowSwitch(BuildContext context, {required String label, required bool value, required ValueChanged<bool> onChanged}) {
  final cs = Theme.of(context).colorScheme;
  return Row(
    children: [
      Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: cs.onSurface.withOpacity(0.9), fontWeight: FontWeight.w600))),
      IosSwitch(value: value, onChanged: onChanged),
    ],
  );
}

Widget _rowButton(BuildContext context, {required String label, required VoidCallback onTap}) {
  final cs = Theme.of(context).colorScheme;
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: cs.onSurface.withOpacity(0.9), fontWeight: FontWeight.w600))),
          const Icon(lucide.Lucide.ChevronRight, size: 16),
        ],
      ),
    ),
  );
}

// Small, consistent section label used in providers pane dialogs
Widget _sectionLabel(BuildContext context, String text, {bool bold = false}) {
  final cs = Theme.of(context).colorScheme;
  return Text(
    text,
    style: TextStyle(
      fontSize: 13,
      color: cs.onSurface.withOpacity(0.8),
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    ),
  );
}

class _GreyCapsule extends StatelessWidget {
  const _GreyCapsule({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF2F3F5);
    final fg = Theme.of(context).colorScheme.onSurface.withOpacity(0.85);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

class _IconBtn extends StatefulWidget {
  const _IconBtn({super.key, required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover ? (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)) : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 18, color: cs.onSurface),
        ),
      ),
    );
  }
}

class _BrandCircle extends StatelessWidget {
  const _BrandCircle({required this.name, this.size = 22});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = BrandAssets.assetForName(name);
    Widget inner;
    if (asset == null) {
      inner = Text(name.isNotEmpty ? name.characters.first.toUpperCase() : '?', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800, fontSize: size * 0.45));
    } else if (asset.endsWith('.svg')) {
      inner = SvgPicture.asset(asset, width: size * 0.62, height: size * 0.62, fit: BoxFit.contain);
    } else {
      inner = Image.asset(asset, width: size * 0.62, height: size * 0.62, fit: BoxFit.contain);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: isDark ? Colors.white10 : cs.primary.withOpacity(0.10), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: inner,
    );
  }
}

class _ProviderListRow extends StatefulWidget {
  const _ProviderListRow({
    required this.name,
    required this.enabled,
    required this.selected,
    required this.background,
    required this.onTap,
    required this.onEdit,
    this.onDelete,
  });
  final String name;
  final bool enabled;
  final bool selected;
  final Color background;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final Future<void> Function()? onDelete;
  @override
  State<_ProviderListRow> createState() => _ProviderListRowState();
}

class _ProviderListRowState extends State<_ProviderListRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hoverBg = _hover && !widget.selected ? Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04) : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapDown: (details) async {
          final items = <DesktopContextMenuItem>[
            DesktopContextMenuItem(icon: lucide.Lucide.Pencil, label: AppLocalizations.of(context)!.providerDetailPageEditTooltip, onTap: widget.onEdit),
            if (widget.onDelete != null)
              DesktopContextMenuItem(icon: lucide.Lucide.Trash2, label: AppLocalizations.of(context)!.providerDetailPageDeleteProviderTooltip, danger: true, onTap: () => widget.onDelete?.call()),
          ];
          await showDesktopContextMenuAt(context, globalPosition: details.globalPosition, items: items);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(color: Color.alphaBlend(hoverBg, widget.background), borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              _BrandCircle(name: widget.name, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (widget.enabled ? Colors.green : Colors.orange).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  // No border for left list status
                ),
                child: Text(
                  widget.enabled ? AppLocalizations.of(context)!.providersPageEnabledStatus : AppLocalizations.of(context)!.providersPageDisabledStatus,
                  style: TextStyle(fontSize: 11, color: widget.enabled ? Colors.green : Colors.orange, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddFullWidthButton extends StatefulWidget {
  const _AddFullWidthButton({required this.label, required this.onTap, this.height = 44});
  final String label;
  final VoidCallback onTap;
  final double height;
  @override
  State<_AddFullWidthButton> createState() => _AddFullWidthButtonState();
}

class _AddFullWidthButtonState extends State<_AddFullWidthButton> {
  bool _pressed = false;
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBg = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04);
    final hoverBg = isDark ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.06);
    final bg = _hover ? hoverBg : baseBg;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:   (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Container(
          height: widget.height,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.outlineVariant.withOpacity(0.2))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(lucide.Lucide.Plus, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(widget.label, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _ApiKeyRow extends StatelessWidget {
  const _ApiKeyRow({required this.keyConfig, required this.onToggle, required this.onDelete});
  final ApiKeyConfig keyConfig;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String label;
    if ((keyConfig.name ?? '').trim().isNotEmpty) label = keyConfig.name!.trim(); else {
      final s = keyConfig.key.trim();
      label = s.length <= 8 ? '••••' : '${s.substring(0, 4)}••••${s.substring(s.length - 4)}';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.02) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.14), width: 0.6),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
          const SizedBox(width: 10),
          IosSwitch(value: keyConfig.isEnabled, onChanged: onToggle),
          const SizedBox(width: 6),
          _IconBtn(icon: lucide.Lucide.Minus, onTap: onDelete),
        ],
      ),
    );
  }
}

class _ModelGroupAccordion extends StatefulWidget {
  const _ModelGroupAccordion({required this.group, required this.modelIds, required this.providerKey});
  final String group;
  final List<String> modelIds;
  final String providerKey;
  @override
  State<_ModelGroupAccordion> createState() => _ModelGroupAccordionState();
}

class _ModelGroupAccordionState extends State<_ModelGroupAccordion> {
  bool _open = true;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              child: InkWell(
                highlightColor: Colors.transparent,
                splashColor: Colors.transparent,
                hoverColor: Colors.transparent,
                focusColor: Colors.transparent,
                onTap: () => setState(() => _open = !_open),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      AnimatedRotation(
                        turns: _open ? 0.25 : 0.0, // right (0) -> down (0.25)
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: Icon(lucide.Lucide.ChevronRight, size: 16, color: cs.onSurface.withOpacity(0.9)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(widget.group, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(children: [for (final id in widget.modelIds) _ModelRow(modelId: id, providerKey: widget.providerKey)]),
              crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
              sizeCurve: Curves.easeOutCubic,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({required this.modelId, required this.providerKey});
  final String modelId;
  final String providerKey;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sp = context.watch<SettingsProvider>();
    final cfg = sp.getProviderConfig(providerKey);
    ModelInfo _infer(String id) => ModelRegistry.infer(ModelInfo(id: id, displayName: id));
    ModelInfo _effective() {
      final base = _infer(modelId);
      final ov = cfg.modelOverrides[modelId] as Map?;
      if (ov == null) return base;
      ModelType? type;
      final t = (ov['type'] as String?) ?? '';
      if (t == 'embedding') type = ModelType.embedding; else if (t == 'chat') type = ModelType.chat;
      List<Modality>? input;
      if (ov['input'] is List) {
        input = [
          for (final e in (ov['input'] as List)) (e.toString() == 'image' ? Modality.image : Modality.text)
        ];
      }
      List<Modality>? output;
      if (ov['output'] is List) {
        output = [
          for (final e in (ov['output'] as List)) (e.toString() == 'image' ? Modality.image : Modality.text)
        ];
      }
      List<ModelAbility>? abilities;
      if (ov['abilities'] is List) {
        abilities = [
          for (final e in (ov['abilities'] as List)) (e.toString() == 'reasoning' ? ModelAbility.reasoning : ModelAbility.tool)
        ];
      }
      return base.copyWith(
        type: type ?? base.type,
        input: input ?? base.input,
        output: output ?? base.output,
        abilities: abilities ?? base.abilities,
      );
    }
    final info = _effective();

    Widget cap(String text) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final bg = isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF2F3F5);
      final fg = cs.onSurface.withOpacity(0.85);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontSize: 11, color: fg)),
      );
    }

    // Build capsule pill style like mobile
    final caps = <Widget>[];
    Widget pillCapsule(Widget icon, Color color) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final bg = isDark ? color.withOpacity(0.20) : color.withOpacity(0.16);
      final bd = color.withOpacity(0.25);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: bd, width: 0.5),
        ),
        child: icon,
      );
    }
    // Build from effective info similar to mobile
    if (info.input.contains(Modality.image)) {
      caps.add(pillCapsule(Icon(lucide.Lucide.Eye, size: 12, color: cs.secondary), cs.secondary));
    }
    if (info.output.contains(Modality.image)) {
      caps.add(pillCapsule(Icon(lucide.Lucide.Image, size: 12, color: cs.tertiary), cs.tertiary));
    }
    for (final ab in info.abilities) {
      if (ab == ModelAbility.tool) {
        caps.add(pillCapsule(Icon(lucide.Lucide.Hammer, size: 12, color: cs.primary), cs.primary));
      } else if (ab == ModelAbility.reasoning) {
        caps.add(pillCapsule(SvgPicture.asset('assets/icons/deepthink.svg', width: 12, height: 12, colorFilter: ColorFilter.mode(cs.secondary, BlendMode.srcIn)), cs.secondary));
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _BrandCircle(name: modelId, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(modelId, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
          ),
          const SizedBox(width: 8),
          Row(children: caps.map((w) => Padding(padding: const EdgeInsets.only(left: 4), child: w)).toList()),
          const SizedBox(width: 8),
          _IconBtn(icon: lucide.Lucide.Settings2, onTap: () async { await showDesktopModelEditDialog(context, providerKey: providerKey, modelId: modelId); }),
          const SizedBox(width: 4),
          _IconBtn(icon: lucide.Lucide.Minus, onTap: () async {
            final old = context.read<SettingsProvider>().getProviderConfig(providerKey);
            final list = List<String>.from(old.models)..removeWhere((e) => e == modelId);
            await context.read<SettingsProvider>().setProviderConfig(providerKey, old.copyWith(models: list));
          }),
        ],
      ),
    );
  }
}

class _CardPress extends StatefulWidget {
  const _CardPress({required this.builder, this.onTap, this.pressedScale = 0.98});
  final Widget Function(bool pressed, Color overlay) builder;
  final VoidCallback? onTap;
  final double pressedScale;
  @override
  State<_CardPress> createState() => _CardPressState();
}

class _CardPressState extends State<_CardPress> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlay = _pressed
        ? (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04))
        : Colors.transparent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _pressed = false),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: widget.builder(_pressed, overlay),
        ),
      ),
    );
  }
}

// Removed embedded default model pane; now in setting/default_model_pane.dart

// Removed default model prompt dialogs; migrated to setting/default_model_pane.dart


// Removed embedded default model card; now in setting/default_model_pane.dart

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
                  _RowDivider(),
                  _ToggleRowPureBackground(),
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
    final sp = context.watch<SettingsProvider>();
    return Material(
      color: sp.usePureBackground ? (isDark ? Colors.black : Colors.white) : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
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
                // Align card title with other panes (15, semi-bold)
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface),
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
              // Match other settings row labels (14, normal, slightly dimmed)
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: cs.onSurface.withOpacity(0.9), decoration: TextDecoration.none),
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
                        // Reduce segmented labels to 14 for consistency
                        style: TextStyle(
                          fontSize: 14,
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
              // Keep pill text size aligned with row labels
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: fg, decoration: TextDecoration.none)),
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

class _ToggleRowPureBackground extends StatelessWidget {
  const _ToggleRowPureBackground();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.themeSettingsPageUsePureBackgroundTitle,
      value: sp.usePureBackground,
      onChanged: (v) => context.read<SettingsProvider>().setUsePureBackground(v),
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
        // Keep measurement consistent with dropdown item text (14)
        final style = const TextStyle(fontSize: 14);
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
        // item padding (12*2) + check icon (16) + gap to check (10)
        // + list padding (8*2) + gap between flag and text (8) + small fudge (2)
        return maxText + 12 * 2 + 16 + 10 + 8 * 2 + 8 + 2;
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
  const _HoverDropdownButton({
    super.key,
    required this.hovered,
    required this.open,
    required this.label,
    required this.onHover,
    required this.onTap,
    this.fontSize = 14,
    this.verticalPadding = 8,
    this.borderRadius = 10,
    this.rightAlignArrow = false,
  });
  final bool hovered;
  final bool open;
  final String label;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;
  final double fontSize;
  final double verticalPadding;
  final double borderRadius;
  final bool rightAlignArrow;
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
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: verticalPadding),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(borderRadius),
            // Match input border color and width
            border: Border.all(color: cs.outlineVariant.withOpacity(0.12), width: 0.6),
          ),
          child: rightAlignArrow
              ? Row(
                  children: [
                    Expanded(child: Text(label, style: TextStyle(fontSize: fontSize, color: cs.onSurface.withOpacity(0.9), fontWeight: FontWeight.w400))),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: angle / (2 * 3.1415926),
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: Icon(lucide.Lucide.ChevronDown, size: 16, color: cs.onSurface.withOpacity(0.8)),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: TextStyle(fontSize: fontSize, color: cs.onSurface.withOpacity(0.9), fontWeight: FontWeight.w400)),
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

class _OverlayMenuItem extends StatefulWidget {
  const _OverlayMenuItem({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  State<_OverlayMenuItem> createState() => _OverlayMenuItemState();
}

class _OverlayMenuItemState extends State<_OverlayMenuItem> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.selected
        ? cs.primary.withOpacity(0.08)
        : (_hover ? (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)) : Colors.transparent);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Expanded(child: Text(widget.label, style: TextStyle(fontSize: 14, color: cs.onSurface.withOpacity(0.9)))),
            if (widget.selected) Icon(lucide.Lucide.Check, size: 16, color: cs.primary),
          ]),
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
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white,
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
              Expanded(
                child: Text(
                  widget.item.label,
                  style: TextStyle(fontSize: 14, color: cs.onSurface, decoration: TextDecoration.none),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
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
              // Reduce toggle row label size to 14 to match other panes
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: cs.onSurface.withOpacity(0.9), decoration: TextDecoration.none),
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
