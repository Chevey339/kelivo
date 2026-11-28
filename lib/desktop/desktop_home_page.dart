import '../features/side_panel/desktop_side_panel_controller.dart';
import 'package:flutter/material.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'desktop_nav_rail.dart';
import 'desktop_media_creation_page.dart';
import '../core/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import 'desktop_tab.dart';
import 'desktop_sidebar_customization.dart';
import '../core/models/sidebar_layout.dart';
import 'desktop_chat_page.dart';
import 'window_title_bar.dart';
import '../shared/responsive/screen_type_helper.dart';
import '../shared/widgets/ios_tactile.dart';
import '../icons/lucide_adapter.dart';
import 'desktop_settings_page.dart';
import 'desktop_translate_page.dart';
import '../features/settings/pages/storage_space_page.dart';
import '../l10n/app_localizations.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:async';
import 'hotkeys/hotkey_event_bus.dart';
import 'hotkeys/chat_action_bus.dart';
import 'desktop_settings_navigation_bus.dart';
import '../core/services/notification_service.dart';
import '../features/chat/widgets/chat_assistant_background.dart';
import '../features/chat/widgets/frosted/chat_frosted_backdrop.dart';
import '../theme/surface_ladder.dart';

/// Desktop home screen: left compact rail + main content.
/// Phase 1 focuses on structure and platform-appropriate interactions/hover.
class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({
    super.key,
    this.initialTab = DesktopTab.chat,
    this.initialProviderKey,
  });

  final DesktopTab initialTab;
  final String? initialProviderKey;

  @override
  State<DesktopHomePage> createState() => _DesktopHomePageState();
}

class _DesktopHomePageState extends State<DesktopHomePage> {
  late DesktopTab _activeTab;
  final _visitedTabs = <DesktopTab>{};
  bool _customizeSidebarOpen = false;
  bool _navigationOpen = false;
  bool _globalSearchActive = false;
  StreamSubscription<HotkeyAction>? _hotkeySub;
  StreamSubscription<ChatAction>? _chatActionSub;
  StreamSubscription<ChatNavigationAction>? _navigationSub;
  OpenCreationArtwork? _artworkRequest;
  StreamSubscription<DesktopSettingsNavigationTarget>? _settingsNavSub;
  StreamSubscription<String>? _conversationOpenSub;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _visitedTabs.add(_activeTab);
    _conversationOpenSub = NotificationService.conversationTaps.listen((_) {
      if (!mounted) return;
      setState(() {
        _activeTab = DesktopTab.chat;
        _globalSearchActive = false;
      });
      ChatActionBus.instance.fire(ChatAction.exitGlobalSearch);
    });
    // 初始进入时如果就是聊天页，则聚焦聊天输入框
    if (_activeTab == DesktopTab.chat) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ChatActionBus.instance.fire(ChatAction.focusInput);
      });
    }
    // Listen to global hotkey actions affecting the main tabs/window
    _hotkeySub = HotkeyEventBus.instance.stream.listen((action) async {
      switch (action) {
        case HotkeyAction.toggleSidePanel:
        case HotkeyAction.sidePanelNewWeb:
        case HotkeyAction.sidePanelFiles:
          if (mounted && _activeTab != DesktopTab.chat) {
            setState(() {
              _activeTab = DesktopTab.chat;
              _globalSearchActive = false;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) HotkeyEventBus.instance.fire(action);
            });
          }
          break;
        case HotkeyAction.sidePanelExpand:
        case HotkeyAction.sidePanelReopenTab:
        case HotkeyAction.sidePanelNextTab:
        case HotkeyAction.sidePanelPreviousTab:
        case HotkeyAction.sidePanelAddress:
        case HotkeyAction.sidePanelFocus:
          break;
        case HotkeyAction.openSettings:
          if (mounted) {
            _selectTab(DesktopTab.settings, dismissNavigation: false);
          }
          break;
        case HotkeyAction.closeWindow:
          final panel = DesktopSidePanelController.instance;
          if (_activeTab == DesktopTab.chat &&
              mounted &&
              ModalRoute.of(context)?.isCurrent != false &&
              panel.handleCloseWindow()) {
            break;
          }
          try {
            await windowManager.close();
          } catch (_) {}
          break;
        case HotkeyAction.toggleAppVisibility:
          try {
            final visible = await windowManager.isVisible();
            final minimized = await windowManager.isMinimized();
            final focused = await windowManager.isFocused();

            // 优先级：
            // 1. 如果窗口不可见或最小化，则显示并聚焦
            // 2. 如果窗口可见但未聚焦，则聚焦
            // 3. 如果窗口可见且已聚焦，则隐藏
            if (!visible || minimized) {
              await windowManager.show();
              await windowManager.focus();
              // 如果当前是聊天页，显示窗口时聚焦输入框
              if (_activeTab == DesktopTab.chat) {
                ChatActionBus.instance.fire(ChatAction.focusInput);
              }
            } else if (!focused) {
              await windowManager.focus();
              // 如果当前是聊天页，聚焦窗口时也聚焦输入框
              if (_activeTab == DesktopTab.chat) {
                ChatActionBus.instance.fire(ChatAction.focusInput);
              }
            } else {
              await windowManager.hide();
            }
          } catch (_) {}
          break;
        case HotkeyAction.newTopic:
          if (_activeTab == DesktopTab.chat) {
            ChatActionBus.instance.fire(ChatAction.newTopic);
          }
          break;
        case HotkeyAction.switchModel:
          if (_activeTab == DesktopTab.chat) {
            ChatActionBus.instance.fire(ChatAction.switchModel);
          }
          break;
        case HotkeyAction.toggleLeftPanelAssistants:
          if (_activeTab == DesktopTab.chat) {
            ChatActionBus.instance.fire(ChatAction.toggleLeftPanelAssistants);
          }
          break;
        case HotkeyAction.toggleLeftPanelTopics:
          if (_activeTab == DesktopTab.chat) {
            ChatActionBus.instance.fire(ChatAction.toggleLeftPanelTopics);
          }
          break;
      }
    });

    _chatActionSub = ChatActionBus.instance.stream.listen((action) {
      if (!mounted) return;
      switch (action) {
        case ChatAction.enterGlobalSearch:
          setState(() {
            _activeTab = DesktopTab.chat;
            _globalSearchActive = true;
          });
          break;
        case ChatAction.exitGlobalSearch:
          setState(() {
            _globalSearchActive = false;
          });
          break;
        default:
          break;
      }
    });
    _settingsNavSub = DesktopSettingsNavigationBus.instance.stream.listen((_) {
      if (mounted) _selectTab(DesktopTab.settings, dismissNavigation: false);
    });
    _navigationSub = ChatActionBus.instance.navigationStream.listen((action) {
      if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
      switch (action) {
        case OpenCreationArtwork():
          _artworkRequest = action;
          _selectTab(DesktopTab.media);
        case PrefillChatImage() || OpenConversationMessage():
          _selectTab(DesktopTab.chat);
      }
    });
  }

  void _selectTab(
    DesktopTab tab, {
    bool search = false,
    bool dismissNavigation = true,
  }) {
    setState(() {
      _activeTab = tab;
      _globalSearchActive = search;
      if (dismissNavigation) _navigationOpen = false;
      _visitedTabs.add(tab);
    });
    ChatActionBus.instance.fire(
      search ? ChatAction.enterGlobalSearch : ChatAction.exitGlobalSearch,
    );
    if (tab == DesktopTab.chat && !search) {
      ChatActionBus.instance.fire(ChatAction.focusInput);
    }
  }

  void _selectSidebarEntry(SidebarEntry entry) {
    switch (entry) {
      case SidebarEntry.search:
        _selectTab(DesktopTab.chat, search: true);
      case SidebarEntry.media:
        unawaited(context.read<SettingsProvider>().markMediaEntrySeen());
        _selectTab(DesktopTab.media);
      case SidebarEntry.translate:
        _selectTab(DesktopTab.translate);
      case SidebarEntry.storage:
        _selectTab(DesktopTab.storage);
      case SidebarEntry.history:
        _selectTab(DesktopTab.chat);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ChatActionBus.instance.fire(ChatAction.openHistory);
        });
    }
  }

  Widget _buildTab(DesktopTab tab) {
    if (tab != DesktopTab.chat && !_visitedTabs.contains(tab)) {
      return const SizedBox.shrink();
    }
    return switch (tab) {
      DesktopTab.chat => TickerMode(
        enabled: _activeTab == tab,
        child: const DesktopChatPage(),
      ),
      DesktopTab.media => TickerMode(
        enabled: _activeTab == tab,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              if (defaultTargetPlatform == TargetPlatform.macOS &&
                  !ResponsiveHelper.isMobile(context))
                const SizedBox(
                  height: 38,
                  child: DragToMoveArea(child: SizedBox.expand()),
                ),
              Expanded(
                child: DesktopMediaCreationPage(
                  artworkRequest: _artworkRequest,
                  onArtworkOpened: () => setState(() => _artworkRequest = null),
                ),
              ),
            ],
          ),
        ),
      ),
      DesktopTab.translate => const DesktopTranslatePage(
        key: ValueKey('translate_page'),
      ),
      DesktopTab.storage => StorageSpacePage(
        key: const ValueKey('storage_space_page'),
        embedded: true,
        active: _activeTab == tab,
      ),
      DesktopTab.settings => DesktopSettingsPage(
        key: const ValueKey('settings_page'),
        initialProviderKey: widget.initialProviderKey,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final compact = ResponsiveHelper.isMobile(context);
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    final isMac = defaultTargetPlatform == TargetPlatform.macOS;
    final menu = IosIconButton(
      key: const ValueKey('desktop-navigation-menu'),
      icon: Lucide.Menu,
      minSize: 40,
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      onTap: () => setState(() => _navigationOpen = !_navigationOpen),
    );
    return ChatFrostedBackdrop(
      backdrop: ColoredBox(
        color: SurfaceLadder.fromScheme(
          Theme.of(context).colorScheme,
        ).surfaceFill,
        child: const ChatAssistantBackground(desktop: true),
      ),
      child: NotificationListener<DesktopCustomizeSidebarNotification>(
        onNotification: (_) {
          setState(() {
            _customizeSidebarOpen = true;
            _navigationOpen = false;
          });
          return true;
        },
        child: Column(
          children: [
            if (isWindows)
              WindowTitleBar(
                leftChildren: [if (compact) menu, const _TitleBarLeading()],
              )
            else
              SizedBox(
                height: compact ? 40 : 0,
                child: Offstage(
                  offstage: !compact,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: DragToMoveArea(child: SizedBox.expand()),
                      ),
                      Row(
                        children: [
                          if (isMac) const SizedBox(width: 72),
                          menu,
                          const _TitleBarLeading(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    key: const ValueKey('desktop-pages'),
                    child: Row(
                      children: [
                        SizedBox(width: compact ? 0 : DesktopNavRail.width),
                        Expanded(
                          // Keep the same subtree across resizing and tab changes.
                          child: ClipRect(
                            key: const ValueKey('desktopWorkspaceFrame'),
                            child: IndexedStack(
                              index: _activeTab.index,
                              children: [
                                for (final tab in DesktopTab.values)
                                  _buildTab(tab),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (compact && _navigationOpen)
                    Positioned.fill(
                      child: ModalBarrier(
                        color: Theme.of(
                          context,
                        ).colorScheme.scrim.withValues(alpha: .16),
                        onDismiss: () =>
                            setState(() => _navigationOpen = false),
                      ),
                    ),
                  Positioned(
                    key: const ValueKey('desktop-navigation'),
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: DesktopNavRail.width,
                    child: ExcludeFocus(
                      excluding: compact && !_navigationOpen,
                      child: Offstage(
                        offstage: compact && !_navigationOpen,
                        child: DesktopNavRail(
                          activeTab: _activeTab,
                          globalSearchActive: _globalSearchActive,
                          onTapChat: () => _selectTab(DesktopTab.chat),
                          onTapEntry: _selectSidebarEntry,
                          onTapSettings: () => _selectTab(DesktopTab.settings),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DesktopSidebarCustomization(
                      open: _customizeSidebarOpen,
                      onClose: () =>
                          setState(() => _customizeSidebarOpen = false),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_conversationOpenSub?.cancel());
    unawaited(_navigationSub?.cancel());
    try {
      _hotkeySub?.cancel();
    } catch (_) {}
    try {
      _chatActionSub?.cancel();
    } catch (_) {}
    try {
      _settingsNavSub?.cancel();
    } catch (_) {}
    super.dispose();
  }
}

// No extra router/shim; we import DesktopSettingsPage directly above.

class _TitleBarLeading extends StatelessWidget {
  const _TitleBarLeading();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // App icon
        Image.asset(
          'assets/icons/kelivo.png',
          width: 16,
          height: 16,
          filterQuality: FilterQuality.medium,
        ),
        const SizedBox(width: 8),
        // App name
        Text(
          l10n.aboutPageAppName,
          style: TextStyle(
            fontSize: 13,
            fontWeight: AppFontWeights.semibold,
            color: cs.onSurface.withValues(alpha: 0.8),
            // Avoid accidental underline when not under a Material ancestor in edge cases
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
