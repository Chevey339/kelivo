import '../features/side_panel/desktop_side_panel_controller.dart';
import 'package:flutter/material.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'desktop_nav_rail.dart';
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
    this.initialTabIndex,
    this.initialProviderKey,
  });

  final int? initialTabIndex; // 0=Chat,1=Translate,2=Storage,3=Settings
  final String? initialProviderKey;

  @override
  State<DesktopHomePage> createState() => _DesktopHomePageState();
}

class _DesktopHomePageState extends State<DesktopHomePage> {
  int _tabIndex = 0; // 0=Chat, 1=Translate, 2=Storage, 3=Settings
  bool _storageVisited = false;
  bool _navigationOpen = false;
  bool _globalSearchActive = false;
  StreamSubscription<HotkeyAction>? _hotkeySub;
  StreamSubscription<ChatAction>? _chatActionSub;
  StreamSubscription<DesktopSettingsNavigationTarget>? _settingsNavSub;
  StreamSubscription<String>? _conversationOpenSub;

  @override
  void initState() {
    super.initState();
    if (widget.initialTabIndex != null) {
      _tabIndex = widget.initialTabIndex!.clamp(0, 3);
    }
    _storageVisited = _tabIndex == 2;
    _conversationOpenSub = NotificationService.conversationTaps.listen((_) {
      if (!mounted) return;
      setState(() {
        _tabIndex = 0;
        _globalSearchActive = false;
      });
      ChatActionBus.instance.fire(ChatAction.exitGlobalSearch);
    });
    // 初始进入时如果就是聊天页，则聚焦聊天输入框
    if (_tabIndex == 0) {
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
          if (mounted && _tabIndex != 0) {
            setState(() {
              _tabIndex = 0;
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
            setState(() {
              _tabIndex = 3;
              _globalSearchActive = false;
            });
            ChatActionBus.instance.fire(ChatAction.exitGlobalSearch);
          }
          break;
        case HotkeyAction.closeWindow:
          final panel = DesktopSidePanelController.instance;
          if (_tabIndex == 0 &&
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
              if (_tabIndex == 0) {
                ChatActionBus.instance.fire(ChatAction.focusInput);
              }
            } else if (!focused) {
              await windowManager.focus();
              // 如果当前是聊天页，聚焦窗口时也聚焦输入框
              if (_tabIndex == 0) {
                ChatActionBus.instance.fire(ChatAction.focusInput);
              }
            } else {
              await windowManager.hide();
            }
          } catch (_) {}
          break;
        case HotkeyAction.newTopic:
          if (_tabIndex == 0) {
            ChatActionBus.instance.fire(ChatAction.newTopic);
          }
          break;
        case HotkeyAction.switchModel:
          if (_tabIndex == 0) {
            ChatActionBus.instance.fire(ChatAction.switchModel);
          }
          break;
        case HotkeyAction.toggleLeftPanelAssistants:
          if (_tabIndex == 0) {
            ChatActionBus.instance.fire(ChatAction.toggleLeftPanelAssistants);
          }
          break;
        case HotkeyAction.toggleLeftPanelTopics:
          if (_tabIndex == 0) {
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
            _tabIndex = 0;
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
    _settingsNavSub = DesktopSettingsNavigationBus.instance.stream.listen((
      target,
    ) {
      if (!mounted) return;
      switch (target) {
        case DesktopSettingsNavigationTarget.topicPosition:
        case DesktopSettingsNavigationTarget.backup:
        case DesktopSettingsNavigationTarget.mcp:
          setState(() {
            _tabIndex = 3;
            _globalSearchActive = false;
          });
          ChatActionBus.instance.fire(ChatAction.exitGlobalSearch);
          break;
      }
    });
  }

  void _selectTab(int index, {bool search = false}) {
    setState(() {
      _tabIndex = index;
      _globalSearchActive = search;
      _navigationOpen = false;
      if (index == 2) _storageVisited = true;
    });
    ChatActionBus.instance.fire(
      search ? ChatAction.enterGlobalSearch : ChatAction.exitGlobalSearch,
    );
    if (index == 0 && !search) {
      ChatActionBus.instance.fire(ChatAction.focusInput);
    }
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
                            index: _tabIndex,
                            children: [
                              const DesktopChatPage(),
                              const DesktopTranslatePage(
                                key: ValueKey('translate_page'),
                              ),
                              _storageVisited
                                  ? const StorageSpacePage(
                                      key: ValueKey('storage_space_page'),
                                      embedded: true,
                                    )
                                  : const SizedBox.shrink(),
                              DesktopSettingsPage(
                                key: const ValueKey('settings_page'),
                                initialProviderKey: widget.initialProviderKey,
                              ),
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
                      onDismiss: () => setState(() => _navigationOpen = false),
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
                        activeIndex: _tabIndex,
                        globalSearchActive: _globalSearchActive,
                        onTapChat: () => _selectTab(0),
                        onTapGlobalSearch: () => _selectTab(0, search: true),
                        onTapTranslate: () => _selectTab(1),
                        onTapStorage: () => _selectTab(2),
                        onTapSettings: () => _selectTab(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_conversationOpenSub?.cancel());
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
