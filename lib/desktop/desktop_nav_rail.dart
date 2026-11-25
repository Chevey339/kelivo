import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../shared/widgets/emoji_text.dart';
import '../l10n/app_localizations.dart';
import '../core/providers/user_provider.dart';
import '../core/providers/settings_provider.dart';
import 'user_profile_dialog.dart';
import '../icons/lucide_adapter.dart' as lucide;
import '../shared/widgets/avatar_image.dart';
import '../shared/widgets/sliding_segmented_tabs.dart';
import '../theme/app_font_weights.dart';
import 'widgets/desktop_pane_surface.dart';
import '../core/models/sidebar_layout.dart';
import '../shared/widgets/sidebar_entry_labels.dart';
import 'desktop_context_menu.dart';
import 'desktop_sidebar_customization.dart';
import 'desktop_tab.dart';

/// A compact left rail for desktop with avatar, primary actions, and bottom system toggles.
class DesktopNavRail extends StatelessWidget {
  const DesktopNavRail({
    super.key,
    required this.activeTab,
    this.globalSearchActive = false,
    required this.onTapChat,
    required this.onTapEntry,
    required this.onTapSettings,
  });

  final DesktopTab activeTab;
  final bool globalSearchActive;
  final VoidCallback onTapChat;
  final ValueChanged<SidebarEntry> onTapEntry;
  final VoidCallback onTapSettings;

  static const double width = 64.0;

  bool _isActive(SidebarEntry entry) => switch (entry) {
    SidebarEntry.search => globalSearchActive,
    SidebarEntry.media => activeTab == DesktopTab.media,
    SidebarEntry.translate => activeTab == DesktopTab.translate,
    SidebarEntry.storage => activeTab == DesktopTab.storage,
    SidebarEntry.history => false,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final entries = settings.desktopRailEntries;
    final shown = sidebarEntriesWithVisibility(
      entries,
      SidebarVisibility.show,
    ).where((entry) => entry != SidebarEntry.history);
    final more = sidebarEntriesWithVisibility(entries, SidebarVisibility.more);

    final rail = Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            primary: false,
            child: Column(
              children: [
                SizedBox(height: Platform.isMacOS ? 36 : 8),
                _UserAvatarButton(),
                const SizedBox(height: 12),
                _CircleAction(
                  tooltip: l10n.desktopNavChatTooltip,
                  icon: lucide.Lucide.MessageCircle,
                  onTap: onTapChat,
                  onSecondaryTapDown: (details) => showDesktopSidebarEntryMenu(
                    context,
                    details.globalPosition,
                  ),
                  iconColor: activeTab == DesktopTab.chat && !globalSearchActive
                      ? cs.primary
                      : null,
                ),
                for (final entry in shown) ...[
                  const SizedBox(height: 8),
                  _CircleAction(
                    key: ValueKey(entry),
                    tooltip: entry.label(l10n),
                    icon: entry.icon,
                    unread:
                        entry == SidebarEntry.media && !settings.mediaEntrySeen,
                    onTap: () => onTapEntry(entry),
                    onSecondaryTapDown: (details) =>
                        showDesktopSidebarEntryMenu(
                          context,
                          details.globalPosition,
                          entry: entry,
                        ),
                    iconColor: _isActive(entry) ? cs.primary : null,
                  ),
                ],
                if (more.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Builder(
                    builder: (buttonContext) => _CircleAction(
                      tooltip: l10n.sidebarMore,
                      icon: lucide.Lucide.Ellipsis,
                      iconColor: more.any(_isActive) ? cs.primary : null,
                      onTap: () {
                        final box =
                            buttonContext.findRenderObject()! as RenderBox;
                        showDesktopContextMenuAt(
                          context,
                          globalPosition: box.localToGlobal(
                            Offset(box.size.width, 0),
                          ),
                          items: [
                            for (final entry in more)
                              DesktopContextMenuItem(
                                icon: entry.icon,
                                label: entry.label(l10n),
                                checked: _isActive(entry),
                                onTap: () => onTapEntry(entry),
                              ),
                            DesktopContextMenuItem(
                              icon: lucide.Lucide.panelLeft,
                              label: l10n.sidebarCustomize,
                              startsGroup: true,
                              onTap: () {
                                if (context.mounted) {
                                  const DesktopCustomizeSidebarNotification()
                                      .dispatch(context);
                                }
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        _ThemeCycleButton(),
        const SizedBox(height: 8),
        _CircleAction(
          tooltip: l10n.desktopNavSettingsTooltip,
          icon: lucide.Lucide.Settings,
          onTap: onTapSettings,
          iconColor: activeTab == DesktopTab.settings ? cs.primary : null,
        ),
        const SizedBox(height: 12),
      ],
    );
    return SizedBox(
      width: width,
      child: activeTab == DesktopTab.media
          ? ColoredBox(color: cs.surface, child: rail)
          : DesktopPaneSurface(child: rail),
    );
  }
}

class _UserAvatarButton extends StatefulWidget {
  @override
  State<_UserAvatarButton> createState() => _UserAvatarButtonState();
}

class _UserAvatarButtonState extends State<_UserAvatarButton> {
  @override
  Widget build(BuildContext context) {
    final up = context.watch<UserProvider>();
    final cs = Theme.of(context).colorScheme;
    Widget avatar;
    final type = up.avatarType;
    final value = up.avatarValue;
    if (type == 'emoji' && value != null && value.isNotEmpty) {
      avatar = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: EmojiText(value, fontSize: 18, optimizeEmojiAlign: true),
      );
    } else if ((type == 'file' || type == 'url') &&
        value != null &&
        value.isNotEmpty) {
      avatar = AvatarImage(
        source: value,
        isNetwork: type == 'url',
        size: 36,
        fallback: _initialAvatar(up.name, cs),
      );
    } else {
      avatar = _initialAvatar(up.name, cs);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onTap: () {
          // Open centered profile dialog
          showUserProfileDialog(context);
        },
        onSecondaryTap: () {
          // Also open dialog on right-click for consistency
          showUserProfileDialog(context);
        },
        child: _HoverCircle(size: 42, child: avatar),
      ),
    );
  }

  Widget _initialAvatar(String name, ColorScheme cs) {
    final letter = name.isNotEmpty ? name.characters.first : '?';
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: cs.primary,
          fontWeight: AppFontWeights.emphasis,
          decoration: TextDecoration.none,
          fontSize: 36 * 0.44, // keep initial scaled to avatar size
        ),
      ),
    );
  }

  // Context menu moved into the centered dialog (avatar tap opens menu there).
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.onSecondaryTapDown,
    this.unread = false,
    this.iconColor,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color? iconColor;
  final bool unread;
  final GestureTapDownCallback? onSecondaryTapDown;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: iconColor != null,
      child: Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 300),
        child: _HoverCircle(
          size: 40,
          selected: iconColor != null,
          onActivate: onTap,
          onSecondaryTapDown: onSecondaryTapDown,
          child: SidebarEntryGlyph(
            icon: icon,
            size: 18,
            color: iconColor ?? cs.onSurface.withValues(alpha: .8),
            unread: unread,
          ),
        ),
      ),
    );
  }
}

class _HoverCircle extends StatefulWidget {
  const _HoverCircle({
    required this.child,
    this.size = 44,
    this.selected = false,
    this.onActivate,
    this.onSecondaryTapDown,
  });
  final bool selected;
  final VoidCallback? onActivate;
  final GestureTapDownCallback? onSecondaryTapDown;
  final Widget child;
  final double size;
  @override
  State<_HoverCircle> createState() => _HoverCircleState();
}

class _HoverCircleState extends State<_HoverCircle> {
  bool _hovered = false;
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final body = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: handoffDuration(context, 140),
        curve: handoffCurve,
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.selected
              ? cs.primary.withValues(
                  alpha: cs.brightness == Brightness.dark ? .16 : .12,
                )
              : _hovered || _focused
              ? cs.primary.withValues(alpha: 0.10)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: widget.child,
      ),
    );
    final activate = widget.onActivate;
    if (activate == null) return body;
    return FocusableActionDetector(
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            activate();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: activate,
        onSecondaryTapDown: widget.onSecondaryTapDown,
        child: body,
      ),
    );
  }
}

class _ThemeCycleButton extends StatefulWidget {
  @override
  State<_ThemeCycleButton> createState() => _ThemeCycleButtonState();
}

class _ThemeCycleButtonState extends State<_ThemeCycleButton> {
  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    final icon = _iconFor(sp.themeMode);
    final l10n = AppLocalizations.of(context)!;
    return Tooltip(
      message: l10n.desktopNavThemeToggleTooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: () => _cycleTheme(context),
        child: _HoverCircle(
          size: 40,
          child: Icon(
            icon,
            size: 20,
            color: cs.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return lucide.Lucide.Sun;
      case ThemeMode.dark:
        return lucide.Lucide.Moon;
      case ThemeMode.system:
        return lucide.Lucide.Monitor;
    }
  }

  void _cycleTheme(BuildContext context) {
    final sp = context.read<SettingsProvider>();
    final current = sp.themeMode;
    final next = () {
      switch (current) {
        case ThemeMode.system:
          return ThemeMode.light;
        case ThemeMode.light:
          return ThemeMode.dark;
        case ThemeMode.dark:
          return ThemeMode.system;
      }
    }();
    sp.setThemeMode(next);
  }
}
