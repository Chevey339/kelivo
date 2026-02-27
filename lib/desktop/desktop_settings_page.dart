import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

part 'setting/coming_soon_pane.dart';
part 'setting/assistants_pane.dart';
part 'setting/providers_pane.dart';
part 'setting/display_pane.dart';

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

