import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../icons/lucide_adapter.dart' as lucide;
import '../l10n/app_localizations.dart';
import '../theme/palettes.dart';
import '../core/providers/settings_provider.dart';
import '../core/providers/model_provider.dart';
import 'model_fetch_dialog.dart' show showModelFetchDialog;
import 'widgets/desktop_select_dropdown.dart';
import '../shared/widgets/ios_switch.dart';
import '../shared/widgets/ios_checkbox.dart';
import '../shared/widgets/input_height_constraints.dart';
import '../shared/widgets/plain_text_code_editor.dart';
// Desktop assistants panel dependencies
import '../features/assistant/pages/assistant_settings_edit_page.dart'
    show showAssistantDesktopDialog; // dialog opener only
import '../core/providers/assistant_provider.dart';
import '../core/models/assistant.dart';
import '../utils/avatar_cache.dart';
import '../utils/sandbox_path_resolver.dart';
import 'dart:io' show Directory, File, Platform;
import '../utils/app_directories.dart';
import 'package:characters/characters.dart';
import '../utils/re_editor_utils.dart';
import '../features/provider/pages/multi_key_manager_page.dart';
import '../features/model/widgets/model_detail_sheet.dart';
import 'add_provider_dialog.dart' show showDesktopAddProviderDialog;
import 'model_edit_dialog.dart'
    show showDesktopCreateModelDialog, showDesktopModelEditDialog;
// Use the unified model selector (desktop dialog on desktop platforms)
import '../features/model/widgets/model_select_sheet.dart'
    show showModelSelector;
import '../utils/brand_assets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import '../core/models/api_keys.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'desktop_context_menu.dart';
import '../shared/widgets/snackbar.dart';
import 'setting/default_model_pane.dart';
import 'setting/search_services_pane.dart';
import 'setting/mcp_pane.dart';
import 'setting/tts_services_pane.dart';
import 'setting/quick_phrases_pane.dart';
import 'setting/instruction_injection_pane.dart';
import 'setting/world_book_pane.dart';
import 'setting/backup_pane.dart';
import 'setting/hotkeys_pane.dart';
import 'setting/network_proxy_pane.dart';
import 'setting/about_pane.dart';
import 'package:system_fonts/system_fonts.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:super_clipboard/super_clipboard.dart';
import '../features/provider/widgets/provider_avatar.dart';
import '../features/provider/widgets/share_provider_sheet.dart'
    show encodeProviderConfig;
import '../utils/clipboard_images.dart';
import '../utils/provider_grouping_logic.dart';

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
  instructionInjection,
  worldBook,
  tts,
  networkProxy,
  backup,
  hotkeys,
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
        case _SettingsMenuItem.instructionInjection:
          return l10n.settingsPageInstructionInjection;
        case _SettingsMenuItem.worldBook:
          return l10n.settingsPageWorldBook;
        case _SettingsMenuItem.tts:
          return l10n.settingsPageTts;
        case _SettingsMenuItem.networkProxy:
          return l10n.settingsPageNetworkProxy;
        case _SettingsMenuItem.backup:
          return l10n.settingsPageBackup;
        case _SettingsMenuItem.hotkeys:
          return l10n.settingsPageHotkeys;
        case _SettingsMenuItem.about:
          return l10n.settingsPageAbout;
      }
    }

    const double menuWidth = 250;
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
                  width: menuWidth,
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
                          return const _DisplaySettingsBody(
                            key: ValueKey('display'),
                          );
                        case _SettingsMenuItem.assistant:
                          return const _DesktopAssistantsBody(
                            key: ValueKey('assistants'),
                          );
                        case _SettingsMenuItem.providers:
                          return _DesktopProvidersBody(
                            key: const ValueKey('providers'),
                            initialSelectedKey: widget.initialProviderKey,
                          );
                        case _SettingsMenuItem.defaultModel:
                          return const DesktopDefaultModelPane(
                            key: ValueKey('defaultModel'),
                          );
                        case _SettingsMenuItem.search:
                          return const DesktopSearchServicesPane(
                            key: ValueKey('search'),
                          );
                        case _SettingsMenuItem.mcp:
                          return const DesktopMcpPane(key: ValueKey('mcp'));
                        case _SettingsMenuItem.networkProxy:
                          return const DesktopNetworkProxyPane(
                            key: ValueKey('networkProxy'),
                          );
                        case _SettingsMenuItem.backup:
                          return const DesktopBackupPane(
                            key: ValueKey('backup'),
                          );
                        case _SettingsMenuItem.hotkeys:
                          return const DesktopHotkeysPane(
                            key: ValueKey('hotkeys'),
                          );
                        case _SettingsMenuItem.quickPhrases:
                          return const DesktopQuickPhrasesPane(
                            key: ValueKey('quickPhrases'),
                          );
                        case _SettingsMenuItem.instructionInjection:
                          return const DesktopInstructionInjectionPane(
                            key: ValueKey('instructionInjection'),
                          );
                        case _SettingsMenuItem.worldBook:
                          return const DesktopWorldBookPane(
                            key: ValueKey('worldBook'),
                          );
                        case _SettingsMenuItem.tts:
                          return const DesktopTtsServicesPane(
                            key: ValueKey('tts'),
                          );
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
      (
        _SettingsMenuItem.display,
        lucide.Lucide.Monitor,
        l10n.settingsPageDisplay,
      ),
      (
        _SettingsMenuItem.providers,
        lucide.Lucide.Boxes,
        l10n.settingsPageProviders,
      ),
      (
        _SettingsMenuItem.assistant,
        lucide.Lucide.Bot,
        l10n.settingsPageAssistant,
      ),
      (
        _SettingsMenuItem.defaultModel,
        lucide.Lucide.Heart,
        l10n.settingsPageDefaultModel,
      ),
      (_SettingsMenuItem.search, lucide.Lucide.Earth, l10n.settingsPageSearch),
      (_SettingsMenuItem.mcp, lucide.Lucide.Terminal, l10n.settingsPageMcp),
      (
        _SettingsMenuItem.quickPhrases,
        lucide.Lucide.Zap,
        l10n.settingsPageQuickPhrase,
      ),
      (
        _SettingsMenuItem.instructionInjection,
        lucide.Lucide.Layers,
        l10n.settingsPageInstructionInjection,
      ),
      (
        _SettingsMenuItem.worldBook,
        lucide.Lucide.BookOpen,
        l10n.settingsPageWorldBook,
      ),
      (_SettingsMenuItem.tts, lucide.Lucide.Volume2, l10n.settingsPageTts),
      (
        _SettingsMenuItem.networkProxy,
        lucide.Lucide.EthernetPort,
        l10n.settingsPageNetworkProxy,
      ),
      (
        _SettingsMenuItem.backup,
        lucide.Lucide.Database,
        l10n.settingsPageBackup,
      ),
      (
        _SettingsMenuItem.hotkeys,
        lucide.Lucide.Keyboard,
        l10n.settingsPageHotkeys,
      ),
      (
        _SettingsMenuItem.about,
        lucide.Lucide.BadgeInfo,
        l10n.settingsPageAbout,
      ),
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
              hoverBg: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.04),
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
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w400,
                    color: fg,
                    decoration: TextDecoration.none,
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
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withOpacity(0.25),
          ),
        ),
        child: Text(
          'Coming soon',
          style: TextStyle(
            fontSize: 16,
            color: cs.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w600,
          ),
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
                          AppLocalizations.of(
                            context,
                          )!.desktopAssistantsListTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurface.withOpacity(0.9),
                          ),
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
                      await context.read<AssistantProvider>().reorderAssistants(
                        oldIndex,
                        newIndex,
                      );
                    },
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, _) {
                          final t = Curves.easeOutCubic.transform(
                            animation.value,
                          );
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
                              onTap: () => showAssistantDesktopDialog(
                                context,
                                assistantId: item.id,
                              ),
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
    final bg = _hover
        ? (isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.05))
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          final name = await _showAddAssistantDesktopDialog(context);
          if (name == null || name.trim().isEmpty) return;
          await context.read<AssistantProvider>().addAssistant(
            name: name.trim(),
            context: context,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
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
                        child: Text(
                          l10n.assistantSettingsAddSheetTitle,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          ctx,
                        ).closeButtonTooltip,
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
                        fillColor: Theme.of(ctx).brightness == Brightness.dark
                            ? Colors.white10
                            : const Color(0xFFF7F7F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: cs.outlineVariant.withOpacity(0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: cs.primary.withOpacity(0.4),
                          ),
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
                          onTap: () =>
                              Navigator.of(ctx).pop(controller.text.trim()),
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
    final bg = _hover
        ? (isDark ? cs.error.withOpacity(0.18) : cs.error.withOpacity(0.14))
        : Colors.transparent;
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

class _CopyAssistantIcon extends StatefulWidget {
  const _CopyAssistantIcon({required this.onCopy});
  final Future<void> Function() onCopy;
  @override
  State<_CopyAssistantIcon> createState() => _CopyAssistantIconState();
}

class _CopyAssistantIconState extends State<_CopyAssistantIcon> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? (isDark ? cs.primary.withOpacity(0.16) : cs.primary.withOpacity(0.12))
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onCopy(),
        child: Container(
          margin: const EdgeInsets.only(left: 8),
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(lucide.Lucide.Copy, size: 15, color: cs.primary),
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
      final dialog = Material(
        color: Colors.transparent,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: cs.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: Theme.of(ctx).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.08)
                        : cs.outlineVariant.withOpacity(0.25),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.assistantSettingsDeleteDialogTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: MaterialLocalizations.of(
                              ctx,
                            ).closeButtonTooltip,
                            icon: const Icon(lucide.Lucide.X, size: 18),
                            color: cs.onSurface,
                            onPressed: () => Navigator.of(ctx).maybePop(false),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: cs.outlineVariant.withOpacity(0.12),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.assistantSettingsDeleteDialogContent,
                          style: TextStyle(
                            color: cs.onSurface.withOpacity(0.9),
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 12),
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
      );
      return dialog;
    },
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _DeskIosButton extends StatefulWidget {
  const _DeskIosButton({
    required this.label,
    required this.onTap,
    this.filled = false,
    this.danger = false,
    this.dense = false,
  });
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
    final textColor = widget.filled
        ? (widget.danger ? cs.onError : cs.onPrimary)
        : baseColor;
    final baseBg = widget.filled
        ? baseColor
        : (isDark ? Colors.white10 : Colors.transparent);
    final hoverBg = widget.filled
        ? baseColor.withOpacity(0.92)
        : (isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.04));
    final bg = _hover ? hoverBg : baseBg;
    final borderColor = widget.filled
        ? Colors.transparent
        : baseColor.withOpacity(isDark ? 0.6 : 0.5);
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
            padding: EdgeInsets.symmetric(
              vertical: widget.dense ? 8 : 12,
              horizontal: 12,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: widget.dense ? 13 : 14,
              ),
            ),
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
    final borderColor = _hover
        ? cs.primary.withOpacity(isDark ? 0.35 : 0.45)
        : cs.outlineVariant.withOpacity(isDark ? 0.12 : 0.08);
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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (!widget.item.deletable)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: cs.primary.withOpacity(0.35),
                                ),
                              ),
                              child: Text(
                                AppLocalizations.of(
                                  context,
                                )!.assistantSettingsDefaultTag,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          _CopyAssistantIcon(
                            onCopy: () async {
                              final l10n = AppLocalizations.of(context)!;
                              final newId = await context
                                  .read<AssistantProvider>()
                                  .duplicateAssistant(
                                    widget.item.id,
                                    l10n: l10n,
                                  );
                              if (!mounted) return;
                              if (newId != null) {
                                showAppSnackBar(
                                  context,
                                  message: l10n.assistantSettingsCopySuccess,
                                  type: NotificationType.success,
                                );
                              }
                            },
                          ),
                          _DeleteAssistantIcon(
                            onConfirm: () async {
                              final l10n = AppLocalizations.of(context)!;
                              final count = context
                                  .read<AssistantProvider>()
                                  .assistants
                                  .length;
                              if (count <= 1) {
                                showAppSnackBar(
                                  context,
                                  message: l10n
                                      .assistantSettingsAtLeastOneAssistantRequired,
                                  type: NotificationType.warning,
                                );
                                return;
                              }
                              final ok = await _confirmDeleteDesktop(context);
                              if (ok == true) {
                                final success = await context
                                    .read<AssistantProvider>()
                                    .deleteAssistant(widget.item.id);
                                if (success != true) {
                                  showAppSnackBar(
                                    context,
                                    message: l10n
                                        .assistantSettingsAtLeastOneAssistantRequired,
                                    type: NotificationType.warning,
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (widget.item.systemPrompt.trim().isEmpty
                            ? AppLocalizations.of(
                                context,
                              )!.assistantSettingsNoPromptPlaceholder
                            : widget.item.systemPrompt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withOpacity(0.7),
                          height: 1.25,
                        ),
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
              return ClipOval(
                child: Image(
                  image: FileImage(File(p)),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                ),
              );
            }
            return ClipOval(
              child: Image.network(
                av,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => _initial(cs),
              ),
            );
          },
        );
      } else if (av.startsWith('/') || av.contains(':')) {
        final fixed = SandboxPathResolver.fix(av);
        final f = File(fixed);
        if (f.existsSync()) {
          return ClipOval(
            child: Image(
              image: FileImage(f),
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          );
        }
        return _initial(cs);
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
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }

  Widget _emoji(ColorScheme cs, String emoji) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        emoji.characters.take(1).toString(),
        style: TextStyle(fontSize: size * 0.5),
      ),
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
  final GlobalKey<_DesktopProviderDetailPaneState> _detailKey =
      GlobalKey<_DesktopProviderDetailPaneState>();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalizeSearchQuery(String value) => value.trim().toLowerCase();

  bool _matchesQuery(String value, String normalizedQuery) {
    if (normalizedQuery.isEmpty) return true;
    return value.toLowerCase().contains(normalizedQuery);
  }

  bool _providerMatches({
    required ({String name, String key}) item,
    required SettingsProvider settings,
    required String normalizedQuery,
  }) {
    if (normalizedQuery.isEmpty) return true;
    final cfg = settings.getProviderConfig(item.key, defaultName: item.name);
    final displayName = cfg.name.isNotEmpty ? cfg.name : item.name;
    return _matchesQuery(displayName, normalizedQuery);
  }

  List<({String name, String key})> _applySearchToProviders({
    required List<({String name, String key})> items,
    required SettingsProvider settings,
    required String normalizedQuery,
  }) {
    if (normalizedQuery.isEmpty) return items;
    return [
      for (final item in items)
        if (_providerMatches(
          item: item,
          settings: settings,
          normalizedQuery: normalizedQuery,
        ))
          item,
    ];
  }

  List<_DesktopProviderGroupingRowVM> _buildProviderGroupingRows({
    required AppLocalizations l10n,
    required SettingsProvider settings,
    required List<({String name, String key})> items,
    String normalizedQuery = '',
  }) {
    final ungroupedKey = SettingsProvider.providerUngroupedGroupKey;
    final groups = settings.providerGroups;
    final groupById = {for (final g in groups) g.id: g};
    final providersByGroupKey = <String, List<({String name, String key})>>{
      for (final g in groups) g.id: <({String name, String key})>[],
      ungroupedKey: <({String name, String key})>[],
    };

    for (final p in items) {
      final gid = settings.groupIdForProvider(p.key);
      final groupKey = (gid != null && groupById.containsKey(gid))
          ? gid
          : ungroupedKey;
      (providersByGroupKey[groupKey] ??= <({String name, String key})>[]).add(
        p,
      );
    }

    final rows = <_DesktopProviderGroupingRowVM>[];
    final searching = normalizedQuery.isNotEmpty;

    List<({String name, String key})> providersForGroup(
      String groupKey,
      String title,
    ) {
      final list =
          providersByGroupKey[groupKey] ??
          const <({String name, String key})>[];
      if (!searching) return list;
      final groupMatched = _matchesQuery(title, normalizedQuery);
      if (groupMatched) return list;
      return [
        for (final item in list)
          if (_providerMatches(
            item: item,
            settings: settings,
            normalizedQuery: normalizedQuery,
          ))
            item,
      ];
    }

    for (final g in groups) {
      final list = providersForGroup(g.id, g.name);
      if (list.isEmpty) continue;
      final collapsed = searching ? false : settings.isGroupCollapsed(g.id);
      rows.add(
        _DesktopProviderGroupingHeaderVM(
          groupKey: g.id,
          title: g.name,
          count: list.length,
          collapsed: collapsed,
        ),
      );
      for (final p in list) {
        rows.add(_DesktopProviderGroupingProviderVM(item: p, groupKey: g.id));
      }
    }

    final ungrouped = providersForGroup(ungroupedKey, l10n.providerGroupsOther);
    if (ungrouped.isNotEmpty) {
      final collapsed = searching
          ? false
          : settings.isGroupCollapsed(ungroupedKey);
      rows.add(
        _DesktopProviderGroupingHeaderVM(
          groupKey: ungroupedKey,
          title: l10n.providerGroupsOther,
          count: ungrouped.length,
          collapsed: collapsed,
        ),
      );
      for (final p in ungrouped) {
        rows.add(
          _DesktopProviderGroupingProviderVM(item: p, groupKey: ungroupedKey),
        );
      }
    }
    return rows;
  }

  Future<void> _showShareDialog(String providerKey, String displayName) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _DesktopProviderShareDialog(
        providerKey: providerKey,
        displayName: displayName,
      ),
    );
  }

  Widget _buildDesktopProviderRow({
    required ({String name, String key}) item,
    required SettingsProvider settings,
    required List<({String name, String key})> ordered,
    required Set<String> baseKeys,
    required ColorScheme colorScheme,
  }) {
    final cfg = settings.getProviderConfig(item.key, defaultName: item.name);
    final enabled = cfg.enabled;
    final selected = item.key == _selectedKey;
    final bg = selected
        ? colorScheme.primary.withOpacity(0.08)
        : Colors.transparent;
    return _ProviderListRow(
      name: item.name,
      keyName: item.key,
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
      onShare: () {
        setState(() => _selectedKey = item.key);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showShareDialog(
            item.key,
            cfg.name.isNotEmpty ? cfg.name : item.name,
          );
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
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(l10n.providerDetailPageCancelButton),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(
                        l10n.providerDetailPageDeleteButton,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              try {
                final ap = context.read<AssistantProvider>();
                for (final assistant in ap.assistants) {
                  if (assistant.chatModelProvider == item.key) {
                    await ap.updateAssistant(
                      assistant.copyWith(clearChatModel: true),
                    );
                  }
                }
              } catch (_) {}
              await settings.removeProviderConfig(item.key);
              if (!mounted) return;
              setState(() {
                if (_selectedKey == item.key) {
                  _selectedKey = ordered.isNotEmpty ? ordered.first.key : null;
                }
              });
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
      (name: 'AIhubmix', key: 'AIhubmix'),
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
        dynamicItems.add((
          name: (cfg.name.isNotEmpty ? cfg.name : key),
          key: key,
        ));
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
    final filteredOrdered = _applySearchToProviders(
      items: ordered,
      settings: settings,
      normalizedQuery: _searchQuery,
    );
    final groupingActive = settings.providerGroupingActive;
    final groupingRows = groupingActive
        ? _buildProviderGroupingRows(
            l10n: l10n,
            settings: settings,
            items: ordered,
            normalizedQuery: _searchQuery,
          )
        : const <_DesktopProviderGroupingRowVM>[];

    _selectedKey ??=
        (widget.initialSelectedKey ??
        (ordered.isNotEmpty ? ordered.first.key : null));
    final selectedKey = _selectedKey;
    final rightPane = selectedKey == null
        ? const SizedBox()
        : _DesktopProviderDetailPane(
            key: _detailKey,
            providerKey: selectedKey,
            displayName: settings.getProviderConfig(selectedKey).name.isNotEmpty
                ? settings.getProviderConfig(selectedKey).name
                : selectedKey,
          );

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
                    _DesktopProvidersSearchField(
                      controller: _searchController,
                      hintText: l10n.providersPageSearchHint,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = _normalizeSearchQuery(value);
                        });
                      },
                      onClear: () {
                        if (_searchController.text.isEmpty) return;
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: groupingActive
                          ? ReorderableListView.builder(
                              buildDefaultDragHandles: false,
                              padding: EdgeInsets.zero,
                              itemCount: groupingRows.length,
                              onReorder: (oldIndex, newIndex) async {
                                if (_searchQuery.isNotEmpty) return;
                                if (groupingRows.isEmpty) return;
                                final sp = context.read<SettingsProvider>();

                                final logicRows = <ProviderGroupingRowVM>[
                                  for (final r in groupingRows)
                                    if (r is _DesktopProviderGroupingHeaderVM)
                                      ProviderGroupingHeaderVM(
                                        groupKey: r.groupKey,
                                      )
                                    else if (r
                                        is _DesktopProviderGroupingProviderVM)
                                      ProviderGroupingProviderVM(
                                        providerKey: r.item.key,
                                        groupKey: r.groupKey,
                                      ),
                                ];

                                final analysis = analyzeProviderGroupingReorder(
                                  rows: logicRows,
                                  oldIndex: oldIndex,
                                  newIndex: newIndex,
                                  isGroupCollapsed: sp.isGroupCollapsed,
                                );

                                if (analysis.blockedReason ==
                                    ProviderGroupingReorderBlockedReason
                                        .targetGroupCollapsed) {
                                  showAppSnackBar(
                                    context,
                                    message:
                                        l10n.providerGroupsExpandToMoveToast,
                                    type: NotificationType.info,
                                  );
                                  if (mounted) setState(() {});
                                  return;
                                }

                                final intent = analysis.intent;
                                if (intent == null) return;
                                final targetGroupId =
                                    intent.targetGroupKey ==
                                        SettingsProvider
                                            .providerUngroupedGroupKey
                                    ? null
                                    : intent.targetGroupKey;
                                await sp.moveProvider(
                                  intent.providerKey,
                                  targetGroupId,
                                  intent.targetPos,
                                );
                              },
                              proxyDecorator: (child, index, animation) {
                                return AnimatedBuilder(
                                  animation: animation,
                                  builder: (context, _) => ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: child,
                                  ),
                                );
                              },
                              itemBuilder: (ctx, i) {
                                final row = groupingRows[i];
                                if (row is _DesktopProviderGroupingHeaderVM) {
                                  return KeyedSubtree(
                                    key: ValueKey(
                                      'desktop-provider-group-header-${row.groupKey}',
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        bottom: 6,
                                        top: i == 0 ? 0 : 6,
                                      ),
                                      child: _DesktopProviderGroupHeaderRow(
                                        title: row.title,
                                        count: row.count,
                                        collapsed: row.collapsed,
                                        onToggle: _searchQuery.isNotEmpty
                                            ? null
                                            : () => unawaited(
                                                context
                                                    .read<SettingsProvider>()
                                                    .toggleGroupCollapsed(
                                                      row.groupKey,
                                                    ),
                                              ),
                                      ),
                                    ),
                                  );
                                }
                                if (row is _DesktopProviderGroupingProviderVM) {
                                  final collapsed = _searchQuery.isNotEmpty
                                      ? false
                                      : settings.isGroupCollapsed(row.groupKey);
                                  return KeyedSubtree(
                                    key: ValueKey(
                                      'desktop-prov-${row.item.key}',
                                    ),
                                    child: AnimatedSize(
                                      duration: const Duration(
                                        milliseconds: 260,
                                      ),
                                      curve: Curves.easeInOutCubic,
                                      alignment: Alignment.topCenter,
                                      child: collapsed
                                          ? const SizedBox.shrink()
                                          : Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              child: _searchQuery.isNotEmpty
                                                  ? _buildDesktopProviderRow(
                                                      item: row.item,
                                                      settings: settings,
                                                      ordered: ordered,
                                                      baseKeys: baseKeys,
                                                      colorScheme: cs,
                                                    )
                                                  : ReorderableDragStartListener(
                                                      index: i,
                                                      child:
                                                          _buildDesktopProviderRow(
                                                            item: row.item,
                                                            settings: settings,
                                                            ordered: ordered,
                                                            baseKeys: baseKeys,
                                                            colorScheme: cs,
                                                          ),
                                                    ),
                                            ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            )
                          : ReorderableListView.builder(
                              buildDefaultDragHandles: false,
                              padding: EdgeInsets.zero,
                              itemCount: filteredOrdered.length,
                              onReorder: (oldIndex, newIndex) async {
                                if (_searchQuery.isNotEmpty) return;
                                if (newIndex > oldIndex) newIndex -= 1;
                                final list =
                                    List<({String name, String key})>.from(
                                      ordered,
                                    );
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
                                final item = filteredOrdered[i];
                                final row = _buildDesktopProviderRow(
                                  item: item,
                                  settings: settings,
                                  ordered: ordered,
                                  baseKeys: baseKeys,
                                  colorScheme: cs,
                                );
                                return KeyedSubtree(
                                  key: ValueKey('desktop-prov-${item.key}'),
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _searchQuery.isNotEmpty
                                        ? row
                                        : ReorderableDragStartListener(
                                            index: i,
                                            child: row,
                                          ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    // Bottom add button
                    _AddFullWidthButton(
                      height: 36,
                      label: l10n.addProviderSheetAddButton,
                      onTap: () async {
                        final created = await showDesktopAddProviderDialog(
                          context,
                        );
                        if (!mounted) return;
                        if (created != null && created.isNotEmpty) {
                          setState(() {
                            _selectedKey = created;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              VerticalDivider(
                width: 1,
                thickness: 0.5,
                color: cs.outlineVariant.withOpacity(0.12),
              ),
              // Right detail pane
              Expanded(child: rightPane),
            ],
          ),
        ),
      ),
    );
  }
}

sealed class _DesktopProviderGroupingRowVM {
  const _DesktopProviderGroupingRowVM();
}

class _DesktopProviderGroupingHeaderVM extends _DesktopProviderGroupingRowVM {
  const _DesktopProviderGroupingHeaderVM({
    required this.groupKey,
    required this.title,
    required this.count,
    required this.collapsed,
  });

  final String groupKey;
  final String title;
  final int count;
  final bool collapsed;
}

class _DesktopProviderGroupingProviderVM extends _DesktopProviderGroupingRowVM {
  const _DesktopProviderGroupingProviderVM({
    required this.item,
    required this.groupKey,
  });

  final ({String name, String key}) item;
  final String groupKey;
}

class _DesktopProvidersSearchField extends StatelessWidget {
  const _DesktopProvidersSearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasText = controller.text.trim().isNotEmpty;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 14,
      ),
      cursorColor: cs.primary,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: cs.onSurface.withOpacity(0.5),
          fontSize: 13.5,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        prefixIcon: Icon(
          lucide.Lucide.Search,
          size: 16,
          color: cs.onSurface.withOpacity(0.5),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 34,
          minHeight: 34,
        ),
        suffixIcon: hasText
            ? IconButton(
                onPressed: onClear,
                icon: Icon(
                  lucide.Lucide.X,
                  size: 14,
                  color: cs.onSurface.withOpacity(0.48),
                ),
                tooltip: hintText,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
              )
            : null,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 34,
          minHeight: 34,
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.12)
            : const Color(0xFFEBEBEB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _DesktopProviderGroupHeaderRow extends StatefulWidget {
  const _DesktopProviderGroupHeaderRow({
    required this.title,
    required this.count,
    required this.collapsed,
    this.onToggle,
  });

  final String title;
  final int count;
  final bool collapsed;
  final VoidCallback? onToggle;

  @override
  State<_DesktopProviderGroupHeaderRow> createState() =>
      _DesktopProviderGroupHeaderRowState();
}

class _DesktopProviderGroupHeaderRowState
    extends State<_DesktopProviderGroupHeaderRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? (isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04))
        : Colors.transparent;

    return MouseRegion(
      cursor: widget.onToggle == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            children: [
              AnimatedRotation(
                turns: widget.collapsed ? 0.0 : 0.25, // right -> down
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: Icon(
                  lucide.Lucide.ChevronRight,
                  size: 16,
                  color: cs.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withOpacity(0.9),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _GreyCapsule(label: '${widget.count}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopProviderDetailPane extends StatefulWidget {
  const _DesktopProviderDetailPane({
    super.key,
    required this.providerKey,
    required this.displayName,
  });
  final String providerKey;
  final String displayName;
  @override
  State<_DesktopProviderDetailPane> createState() =>
      _DesktopProviderDetailPaneState();
}

class _DesktopProviderDetailPaneState
    extends State<_DesktopProviderDetailPane> {
  bool _showSearch = false;
  final TextEditingController _filterCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _showApiKey = false;
  bool _eyeHover = false;

  // 批量选择模式相关
  bool _isSelectionMode = false;
  final Set<String> _selectedModels = {};
  bool _isDetecting = false;
  bool _detectUseStream = false;
  final Map<String, bool> _detectionResults = {};
  final Map<String, String> _detectionErrorMessages = {};
  String? _currentDetectingModel;
  final Set<String> _pendingModels = {};

  // Connection test state for inline dialog
  // Keep local to this file to avoid cross-file coupling

  // Persistent controllers for provider top inputs (desktop)
  // Avoid rebuilding controllers each frame which breaks focus/IME
  final TextEditingController _apiKeyCtrl = TextEditingController();
  final TextEditingController _baseUrlCtrl = TextEditingController();
  final TextEditingController _locationCtrl = TextEditingController();
  final TextEditingController _projectIdCtrl = TextEditingController();
  final CodeLineEditingController _saJsonCtrl = CodeLineEditingController();
  final TextEditingController _apiPathCtrl = TextEditingController();
  Timer? _saJsonSaveTimer;
  String _lastSavedSaJson = '';

  void _syncCtrl(TextEditingController c, String newText) {
    final v = c.value;
    // Do not disturb ongoing IME composition
    if (v.composing.isValid) return;
    if (c.text != newText) {
      c.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  void _syncCodeCtrl(CodeLineEditingController c, String newText) {
    c.setTextSafely(newText);
  }

  void _syncControllersFromConfig(ProviderConfig cfg) {
    _syncCtrl(_apiKeyCtrl, cfg.apiKey);
    _syncCtrl(_baseUrlCtrl, cfg.baseUrl);
    _syncCtrl(_apiPathCtrl, cfg.chatPath ?? '/chat/completions');
    _syncCtrl(_locationCtrl, cfg.location ?? '');
    _syncCtrl(_projectIdCtrl, cfg.projectId ?? '');
    _syncCodeCtrl(_saJsonCtrl, cfg.serviceAccountJson ?? '');
    _lastSavedSaJson = cfg.serviceAccountJson ?? '';
  }

  Future<void> _saveSaJsonNow(SettingsProvider sp) async {
    final text = _saJsonCtrl.text;
    if (text == _lastSavedSaJson) return;
    _lastSavedSaJson = text;
    final old = sp.getProviderConfig(widget.providerKey, defaultName: widget.displayName);
    await sp.setProviderConfig(widget.providerKey, old.copyWith(serviceAccountJson: text));
  }

  void _scheduleSaJsonSave(SettingsProvider sp) {
    _saJsonSaveTimer?.cancel();
    _saJsonSaveTimer = Timer(const Duration(milliseconds: 400), () {
      _saJsonSaveTimer = null;
      if (!mounted) return;
      _saveSaJsonNow(sp);
    });
  }

  void _flushSaJsonSave(SettingsProvider sp) {
    _saJsonSaveTimer?.cancel();
    _saJsonSaveTimer = null;
    _saveSaJsonNow(sp);
  }

  @override
  void dispose() {
    try {
      final sp = context.read<SettingsProvider>();
      _flushSaJsonSave(sp);
    } catch (_) {}
    _saJsonSaveTimer?.cancel();
    _filterCtrl.dispose();
    _searchFocus.dispose();
    _apiKeyCtrl.dispose();
    _baseUrlCtrl.dispose();
    _locationCtrl.dispose();
    _projectIdCtrl.dispose();
    _saJsonCtrl.dispose();
    _apiPathCtrl.dispose();
    super.dispose();
  }

  Future<String?> _inputDialog(
    BuildContext context, {
    required String title,
    required String hint,
  }) async {
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _IconBtn(
                      icon: lucide.Lucide.X,
                      onTap: () => Navigator.of(ctx).maybePop(),
                    ),
                  ],
                ),
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
                  child: _DeskIosButton(
                    label: AppLocalizations.of(
                      context,
                    )!.assistantEditEmojiDialogSave,
                    filled: true,
                    dense: true,
                    onTap: () => Navigator.of(ctx).pop(ctrl.text.trim()),
                  ),
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
    final cfg = sp.getProviderConfig(
      widget.providerKey,
      defaultName: widget.displayName,
    );
    // Keep controllers synced without breaking IME composition
    _syncControllersFromConfig(cfg);
    final kind = ProviderConfig.classify(
      widget.providerKey,
      explicitType: cfg.providerType,
    );

    final models = List<String>.from(cfg.models);
    final allSelected =
        _selectedModels.length == models.length && models.isNotEmpty;
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
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
                    final old = sp.getProviderConfig(
                      widget.providerKey,
                      defaultName: widget.displayName,
                    );
                    await sp.setProviderConfig(
                      widget.providerKey,
                      old.copyWith(enabled: v),
                    );
                    // If provider is now disabled, clear model selections referencing it
                    if (!v && old.enabled) {
                      await sp.clearSelectionsForProvider(widget.providerKey);
                      try {
                        final ap = context.read<AssistantProvider>();
                        for (final a in ap.assistants) {
                          if (a.chatModelProvider == widget.providerKey) {
                            await ap.updateAssistant(
                              a.copyWith(clearChatModel: true),
                            );
                          }
                        }
                      } catch (_) {}
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Divider(
            height: 1,
            thickness: 0.5,
            color: cs.outlineVariant.withOpacity(0.12),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              // Partner info banners
              if (widget.providerKey.toLowerCase() == 'tensdaq') ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.primary.withOpacity(0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '革命性竞价 AI MaaS 平台，价格由市场供需决定，告别高成本固定定价。',
                        style: TextStyle(color: cs.onSurface.withOpacity(0.8)),
                      ),
                      const SizedBox(height: 6),
                      Text.rich(
                        TextSpan(
                          text: '官网：',
                          style: TextStyle(
                            color: cs.onSurface.withOpacity(0.8),
                          ),
                          children: [
                            TextSpan(
                              text: 'https://dashboard.x-aio.com',
                              style: TextStyle(
                                color: cs.primary,
                                fontWeight: FontWeight.w700,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () async {
                                  final uri = Uri.parse(
                                    'https://dashboard.x-aio.com',
                                  );
                                  try {
                                    final ok = await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                    if (!ok) {
                                      await launchUrl(uri);
                                    }
                                  } catch (_) {
                                    await launchUrl(uri);
                                  }
                                },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (widget.providerKey.toLowerCase() == 'siliconflow') ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.primary.withOpacity(0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '已内置硅基流动的免费模型，无需 API Key。若需更强大的模型，请申请并在此配置你自己的 API Key。',
                        style: TextStyle(color: cs.onSurface.withOpacity(0.8)),
                      ),
                      const SizedBox(height: 6),
                      Text.rich(
                        TextSpan(
                          text: '官网：',
                          style: TextStyle(
                            color: cs.onSurface.withOpacity(0.8),
                          ),
                          children: [
                            TextSpan(
                              text: 'https://siliconflow.cn',
                              style: TextStyle(
                                color: cs.primary,
                                fontWeight: FontWeight.w700,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () async {
                                  final uri = Uri.parse(
                                    'https://siliconflow.cn',
                                  );
                                  try {
                                    final ok = await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                    if (!ok) {
                                      await launchUrl(uri);
                                    }
                                  } catch (_) {
                                    await launchUrl(uri);
                                  }
                                },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // API Key (hidden when Google Vertex)
              if (!(kind == ProviderKind.google && (cfg.vertexAI == true))) ...[
                Row(
                  children: [
                    Expanded(
                      child: _sectionLabel(
                        context,
                        AppLocalizations.of(context)!.multiKeyPageKey,
                        bold: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: l10n.providerDetailPageTestButton,
                      child: _IconTextBtn(
                        icon: lucide.Lucide.HeartPulse,
                        label: l10n.providerDetailPageTestButton,
                        onTap: () => _showTestConnectionDialog(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (cfg.multiKeyEnabled == true)
                  Row(
                    children: [
                      Expanded(
                        child: AbsorbPointer(
                          child: Opacity(
                            opacity: 0.6,
                            child: TextField(
                              controller: TextEditingController(
                                text: '••••••••',
                              ),
                              readOnly: true,
                              style: const TextStyle(fontSize: 14),
                              decoration: _inputDecoration(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _DeskIosButton(
                        label: l10n.providerDetailPageManageKeysButton,
                        filled: false,
                        dense: true,
                        onTap: () => _showMultiKeyDialog(context),
                      ),
                    ],
                  )
                else
                  TextField(
                    controller: _apiKeyCtrl,
                    obscureText: !_showApiKey ? true : false,
                    onChanged: (v) async {
                      // For API keys, save immediately regardless of IME composition
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(apiKey: v),
                      );
                    },
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputDecoration(context).copyWith(
                      hintText: l10n.providerDetailPageApiKeyHint,
                      suffixIcon: MouseRegion(
                        onEnter: (_) => setState(() => _eyeHover = true),
                        onExit: (_) => setState(() => _eyeHover = false),
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _showApiKey = !_showApiKey),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _eyeHover
                                  ? (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white.withOpacity(0.06)
                                        : Colors.black.withOpacity(0.04))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(opacity: anim, child: child),
                              child: AnimatedRotation(
                                key: ValueKey(_showApiKey),
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                turns: _showApiKey ? 0.5 : 0.0,
                                child: Icon(
                                  _showApiKey
                                      ? lucide.Lucide.EyeOff
                                      : lucide.Lucide.Eye,
                                  size: 18,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.8),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 20,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
              ],

              // API Base URL or Vertex AI fields
              if (!(kind == ProviderKind.google && (cfg.vertexAI == true))) ...[
                _sectionLabel(
                  context,
                  AppLocalizations.of(
                    context,
                  )!.providerDetailPageApiBaseUrlLabel,
                  bold: true,
                ),
                const SizedBox(height: 6),
                Focus(
                  onFocusChange: (has) async {
                    if (!has) {
                      final v = _baseUrlCtrl.text;
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(baseUrl: v),
                      );
                    }
                  },
                  child: TextField(
                    controller: _baseUrlCtrl,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) async {
                      final v = _baseUrlCtrl.text;
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(baseUrl: v),
                      );
                    },
                    onEditingComplete: () async {
                      final v = _baseUrlCtrl.text;
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(baseUrl: v),
                      );
                    },
                    onChanged: (v) async {
                      if (_baseUrlCtrl.value.composing.isValid) return;
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(baseUrl: v),
                      );
                    },
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputDecoration(context).copyWith(
                      hintText: ProviderConfig.defaultsFor(
                        widget.providerKey,
                        displayName: widget.displayName,
                      ).baseUrl,
                    ),
                  ),
                ),
              ] else ...[
                _sectionLabel(
                  context,
                  l10n.providerDetailPageLocationLabel,
                  bold: true,
                ),
                const SizedBox(height: 6),
                Focus(
                  onFocusChange: (has) async {
                    if (!has) {
                      final v = _locationCtrl.text.trim();
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(location: v),
                      );
                    }
                  },
                  child: TextField(
                    controller: _locationCtrl,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) async {
                      final v = _locationCtrl.text.trim();
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(location: v),
                      );
                    },
                    onEditingComplete: () async {
                      final v = _locationCtrl.text.trim();
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(location: v),
                      );
                    },
                    onChanged: (v) async {
                      if (_locationCtrl.value.composing.isValid) return;
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(location: v.trim()),
                      );
                    },
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputDecoration(
                      context,
                    ).copyWith(hintText: 'us-central1'),
                  ),
                ),
                const SizedBox(height: 14),
                _sectionLabel(
                  context,
                  l10n.providerDetailPageProjectIdLabel,
                  bold: true,
                ),
                const SizedBox(height: 6),
                Focus(
                  onFocusChange: (has) async {
                    if (!has) {
                      final v = _projectIdCtrl.text.trim();
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(projectId: v),
                      );
                    }
                  },
                  child: TextField(
                    controller: _projectIdCtrl,
                    onChanged: (v) async {
                      if (_projectIdCtrl.value.composing.isValid) return;
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(projectId: v.trim()),
                      );
                    },
                    onSubmitted: (_) async {
                      final v = _projectIdCtrl.text.trim();
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(projectId: v),
                      );
                    },
                    onEditingComplete: () async {
                      final v = _projectIdCtrl.text.trim();
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(projectId: v),
                      );
                    },
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputDecoration(
                      context,
                    ).copyWith(hintText: 'my-project-id'),
                  ),
                ),
                const SizedBox(height: 14),
                _sectionLabel(
                  context,
                  l10n.providerDetailPageServiceAccountJsonLabel,
                  bold: true,
                ),
                const SizedBox(height: 6),
                Builder(
                  builder: (innerCtx) {
                    final rawMaxSaJsonHeight = computeInputMaxHeight(
                      context: innerCtx,
                      reservedHeight: 260,
                      softCapFraction: 0.6,
                      minHeight: 120,
                    );
                    // TODO: computeInputMaxHeight already enforces minHeight; remove this redundant clamp (can be simplified to math.max) and keep the height logic consistent.
                    final maxSaJsonHeight = rawMaxSaJsonHeight < 120 ? 120.0 : rawMaxSaJsonHeight;
                    return ConstrainedBox(
                      constraints: BoxConstraints(minHeight: 120, maxHeight: maxSaJsonHeight),
                      child: Focus(
                        onFocusChange: (has) async {
                          if (!has) {
                            await _saveSaJsonNow(sp);
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF7F7F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: cs.outlineVariant.withOpacity(0.12), width: 0.6),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: PlainTextCodeEditor(
                            controller: _saJsonCtrl,
                            autofocus: false,
                            hint: '{\n  "type": "service_account", ...\n}',
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            fontSize: 14,
                            fontHeight: 1.4,
                            onChanged: (value) async {
                              if (_saJsonCtrl.isComposing) return;
                              _scheduleSaJsonSave(sp);
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _DeskIosButton(
                    label: l10n.providerDetailPageImportJsonButton,
                    filled: false,
                    dense: true,
                    onTap: () async {
                      final res = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['json'],
                        withData: true,
                      );
                      if (res == null || res.files.isEmpty) return;

                      final file = res.files.first;
                      // Desktop FilePicker may not include bytes unless withData is true; fall back to disk read.
                      String? content;
                      if (file.bytes != null && file.bytes!.isNotEmpty) {
                        content = utf8.decode(file.bytes!);
                      } else if (file.path != null && file.path!.isNotEmpty) {
                        try {
                          content = await File(file.path!).readAsString();
                        } catch (_) {}
                      }
                      if (content == null || content.trim().isEmpty) {
                        showAppSnackBar(
                          context,
                          message: 'Failed to read file',
                          type: NotificationType.error,
                        );
                        return;
                      }

                      String projectId = cfg.projectId ?? '';
                      try {
                        final obj = jsonDecode(content);
                        projectId =
                            (obj['project_id'] as String?)?.trim() ?? projectId;
                      } catch (_) {}
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      final updated = old.copyWith(
                        serviceAccountJson: content,
                        projectId: projectId,
                      );
                      _syncControllersFromConfig(updated);
                      await sp.setProviderConfig(widget.providerKey, updated);
                    },
                  ),
                ),
              ],

              // API Path (OpenAI chat)
              if (kind == ProviderKind.openai &&
                  (cfg.useResponseApi != true)) ...[
                const SizedBox(height: 14),
                _sectionLabel(
                  context,
                  l10n.providerDetailPageApiPathLabel,
                  bold: true,
                ),
                const SizedBox(height: 6),
                Focus(
                  onFocusChange: (has) async {
                    if (!has) {
                      final v = _apiPathCtrl.text;
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(chatPath: v),
                      );
                    }
                  },
                  child: TextField(
                    controller: _apiPathCtrl,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) async {
                      final v = _apiPathCtrl.text;
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(chatPath: v),
                      );
                    },
                    onEditingComplete: () async {
                      final v = _apiPathCtrl.text;
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(chatPath: v),
                      );
                    },
                    onChanged: (v) async {
                      if (_apiPathCtrl.value.composing.isValid) return;
                      final old = sp.getProviderConfig(
                        widget.providerKey,
                        defaultName: widget.displayName,
                      );
                      await sp.setProviderConfig(
                        widget.providerKey,
                        old.copyWith(chatPath: v),
                      );
                    },
                    style: const TextStyle(fontSize: 14),
                    decoration: _inputDecoration(
                      context,
                    ).copyWith(hintText: '/chat/completions'),
                  ),
                ),
              ],

              const SizedBox(height: 18),
              // Models header with count + search + actions (test / add / fetch)
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          AppLocalizations.of(
                            context,
                          )!.providerDetailPageModelsTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _GreyCapsule(label: '${models.length}'),
                        const Spacer(),
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              width: _showSearch ? 180 : 28,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 140),
                                transitionBuilder: (child, anim) =>
                                    FadeTransition(opacity: anim, child: child),
                                child: _showSearch
                                    ? TextField(
                                        key: const ValueKey('search-field'),
                                        controller: _filterCtrl,
                                        focusNode: _searchFocus,
                                        autofocus: true,
                                        style: const TextStyle(fontSize: 14),
                                        decoration: _inputDecoration(context)
                                            .copyWith(
                                              hintText: l10n
                                                  .providerDetailPageFilterHint,
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8,
                                                  ),
                                            ),
                                        onChanged: (_) => setState(() {}),
                                      )
                                    : _IconBtn(
                                        key: const ValueKey('search-icon'),
                                        icon: lucide.Lucide.Search,
                                        onTap: () => setState(() {
                                          _showSearch = true;
                                          _searchFocus.addListener(() {
                                            if (!_searchFocus.hasFocus)
                                              setState(
                                                () => _showSearch = false,
                                              );
                                          });
                                        }),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (_isSelectionMode) ...[
                    Tooltip(
                      message: l10n.homePageCancel,
                      child: _IconBtn(
                        icon: lucide.Lucide.X,
                        onTap: _exitSelectionMode,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: allSelected
                          ? l10n.mcpAssistantSheetClearAll
                          : l10n.mcpAssistantSheetSelectAll,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: _IconBtn(
                          key: ValueKey(allSelected),
                          icon: allSelected
                              ? lucide.Lucide.Square
                              : lucide.Lucide.CheckSquare,
                          color: cs.onSurface.withOpacity(0.85),
                          onTap: () {
                            setState(() {
                              if (allSelected) {
                                _selectedModels.clear();
                              } else {
                                _selectedModels.clear();
                                _selectedModels.addAll(models);
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: l10n.providerDetailPageUseStreamingLabel,
                      child: GestureDetector(
                        onTap: () => setState(
                          () => _detectUseStream = !_detectUseStream,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: _detectUseStream
                                ? cs.onSurface.withOpacity(0.08)
                                : Colors.transparent,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            transitionBuilder: (child, anim) =>
                                ScaleTransition(scale: anim, child: child),
                            child: Icon(
                              _detectUseStream
                                  ? lucide.Lucide.AudioWaveform
                                  : lucide.Lucide.SquareEqual,
                              key: ValueKey(_detectUseStream),
                              size: 18,
                              color: cs.onSurface.withOpacity(0.85),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: _isDetecting
                          ? l10n.providerDetailPageBatchDetecting
                          : l10n.providerDetailPageBatchDetectStart,
                      child: _IconTextBtn(
                        icon: _isDetecting
                            ? lucide.Lucide.Loader
                            : lucide.Lucide.HeartPulse,
                        label: _isDetecting
                            ? l10n.providerDetailPageBatchDetecting
                            : l10n.providerDetailPageBatchDetectButton,
                        color: _selectedModels.isEmpty
                            ? cs.onSurface.withOpacity(0.4)
                            : null,
                        onTap: () {
                          if (_selectedModels.isEmpty) return;
                          _startDetection();
                        },
                      ),
                    ),
                  ] else ...[
                    if (!_isDetecting)
                      Tooltip(
                        message: l10n.searchServicesPageTestConnectionTooltip,
                        child: _IconBtn(
                          icon: lucide.Lucide.HeartPulse,
                          onTap: _enterSelectionMode,
                        ),
                      )
                    else
                      Tooltip(
                        message: l10n.providerDetailPageBatchDetecting,
                        child: _IconBtn(
                          icon: lucide.Lucide.Loader,
                          onTap: () {},
                        ),
                      ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: l10n.providerDetailPageAddNewModelButton,
                      child: _IconBtn(
                        icon: lucide.Lucide.Plus,
                        onTap: () => _createModel(context),
                      ),
                    ),
                    if (models.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: '删除全部模型',
                        child: _IconBtn(
                          icon: lucide.Lucide.Trash2,
                          color: cs.onSurface.withOpacity(0.85),
                          onTap: _confirmDeleteAllModels,
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Tooltip(
                      message: l10n.providerDetailPageFetchModelsButton,
                      child: _IconTextBtn(
                        icon: lucide.Lucide.RefreshCcwDot,
                        label: l10n.providerDetailPageFetchModelsButton,
                        onTap: () async {
                          final providerName = widget.displayName;
                          await showModelFetchDialog(
                            context,
                            providerKey: widget.providerKey,
                            providerDisplayName: providerName,
                          );
                        },
                      ),
                    ),
                  ],
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
                    isSelectionMode: _isSelectionMode,
                    selectedModels: _selectedModels,
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        _selectedModels.clear();
                        _selectedModels.addAll(newSelection);
                      });
                    },
                    detectionResults: _detectionResults,
                    detectionErrorMessages: _detectionErrorMessages,
                    currentDetectingModel: _currentDetectingModel,
                    pendingModels: _pendingModels,
                  ),
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
      if (m.contains('/'))
        g = m.split('/').first;
      else if (m.contains(':'))
        g = m.split(':').first;
      else if (m.contains('-'))
        g = m.split('-').first;
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
    return [
      for (final m in src)
        if (m.toLowerCase().contains(k)) m,
    ];
  }

  InputDecoration _inputDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: isDark ? Colors.white10 : const Color(0xFFF7F7F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: cs.outlineVariant.withOpacity(0.12),
          width: 0.6,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: cs.outlineVariant.withOpacity(0.12),
          width: 0.6,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: cs.primary.withOpacity(0.35), width: 0.8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Future<void> _showProviderSettingsDialog(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final sp = context.read<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    ProviderConfig cfg = sp.getProviderConfig(
      widget.providerKey,
      defaultName: widget.displayName,
    );
    ProviderKind kind = ProviderConfig.classify(
      widget.providerKey,
      explicitType: cfg.providerType,
    );
    bool multi = cfg.multiKeyEnabled ?? false;
    bool openaiResp = cfg.useResponseApi ?? false;
    bool googleVertex = cfg.vertexAI ?? false;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final GlobalKey _avatarKey = GlobalKey();
        final nameCtrl = TextEditingController(text: cfg.name);
        final proxyHostCtrl = TextEditingController(text: cfg.proxyHost ?? '');
        final proxyPortCtrl = TextEditingController(
          text: cfg.proxyPort ?? '8080',
        );
        final proxyUserCtrl = TextEditingController(
          text: cfg.proxyUsername ?? '',
        );
        final proxyPassCtrl = TextEditingController(
          text: cfg.proxyPassword ?? '',
        );
        ProviderKind tmpKind = kind;
        bool tmpMulti = multi;
        bool tmpResp = openaiResp;
        bool tmpVertex = googleVertex;
        return Dialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Consumer<SettingsProvider>(
              builder: (c, spWatch, _) {
                final cfgNow = spWatch.getProviderConfig(
                  widget.providerKey,
                  defaultName: widget.displayName,
                );
                // IME-friendly sync: avoid overwriting while composing
                void syncCtrl(TextEditingController ctrl, String text) {
                  final v = ctrl.value;
                  if (v.composing.isValid) return;
                  if (ctrl.text != text) {
                    ctrl.value = TextEditingValue(
                      text: text,
                      selection: TextSelection.collapsed(offset: text.length),
                    );
                  }
                }

                syncCtrl(nameCtrl, cfgNow.name);
                syncCtrl(proxyHostCtrl, cfgNow.proxyHost ?? '');
                syncCtrl(proxyPortCtrl, cfgNow.proxyPort ?? '8080');
                syncCtrl(proxyUserCtrl, cfgNow.proxyUsername ?? '');
                syncCtrl(proxyPassCtrl, cfgNow.proxyPassword ?? '');
                final kindNow =
                    cfgNow.providerType ??
                    ProviderConfig.classify(
                      cfgNow.id,
                      explicitType: cfgNow.providerType,
                    );
                final multiNow = cfgNow.multiKeyEnabled ?? false;
                final respNow = cfgNow.useResponseApi ?? false;
                final vertexNow = cfgNow.vertexAI ?? false;
                final proxyEnabledNow = cfgNow.proxyEnabled ?? false;
                final aihubmixAppCodeEnabled =
                    cfgNow.aihubmixAppCodeEnabled ?? false;
                final groupsNow = spWatch.providerGroups;
                final groupValue =
                    spWatch.groupIdForProvider(widget.providerKey) ??
                    SettingsProvider.providerUngroupedGroupKey;
                final groupOptions = <DesktopSelectOption<String>>[
                  DesktopSelectOption(
                    value: SettingsProvider.providerUngroupedGroupKey,
                    label: l10n.providerGroupsOtherUngroupedOption,
                  ),
                  for (final g in groupsNow)
                    DesktopSelectOption(value: g.id, label: g.name),
                ];
                Widget row(String label, Widget trailing) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurface.withOpacity(0.9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(width: 260, child: trailing),
                    ],
                  ),
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
                            Expanded(
                              child: Text(
                                cfgNow.name.isNotEmpty
                                    ? cfgNow.name
                                    : widget.providerKey,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _IconBtn(
                              icon: lucide.Lucide.X,
                              onTap: () => Navigator.of(ctx).maybePop(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Divider(
                        height: 1,
                        thickness: 0.5,
                        color: cs.outlineVariant.withOpacity(0.12),
                      ),
                    ),
                    // Centered provider avatar (smaller than user dialog)
                    Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 6),
                      child: Center(
                        child: GestureDetector(
                          key: _avatarKey,
                          onTapDown: (_) async {
                            // Open avatar menu (anchored)
                            final l10n2 = AppLocalizations.of(context)!;
                            await showDesktopAnchoredMenu(
                              context,
                              anchorKey: _avatarKey,
                              offset: const Offset(0, 8),
                              items: [
                                DesktopContextMenuItem(
                                  icon: lucide.Lucide.Image,
                                  label: l10n2.sideDrawerChooseImage,
                                  onTap: () async {
                                    try {
                                      final res = await FilePicker.platform
                                          .pickFiles(
                                            allowMultiple: false,
                                            withData: false,
                                            type: FileType.custom,
                                            allowedExtensions: const [
                                              'png',
                                              'jpg',
                                              'jpeg',
                                              'gif',
                                              'webp',
                                              'heic',
                                              'heif',
                                            ],
                                          );
                                      final f =
                                          (res != null && res.files.isNotEmpty)
                                          ? res.files.first
                                          : null;
                                      final path = f?.path;
                                      if (path != null && path.isNotEmpty) {
                                        await context
                                            .read<SettingsProvider>()
                                            .setProviderAvatarFilePath(
                                              widget.providerKey,
                                              path,
                                            );
                                      }
                                    } catch (_) {}
                                  },
                                ),
                                DesktopContextMenuItem(
                                  icon: lucide.Lucide.Link,
                                  label: l10n2.sideDrawerEnterLink,
                                  onTap: () async {
                                    await _inputProviderAvatarUrl(
                                      context,
                                      widget.providerKey,
                                    );
                                  },
                                ),
                                DesktopContextMenuItem(
                                  icon: lucide.Lucide.RotateCw,
                                  label: l10n2.desktopAvatarMenuReset,
                                  onTap: () async {
                                    await context
                                        .read<SettingsProvider>()
                                        .resetProviderAvatar(
                                          widget.providerKey,
                                        );
                                  },
                                ),
                              ],
                            );
                          },
                          child: ProviderAvatar(
                            providerKey: widget.providerKey,
                            displayName: widget.displayName,
                            size: 64,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1) Name
                          row(
                            l10n.providerDetailPageNameLabel,
                            Focus(
                              onFocusChange: (has) async {
                                if (!has) {
                                  final v = nameCtrl.text.trim();
                                  final old = spWatch.getProviderConfig(
                                    widget.providerKey,
                                    defaultName: widget.displayName,
                                  );
                                  await spWatch.setProviderConfig(
                                    widget.providerKey,
                                    old.copyWith(
                                      name: v.isEmpty ? widget.displayName : v,
                                    ),
                                  );
                                }
                              },
                              child: TextField(
                                controller: nameCtrl,
                                style: const TextStyle(fontSize: 14),
                                decoration: _inputDecoration(ctx),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) async {
                                  final v = nameCtrl.text.trim();
                                  final old = spWatch.getProviderConfig(
                                    widget.providerKey,
                                    defaultName: widget.displayName,
                                  );
                                  await spWatch.setProviderConfig(
                                    widget.providerKey,
                                    old.copyWith(
                                      name: v.isEmpty ? widget.displayName : v,
                                    ),
                                  );
                                },
                                onEditingComplete: () async {
                                  final v = nameCtrl.text.trim();
                                  final old = spWatch.getProviderConfig(
                                    widget.providerKey,
                                    defaultName: widget.displayName,
                                  );
                                  await spWatch.setProviderConfig(
                                    widget.providerKey,
                                    old.copyWith(
                                      name: v.isEmpty ? widget.displayName : v,
                                    ),
                                  );
                                },
                                onChanged: (_) async {
                                  // Avoid saving during IME composing to prevent glitches with Pinyin input
                                  if (nameCtrl.value.composing.isValid) return;
                                  final v = nameCtrl.text.trim();
                                  final old = spWatch.getProviderConfig(
                                    widget.providerKey,
                                    defaultName: widget.displayName,
                                  );
                                  await spWatch.setProviderConfig(
                                    widget.providerKey,
                                    old.copyWith(
                                      name: v.isEmpty ? widget.displayName : v,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // 1.5) Group
                          row(
                            l10n.providerGroupsGroupLabel,
                            Row(
                              children: [
                                Expanded(
                                  child: DesktopSelectDropdown<String>(
                                    value: groupValue,
                                    options: groupOptions,
                                    maxLabelWidth: 150,
                                    triggerFillColor:
                                        Theme.of(ctx).brightness ==
                                            Brightness.dark
                                        ? Colors.white10
                                        : const Color(0xFFF7F7F9),
                                    onSelected: (v) async {
                                      if (v ==
                                          SettingsProvider
                                              .providerUngroupedGroupKey) {
                                        await spWatch.setProviderGroup(
                                          widget.providerKey,
                                          null,
                                        );
                                      } else {
                                        await spWatch.setProviderGroup(
                                          widget.providerKey,
                                          v,
                                        );
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _IconBtn(
                                  icon: lucide.Lucide.Plus,
                                  onTap: () => unawaited(() async {
                                    final controller = TextEditingController();
                                    final ok = await showDialog<bool>(
                                      context: ctx,
                                      barrierColor: Colors.black.withOpacity(
                                        0.12,
                                      ),
                                      builder: (dctx) => AlertDialog(
                                        title: Text(
                                          l10n.providerGroupsCreateDialogTitle,
                                        ),
                                        content: TextField(
                                          controller: controller,
                                          autofocus: true,
                                          decoration: InputDecoration(
                                            hintText:
                                                l10n.providerGroupsNameHint,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(dctx).pop(false),
                                            child: Text(
                                              l10n.providerGroupsCreateDialogCancel,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(dctx).pop(true),
                                            child: Text(
                                              l10n.providerGroupsCreateDialogOk,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok != true) return;
                                    final name = controller.text.trim();
                                    if (name.isEmpty) return;
                                    final id = await spWatch.createGroup(name);
                                    if (id.isEmpty) return;
                                    await spWatch.setProviderGroup(
                                      widget.providerKey,
                                      id,
                                    );
                                  }()),
                                ),
                                const SizedBox(width: 4),
                                _IconBtn(
                                  icon: lucide.Lucide.Settings,
                                  onTap: () => unawaited(
                                    showDialog<void>(
                                      context: ctx,
                                      barrierDismissible: true,
                                      barrierColor: Colors.black.withOpacity(
                                        0.12,
                                      ),
                                      builder: (_) =>
                                          const _DesktopProviderGroupsDialog(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          // 2) Provider type
                          row(
                            l10n.providerDetailPageProviderTypeTitle,
                            _ProviderTypeDropdown(
                              value: kindNow,
                              onChanged: (k) async {
                                final old = spWatch.getProviderConfig(
                                  widget.providerKey,
                                  defaultName: widget.displayName,
                                );
                                await spWatch.setProviderConfig(
                                  widget.providerKey,
                                  old.copyWith(providerType: k),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 4),
                          // 3) Multi-Key
                          row(
                            l10n.providerDetailPageMultiKeyModeTitle,
                            Align(
                              alignment: Alignment.centerRight,
                              child: IosSwitch(
                                value: multiNow,
                                onChanged: (v) async {
                                  final old = spWatch.getProviderConfig(
                                    widget.providerKey,
                                    defaultName: widget.displayName,
                                  );
                                  await spWatch.setProviderConfig(
                                    widget.providerKey,
                                    old.copyWith(multiKeyEnabled: v),
                                  );
                                },
                              ),
                            ),
                          ),
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
                                  child: row(
                                    l10n.providerDetailPageResponseApiTitle,
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: IosSwitch(
                                        value: respNow,
                                        onChanged: (v) async {
                                          final old = spWatch.getProviderConfig(
                                            widget.providerKey,
                                            defaultName: widget.displayName,
                                          );
                                          await spWatch.setProviderConfig(
                                            widget.providerKey,
                                            old.copyWith(useResponseApi: v),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              }
                              if (kindNow == ProviderKind.google) {
                                return KeyedSubtree(
                                  key: const ValueKey('google-vertex'),
                                  child: row(
                                    l10n.providerDetailPageVertexAiTitle,
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: IosSwitch(
                                        value: vertexNow,
                                        onChanged: (v) async {
                                          final old = spWatch.getProviderConfig(
                                            widget.providerKey,
                                            defaultName: widget.displayName,
                                          );
                                          await spWatch.setProviderConfig(
                                            widget.providerKey,
                                            old.copyWith(vertexAI: v),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink(
                                key: ValueKey('none'),
                              );
                            }(),
                          ),
                          const SizedBox(height: 4),
                          if (_isAihubmix(cfgNow))
                            row(
                              l10n.providerDetailPageAihubmixAppCodeLabel,
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Tooltip(
                                    message: l10n
                                        .providerDetailPageAihubmixAppCodeHelp,
                                    child: Icon(
                                      Icons.help_outline,
                                      size: 16,
                                      color: cs.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IosSwitch(
                                    value: aihubmixAppCodeEnabled,
                                    onChanged: (v) async {
                                      final old = spWatch.getProviderConfig(
                                        widget.providerKey,
                                        defaultName: widget.displayName,
                                      );
                                      await spWatch.setProviderConfig(
                                        widget.providerKey,
                                        old.copyWith(aihubmixAppCodeEnabled: v),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 4),
                          // 5) Network proxy inline
                          row(
                            l10n.providerDetailPageNetworkTab,
                            Align(
                              alignment: Alignment.centerRight,
                              child: IosSwitch(
                                value: proxyEnabledNow,
                                onChanged: (v) async {
                                  final old = spWatch.getProviderConfig(
                                    widget.providerKey,
                                    defaultName: widget.displayName,
                                  );
                                  await spWatch.setProviderConfig(
                                    widget.providerKey,
                                    old.copyWith(proxyEnabled: v),
                                  );
                                },
                              ),
                            ),
                          ),
                          AnimatedCrossFade(
                            firstChild: const SizedBox.shrink(),
                            secondChild: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  row(
                                    l10n.providerDetailPageHostLabel,
                                    Focus(
                                      onFocusChange: (has) async {
                                        if (!has) {
                                          final v = proxyHostCtrl.text.trim();
                                          final old = spWatch.getProviderConfig(
                                            widget.providerKey,
                                            defaultName: widget.displayName,
                                          );
                                          await spWatch.setProviderConfig(
                                            widget.providerKey,
                                            old.copyWith(proxyHost: v),
                                          );
                                        }
                                      },
                                      child: TextField(
                                        controller: proxyHostCtrl,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: _inputDecoration(
                                          ctx,
                                        ).copyWith(hintText: '127.0.0.1'),
                                        onChanged: (_) async {
                                          if (proxyHostCtrl
                                              .value
                                              .composing
                                              .isValid)
                                            return;
                                          final old = spWatch.getProviderConfig(
                                            widget.providerKey,
                                            defaultName: widget.displayName,
                                          );
                                          await spWatch.setProviderConfig(
                                            widget.providerKey,
                                            old.copyWith(
                                              proxyHost: proxyHostCtrl.text
                                                  .trim(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  row(
                                    l10n.providerDetailPagePortLabel,
                                    Focus(
                                      onFocusChange: (has) async {
                                        if (!has) {
                                          final v = proxyPortCtrl.text.trim();
                                          final old = spWatch.getProviderConfig(
                                            widget.providerKey,
                                            defaultName: widget.displayName,
                                          );
                                          await spWatch.setProviderConfig(
                                            widget.providerKey,
                                            old.copyWith(proxyPort: v),
                                          );
                                        }
                                      },
                                      child: TextField(
                                        controller: proxyPortCtrl,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: _inputDecoration(
                                          ctx,
                                        ).copyWith(hintText: '8080'),
                                        onChanged: (_) async {
                                          if (proxyPortCtrl
                                              .value
                                              .composing
                                              .isValid)
                                            return;
                                          final old = spWatch.getProviderConfig(
                                            widget.providerKey,
                                            defaultName: widget.displayName,
                                          );
                                          await spWatch.setProviderConfig(
                                            widget.providerKey,
                                            old.copyWith(
                                              proxyPort: proxyPortCtrl.text
                                                  .trim(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  row(
                                    l10n.providerDetailPageUsernameOptionalLabel,
                                    Focus(
                                      onFocusChange: (has) async {
                                        if (!has) {
                                          final v = proxyUserCtrl.text.trim();
                                          final old = spWatch.getProviderConfig(
                                            widget.providerKey,
                                            defaultName: widget.displayName,
                                          );
                                          await spWatch.setProviderConfig(
                                            widget.providerKey,
                                            old.copyWith(proxyUsername: v),
                                          );
                                        }
                                      },
                                      child: TextField(
                                        controller: proxyUserCtrl,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: _inputDecoration(ctx),
                                        onChanged: (_) async {
                                          if (proxyUserCtrl
                                              .value
                                              .composing
                                              .isValid)
                                            return;
                                          final old = spWatch.getProviderConfig(
                                            widget.providerKey,
                                            defaultName: widget.displayName,
                                          );
                                          await spWatch.setProviderConfig(
                                            widget.providerKey,
                                            old.copyWith(
                                              proxyUsername: proxyUserCtrl.text
                                                  .trim(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  row(
                                    l10n.providerDetailPagePasswordOptionalLabel,
                                    Focus(
                                      onFocusChange: (has) async {
                                        if (!has) {
                                          final v = proxyPassCtrl.text.trim();
                                          final old = spWatch.getProviderConfig(
                                            widget.providerKey,
                                            defaultName: widget.displayName,
                                          );
                                          await spWatch.setProviderConfig(
                                            widget.providerKey,
                                            old.copyWith(proxyPassword: v),
                                          );
                                        }
                                      },
                                      child: TextField(
                                        controller: proxyPassCtrl,
                                        style: const TextStyle(fontSize: 13),
                                        obscureText: true,
                                        decoration: _inputDecoration(ctx),
                                        onChanged: (_) async {
                                          if (proxyPassCtrl
                                              .value
                                              .composing
                                              .isValid)
                                            return;
                                          final old = spWatch.getProviderConfig(
                                            widget.providerKey,
                                            defaultName: widget.displayName,
                                          );
                                          await spWatch.setProviderConfig(
                                            widget.providerKey,
                                            old.copyWith(
                                              proxyPassword: proxyPassCtrl.text
                                                  .trim(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            crossFadeState: proxyEnabledNow
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 180),
                            sizeCurve: Curves.easeOutCubic,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _inputProviderAvatarUrl(
    BuildContext context,
    String providerKey,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        bool valid(String s) =>
            s.trim().startsWith('http://') || s.trim().startsWith('https://');
        String value = '';
        return StatefulBuilder(
          builder: (ctx2, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: cs.surface,
              title: Text(l10n.sideDrawerImageUrlDialogTitle),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.sideDrawerImageUrlDialogHint,
                  filled: true,
                  fillColor: Theme.of(ctx2).brightness == Brightness.dark
                      ? Colors.white10
                      : const Color(0xFFF2F3F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.transparent),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Colors.transparent),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.primary.withOpacity(0.4)),
                  ),
                ),
                onChanged: (v) => setLocal(() => value = v),
                onSubmitted: (_) {
                  if (valid(value)) Navigator.of(ctx2).pop(true);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l10n.sideDrawerCancel),
                ),
                TextButton(
                  onPressed: valid(value)
                      ? () => Navigator.of(ctx).pop(true)
                      : null,
                  child: Text(
                    l10n.sideDrawerSave,
                    style: TextStyle(
                      color: valid(value)
                          ? cs.primary
                          : cs.onSurface.withOpacity(0.38),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok == true) {
      final url = controller.text.trim();
      if (url.isNotEmpty) {
        await context.read<SettingsProvider>().setProviderAvatarUrl(
          providerKey,
          url,
        );
      }
    }
  }

  bool _isAihubmix(ProviderConfig cfg) {
    final base = cfg.baseUrl.toLowerCase();
    final key = cfg.id.toLowerCase();
    return key.contains('aihubmix') || base.contains('aihubmix.com');
  }

  Future<void> _showNetworkDialog(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final sp = context.read<SettingsProvider>();
    final cfg = sp.getProviderConfig(
      widget.providerKey,
      defaultName: widget.displayName,
    );
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
          child: StatefulBuilder(
            builder: (ctx, setSt) {
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
                          Expanded(
                            child: Text(
                              AppLocalizations.of(
                                ctx,
                              )!.providerDetailPageNetworkTab,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
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
                    child: Divider(
                      height: 1,
                      thickness: 0.5,
                      color: cs.outlineVariant.withOpacity(0.12),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _rowSwitch(
                          ctx,
                          label: AppLocalizations.of(
                            ctx,
                          )!.providerDetailPageEnableProxyTitle,
                          value: enabled,
                          onChanged: (v) async {
                            setSt(() => enabled = v);
                            final old = sp.getProviderConfig(
                              widget.providerKey,
                              defaultName: widget.displayName,
                            );
                            await sp.setProviderConfig(
                              widget.providerKey,
                              old.copyWith(proxyEnabled: v),
                            );
                          },
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 12),
                              _sectionLabel(
                                ctx,
                                AppLocalizations.of(
                                  ctx,
                                )!.providerDetailPageHostLabel,
                              ),
                              const SizedBox(height: 6),
                              Focus(
                                onFocusChange: (has) async {
                                  if (!has) {
                                    final v = host.text.trim();
                                    final old = sp.getProviderConfig(
                                      widget.providerKey,
                                      defaultName: widget.displayName,
                                    );
                                    await sp.setProviderConfig(
                                      widget.providerKey,
                                      old.copyWith(proxyHost: v),
                                    );
                                  }
                                },
                                child: TextField(
                                  controller: host,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: _inputDecoration(
                                    ctx,
                                  ).copyWith(hintText: '127.0.0.1'),
                                  onChanged: (_) async {
                                    final old = sp.getProviderConfig(
                                      widget.providerKey,
                                      defaultName: widget.displayName,
                                    );
                                    await sp.setProviderConfig(
                                      widget.providerKey,
                                      old.copyWith(proxyHost: host.text.trim()),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              _sectionLabel(
                                ctx,
                                AppLocalizations.of(
                                  ctx,
                                )!.providerDetailPagePortLabel,
                              ),
                              const SizedBox(height: 6),
                              Focus(
                                onFocusChange: (has) async {
                                  if (!has) {
                                    final v = port.text.trim();
                                    final old = sp.getProviderConfig(
                                      widget.providerKey,
                                      defaultName: widget.displayName,
                                    );
                                    await sp.setProviderConfig(
                                      widget.providerKey,
                                      old.copyWith(proxyPort: v),
                                    );
                                  }
                                },
                                child: TextField(
                                  controller: port,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: _inputDecoration(
                                    ctx,
                                  ).copyWith(hintText: '8080'),
                                  onChanged: (_) async {
                                    final old = sp.getProviderConfig(
                                      widget.providerKey,
                                      defaultName: widget.displayName,
                                    );
                                    await sp.setProviderConfig(
                                      widget.providerKey,
                                      old.copyWith(proxyPort: port.text.trim()),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              _sectionLabel(
                                ctx,
                                AppLocalizations.of(
                                  ctx,
                                )!.providerDetailPageUsernameOptionalLabel,
                              ),
                              const SizedBox(height: 6),
                              Focus(
                                onFocusChange: (has) async {
                                  if (!has) {
                                    final v = user.text.trim();
                                    final old = sp.getProviderConfig(
                                      widget.providerKey,
                                      defaultName: widget.displayName,
                                    );
                                    await sp.setProviderConfig(
                                      widget.providerKey,
                                      old.copyWith(proxyUsername: v),
                                    );
                                  }
                                },
                                child: TextField(
                                  controller: user,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: _inputDecoration(ctx),
                                  onChanged: (_) async {
                                    final old = sp.getProviderConfig(
                                      widget.providerKey,
                                      defaultName: widget.displayName,
                                    );
                                    await sp.setProviderConfig(
                                      widget.providerKey,
                                      old.copyWith(
                                        proxyUsername: user.text.trim(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              _sectionLabel(
                                ctx,
                                AppLocalizations.of(
                                  ctx,
                                )!.providerDetailPagePasswordOptionalLabel,
                              ),
                              const SizedBox(height: 6),
                              Focus(
                                onFocusChange: (has) async {
                                  if (!has) {
                                    final v = pass.text.trim();
                                    final old = sp.getProviderConfig(
                                      widget.providerKey,
                                      defaultName: widget.displayName,
                                    );
                                    await sp.setProviderConfig(
                                      widget.providerKey,
                                      old.copyWith(proxyPassword: v),
                                    );
                                  }
                                },
                                child: TextField(
                                  controller: pass,
                                  style: const TextStyle(fontSize: 13),
                                  obscureText: true,
                                  decoration: _inputDecoration(ctx),
                                  onChanged: (_) async {
                                    final old = sp.getProviderConfig(
                                      widget.providerKey,
                                      defaultName: widget.displayName,
                                    );
                                    await sp.setProviderConfig(
                                      widget.providerKey,
                                      old.copyWith(
                                        proxyPassword: pass.text.trim(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          crossFadeState: enabled
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 180),
                          sizeCurve: Curves.easeOutCubic,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
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
        ProviderConfig cfg = sp.getProviderConfig(
          widget.providerKey,
          defaultName: widget.displayName,
        );
        LoadBalanceStrategy strat =
            cfg.keyManagement?.strategy ?? LoadBalanceStrategy.roundRobin;
        final keys = List<ApiKeyConfig>.from(
          cfg.apiKeys ?? const <ApiKeyConfig>[],
        );
        final listCtrl = ScrollController();
        Future<void> saveStrategy(LoadBalanceStrategy s) async {
          final old = sp.getProviderConfig(
            widget.providerKey,
            defaultName: widget.displayName,
          );
          final km = (old.keyManagement ?? const KeyManagementConfig())
              .copyWith(strategy: s);
          await sp.setProviderConfig(
            widget.providerKey,
            old.copyWith(keyManagement: km),
          );
        }

        // addKeys defined below after detection helpers
        // Persisted state across inner StatefulBuilder rebuilds
        String? detectModelId;
        bool detecting = false;
        String? testingKeyId;
        StateSetter? _setDRef;

        Future<void> _pickDetectModel(BuildContext dctx) async {
          final sel = await showModelSelector(
            dctx,
            limitProviderKey: widget.providerKey,
          );
          if (sel != null) {
            detectModelId = sel.modelId;
            _setDRef?.call(() {});
          }
        }

        Future<void> _testSingleKey(
          ProviderConfig baseCfg,
          String modelId,
          ApiKeyConfig key,
        ) async {
          // Force using the specific key by disabling multi-key selection
          final cfg2 = baseCfg.copyWith(
            apiKey: key.key,
            multiKeyEnabled: false,
            apiKeys: const [],
          );
          await ProviderManager.testConnection(cfg2, modelId);
        }

        Future<void> _testKeysAndSave(
          BuildContext dctx,
          List<ApiKeyConfig> fullList,
          List<ApiKeyConfig> toTest,
          String modelId,
        ) async {
          final settings = dctx.read<SettingsProvider>();
          final base = settings.getProviderConfig(
            widget.providerKey,
            defaultName: widget.displayName,
          );
          final out = List<ApiKeyConfig>.from(fullList);
          for (int i = 0; i < toTest.length; i++) {
            final k = toTest[i];
            bool ok = true;
            try {
              await _testSingleKey(base, modelId, k);
            } catch (_) {
              ok = false;
            }
            final idx = out.indexWhere((e) => e.id == k.id);
            if (idx >= 0)
              out[idx] = k.copyWith(
                status: ok ? ApiKeyStatus.active : ApiKeyStatus.error,
                usage: k.usage.copyWith(
                  totalRequests: k.usage.totalRequests + 1,
                  successfulRequests: k.usage.successfulRequests + (ok ? 1 : 0),
                  failedRequests: k.usage.failedRequests + (ok ? 0 : 1),
                  consecutiveFailures: ok
                      ? 0
                      : (k.usage.consecutiveFailures + 1),
                  lastUsed: DateTime.now().millisecondsSinceEpoch,
                ),
                lastError: ok ? null : 'Test failed',
                updatedAt: DateTime.now().millisecondsSinceEpoch,
              );
            await Future.delayed(const Duration(milliseconds: 120));
          }
          await settings.setProviderConfig(
            widget.providerKey,
            base.copyWith(apiKeys: out),
          );
        }

        Future<void> _detectAll(BuildContext dctx) async {
          if (detecting) return;
          final settings = dctx.read<SettingsProvider>();
          final cfgX = settings.getProviderConfig(
            widget.providerKey,
            defaultName: widget.displayName,
          );
          final models = cfgX.models;
          if (detectModelId == null) {
            if (models.isEmpty) {
              showAppSnackBar(
                dctx,
                message: AppLocalizations.of(dctx)!.multiKeyPagePleaseAddModel,
                type: NotificationType.warning,
              );
              return;
            }
            detectModelId = models.first;
          }
          detecting = true;
          _setDRef?.call(() {});
          try {
            final list = List<ApiKeyConfig>.from(
              cfgX.apiKeys ?? const <ApiKeyConfig>[],
            );
            await _testKeysAndSave(dctx, list, list, detectModelId!);
          } finally {
            detecting = false;
            _setDRef?.call(() {});
          }
        }

        Future<void> _detectOnly(BuildContext dctx, List<String> keys) async {
          final settings = dctx.read<SettingsProvider>();
          final cfgX = settings.getProviderConfig(
            widget.providerKey,
            defaultName: widget.displayName,
          );
          final models = cfgX.models;
          if (detectModelId == null) {
            if (models.isEmpty) {
              showAppSnackBar(
                dctx,
                message: AppLocalizations.of(dctx)!.multiKeyPagePleaseAddModel,
                type: NotificationType.warning,
              );
              return;
            }
            detectModelId = models.first;
          }
          final list = List<ApiKeyConfig>.from(
            cfgX.apiKeys ?? const <ApiKeyConfig>[],
          );
          final toTest = list.where((e) => keys.contains(e.key)).toList();
          await _testKeysAndSave(dctx, list, toTest, detectModelId!);
        }

        Future<void> _detectOne(BuildContext dctx, ApiKeyConfig key) async {
          if (detecting || testingKeyId != null) return;
          final settings = dctx.read<SettingsProvider>();
          final cfgX = settings.getProviderConfig(
            widget.providerKey,
            defaultName: widget.displayName,
          );
          final models = cfgX.models;
          if (detectModelId == null) {
            if (models.isEmpty) {
              showAppSnackBar(
                dctx,
                message: AppLocalizations.of(dctx)!.multiKeyPagePleaseAddModel,
                type: NotificationType.warning,
              );
              return;
            }
            detectModelId = models.first;
          }
          testingKeyId = key.id;
          _setDRef?.call(() {});
          try {
            final list = List<ApiKeyConfig>.from(
              cfgX.apiKeys ?? const <ApiKeyConfig>[],
            );
            final toTest = list.where((e) => e.id == key.id).toList();
            await _testKeysAndSave(dctx, list, toTest, detectModelId!);
          } finally {
            testingKeyId = null;
            _setDRef?.call(() {});
          }
        }

        Future<void> _deleteAllErrorKeys(BuildContext dctx) async {
          final settings = dctx.read<SettingsProvider>();
          final cfgX = settings.getProviderConfig(
            widget.providerKey,
            defaultName: widget.displayName,
          );
          final keys = List<ApiKeyConfig>.from(
            cfgX.apiKeys ?? const <ApiKeyConfig>[],
          );
          final errorKeys = keys
              .where((e) => e.status == ApiKeyStatus.error)
              .toList();
          if (errorKeys.isEmpty) return;
          final l10nX = AppLocalizations.of(dctx)!;
          final csX = Theme.of(dctx).colorScheme;
          final ok = await showDialog<bool>(
            context: dctx,
            builder: (ctx2) => AlertDialog(
              title: Text(l10nX.multiKeyPageDeleteErrorsConfirmTitle),
              content: Text(l10nX.multiKeyPageDeleteErrorsConfirmContent),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx2).pop(false),
                  child: Text(l10nX.multiKeyPageCancel),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx2).pop(true),
                  style: TextButton.styleFrom(foregroundColor: csX.error),
                  child: Text(l10nX.multiKeyPageDelete),
                ),
              ],
            ),
          );
          if (ok != true) return;
          final remain = keys
              .where((e) => e.status != ApiKeyStatus.error)
              .toList();
          await settings.setProviderConfig(
            widget.providerKey,
            cfgX.copyWith(apiKeys: remain),
          );
          showAppSnackBar(
            dctx,
            message: l10nX.multiKeyPageDeletedErrorsSnackbar(errorKeys.length),
            type: NotificationType.success,
          );
          _setDRef?.call(() {});
        }

        Future<ApiKeyConfig?> _showEditKeyDialog(
          BuildContext dctx,
          ApiKeyConfig k,
        ) async {
          final cs2 = Theme.of(dctx).colorScheme;
          final l10n2 = AppLocalizations.of(dctx)!;
          final aliasCtrl = TextEditingController(text: k.name ?? '');
          final keyCtrl = TextEditingController(text: k.key);
          final priCtrl = TextEditingController(text: k.priority.toString());
          final res = await showDialog<ApiKeyConfig?>(
            context: dctx,
            barrierDismissible: true,
            builder: (c2) => Dialog(
              backgroundColor: cs2.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: StatefulBuilder(
                  builder: (cc, setCC) {
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
                                Expanded(
                                  child: Text(
                                    l10n2.multiKeyPageEdit,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                _IconBtn(
                                  icon: lucide.Lucide.X,
                                  onTap: () => Navigator.of(c2).maybePop(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: cs2.outlineVariant.withOpacity(0.12),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _sectionLabel(cc, l10n2.multiKeyPageAlias),
                              const SizedBox(height: 6),
                              TextField(
                                controller: aliasCtrl,
                                style: const TextStyle(fontSize: 13),
                                decoration: _inputDecoration(cc),
                              ),
                              const SizedBox(height: 12),
                              _sectionLabel(cc, l10n2.multiKeyPageKey),
                              const SizedBox(height: 6),
                              TextField(
                                controller: keyCtrl,
                                style: const TextStyle(fontSize: 13),
                                decoration: _inputDecoration(cc),
                              ),
                              const SizedBox(height: 12),
                              _sectionLabel(cc, l10n2.multiKeyPagePriority),
                              const SizedBox(height: 6),
                              TextField(
                                controller: priCtrl,
                                style: const TextStyle(fontSize: 13),
                                decoration: _inputDecoration(
                                  cc,
                                ).copyWith(hintText: '1-10'),
                              ),
                              const SizedBox(height: 14),
                              Align(
                                alignment: Alignment.centerRight,
                                child: _DeskIosButton(
                                  label: l10n2.multiKeyPageEdit,
                                  filled: true,
                                  onTap: () {
                                    final p =
                                        int.tryParse(priCtrl.text.trim()) ??
                                        k.priority;
                                    final clamped = p.clamp(1, 10) as int;
                                    Navigator.of(c2).pop(
                                      k.copyWith(
                                        name: aliasCtrl.text.trim().isEmpty
                                            ? null
                                            : aliasCtrl.text.trim(),
                                        key: keyCtrl.text.trim(),
                                        priority: clamped,
                                        updatedAt: DateTime.now()
                                            .millisecondsSinceEpoch,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
          return res;
        }

        // Define addKeys now that helpers are in scope
        Future<void> addKeys(BuildContext c) async {
          final text = await _inputDialog(
            c,
            title: l10n.multiKeyPageAdd,
            hint: l10n.multiKeyPageAddHint,
          );
          if (text == null || text.trim().isEmpty) return;
          final parts = text
              .split(RegExp(r'[\s,]+'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          if (parts.isEmpty) return;
          final existing =
              sp
                  .getProviderConfig(
                    widget.providerKey,
                    defaultName: widget.displayName,
                  )
                  .apiKeys ??
              const <ApiKeyConfig>[];
          final existingSet = existing.map((e) => e.key.trim()).toSet();
          final list = List<ApiKeyConfig>.from(existing);
          final uniqueAdded = <String>[];
          for (final k in parts) {
            if (!existingSet.contains(k)) {
              list.add(ApiKeyConfig.create(k));
              uniqueAdded.add(k);
            }
          }
          final old = sp.getProviderConfig(
            widget.providerKey,
            defaultName: widget.displayName,
          );
          await sp.setProviderConfig(
            widget.providerKey,
            old.copyWith(apiKeys: list, multiKeyEnabled: true),
          );
          if (uniqueAdded.isNotEmpty) {
            showAppSnackBar(
              c,
              message: l10n.multiKeyPageImportedSnackbar(uniqueAdded.length),
              type: NotificationType.success,
            );
            await _detectOnly(c, uniqueAdded);
          } else {
            showAppSnackBar(c, message: l10n.multiKeyPageImportedSnackbar(0));
          }
        }

        return Dialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
            child: StatefulBuilder(
              builder: (dctx, setD) {
                _setDRef = setD;
                ProviderConfig cfg2 = sp.getProviderConfig(
                  widget.providerKey,
                  defaultName: widget.displayName,
                );
                final keyList = List<ApiKeyConfig>.from(
                  cfg2.apiKeys ?? const <ApiKeyConfig>[],
                );
                final currentStrat =
                    cfg2.keyManagement?.strategy ??
                    LoadBalanceStrategy.roundRobin;
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
                            Expanded(
                              child: Text(
                                l10n.multiKeyPageTitle,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            // Delete all error keys
                            Tooltip(
                              message: l10n.multiKeyPageDeleteErrorsTooltip,
                              child: _IconBtn(
                                icon: lucide.Lucide.Trash2,
                                onTap: () => _deleteAllErrorKeys(dctx),
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Detect / test all keys
                            if (detecting)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.primary,
                                  ),
                                ),
                              )
                            else
                              Tooltip(
                                message: l10n.multiKeyPageDetect,
                                child: _IconBtn(
                                  icon: lucide.Lucide.HeartPulse,
                                  onTap: () => _detectAll(dctx),
                                  onLongPress: () => _pickDetectModel(dctx),
                                ),
                              ),
                            const SizedBox(width: 6),
                            _IconBtn(
                              icon: lucide.Lucide.X,
                              onTap: () => Navigator.of(ctx).maybePop(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: cs.outlineVariant.withOpacity(0.12),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.multiKeyPageStrategyTitle,
                              style: TextStyle(
                                fontSize: 14,
                                color: cs.onSurface.withOpacity(0.9),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: _StrategyDropdown(
                              value: currentStrat,
                              onChanged: (s) async {
                                await saveStrategy(s);
                                setD(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Scrollbar(
                        thumbVisibility: true,
                        controller: listCtrl,
                        child: ListView(
                          controller: listCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            _DesktopIosSectionCard(
                              children: [
                                if (keyList.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    child: Center(
                                      child: Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.multiKeyPageNoKeys,
                                      ),
                                    ),
                                  )
                                else
                                  for (int i = 0; i < keyList.length; i++)
                                    _DesktopKeyRow(
                                      keyConfig: keyList[i],
                                      showDivider: false,
                                      onToggle: (v) async {
                                        final old = sp.getProviderConfig(
                                          widget.providerKey,
                                          defaultName: widget.displayName,
                                        );
                                        final list = List<ApiKeyConfig>.from(
                                          old.apiKeys ?? const <ApiKeyConfig>[],
                                        );
                                        final idx = list.indexWhere(
                                          (e) => e.id == keyList[i].id,
                                        );
                                        if (idx >= 0)
                                          list[idx] = keyList[i].copyWith(
                                            isEnabled: v,
                                            updatedAt: DateTime.now()
                                                .millisecondsSinceEpoch,
                                          );
                                        await sp.setProviderConfig(
                                          widget.providerKey,
                                          old.copyWith(apiKeys: list),
                                        );
                                        setD(() {});
                                      },
                                      onEdit: () async {
                                        final updated =
                                            await _showEditKeyDialog(
                                              dctx,
                                              keyList[i],
                                            );
                                        if (updated == null) return;
                                        // Prevent duplicate keys
                                        final latest = sp.getProviderConfig(
                                          widget.providerKey,
                                          defaultName: widget.displayName,
                                        );
                                        final list = List<ApiKeyConfig>.from(
                                          latest.apiKeys ??
                                              const <ApiKeyConfig>[],
                                        );
                                        final dup = list.any(
                                          (e) =>
                                              e.id != keyList[i].id &&
                                              e.key.trim() ==
                                                  updated.key.trim(),
                                        );
                                        if (dup) {
                                          showAppSnackBar(
                                            dctx,
                                            message: AppLocalizations.of(
                                              dctx,
                                            )!.multiKeyPageDuplicateKeyWarning,
                                            type: NotificationType.warning,
                                          );
                                          return;
                                        }
                                        final idx = list.indexWhere(
                                          (e) => e.id == keyList[i].id,
                                        );
                                        if (idx >= 0) list[idx] = updated;
                                        await sp.setProviderConfig(
                                          widget.providerKey,
                                          latest.copyWith(apiKeys: list),
                                        );
                                        setD(() {});
                                      },
                                      onTest: () =>
                                          _detectOne(dctx, keyList[i]),
                                      testing: testingKeyId == keyList[i].id,
                                      onDelete: () async {
                                        final old = sp.getProviderConfig(
                                          widget.providerKey,
                                          defaultName: widget.displayName,
                                        );
                                        final list = List<ApiKeyConfig>.from(
                                          old.apiKeys ?? const <ApiKeyConfig>[],
                                        );
                                        final idx = list.indexWhere(
                                          (e) => e.id == keyList[i].id,
                                        );
                                        if (idx >= 0) {
                                          list.removeAt(idx);
                                          await sp.setProviderConfig(
                                            widget.providerKey,
                                            old.copyWith(apiKeys: list),
                                          );
                                          setD(() {});
                                        }
                                      },
                                    ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _DeskIosButton(
                            label: l10n.multiKeyPageAdd,
                            filled: false,
                            onTap: () => addKeys(dctx),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
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
    final res = await showDesktopCreateModelDialog(
      context,
      providerKey: widget.providerKey,
    );
    if (res == true && mounted) setState(() {});
  }

  Future<void> _showTestConnectionDialog(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    String? selectedModelId;
    _TestState state = _TestState.idle;
    String errorMessage = '';
    bool useStream = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        Future<void> pickModel() async {
          // Use the desktop model selector dialog and limit to current provider
          final sel = await showModelSelector(
            ctx,
            limitProviderKey: widget.providerKey,
          );
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
            final cfg = sp.getProviderConfig(
              widget.providerKey,
              defaultName: widget.displayName,
            );
            await ProviderManager.testConnection(
              cfg,
              selectedModelId!,
              useStream: useStream,
            );
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
            message = selectedModelId == null
                ? l10n.modelSelectSheetSearchHint
                : l10n.providerDetailPageTestingMessage;
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
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Dialog(
              backgroundColor: cs.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Text(
                          l10n.providerDetailPageTestConnectionTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: pickModel,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(ctx).brightness == Brightness.dark
                                ? Colors.white10
                                : const Color(0xFFF7F7F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: cs.outlineVariant.withOpacity(0.12),
                              width: 0.6,
                            ),
                          ),
                          child: Row(
                            children: [
                              if (selectedModelId != null)
                                _BrandCircle(name: selectedModelId!, size: 22),
                              if (selectedModelId != null)
                                const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  selectedModelId ??
                                      l10n.providerDetailPageSelectModelButton,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.providerDetailPageUseStreamingLabel,
                              style: TextStyle(
                                fontSize: 14,
                                color: cs.onSurface.withOpacity(0.9),
                              ),
                            ),
                          ),
                          IosSwitch(
                            value: useStream,
                            onChanged: (v) => setState(() => useStream = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (state == _TestState.loading)
                        Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.primary,
                            ),
                          ),
                        )
                      else if (state != _TestState.idle)
                        Center(
                          child: Text(
                            message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: color,
                              fontSize: 14,
                              fontWeight: state == _TestState.success
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _DeskIosButton(
                            label: l10n.providerDetailPageCancelButton,
                            filled: false,
                            dense: true,
                            onTap: () => Navigator.of(ctx).maybePop(),
                          ),
                          const SizedBox(width: 8),
                          _DeskIosButton(
                            label: l10n.providerDetailPageTestButton,
                            filled: true,
                            dense: true,
                            onTap: canTest ? doTest : () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedModels.clear();
      _detectionResults.clear();
      _detectionErrorMessages.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedModels.clear();
      _detectionResults.clear();
      _detectionErrorMessages.clear();
    });
  }

  Future<void> _confirmDeleteAllModels() async {
    final sp = context.read<SettingsProvider>();
    final cfg = sp.getProviderConfig(
      widget.providerKey,
      defaultName: widget.displayName,
    );
    if (cfg.models.isEmpty) return;
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.providerDetailPageConfirmDeleteTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _IconBtn(
                      icon: lucide.Lucide.X,
                      onTap: () => Navigator.of(ctx).maybePop(false),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                color: cs.outlineVariant.withOpacity(0.12),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.providerDetailPageDeleteAllModelsWarning,
                    style: TextStyle(color: cs.onSurface.withOpacity(0.85)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _DeskIosButton(
                      label: l10n.providerDetailPageCancelButton,
                      filled: false,
                      dense: true,
                      onTap: () => Navigator.of(ctx).maybePop(false),
                    ),
                    const SizedBox(width: 8),
                    _DeskIosButton(
                      label: l10n.providerDetailPageDeleteButton,
                      filled: true,
                      dense: true,
                      onTap: () => Navigator.of(ctx).maybePop(true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    final cleared = cfg.copyWith(models: const [], modelOverrides: const {});
    await sp.setProviderConfig(widget.providerKey, cleared);
    if (!mounted) return;
    setState(() {
      _selectedModels.clear();
      _detectionResults.clear();
      _detectionErrorMessages.clear();
      _pendingModels.clear();
      _currentDetectingModel = null;
      _isSelectionMode = false;
    });
  }

  Future<void> _startDetection() async {
    if (_selectedModels.isEmpty || _isDetecting) return;

    final modelsToTest = Set<String>.from(_selectedModels);

    setState(() {
      _isDetecting = true;
      _detectionResults.clear();
      _detectionErrorMessages.clear();
      _isSelectionMode = false;
      _selectedModels.clear();
      _pendingModels.clear();
      _pendingModels.addAll(modelsToTest);
      _currentDetectingModel = null;
    });

    final sp = context.read<SettingsProvider>();
    final cfg = sp.getProviderConfig(
      widget.providerKey,
      defaultName: widget.displayName,
    );

    for (final modelId in modelsToTest) {
      if (mounted) {
        setState(() {
          _currentDetectingModel = modelId;
          _pendingModels.remove(modelId);
        });
      }

      try {
        await ProviderManager.testConnection(
          cfg,
          modelId,
          useStream: _detectUseStream,
        );
        if (mounted) {
          setState(() {
            _detectionResults[modelId] = true;
            _detectionErrorMessages.remove(modelId);
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _detectionResults[modelId] = false;
            _detectionErrorMessages[modelId] = e.toString();
          });
        }
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (mounted) {
      setState(() {
        _isDetecting = false;
        _currentDetectingModel = null;
        _pendingModels.clear();
      });
    }
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
    final overlayBox =
        Overlay.of(context)?.context.findRenderObject() as RenderBox?;
    if (rb == null || overlayBox == null) return;
    final size = rb.size;
    final triggerW = size.width;
    const maxW = 280.0; // unused after width sync, kept for reference
    final items = const [
      (ProviderKind.openai, 'OpenAI'),
      (ProviderKind.google, 'Google'),
      (ProviderKind.claude, 'Claude'),
    ];
    _entry = OverlayEntry(
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final content = Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color:
                  (Provider.of<SettingsProvider>(
                    ctx,
                    listen: false,
                  ).usePureBackground)
                  ? (isDark ? Colors.black : Colors.white)
                  : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.outlineVariant.withOpacity(0.12),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
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
                  onTap: () {
                    widget.onChanged(k);
                    _close();
                  },
                );
              },
            ),
          ),
        );
        final width = triggerW; // menu width equals trigger width
        final dx = 0.0; // align left edges
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _close,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: Offset(dx, size.height + 6),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: width, maxWidth: width),
                child: content,
              ),
            ),
          ],
        );
      },
    );
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

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() => _open = false);
  }

  void _openMenu() {
    if (_entry != null) return;
    final rb = _key.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final size = rb.size;
    final triggerW = size.width;
    final labelFor = (LoadBalanceStrategy s) =>
        s == LoadBalanceStrategy.roundRobin
        ? AppLocalizations.of(context)!.multiKeyPageStrategyRoundRobin
        : AppLocalizations.of(context)!.multiKeyPageStrategyRandom;
    final entries = [
      LoadBalanceStrategy.roundRobin,
      LoadBalanceStrategy.random,
    ];
    _entry = OverlayEntry(
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _close,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 6),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: BoxConstraints(
                    minWidth: triggerW,
                    maxWidth: triggerW,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (Provider.of<SettingsProvider>(
                          ctx,
                          listen: false,
                        ).usePureBackground)
                        ? (isDark ? Colors.black : Colors.white)
                        : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cs.outlineVariant.withOpacity(0.12),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    shrinkWrap: true,
                    itemCount: entries.length,
                    itemBuilder: (c, i) {
                      final s = entries[i];
                      final selected = widget.value == s;
                      return _OverlayMenuItem(
                        label: labelFor(s),
                        selected: selected,
                        onTap: () {
                          widget.onChanged(s);
                          _close();
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
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

Widget _rowSwitch(
  BuildContext context, {
  required String label,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  final cs = Theme.of(context).colorScheme;
  return Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: cs.onSurface.withOpacity(0.9),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      IosSwitch(value: value, onChanged: onChanged),
    ],
  );
}

Widget _rowButton(
  BuildContext context, {
  required String label,
  required VoidCallback onTap,
}) {
  final cs = Theme.of(context).colorScheme;
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withOpacity(0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
    final bg = isDark
        ? Colors.white.withOpacity(0.06)
        : const Color(0xFFF2F3F5);
    final fg = Theme.of(context).colorScheme.onSurface.withOpacity(0.85);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _IconBtn extends StatefulWidget {
  const _IconBtn({
    super.key,
    required this.icon,
    required this.onTap,
    this.onLongPress,
    this.color,
  });
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? (isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.05))
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: 18,
            color: widget.color ?? cs.onSurface,
          ),
        ),
      ),
    );
  }
}

class _IconTextBtn extends StatefulWidget {
  const _IconTextBtn({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  @override
  State<_IconTextBtn> createState() => _IconTextBtnState();
}

class _IconTextBtnState extends State<_IconTextBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? (isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.05))
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: widget.color ?? cs.onSurface),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  color: widget.color ?? cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopProviderGroupsDialog extends StatefulWidget {
  const _DesktopProviderGroupsDialog();

  @override
  State<_DesktopProviderGroupsDialog> createState() =>
      _DesktopProviderGroupsDialogState();
}

class _DesktopProviderGroupsDialogState
    extends State<_DesktopProviderGroupsDialog> {
  Future<String?> _promptName(
    BuildContext context, {
    required String title,
    String initialText = '',
    required String okText,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: initialText);
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.12),
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.providerGroupsNameHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.providerGroupsCreateDialogCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(okText),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    final name = controller.text.trim();
    if (name.isEmpty) return null;
    return name;
  }

  Future<void> _createGroup(BuildContext context) async {
    final sp = context.read<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    final name = await _promptName(
      context,
      title: l10n.providerGroupsCreateDialogTitle,
      okText: l10n.providerGroupsCreateDialogOk,
    );
    if (name == null) return;
    final id = await sp.createGroup(name);
    if (id.isEmpty && context.mounted) {
      showAppSnackBar(
        context,
        message: l10n.providerGroupsCreateFailedToast,
        type: NotificationType.error,
      );
    }
  }

  Future<void> _renameGroup(
    BuildContext context, {
    required String groupId,
    required String oldName,
  }) async {
    final sp = context.read<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    final name = await _promptName(
      context,
      title: l10n.providerDetailPageEditTooltip,
      initialText: oldName,
      okText: l10n.sideDrawerSave,
    );
    if (name == null) return;
    await sp.renameGroup(groupId, name);
  }

  Future<void> _deleteGroup(BuildContext context, String groupId) async {
    final sp = context.read<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.12),
      builder: (ctx) => AlertDialog(
        title: Text(l10n.providerGroupsDeleteConfirmTitle),
        content: Text(l10n.providerGroupsDeleteConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.providerGroupsDeleteConfirmCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.providerGroupsDeleteConfirmOk,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await sp.deleteGroup(groupId);
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: l10n.providerGroupsDeletedToast,
      type: NotificationType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final groups = sp.providerGroups;

    final counts = <String, int>{};
    for (final k in sp.providersOrder) {
      final gid = sp.groupIdForProvider(k);
      if (gid != null) counts[gid] = (counts[gid] ?? 0) + 1;
    }

    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.providerGroupsManageTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _IconBtn(
                      icon: lucide.Lucide.Plus,
                      onTap: () => unawaited(_createGroup(context)),
                    ),
                    const SizedBox(width: 6),
                    _IconBtn(
                      icon: lucide.Lucide.X,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: groups.isEmpty
                  ? Center(
                      child: Text(
                        l10n.providerGroupsEmptyState,
                        style: TextStyle(
                          color: cs.onSurface.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                      itemCount: groups.length,
                      buildDefaultDragHandles: false,
                      proxyDecorator: (child, index, animation) {
                        return ScaleTransition(
                          scale: Tween<double>(
                            begin: 1.0,
                            end: 1.02,
                          ).animate(animation),
                          child: child,
                        );
                      },
                      onReorder: (oldIndex, newIndex) async {
                        if (newIndex > oldIndex) newIndex -= 1;
                        await context
                            .read<SettingsProvider>()
                            .reorderProviderGroups(oldIndex, newIndex);
                      },
                      itemBuilder: (ctx, i) {
                        final g = groups[i];
                        final count = counts[g.id] ?? 0;
                        return KeyedSubtree(
                          key: ValueKey('desktop-provider-group-${g.id}'),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _DesktopProviderGroupCard(
                              title: g.name,
                              count: count,
                              onEdit: () => unawaited(
                                _renameGroup(
                                  context,
                                  groupId: g.id,
                                  oldName: g.name,
                                ),
                              ),
                              onDelete: () =>
                                  unawaited(_deleteGroup(context, g.id)),
                              dragHandle: ReorderableDragStartListener(
                                index: i,
                                child: const _DesktopDragHandle(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopProviderGroupCard extends StatelessWidget {
  const _DesktopProviderGroupCard({
    required this.title,
    required this.count,
    required this.onEdit,
    required this.onDelete,
    required this.dragHandle,
  });

  final String title;
  final int count;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white10 : const Color(0xFFF7F7F9);
    final borderColor = cs.outlineVariant.withOpacity(isDark ? 0.12 : 0.10);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          _DesktopCountPill(count: count),
          const SizedBox(width: 10),
          _IconBtn(icon: lucide.Lucide.Pencil, onTap: onEdit),
          const SizedBox(width: 4),
          _IconBtn(
            icon: lucide.Lucide.Trash2,
            color: cs.error,
            onTap: onDelete,
          ),
          const SizedBox(width: 4),
          dragHandle,
        ],
      ),
    );
  }
}

class _DesktopCountPill extends StatelessWidget {
  const _DesktopCountPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.primary.withOpacity(0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          color: cs.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DesktopDragHandle extends StatefulWidget {
  const _DesktopDragHandle();

  @override
  State<_DesktopDragHandle> createState() => _DesktopDragHandleState();
}

class _DesktopDragHandleState extends State<_DesktopDragHandle> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? (isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.05))
        : Colors.transparent;
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(
          lucide.Lucide.GripVertical,
          size: 18,
          color: cs.onSurface.withOpacity(0.7),
        ),
      ),
    );
  }
}

class _DesktopProviderShareDialog extends StatefulWidget {
  const _DesktopProviderShareDialog({
    required this.providerKey,
    required this.displayName,
  });
  final String providerKey;
  final String displayName;

  @override
  State<_DesktopProviderShareDialog> createState() =>
      _DesktopProviderShareDialogState();
}

class _DesktopProviderShareDialogState
    extends State<_DesktopProviderShareDialog> {
  late final String _code;
  final GlobalKey _qrKey = GlobalKey();
  bool _copyingQr = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    final cfg =
        settings.providerConfigs[widget.providerKey] ??
        settings.getProviderConfig(
          widget.providerKey,
          defaultName: widget.displayName,
        );
    _code = encodeProviderConfig(cfg);
  }

  Future<void> _copyText() async {
    await Clipboard.setData(ClipboardData(text: _code));
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: AppLocalizations.of(context)!.shareProviderSheetCopiedMessage,
      type: NotificationType.success,
    );
  }

  Future<Uint8List?> _captureQrBytes() async {
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _writeQrToClipboard(Uint8List bytes) async {
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard != null) {
        final item = DataWriterItem(suggestedName: 'provider-qr.png');
        item.add(Formats.png(bytes));
        await clipboard.write([item]);
        return true;
      }
    } catch (_) {}

    try {
      final file = File(
        p.join(Directory.systemTemp.path, 'kelivo-provider-qr.png'),
      );
      await file.writeAsBytes(bytes, flush: true);
      return await ClipboardImages.setImagePath(file.path);
    } catch (_) {
      return false;
    }
  }

  Future<void> _copyQr() async {
    if (_copyingQr) return;
    setState(() => _copyingQr = true);
    bool ok = false;
    try {
      final bytes = await _captureQrBytes();
      if (bytes != null && bytes.isNotEmpty) {
        ok = await _writeQrToClipboard(bytes);
      }
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _copyingQr = false);
    final l10n = AppLocalizations.of(context)!;
    showAppSnackBar(
      context,
      message: ok
          ? l10n.shareProviderSheetCopiedMessage
          : l10n.messageExportSheetExportFailed('copy-failed'),
      type: ok ? NotificationType.success : NotificationType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.shareProviderSheetTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _IconBtn(
                    icon: lucide.Lucide.X,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                l10n.shareProviderSheetDescription,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withOpacity(0.85),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: RepaintBoundary(
                  key: _qrKey,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cs.outlineVariant.withOpacity(0.2),
                      ),
                    ),
                    child: PrettyQr(
                      data: _code,
                      size: 180,
                      roundEdges: true,
                      errorCorrectLevel: QrErrorCorrectLevel.M,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: cs.outlineVariant.withOpacity(0.25),
                  ),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _code,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _DialogActionButton(
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: l10n.desktopProviderShareCopyText,
                    filled: false,
                    onTap: _copyText,
                  ),
                  const SizedBox(width: 10),
                  _DialogActionButton(
                    icon: _copyingQr
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CupertinoActivityIndicator(radius: 8),
                          )
                        : const Icon(Icons.qr_code_2, size: 18),
                    label: l10n.desktopProviderShareCopyQr,
                    filled: true,
                    onTap: _copyingQr ? null : _copyQr,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogActionButton extends StatefulWidget {
  const _DialogActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });
  final Widget icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  State<_DialogActionButton> createState() => _DialogActionButtonState();
}

class _DialogActionButtonState extends State<_DialogActionButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = widget.onTap != null;
    final baseBg = widget.filled ? cs.primary : Colors.transparent;
    final hoverOverlay = widget.filled
        ? Colors.white.withOpacity(isDark ? 0.08 : 0.10)
        : cs.primary.withOpacity(isDark ? 0.12 : 0.10);
    final bg = Color.alphaBlend(
      (_hover ? hoverOverlay : Colors.transparent),
      baseBg,
    );
    final borderColor = widget.filled
        ? cs.primary.withOpacity(isDark ? 0.30 : 0.25)
        : cs.primary.withOpacity(0.35);
    final fg = widget.filled ? cs.onPrimary : cs.primary;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: enabled ? bg : baseBg.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconTheme.merge(
                  data: IconThemeData(color: fg, size: 18),
                  child: widget.icon,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: enabled ? fg : fg.withOpacity(0.5),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
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
      inner = Text(
        name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
        style: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.45,
        ),
      );
    } else if (asset.endsWith('.svg')) {
      inner = SvgPicture.asset(
        asset,
        width: size * 0.62,
        height: size * 0.62,
        fit: BoxFit.contain,
      );
    } else {
      inner = Image.asset(
        asset,
        width: size * 0.62,
        height: size * 0.62,
        fit: BoxFit.contain,
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : cs.primary.withOpacity(0.10),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: inner,
    );
  }
}

class _ProviderListRow extends StatefulWidget {
  const _ProviderListRow({
    required this.name,
    required this.keyName,
    required this.enabled,
    required this.selected,
    required this.background,
    required this.onTap,
    required this.onEdit,
    required this.onShare,
    this.onDelete,
  });
  final String name;
  final String keyName;
  final bool enabled;
  final bool selected;
  final Color background;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onShare;
  final Future<void> Function()? onDelete;
  @override
  State<_ProviderListRow> createState() => _ProviderListRowState();
}

class _ProviderListRowState extends State<_ProviderListRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hoverBg = _hover && !widget.selected
        ? Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04)
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapDown: (details) async {
          final items = <DesktopContextMenuItem>[
            DesktopContextMenuItem(
              icon: lucide.Lucide.Share2,
              label: AppLocalizations.of(
                context,
              )!.desktopProviderContextMenuShare,
              onTap: widget.onShare,
            ),
            DesktopContextMenuItem(
              icon: lucide.Lucide.Pencil,
              label: AppLocalizations.of(
                context,
              )!.providerDetailPageEditTooltip,
              onTap: widget.onEdit,
            ),
            if (widget.onDelete != null)
              DesktopContextMenuItem(
                icon: lucide.Lucide.Trash2,
                label: AppLocalizations.of(
                  context,
                )!.providerDetailPageDeleteProviderTooltip,
                danger: true,
                onTap: () => widget.onDelete?.call(),
              ),
          ];
          await showDesktopContextMenuAt(
            context,
            globalPosition: details.globalPosition,
            items: items,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: Color.alphaBlend(hoverBg, widget.background),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              ProviderAvatar(
                providerKey: widget.keyName,
                displayName: widget.name,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (widget.enabled ? Colors.green : Colors.orange)
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  // No border for left list status
                ),
                child: Text(
                  widget.enabled
                      ? AppLocalizations.of(context)!.providersPageEnabledStatus
                      : AppLocalizations.of(
                          context,
                        )!.providersPageDisabledStatus,
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.enabled ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w700,
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

class _AddFullWidthButton extends StatefulWidget {
  const _AddFullWidthButton({
    required this.label,
    required this.onTap,
    this.height = 44,
  });
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
    final baseBg = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.04);
    final hoverBg = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.black.withOpacity(0.06);
    final bg = _hover ? hoverBg : baseBg;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
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
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(lucide.Lucide.Plus, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
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

class _DesktopIosSectionCard extends StatelessWidget {
  const _DesktopIosSectionCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final Color base = cs.surface;
    final Color bg = isDark
        ? Color.lerp(base, Colors.white, 0.06)!
        : const Color(0xFFF7F7F9);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06),
          width: 0.6,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _DesktopKeyRow extends StatelessWidget {
  const _DesktopKeyRow({
    required this.keyConfig,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    required this.onTest,
    this.testing = false,
    this.showDivider = false,
  });
  final ApiKeyConfig keyConfig;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onTest;
  final bool testing;
  final bool showDivider;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    String label;
    if ((keyConfig.name ?? '').trim().isNotEmpty) {
      label = keyConfig.name!.trim();
    } else {
      final s = keyConfig.key.trim();
      label = s.length <= 8
          ? '••••'
          : '${s.substring(0, 4)}••••${s.substring(s.length - 4)}';
    }
    Color statusColor(ApiKeyStatus st) {
      switch (st) {
        case ApiKeyStatus.active:
          return Colors.green;
        case ApiKeyStatus.disabled:
          return cs.onSurface.withOpacity(0.6);
        case ApiKeyStatus.error:
          return cs.error;
        case ApiKeyStatus.rateLimited:
          return cs.tertiary;
      }
    }

    String statusText(ApiKeyStatus st) {
      switch (st) {
        case ApiKeyStatus.active:
          return l10n.multiKeyPageStatusActive;
        case ApiKeyStatus.disabled:
          return l10n.multiKeyPageStatusDisabled;
        case ApiKeyStatus.error:
          return l10n.multiKeyPageStatusError;
        case ApiKeyStatus.rateLimited:
          return l10n.multiKeyPageStatusRateLimited;
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              // Status capsule
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor(keyConfig.status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusText(keyConfig.status),
                  style: TextStyle(
                    color: statusColor(keyConfig.status),
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IosSwitch(
                value: keyConfig.isEnabled,
                onChanged: onToggle,
                width: 46,
                height: 28,
              ),
              const SizedBox(width: 6),
              if (testing)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary,
                  ),
                )
              else
                Tooltip(
                  message: l10n.multiKeyPageDetect,
                  child: _IconBtn(
                    icon: lucide.Lucide.HeartPulse,
                    onTap: onTest,
                    color: cs.primary,
                  ),
                ),
              const SizedBox(width: 4),
              _IconBtn(
                icon: lucide.Lucide.Pencil,
                onTap: onEdit,
                color: cs.primary,
              ),
              const SizedBox(width: 4),
              _IconBtn(
                icon: lucide.Lucide.Trash2,
                onTap: onDelete,
                color: cs.error,
              ),
            ],
          ),
        ),
        if (showDivider)
          Container(height: 0.6, color: cs.outlineVariant.withOpacity(0.25)),
      ],
    );
  }
}

class _ModelGroupAccordion extends StatefulWidget {
  const _ModelGroupAccordion({
    required this.group,
    required this.modelIds,
    required this.providerKey,
    this.isSelectionMode = false,
    this.selectedModels = const {},
    this.onSelectionChanged,
    this.detectionResults = const {},
    this.detectionErrorMessages = const {},
    this.currentDetectingModel,
    this.pendingModels = const {},
  });
  final String group;
  final List<String> modelIds;
  final String providerKey;
  final bool isSelectionMode;
  final Set<String> selectedModels;
  final Map<String, String> detectionErrorMessages;
  final ValueChanged<Set<String>>? onSelectionChanged;
  final Map<String, bool> detectionResults;
  final String? currentDetectingModel;
  final Set<String> pendingModels;
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
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
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
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.03)
                        : Colors.black.withOpacity(0.02),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      AnimatedRotation(
                        turns: _open ? 0.25 : 0.0, // right (0) -> down (0.25)
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          lucide.Lucide.ChevronRight,
                          size: 16,
                          color: cs.onSurface.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.group,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: [
                  for (final id in widget.modelIds)
                    _ModelRow(
                      modelId: id,
                      providerKey: widget.providerKey,
                      isSelectionMode: widget.isSelectionMode,
                      isSelected: widget.selectedModels.contains(id),
                      onSelectionChanged: (selected) {
                        final newSelection = Set<String>.from(
                          widget.selectedModels,
                        );
                        if (selected) {
                          newSelection.add(id);
                        } else {
                          newSelection.remove(id);
                        }
                        widget.onSelectionChanged?.call(newSelection);
                      },
                      detectionErrorMessage: widget.detectionErrorMessages[id],
                      detectionResult: widget.detectionResults[id],
                      isDetecting: widget.currentDetectingModel == id,
                      isPending: widget.pendingModels.contains(id),
                    ),
                ],
              ),
              crossFadeState: _open
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
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
  const _ModelRow({
    required this.modelId,
    required this.providerKey,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.detectionErrorMessage,
    this.onSelectionChanged,
    this.detectionResult,
    this.isDetecting = false,
    this.isPending = false,
  });
  final String modelId;
  final String providerKey;
  final bool isSelectionMode;
  final bool isSelected;
  final String? detectionErrorMessage;
  final ValueChanged<bool>? onSelectionChanged;
  final bool? detectionResult;
  final bool isDetecting;
  final bool isPending;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    final cfg = sp.getProviderConfig(providerKey);
    ModelInfo _infer(String id) =>
        ModelRegistry.infer(ModelInfo(id: id, displayName: id));
    // Resolve upstream/api model id for inference + capsules
    String baseId = modelId;
    final ov = cfg.modelOverrides[modelId] as Map?;
    if (ov != null) {
      final apiId = (ov['apiModelId'] ?? ov['api_model_id'])?.toString().trim();
      if (apiId != null && apiId.isNotEmpty) {
        baseId = apiId;
      }
    }

    ModelInfo _effective() {
      final base = _infer(baseId);
      if (ov == null) return base;
      ModelType? type;
      final t = (ov['type'] as String?) ?? '';
      if (t == 'embedding')
        type = ModelType.embedding;
      else if (t == 'chat')
        type = ModelType.chat;
      List<Modality>? input;
      if (ov['input'] is List) {
        input = [
          for (final e in (ov['input'] as List))
            (e.toString() == 'image' ? Modality.image : Modality.text),
        ];
      }
      List<Modality>? output;
      if (ov['output'] is List) {
        output = [
          for (final e in (ov['output'] as List))
            (e.toString() == 'image' ? Modality.image : Modality.text),
        ];
      }
      List<ModelAbility>? abilities;
      if (ov['abilities'] is List) {
        abilities = [
          for (final e in (ov['abilities'] as List))
            (e.toString() == 'reasoning'
                ? ModelAbility.reasoning
                : ModelAbility.tool),
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
    // Display label: prefer override name, then upstream model id, then logical key
    String displayName = modelId;
    if (ov != null) {
      final overrideName = (ov['name'] as String?)?.trim();
      if (overrideName != null && overrideName.isNotEmpty) {
        displayName = overrideName;
      } else {
        displayName = baseId;
      }
    } else {
      displayName = baseId;
    }

    Widget cap(String text) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final bg = isDark
          ? Colors.white.withOpacity(0.06)
          : const Color(0xFFF2F3F5);
      final fg = cs.onSurface.withOpacity(0.85);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
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
      caps.add(
        pillCapsule(
          Icon(lucide.Lucide.Eye, size: 12, color: cs.secondary),
          cs.secondary,
        ),
      );
    }
    if (info.output.contains(Modality.image)) {
      caps.add(
        pillCapsule(
          Icon(lucide.Lucide.Image, size: 12, color: cs.tertiary),
          cs.tertiary,
        ),
      );
    }
    for (final ab in info.abilities) {
      if (ab == ModelAbility.tool) {
        caps.add(
          pillCapsule(
            Icon(lucide.Lucide.Hammer, size: 12, color: cs.primary),
            cs.primary,
          ),
        );
      } else if (ab == ModelAbility.reasoning) {
        caps.add(
          pillCapsule(
            SvgPicture.asset(
              'assets/icons/deepthink.svg',
              width: 12,
              height: 12,
              colorFilter: ColorFilter.mode(cs.secondary, BlendMode.srcIn),
            ),
            cs.secondary,
          ),
        );
      }
    }

    return GestureDetector(
      onTap: isSelectionMode
          ? () => onSelectionChanged?.call(!isSelected)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            if (isSelectionMode) ...[
              IosCheckbox(
                value: isSelected,
                onChanged: (value) => onSelectionChanged?.call(value),
              ),
              const SizedBox(width: 10),
            ],
            _BrandCircle(name: displayName, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
            const SizedBox(width: 8),
            if (isDetecting) ...[
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 8),
            ] else if (isPending) ...[
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: cs.onSurface.withOpacity(0.3),
                    width: 2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ] else if (detectionResult != null) ...[
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Tooltip(
                  message: detectionResult!
                      ? l10n.providerDetailPageDetectSuccess
                      : (detectionErrorMessage ??
                            l10n.providerDetailPageDetectFailed),
                  child: Icon(
                    detectionResult!
                        ? lucide.Lucide.CheckCircle
                        : lucide.Lucide.XCircle,
                    size: 16,
                    color: detectionResult! ? Colors.green : cs.error,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (!isSelectionMode) ...[
              Row(
                children: caps
                    .map(
                      (w) => Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: w,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(width: 8),
              _IconBtn(
                icon: lucide.Lucide.Settings2,
                onTap: () async {
                  await showDesktopModelEditDialog(
                    context,
                    providerKey: providerKey,
                    modelId: modelId,
                  );
                },
              ),
              const SizedBox(width: 4),
              _IconBtn(
                icon: lucide.Lucide.Minus,
                onTap: () async {
                  final sp = context.read<SettingsProvider>();
                  final old = sp.getProviderConfig(providerKey);
                  final list = List<String>.from(old.models)
                    ..removeWhere((e) => e == modelId);
                  await sp.setProviderConfig(
                    providerKey,
                    old.copyWith(models: list),
                  );
                  // Clear global and assistant-level model selections that reference the deleted model
                  await sp.clearSelectionsForModel(providerKey, modelId);
                  try {
                    final ap = context.read<AssistantProvider>();
                    for (final a in ap.assistants) {
                      if (a.chatModelProvider == providerKey &&
                          a.chatModelId == modelId) {
                        await ap.updateAssistant(
                          a.copyWith(clearChatModel: true),
                        );
                      }
                    }
                  } catch (_) {}
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardPress extends StatefulWidget {
  const _CardPress({
    required this.builder,
    this.onTap,
    this.pressedScale = 0.98,
  });
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
        ? (isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04))
        : Colors.transparent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = false),
      onTapCancel: widget.onTap == null
          ? null
          : () => setState(() => _pressed = false),
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
                  _RowDivider(),
                  _ChatMessageBackgroundRow(),
                  _RowDivider(),
                  _TopicPositionRow(),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                title: l10n.desktopSettingsFontsTitle,
                children: const [
                  _DesktopAppFontRow(),
                  _RowDivider(),
                  _DesktopCodeFontRow(),
                  _RowDivider(),
                  _AppLanguageRow(),
                  _RowDivider(),
                  _ChatFontSizeRow(),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                title: l10n.displaySettingsPageTrayTitle,
                children: const [
                  _DesktopTrayShowRow(),
                  _RowDivider(),
                  _DesktopTrayMinimizeOnCloseRow(),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                title: l10n.displaySettingsPageChatItemDisplayTitle,
                children: const [
                  _ToggleRowShowProviderInCapsule(),
                  _RowDivider(),
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
                  _RowDivider(),
                  _AutoCollapseCodeBlocksSection(),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                title: l10n.displaySettingsPageBehaviorStartupTitle,
                children: const [
                  _ToggleRowAutoSwitchTopicsDesktop(),
                  _RowDivider(),
                  _ToggleRowAutoCollapseThinking(),
                  _RowDivider(),
                  _ToggleRowShowUpdates(),
                  _RowDivider(),
                  _ToggleRowMsgNavButtons(),
                  _RowDivider(),
                  _ToggleRowShowChatListDate(),
                  _RowDivider(),
                  _ToggleRowNewChatOnAssistantSwitch(),
                  _RowDivider(),
                  _ToggleRowNewChatAfterDelete(),
                  _RowDivider(),
                  _ToggleRowNewChatOnLaunch(),
                  _RowDivider(),
                  _SendShortcutRow(),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                title: l10n.displaySettingsPageOtherSettingsTitle,
                children: const [
                  _ToggleRowAutoScrollEnabled(),
                  _RowDivider(),
                  _AutoScrollDelayRow(),
                  _RowDivider(),
                  _BackgroundMaskRow(),
                  _RowDivider(),
                  _ToggleRowRequestLogging(),
                  _RowDivider(),
                  _ToggleRowFlutterLogging(),
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
      color: sp.usePureBackground
          ? (isDark ? Colors.black : Colors.white)
          : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          width: 0.5,
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : cs.outlineVariant.withOpacity(0.12),
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
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: cs.onSurface.withOpacity(0.9),
                decoration: TextDecoration.none,
              ),
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

    final trackBg = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.04);
    return Container(
      decoration: BoxDecoration(
        color: trackBg,
        borderRadius: BorderRadius.circular(14),
      ),
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
                onTap: () =>
                    context.read<SettingsProvider>().setThemeMode(items[i].$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: () {
                      final selected = mode == items[i].$1;
                      if (selected)
                        return cs.primary.withOpacity(isDark ? 0.18 : 0.14);
                      if (_hover == i)
                        return isDark
                            ? Colors.white.withOpacity(0.10)
                            : Colors.black.withOpacity(0.06);
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
        ? (isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04))
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
            border: Border.all(
              color: selected
                  ? cs.primary.withOpacity(0.35)
                  : cs.outlineVariant.withOpacity(0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Keep pill text size aligned with row labels
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: fg,
                  decoration: TextDecoration.none,
                ),
              ),
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
  const _ThemeDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });
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
                ? [
                    BoxShadow(
                      color: widget.color.withOpacity(0.45),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
            border: Border.all(
              color: widget.selected
                  ? cs.onSurface.withOpacity(0.85)
                  : Colors.white,
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
      onChanged: (v) =>
          context.read<SettingsProvider>().setUsePureBackground(v),
    );
  }
}

class _ChatMessageBackgroundRow extends StatelessWidget {
  const _ChatMessageBackgroundRow();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _LabeledRow(
      label: l10n.displaySettingsPageChatMessageBackgroundTitle,
      trailing: const _BackgroundStyleDropdown(),
    );
  }
}

// --- Topic position (desktop) ---
class _TopicPositionRow extends StatelessWidget {
  const _TopicPositionRow();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _LabeledRow(
      label: l10n.desktopDisplaySettingsTopicPositionTitle,
      trailing: const _TopicPositionDropdown(),
    );
  }
}

// --- Desktop tray settings ---
class _DesktopTrayShowRow extends StatelessWidget {
  const _DesktopTrayShowRow();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageTrayShowTrayTitle,
      value: sp.desktopShowTray,
      onChanged: (v) => context.read<SettingsProvider>().setDesktopShowTray(v),
    );
  }
}

class _DesktopTrayMinimizeOnCloseRow extends StatelessWidget {
  const _DesktopTrayMinimizeOnCloseRow();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    final enabled = sp.desktopShowTray;
    return _ToggleRow(
      label: l10n.displaySettingsPageTrayMinimizeOnCloseTitle,
      value: enabled && sp.desktopMinimizeToTrayOnClose,
      onChanged: enabled
          ? (v) => context
                .read<SettingsProvider>()
                .setDesktopMinimizeToTrayOnClose(v)
          : null,
    );
  }
}

class _TopicPositionDropdown extends StatefulWidget {
  const _TopicPositionDropdown();
  @override
  State<_TopicPositionDropdown> createState() => _TopicPositionDropdownState();
}

class _TopicPositionDropdownState extends State<_TopicPositionDropdown> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    final options = <DesktopSelectOption<DesktopTopicPosition>>[
      DesktopSelectOption(
        value: DesktopTopicPosition.left,
        label: l10n.desktopDisplaySettingsTopicPositionLeft,
      ),
      DesktopSelectOption(
        value: DesktopTopicPosition.right,
        label: l10n.desktopDisplaySettingsTopicPositionRight,
      ),
    ];

    return DesktopSelectDropdown<DesktopTopicPosition>(
      value: sp.desktopTopicPosition,
      options: options,
      onSelected: (pos) =>
          context.read<SettingsProvider>().setDesktopTopicPosition(pos),
    );
  }
}

class _BackgroundStyleDropdown extends StatefulWidget {
  const _BackgroundStyleDropdown();
  @override
  State<_BackgroundStyleDropdown> createState() =>
      _BackgroundStyleDropdownState();
}

class _BackgroundStyleDropdownState extends State<_BackgroundStyleDropdown> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    final options = <DesktopSelectOption<ChatMessageBackgroundStyle>>[
      DesktopSelectOption(
        value: ChatMessageBackgroundStyle.defaultStyle,
        label: l10n.displaySettingsPageChatMessageBackgroundDefault,
      ),
      DesktopSelectOption(
        value: ChatMessageBackgroundStyle.frosted,
        label: l10n.displaySettingsPageChatMessageBackgroundFrosted,
      ),
      DesktopSelectOption(
        value: ChatMessageBackgroundStyle.solid,
        label: l10n.displaySettingsPageChatMessageBackgroundSolid,
      ),
    ];

    return DesktopSelectDropdown<ChatMessageBackgroundStyle>(
      value: sp.chatMessageBackgroundStyle,
      options: options,
      onSelected: (style) =>
          context.read<SettingsProvider>().setChatMessageBackgroundStyle(style),
    );
  }
}

class _SimpleOptionTile extends StatefulWidget {
  const _SimpleOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  State<_SimpleOptionTile> createState() => _SimpleOptionTileState();
}

class _SimpleOptionTileState extends State<_SimpleOptionTile> {
  bool _hover = false;
  bool _active = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.selected
        ? cs.primary.withOpacity(0.12)
        : (_hover
              ? (isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.04))
              : Colors.transparent);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _active = true),
        onTapCancel: () => setState(() => _active = false),
        onTapUp: (_) => setState(() => _active = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _active ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurface.withOpacity(0.88),
                      fontWeight: widget.selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Opacity(
                  opacity: widget.selected ? 1 : 0,
                  child: Icon(lucide.Lucide.Check, size: 14, color: cs.primary),
                ),
              ],
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
    final overlayBox =
        Overlay.of(context)?.context.findRenderObject() as RenderBox?;
    if (rb == null || overlayBox == null) return;
    final size = rb.size;
    final triggerW = size.width;
    final maxW = 280.0;
    final minW = triggerW;
    _entry = OverlayEntry(
      builder: (ctx) {
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
            final tp = TextPainter(
              text: TextSpan(text: s, style: style),
              textDirection: TextDirection.ltr,
              maxLines: 1,
            )..layout();
            if (tp.width > maxText) maxText = tp.width;
          }
          // item padding (12*2) + check icon (16) + gap to check (10)
          // + list padding (8*2) + gap between flag and text (8) + small fudge (2)
          return maxText + 12 * 2 + 16 + 10 + 8 * 2 + 8 + 2;
        }

        final contentW = measureContentWidth();
        final width = contentW.clamp(minW, maxW);
        final dx = (triggerW - width) / 2;
        return Stack(
          children: [
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
          ],
        );
      },
    );
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
        if ((l.scriptCode ?? '').toLowerCase() == 'hant')
          return l10n.languageDisplayTraditionalChinese;
        return l10n.displaySettingsPageLanguageChineseLabel;
      }
      return l10n.displaySettingsPageLanguageEnglishLabel;
    }

    final current = sp.isFollowingSystemLocale
        ? l10n.settingsPageSystemMode
        : labelFor(sp.appLocale);
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
    final bg = hovered || open
        ? (isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04))
        : Colors.transparent;
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
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(borderRadius),
            // Match input border color and width
            border: Border.all(
              color: cs.outlineVariant.withOpacity(0.12),
              width: 0.6,
            ),
          ),
          child: rightAlignArrow
              ? Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: fontSize,
                          color: cs.onSurface.withOpacity(0.9),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: angle / (2 * 3.1415926),
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        lucide.Lucide.ChevronDown,
                        size: 16,
                        color: cs.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: fontSize,
                        color: cs.onSurface.withOpacity(0.9),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: angle / (2 * 3.1415926),
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        lucide.Lucide.ChevronDown,
                        size: 16,
                        color: cs.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _OverlayMenuItem extends StatefulWidget {
  const _OverlayMenuItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });
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
        : (_hover
              ? (isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.04))
              : Colors.transparent);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withOpacity(0.9),
                  ),
                ),
              ),
              if (widget.selected)
                Icon(lucide.Lucide.Check, size: 16, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// Generic overlay item with leading icon, label and optional selected checkmark.
class _OverlayItem extends StatefulWidget {
  const _OverlayItem({
    required this.icon,
    required this.label,
    required this.background,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color background;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_OverlayItem> createState() => _OverlayItemState();
}

class _OverlayItemState extends State<_OverlayItem> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? Color.alphaBlend(
            (isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04)),
            widget.background,
          )
        : widget.background;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: cs.onSurface.withOpacity(0.85),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withOpacity(0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.selected)
                Icon(lucide.Lucide.Check, size: 16, color: cs.primary),
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
      setState(() {
        _opacity = 1;
        _slide = Offset.zero;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    final items = <(_LangItem, bool)>[
      (
        _LangItem(
          flag: '🖥️',
          label: l10n.settingsPageSystemMode,
          tag: 'system',
        ),
        sp.isFollowingSystemLocale,
      ),
      (
        _LangItem(
          flag: '🇨🇳',
          label: l10n.displaySettingsPageLanguageChineseLabel,
          tag: 'zh_CN',
        ),
        (!sp.isFollowingSystemLocale &&
            sp.appLocale.languageCode == 'zh' &&
            (sp.appLocale.scriptCode ?? '').isEmpty),
      ),
      (
        _LangItem(
          flag: '🇨🇳',
          label: l10n.languageDisplayTraditionalChinese,
          tag: 'zh_Hant',
        ),
        (!sp.isFollowingSystemLocale &&
            sp.appLocale.languageCode == 'zh' &&
            (sp.appLocale.scriptCode ?? '').toLowerCase() == 'hant'),
      ),
      (
        _LangItem(
          flag: '🇺🇸',
          label: l10n.displaySettingsPageLanguageEnglishLabel,
          tag: 'en_US',
        ),
        (!sp.isFollowingSystemLocale && sp.appLocale.languageCode == 'en'),
      ),
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
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1C1C1E)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.outlineVariant.withOpacity(0.12),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
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
                              await context
                                  .read<SettingsProvider>()
                                  .setAppLocaleFollowSystem();
                              break;
                            case 'zh_CN':
                              await context
                                  .read<SettingsProvider>()
                                  .setAppLocale(const Locale('zh', 'CN'));
                              break;
                            case 'zh_Hant':
                              await context
                                  .read<SettingsProvider>()
                                  .setAppLocale(
                                    const Locale.fromSubtags(
                                      languageCode: 'zh',
                                      scriptCode: 'Hant',
                                    ),
                                  );
                              break;
                            case 'en_US':
                            default:
                              await context
                                  .read<SettingsProvider>()
                                  .setAppLocale(const Locale('en', 'US'));
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
  const _LanguageDropdownItem({
    required this.item,
    this.checked = false,
    required this.onTap,
  });
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
            color: _hover
                ? (isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.04))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Text(
                widget.item.flag,
                style: const TextStyle(
                  fontSize: 16,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.item.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface,
                    decoration: TextDecoration.none,
                  ),
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
    final clamped = (n / 100.0).clamp(0.5, 1.5);
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
          Text(
            '%',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontSize: 14,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _BorderInput extends StatefulWidget {
  const _BorderInput({
    required this.controller,
    required this.onSubmitted,
    required this.onFocusLost,
  });
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
      borderSide: BorderSide(
        color: cs.outlineVariant.withOpacity(0.28),
        width: 0.8,
      ),
    );
    final hoverBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: cs.outlineVariant.withOpacity(0.38),
        width: 0.9,
      ),
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 8,
          ),
          border: baseBorder,
          enabledBorder: _focus.hasFocus
              ? focusBorder
              : (_hover ? hoverBorder : baseBorder),
          focusedBorder: focusBorder,
          hoverColor: Colors.transparent,
        ),
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}

// --- Desktop Font Rows ---
class _DesktopAppFontRow extends StatelessWidget {
  const _DesktopAppFontRow();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    final current = sp.appFontFamily;
    final displayText = (current == null || current.isEmpty)
        ? l10n.desktopFontFamilySystemDefault
        : current;
    return _LabeledRow(
      label: l10n.desktopFontAppLabel,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DesktopFontDropdownButton(
            display: displayText,
            onTap: () async {
              final fam = await _showDesktopFontChooserDialog(
                context,
                title: l10n.desktopFontAppLabel,
                initial: sp.appFontFamily,
                showSystemDefault: false,
              );
              if (fam == null) return;
              if (fam == '__SYSTEM__') {
                await context.read<SettingsProvider>().clearAppFont();
              } else {
                await context.read<SettingsProvider>().setAppFontSystemFamily(
                  fam,
                );
              }
            },
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: l10n.displaySettingsPageFontResetLabel,
            child: _IconBtn(
              icon: lucide.Lucide.RotateCcw,
              onTap: () async {
                await context.read<SettingsProvider>().clearAppFont();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopCodeFontRow extends StatelessWidget {
  const _DesktopCodeFontRow();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    final current = sp.codeFontFamily;
    final displayText = (current == null || current.isEmpty)
        ? l10n.desktopFontFamilyMonospaceDefault
        : current;
    return _LabeledRow(
      label: l10n.desktopFontCodeLabel,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DesktopFontDropdownButton(
            display: displayText,
            onTap: () async {
              final fam = await _showDesktopFontChooserDialog(
                context,
                title: l10n.desktopFontCodeLabel,
                initial: sp.codeFontFamily,
                showMonospaceDefault: false,
              );
              if (fam == null) return;
              if (fam == '__MONO__') {
                await context.read<SettingsProvider>().clearCodeFont();
              } else {
                await context.read<SettingsProvider>().setCodeFontSystemFamily(
                  fam,
                );
              }
            },
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: l10n.displaySettingsPageFontResetLabel,
            child: _IconBtn(
              icon: lucide.Lucide.RotateCcw,
              onTap: () async {
                await context.read<SettingsProvider>().clearCodeFont();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopFontDropdownButton extends StatefulWidget {
  const _DesktopFontDropdownButton({
    required this.display,
    required this.onTap,
  });
  final String display;
  final VoidCallback onTap;
  @override
  State<_DesktopFontDropdownButton> createState() =>
      _DesktopFontDropdownButtonState();
}

class _DesktopFontDropdownButtonState
    extends State<_DesktopFontDropdownButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? (isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.05))
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: cs.outlineVariant.withOpacity(0.28),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  widget.display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                lucide.Lucide.ChevronDown,
                size: 16,
                color: cs.onSurface.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> _showDesktopFontChooserDialog(
  BuildContext context, {
  required String title,
  String? initial,
  bool showSystemDefault = false,
  bool showMonospaceDefault = false,
}) async {
  final cs = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context)!;
  final ctrl = TextEditingController();
  String? result;

  Future<List<String>> _fetchSystemFonts() async {
    try {
      final sf = SystemFonts();
      // Only fetch the font family list to avoid huge memory spikes.
      final alt = await Future.value(sf.getFontList());
      final out = List<String>.from(alt ?? const <String>[]);
      out.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (out.isNotEmpty) return out;
    } catch (_) {
      /* ignore and fallback */
    }
    return <String>[
      'System UI',
      'Segoe UI',
      'SF Pro Text',
      'San Francisco',
      'Helvetica Neue',
      'Arial',
      'Roboto',
      'PingFang SC',
      'Microsoft YaHei',
      'SimHei',
      'Noto Sans SC',
      'Noto Serif',
      'Courier New',
      'JetBrains Mono',
      'Fira Code',
      'monospace',
    ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  // Show loading dialog only if fetch takes time, and ensure it closes
  bool loadingShown = false;
  Timer? loadingTimer;
  loadingTimer = Timer(const Duration(milliseconds: 300), () {
    loadingShown = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
        final cs2 = Theme.of(ctx).colorScheme;
        return Dialog(
          elevation: 0,
          backgroundColor: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const CupertinoActivityIndicator(radius: 12),
                const SizedBox(height: 12),
                Text(
                  l10n.desktopFontLoading,
                  style: TextStyle(
                    color: cs2.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  });
  final fonts = await _fetchSystemFonts();
  if (loadingTimer?.isActive ?? false) loadingTimer?.cancel();
  if (loadingShown) {
    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (_) {}
  }
  await showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: StatefulBuilder(
              builder: (context, setState) {
                String q = ctrl.text.trim().toLowerCase();
                final filtered = q.isEmpty
                    ? fonts
                    : fonts.where((f) => f.toLowerCase().contains(q)).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _IconBtn(
                          icon: lucide.Lucide.X,
                          onTap: () => Navigator.of(ctx).maybePop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: ctrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        hintText: l10n.desktopFontFilterHint,
                        fillColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? Colors.white10
                            : const Color(0xFFF7F7F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withOpacity(0.12),
                            width: 0.6,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withOpacity(0.12),
                            width: 0.6,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.35),
                            width: 0.8,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white10
                              : Colors.black.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final fam = filtered[i];
                            final selected = fam == initial;
                            return _FontRowItem(
                              family: fam,
                              selected: selected,
                              onTap: () => Navigator.of(ctx).pop(fam),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  ).then((v) => result = v);
  return result;
}

class _FontRowItem extends StatefulWidget {
  const _FontRowItem({
    required this.family,
    required this.onTap,
    this.selected = false,
  });
  final String family;
  final VoidCallback onTap;
  final bool selected;
  @override
  State<_FontRowItem> createState() => _FontRowItemState();
}

// Cache loaded/ongoing system fonts to avoid duplicate loads
final Set<String> _loadedSystemFontFamilies = <String>{};
final Set<String> _loadingSystemFontFamilies = <String>{};

class _FontRowItemState extends State<_FontRowItem> {
  bool _hover = false;
  @override
  void initState() {
    super.initState();
    // Lazy-load this row's font family for preview (only for visible items)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final fam = widget.family;
      if (_loadedSystemFontFamilies.contains(fam) ||
          _loadingSystemFontFamilies.contains(fam))
        return;
      _loadingSystemFontFamilies.add(fam);
      try {
        await SystemFonts().loadFont(fam);
      } catch (_) {
        // best-effort; fallback rendering will be used if load fails
      } finally {
        _loadingSystemFontFamilies.remove(fam);
        _loadedSystemFontFamilies.add(fam);
        if (mounted) setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? (isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04))
        : Colors.transparent;
    final sample = 'Aa字';
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.family,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      sample,
                      style: TextStyle(
                        fontFamily: widget.family,
                        fontSize: 16,
                        color: cs.onSurface,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.selected) ...[
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
      onChanged: (v) =>
          context.read<SettingsProvider>().setShowUserNameTimestamp(v),
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
      onChanged: (v) =>
          context.read<SettingsProvider>().setShowUserMessageActions(v),
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
      onChanged: (v) =>
          context.read<SettingsProvider>().setShowModelNameTimestamp(v),
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

class _ToggleRowShowProviderInCapsule extends StatelessWidget {
  const _ToggleRowShowProviderInCapsule();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.desktopShowProviderInModelCapsule,
      value: sp.showProviderInModelCapsule,
      onChanged: (v) =>
          context.read<SettingsProvider>().setShowProviderInModelCapsule(v),
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
      onChanged: (v) =>
          context.read<SettingsProvider>().setEnableDollarLatex(v),
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
      onChanged: (v) =>
          context.read<SettingsProvider>().setEnableMathRendering(v),
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
      onChanged: (v) =>
          context.read<SettingsProvider>().setEnableUserMarkdown(v),
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
      onChanged: (v) =>
          context.read<SettingsProvider>().setEnableReasoningMarkdown(v),
    );
  }
}

class _ToggleRowAutoCollapseCodeBlocks extends StatelessWidget {
  const _ToggleRowAutoCollapseCodeBlocks();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageAutoCollapseCodeBlockTitle,
      value: sp.autoCollapseCodeBlock,
      onChanged: (v) =>
          context.read<SettingsProvider>().setAutoCollapseCodeBlock(v),
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
      onChanged: (v) =>
          context.read<SettingsProvider>().setAutoCollapseThinking(v),
    );
  }
}

class _ToggleRowAutoScrollEnabled extends StatelessWidget {
  const _ToggleRowAutoScrollEnabled();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageAutoScrollEnableTitle,
      value: sp.autoScrollEnabled,
      onChanged: (v) =>
          context.read<SettingsProvider>().setAutoScrollEnabled(v),
    );
  }
}

class _ToggleRowRequestLogging extends StatelessWidget {
  const _ToggleRowRequestLogging();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.requestLogSettingTitle,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: cs.onSurface.withOpacity(0.9),
                decoration: TextDecoration.none,
              ),
            ),
          ),
          Tooltip(
            message: l10n.logViewerOpenFolder,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () async {
                final dir = await AppDirectories.getAppDataDirectory();
                final logsDir = Directory('${dir.path}/logs');
                if (!await logsDir.exists()) {
                  await logsDir.create(recursive: true);
                }
                final uri = Uri.file(logsDir.path);
                await launchUrl(uri);
              },
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  lucide.Lucide.FolderOpen,
                  size: 18,
                  color: cs.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IosSwitch(
            value: sp.requestLogEnabled,
            onChanged: (v) =>
                context.read<SettingsProvider>().setRequestLogEnabled(v),
          ),
        ],
      ),
    );
  }
}

class _ToggleRowFlutterLogging extends StatelessWidget {
  const _ToggleRowFlutterLogging();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.flutterLogSettingTitle,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: cs.onSurface.withOpacity(0.9),
                decoration: TextDecoration.none,
              ),
            ),
          ),
          Tooltip(
            message: l10n.logViewerOpenFolder,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () async {
                final dir = await AppDirectories.getAppDataDirectory();
                final logsDir = Directory('${dir.path}/logs');
                if (!await logsDir.exists()) {
                  await logsDir.create(recursive: true);
                }
                final uri = Uri.file(logsDir.path);
                await launchUrl(uri);
              },
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  lucide.Lucide.FolderOpen,
                  size: 18,
                  color: cs.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IosSwitch(
            value: sp.flutterLogEnabled,
            onChanged: (v) =>
                context.read<SettingsProvider>().setFlutterLogEnabled(v),
          ),
        ],
      ),
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

class _ToggleRowAutoSwitchTopicsDesktop extends StatelessWidget {
  const _ToggleRowAutoSwitchTopicsDesktop();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageAutoSwitchTopicsTitle,
      value: sp.desktopAutoSwitchTopics,
      onChanged: (v) =>
          context.read<SettingsProvider>().setDesktopAutoSwitchTopics(v),
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
      onChanged: (v) =>
          context.read<SettingsProvider>().setShowMessageNavButtons(v),
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

class _ToggleRowNewChatOnAssistantSwitch extends StatelessWidget {
  const _ToggleRowNewChatOnAssistantSwitch();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageNewChatOnAssistantSwitchTitle,
      value: sp.newChatOnAssistantSwitch,
      onChanged: (v) =>
          context.read<SettingsProvider>().setNewChatOnAssistantSwitch(v),
    );
  }
}

class _ToggleRowNewChatAfterDelete extends StatelessWidget {
  const _ToggleRowNewChatAfterDelete();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sp = context.watch<SettingsProvider>();
    return _ToggleRow(
      label: l10n.displaySettingsPageNewChatAfterDeleteTitle,
      value: sp.newChatAfterDelete,
      onChanged: (v) =>
          context.read<SettingsProvider>().setNewChatAfterDelete(v),
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
      onChanged: (v) =>
          context.read<SettingsProvider>().setHapticsGlobalEnabled(v),
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
      onChanged: (v) =>
          context.read<SettingsProvider>().setHapticsOnListItemTap(v),
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
      onChanged: (v) =>
          context.read<SettingsProvider>().setHapticsOnGenerate(v),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: cs.onSurface.withOpacity(0.9),
                decoration: TextDecoration.none,
              ),
            ),
          ),
          IosSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _AutoCollapseCodeBlocksSection extends StatelessWidget {
  const _AutoCollapseCodeBlocksSection();
  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _ToggleRowAutoCollapseCodeBlocks(),
        if (sp.autoCollapseCodeBlock) ...[
          const _RowDivider(),
          const _AutoCollapseCodeBlockLinesRow(),
        ],
      ],
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
    final sp = context.watch<SettingsProvider>();
    final enabled = sp.autoScrollEnabled;
    return _LabeledRow(
      label: l10n.displaySettingsPageAutoScrollIdleTitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IntrinsicWidth(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 36, maxWidth: 72),
              child: IgnorePointer(
                ignoring: !enabled,
                child: Opacity(
                  opacity: enabled ? 1.0 : 0.5,
                  child: _BorderInput(
                    controller: _controller,
                    onSubmitted: _commit,
                    onFocusLost: _commit,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            's',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withOpacity(enabled ? 0.7 : 0.35),
              fontSize: 14,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoCollapseCodeBlockLinesRow extends StatefulWidget {
  const _AutoCollapseCodeBlockLinesRow();
  @override
  State<_AutoCollapseCodeBlockLinesRow> createState() =>
      _AutoCollapseCodeBlockLinesRowState();
}

class _AutoCollapseCodeBlockLinesRowState
    extends State<_AutoCollapseCodeBlockLinesRow> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    final v = context.read<SettingsProvider>().autoCollapseCodeBlockLines;
    _controller = TextEditingController(text: '${v.round()}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit(String text) {
    final v = text.trim();
    final n = int.tryParse(v);
    if (n == null) return;
    final clamped = n.clamp(1, 999);
    context.read<SettingsProvider>().setAutoCollapseCodeBlockLines(clamped);
    _controller.text = '$clamped';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _LabeledRow(
      label: l10n.displaySettingsPageAutoCollapseCodeBlockLinesTitle,
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
          Text(
            l10n.displaySettingsPageAutoCollapseCodeBlockLinesUnit,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontSize: 14,
              decoration: TextDecoration.none,
            ),
          ),
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
              child: _BorderInput(
                controller: _controller,
                onSubmitted: _commit,
                onFocusLost: _commit,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '%',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontSize: 14,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Send shortcut ---
class _SendShortcutRow extends StatelessWidget {
  const _SendShortcutRow();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _LabeledRow(
      label: l10n.displaySettingsPageSendShortcutTitle,
      trailing: const _SendShortcutDropdown(),
    );
  }
}

class _SendShortcutDropdown extends StatefulWidget {
  const _SendShortcutDropdown();
  @override
  State<_SendShortcutDropdown> createState() => _SendShortcutDropdownState();
}

class _SendShortcutDropdownState extends State<_SendShortcutDropdown> {
  bool _hover = false;
  bool _open = false;
  final LayerLink _link = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _entry;

  void _toggle() {
    if (_open) {
      _close();
    } else {
      _openMenu();
    }
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() => _open = false);
  }

  String _labelFor(BuildContext context, DesktopSendShortcut s) {
    final l10n = AppLocalizations.of(context)!;
    switch (s) {
      case DesktopSendShortcut.ctrlEnter:
        final modifier = Platform.isMacOS ? '⌘' : 'Ctrl';
        return '$modifier + Enter';
      case DesktopSendShortcut.enter:
      default:
        return l10n.displaySettingsPageSendShortcutEnter;
    }
  }

  void _openMenu() {
    if (_entry != null) return;
    final rb = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final triggerSize = rb.size;
    final triggerWidth = triggerSize.width;

    _entry = OverlayEntry(
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final usePure = Provider.of<SettingsProvider>(
          ctx,
          listen: false,
        ).usePureBackground;
        final bgColor = usePure
            ? (isDark ? Colors.black : Colors.white)
            : (isDark ? const Color(0xFF1C1C1E) : Colors.white);
        final sp = Provider.of<SettingsProvider>(ctx, listen: false);

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _close,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: Offset(0, triggerSize.height + 6),
              child: _SendShortcutOverlay(
                width: triggerWidth,
                backgroundColor: bgColor,
                selected: sp.desktopSendShortcut,
                onSelected: (shortcut) async {
                  await sp.setDesktopSendShortcut(shortcut);
                  _close();
                },
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context)?.insert(_entry!);
    setState(() => _open = true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sp = context.watch<SettingsProvider>();
    final label = _labelFor(context, sp.desktopSendShortcut);

    final baseBorder = cs.outlineVariant.withOpacity(0.18);
    final hoverBorder = cs.primary;
    final borderColor = _open || _hover ? hoverBorder : baseBorder;

    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: _toggle,
          child: AnimatedContainer(
            key: _triggerKey,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            constraints: const BoxConstraints(minWidth: 130, minHeight: 34),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: _open
                  ? [
                      BoxShadow(
                        color: cs.primary.withOpacity(0.10),
                        blurRadius: 0,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withOpacity(0.88),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    lucide.Lucide.ChevronDown,
                    size: 14,
                    color: cs.onSurface.withOpacity(0.5),
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

class _SendShortcutOverlay extends StatefulWidget {
  const _SendShortcutOverlay({
    required this.width,
    required this.backgroundColor,
    required this.selected,
    required this.onSelected,
  });
  final double width;
  final Color backgroundColor;
  final DesktopSendShortcut selected;
  final ValueChanged<DesktopSendShortcut> onSelected;
  @override
  State<_SendShortcutOverlay> createState() => _SendShortcutOverlayState();
}

class _SendShortcutOverlayState extends State<_SendShortcutOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = cs.outlineVariant.withOpacity(0.12);

    // Platform-specific modifier key
    final modifier = Platform.isMacOS ? '⌘' : 'Ctrl';
    final items = <(DesktopSendShortcut, String)>[
      (
        DesktopSendShortcut.enter,
        AppLocalizations.of(context)!.displaySettingsPageSendShortcutEnter,
      ),
      (DesktopSendShortcut.ctrlEnter, '$modifier + Enter'),
    ];

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: widget.width,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.32 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final it in items)
                  _SimpleOptionTile(
                    label: it.$2,
                    selected: widget.selected == it.$1,
                    onTap: () => widget.onSelected(it.$1),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
