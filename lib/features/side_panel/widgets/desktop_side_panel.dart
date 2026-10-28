import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/chat/chat_service.dart';
import '../../../core/providers/hotkey_provider.dart';
import '../../../desktop/desktop_settings_navigation_bus.dart';
import '../../../desktop/hotkeys/chat_action_bus.dart';
import '../../../desktop/hotkeys/hotkey_event_bus.dart';
import '../../../desktop/sidebar_resize_handle.dart';
import '../../../desktop/widgets/desktop_pane_surface.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/design_tokens.dart';
import '../../../utils/app_directories.dart';
import '../../browser/browser_panel_controller.dart';
import '../../browser/widgets/browser_window_chrome.dart';
import '../../workspace/widgets/desktop_workspace_bar.dart';
import '../desktop_side_panel_controller.dart';
import 'side_panel_browser.dart';
import 'side_panel_file_preview.dart';
import 'side_panel_menu.dart';
import 'side_panel_tab_bar.dart';

class DesktopSidePanel extends StatefulWidget {
  const DesktopSidePanel({
    super.key,
    required this.child,
    required this.conversationId,
    required this.topicsOnRight,
    required this.topicsBuilder,
    this.controller,
    this.filesBuilder,
    this.webBuilder,
    this.previewBuilder,
    this.onFocusChat,
  });
  final Widget child;
  final String? conversationId;
  final bool topicsOnRight;
  final Widget Function(BuildContext, double) topicsBuilder;
  final DesktopSidePanelController? controller;
  final WidgetBuilder? filesBuilder, webBuilder;
  final Widget Function(BuildContext, PreviewTab)? previewBuilder;
  final VoidCallback? onFocusChat;
  @override
  State<DesktopSidePanel> createState() => _DesktopSidePanelState();
}

class _DesktopSidePanelState extends State<DesktopSidePanel> {
  late final _controller =
      widget.controller ?? DesktopSidePanelController.instance;
  late final _browserPanel = widget.controller == null
      ? BrowserPanelController.instance
      : BrowserPanelController(panel: _controller);
  final _scope = FocusScopeNode(debugLabel: 'Desktop side panel');
  final _tabsFocus = FocusNode(debugLabel: 'Panel tabs');
  final _contentFocus = FocusNode(debugLabel: 'Panel content');
  final _panelKey = GlobalKey();
  final _tabBarKey = GlobalKey<SidePanelTabBarState>();
  final _browserKey = GlobalKey<SidePanelBrowserState>();
  StreamSubscription<HotkeyAction>? _hotkeys;
  String? _browserError;
  double _available = 0;
  double? _dragWidth;
  Widget? _webBody;
  bool _webMounted = false, _visible = true, _wasOpen = false;
  SidePanelPresentation _presentation = SidePanelPresentation.hidden;

  @override
  void initState() {
    super.initState();
    _controller.setContext(
      conversationId: widget.conversationId,
      topicsOnRight: widget.topicsOnRight,
    );
    _controller.attachFocusScope(_scope);
    _controller.addListener(_changed);
    _scope.addListener(_focusChanged);
    _browserPanel.attachHost();
    _hotkeys = HotkeyEventBus.instance.stream.listen(_hotkey);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_pointer);
    unawaited(_initializeBrowser());
  }

  Future<void> _initializeBrowser() async {
    try {
      await _controller.browser.initialize();
    } catch (error) {
      if (mounted) setState(() => _browserError = error.toString());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled && Visibility.of(context);
    _controller.hostVisible = _visible;
    _controller.hostIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (!_visible && _scope.hasFocus) _scope.unfocus();
  }

  @override
  void didUpdateWidget(DesktopSidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.setContext(
      conversationId: widget.conversationId,
      topicsOnRight: widget.topicsOnRight,
    );
  }

  void _changed() {
    if (!mounted) return;
    if (_controller.browser.isInitialized) _browserError = null;
    if (!_controller.isOpen && _wasOpen && _scope.hasFocus) _focusChat();
    if (_controller.isOpen &&
        !_wasOpen &&
        _controller.presentationFor(_available) ==
            SidePanelPresentation.overlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.isOpen) {
          _tabBarKey.currentState?.focusActiveTab();
        }
      });
    }
    _wasOpen = _controller.isOpen;
    setState(() {});
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  void _pointer(PointerEvent event) {
    if (!_visible ||
        !_controller.hostIsCurrent ||
        !_controller.isOpen ||
        event is! PointerDownEvent) {
      return;
    }
    final box = _panelKey.currentContext?.findRenderObject();
    Rect? bounds;
    if (box is RenderBox && box.hasSize) {
      final rect = box.localToGlobal(Offset.zero) & box.size;
      bounds = _presentation == SidePanelPresentation.docked
          ? Rect.fromLTRB(rect.left - 4.5, rect.top, rect.right, rect.bottom)
          : rect;
    }
    final inside = bounds?.contains(event.position) ?? false;
    if (inside) {
      if (!_scope.hasFocus) _contentFocus.requestFocus();
    } else if (_scope.hasFocus) {
      _scope.unfocus();
    }
  }

  void _focusChat() {
    _scope.unfocus();
    if (widget.onFocusChat != null) {
      widget.onFocusChat!();
    } else {
      ChatActionBus.instance.fire(ChatAction.focusInput);
    }
  }

  void _close() {
    _controller.close();
    _focusChat();
  }

  void _escape() {
    if (_browserKey.currentState?.escapeAddress() == true) {
      _contentFocus.requestFocus();
      return;
    }
    if (_controller.isExpanded) {
      _controller.setExpanded(false);
      return;
    }
    if (_presentation == SidePanelPresentation.overlay) {
      _close();
      return;
    }
    _focusChat();
  }

  void _cycleFocus() {
    if (!_controller.isOpen) return;
    if (!_scope.hasFocus) {
      _tabBarKey.currentState?.focusActiveTab(showHighlight: true);
    } else if (_tabsFocus.hasFocus) {
      _contentFocus.requestFocus();
    } else {
      _focusChat();
    }
  }

  void _hotkey(HotkeyAction action) {
    if (!_visible || ModalRoute.of(context)?.isCurrent == false) return;
    switch (action) {
      case HotkeyAction.toggleSidePanel:
        _controller.toggle();
      case HotkeyAction.sidePanelNewWeb:
        unawaited(_newWeb());
      case HotkeyAction.sidePanelFiles:
        _controller.open(kind: SidePanelTabKind.files);
      case HotkeyAction.sidePanelExpand:
        if (_controller.hasFocus) {
          _controller.setExpanded(!_controller.isExpanded);
        }
      case HotkeyAction.sidePanelReopenTab:
        if (_controller.hasFocus) unawaited(_run(_controller.reopenClosedTab));
      case HotkeyAction.sidePanelNextTab:
        if (_controller.hasFocus) _controller.cycleTab();
      case HotkeyAction.sidePanelPreviousTab:
        if (_controller.hasFocus) _controller.cycleTab(backwards: true);
      case HotkeyAction.sidePanelAddress:
        if (_controller.hasFocus && _controller.activeTab is WebTab) {
          _browserKey.currentState?.focusAddress();
        }
      case HotkeyAction.sidePanelFocus:
        _cycleFocus();
      default:
        break;
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: error.toString(),
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _newWeb() => _run(() async {
    await _controller.newWebTab();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _browserKey.currentState?.focusAddress();
    });
  });

  Future<void> _openFile() => _run(() async {
    final result = await FilePicker.platform.pickFiles();
    final path = result?.files.firstOrNull?.path;
    if (path != null && mounted) _controller.openPreview(path);
  });

  String _title(String id) {
    final l = AppLocalizations.of(context)!;
    final title = context
        .read<ChatService?>()
        ?.getConversation(id)
        ?.title
        .trim();
    return title == null || title.isEmpty
        ? l.browserTabsUnknownConversation
        : title;
  }

  Offset get _menuPosition {
    final box = _panelKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.localToGlobal(Offset(math.max(0, box.size.width - 328), 40)) ??
        Offset.zero;
  }

  Future<void> _allTabs() => showSidePanelMenu(
    context,
    position: _menuPosition,
    listenable: _controller,
    entries: () {
      final l = AppLocalizations.of(context)!;
      final own = _controller.tabs;
      final background = _controller.browser.tabs
          .where(
            (page) => !own.whereType<WebTab>().any(
              (tab) => tab.browserTabId == page.id,
            ),
          )
          .map(
            (page) =>
                WebTab(browserTabId: page.id, browser: _controller.browser),
          );
      final resources = [
        ...own.whereType<WebTab>(),
        ...background,
        ...own.whereType<PreviewTab>(),
      ];
      return [
        for (final tab in resources)
          SidePanelMenuEntry(
            title: sidePanelTabTitle(tab, l),
            subtitle:
                tab is WebTab && tab.conversationId != widget.conversationId
                ? (tab.conversationId == null
                      ? l.browserTabsUnassigned
                      : l.sidePanelBackgroundIn(_title(tab.conversationId!)))
                : null,
            group: tab is WebTab ? l.sidePanelWebPages : l.sidePanelFiles,
            leading: SidePanelTabIcon(tab: tab),
            selected: tab.id == _controller.activeTab.id,
            onTap: () => tab is WebTab
                ? _controller.openWebTab(tab.browserTabId)
                : _controller.activate(tab.id),
            onClose: () {
              if (own.any((item) => item.id == tab.id)) {
                _controller.closeTab(tab.id);
              } else if (tab is WebTab) {
                unawaited(_controller.browser.closeTab(tab.browserTabId));
              }
            },
          ),
      ];
    },
  );
  Future<void> _addMenu() => showSidePanelMenu(
    context,
    position: _menuPosition,
    entries: () {
      final l = AppLocalizations.of(context)!;
      return [
        SidePanelMenuEntry(
          title: _controller.browser.isSupported
              ? l.browserNewTab
              : l.sidePanelOpenExternalUrl,
          leading: const Icon(LucideIcons.globe, size: 14),
          onTap: _newWeb,
        ),
        SidePanelMenuEntry(
          title: l.sidePanelOpenFile,
          leading: const Icon(LucideIcons.filePlus, size: 14),
          onTap: _openFile,
        ),
        SidePanelMenuEntry(
          title: l.sidePanelRecentFiles,
          leading: const Icon(LucideIcons.history, size: 14),
          onTap: _recentFiles,
        ),
        SidePanelMenuEntry(
          title: l.sidePanelReopenTab,
          leading: const Icon(LucideIcons.rotateCcw, size: 14),
          onTap: () => _run(_controller.reopenClosedTab),
        ),
      ];
    },
  );
  Future<void> _recentFiles() => _run(() async {
    final owner = widget.conversationId;
    if (owner == null) return;
    final root = await AppDirectories.sessionDir(owner);
    final files = <({File file, String source, DateTime modified})>[];
    for (final source in ['outputs', 'attachments']) {
      final dir = Directory(p.join(root.path, source));
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          files.add((
            file: entity,
            source: source,
            modified: (await entity.stat()).modified,
          ));
        }
      }
    }
    files.sort((a, b) => b.modified.compareTo(a.modified));
    if (!mounted || widget.conversationId != owner) return;
    final l = AppLocalizations.of(context)!;
    await showSidePanelMenu(
      context,
      position: _menuPosition,
      entries: () => [
        for (final item in files.take(40))
          SidePanelMenuEntry(
            title: p.basename(item.file.path),
            subtitle: item.file.path,
            leading: const Icon(LucideIcons.fileText, size: 14),
            onTap: () =>
                _controller.openPreview(item.file.path, source: item.source),
          ),
        if (files.isEmpty)
          SidePanelMenuEntry(title: l.workspaceFilesEmptyOutputs),
      ],
    );
  });

  Future<void> _contextMenu(SidePanelTab tab, Offset position) async {
    final l = AppLocalizations.of(context)!;
    await showSidePanelMenu(
      context,
      position: position,
      hint: tab.kind == SidePanelTabKind.topics ? l.sidePanelPinnedHint : null,
      entries: () => [
        if (tab.pinned)
          SidePanelMenuEntry(
            title: l.sidePanelPinned,
            leading: const Icon(LucideIcons.pin, size: 14),
          ),
        if (tab.kind == SidePanelTabKind.topics)
          SidePanelMenuEntry(
            title: l.sidePanelMoveTopicsLeft,
            onTap: DesktopSettingsNavigationBus.instance.openTopicPosition,
          ),
        if (tab.closable) ...[
          SidePanelMenuEntry(
            title: l.browserCloseTab,
            onTap: () => _controller.closeTab(tab.id),
          ),
          SidePanelMenuEntry(
            title: l.sidePanelCloseOthers,
            onTap: () => _controller.closeOthers(tab.id),
          ),
          SidePanelMenuEntry(
            title: l.sidePanelCloseRight,
            onTap: () => _controller.closeRight(tab.id),
          ),
        ],
        if (tab is WebTab) ...[
          SidePanelMenuEntry(
            title: l.browserCopyLink,
            onTap: () =>
                Clipboard.setData(ClipboardData(text: tab.page?.url ?? '')),
          ),
          SidePanelMenuEntry(
            title: l.browserOpenExternal,
            onTap: () => launchUrl(
              Uri.parse(tab.page?.url ?? 'about:blank'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.attachFocusScope(null);
    _browserPanel.detachHost();
    if (widget.controller != null) _browserPanel.dispose();
    _hotkeys?.cancel();
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_pointer);
    _scope.removeListener(_focusChanged);
    _scope.dispose();
    _tabsFocus.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  Widget _body(double width) {
    final active = _controller.activeTab;
    if (active is WebTab) _webMounted = true;
    return Stack(
      fit: StackFit.expand,
      children: [
        Visibility(
          visible: active.kind == SidePanelTabKind.files,
          maintainState: true,
          child:
              widget.filesBuilder?.call(context) ??
              DesktopWorkspaceBar(
                conversationId: widget.conversationId,
                onOpenFile: (path, source) async =>
                    _controller.openPreview(path, source: source),
              ),
        ),
        if (widget.topicsOnRight)
          Visibility(
            visible: active.kind == SidePanelTabKind.topics,
            maintainState: true,
            child: widget.topicsBuilder(context, width),
          ),
        if (_webMounted)
          Visibility(
            visible: active is WebTab,
            maintainState: true,
            child: (_webBody ??=
                widget.webBuilder?.call(context) ??
                SidePanelBrowser(
                  key: _browserKey,
                  controller: _controller,
                  onShowAllTabs: _allTabs,
                )),
          ),
        if (active is PreviewTab)
          widget.previewBuilder?.call(context, active) ??
              SidePanelFilePreview(
                key: ValueKey((active.id, active.path)),
                tab: active,
                controller: _controller,
              ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _available = constraints.maxWidth;
      _presentation = _controller.presentationFor(_available);
      final open = _presentation != SidePanelPresentation.hidden;
      final docked = _presentation == SidePanelPresentation.docked;
      final overlay = _presentation == SidePanelPresentation.overlay;
      final expanded = _presentation == SidePanelPresentation.expanded;
      if (!docked) _dragWidth = null;
      final width =
          _dragWidth?.clamp(
            DesktopSidePanelController.minWidth,
            DesktopSidePanelController.maxWidthFor(_available),
          ) ??
          _controller.widthFor(_available);
      final cs = Theme.of(context).colorScheme;
      final l = AppLocalizations.of(context)!;
      void changeWidth(double delta) {
        if (!docked) return;
        setState(
          () => _dragWidth = ((_dragWidth ?? width) - delta).clamp(
            DesktopSidePanelController.minWidth,
            DesktopSidePanelController.maxWidthFor(_available),
          ),
        );
      }

      void saveWidth() {
        final value = _dragWidth;
        if (docked && value != null) _controller.setPreferredWidth(value);
        if (mounted) setState(() => _dragWidth = null);
      }

      final hotkeys = context.watch<HotkeyProvider?>();
      final mac = Theme.of(context).platform == TargetPlatform.macOS;
      final commands =
          hotkeys?.nativeCommands ??
          {
            '${mac ? 'cmd' : 'ctrl'}+w': 'close_window',
            '${mac ? 'cmd' : 'ctrl'}+l': 'side_panel_address',
            '${mac ? 'cmd' : 'ctrl'}+t': 'side_panel_new_web',
            '${mac ? 'cmd' : 'ctrl'}+shift+t': 'side_panel_reopen_tab',
            'ctrl+tab': 'side_panel_next_tab',
            'ctrl+shift+tab': 'side_panel_previous_tab',
            'f6': 'side_panel_focus',
          };
      return BrowserWindowChrome(
        windowSpacing: false,
        shortcutsEnabled: _visible && _controller.hasFocus,
        shortcutCommands: {
          ...commands.keys,
          '${mac ? 'cmd' : 'ctrl'}+r',
          '${mac ? 'cmd' : 'ctrl'}+f',
          'escape',
        },
        onShortcut: (key) {
          if (key == 'escape') {
            _escape();
            return;
          }
          if (key.endsWith('+f') && !commands.containsKey(key)) {
            _browserKey.currentState?.focusFind();
            return;
          }
          final id = commands[key];
          if (id == 'close_window') {
            _controller.closeTab(_controller.activeTab.id);
            return;
          }
          if (id != null && hotkeys != null) {
            hotkeys.invoke(id);
            return;
          }
          switch (id) {
            case 'side_panel_address':
              _browserKey.currentState?.focusAddress();
            case 'side_panel_new_web':
              unawaited(_newWeb());
            case 'side_panel_reopen_tab':
              unawaited(_run(_controller.reopenClosedTab));
            case 'side_panel_next_tab':
              _controller.cycleTab();
            case 'side_panel_previous_tab':
              _controller.cycleTab(backwards: true);
            case 'side_panel_focus':
              _cycleFocus();
            default:
              if (key.endsWith('+r') && _controller.activeTab is WebTab) {
                _browserKey.currentState?.reload();
              }
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              right: docked ? width : 0,
              child: Visibility(
                visible: !expanded,
                maintainState: true,
                child: widget.child,
              ),
            ),
            if (overlay)
              Positioned.fill(
                child: ModalBarrier(
                  key: const ValueKey('sidePanelScrim'),
                  color: cs.scrim.withValues(
                    alpha: cs.brightness == Brightness.dark ? .40 : .25,
                  ),
                  dismissible: true,
                  onDismiss: _close,
                  semanticsLabel: l.sidePanelToggle,
                ),
              ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: math.min(_available, width),
              child: Visibility(
                visible: open,
                maintainState: true,
                child: TickerMode(
                  enabled: open,
                  child: Semantics(
                    scopesRoute: overlay,
                    explicitChildNodes: true,
                    namesRoute: overlay,
                    label: overlay ? l.sidePanelToggle : null,
                    child: FocusScope(
                      node: _scope,
                      child: Focus(
                        onKeyEvent: (_, event) {
                          if (event is! KeyDownEvent) {
                            return KeyEventResult.ignored;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.escape) {
                            _escape();
                            return KeyEventResult.handled;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.f6 &&
                              context.read<HotkeyProvider?>() == null) {
                            _cycleFocus();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: Container(
                          key: _panelKey,
                          decoration: BoxDecoration(
                            boxShadow: overlay
                                ? [
                                    BoxShadow(
                                      color: cs.shadow.withValues(alpha: .18),
                                      blurRadius: 28,
                                      offset: const Offset(-4, 0),
                                    ),
                                  ]
                                : null,
                          ),
                          child: DesktopPaneSurface(
                            child: Material(
                              type: MaterialType.transparency,
                              child: ClipRect(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Column(
                                      children: [
                                        const SizedBox(height: 40),
                                        if (_browserError != null ||
                                            _controller.persistenceError !=
                                                null)
                                          MaterialBanner(
                                            content: Text(
                                              _browserError ??
                                                  _controller.persistenceError!,
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: _browserError != null
                                                    ? _initializeBrowser
                                                    : _controller
                                                          .retryPersistence,
                                                child: Text(l.browserRetry),
                                              ),
                                            ],
                                          ),
                                        Expanded(
                                          child: Focus(
                                            focusNode: _contentFocus,
                                            child: _body(width),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Paint chrome after the native viewport so
                                    // AppKit also sees its full cursor region.
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      child: Focus(
                                        focusNode: _tabsFocus,
                                        child: SidePanelTabBar(
                                          key: _tabBarKey,
                                          controller: _controller,
                                          onAdd: _addMenu,
                                          onAllTabs: _allTabs,
                                          onContextMenu: _contextMenu,
                                          onClose: _close,
                                          conversationTitle: _title,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (docked)
              Positioned(
                top: 0,
                bottom: 0,
                right: width - 4.5,
                width: 9,
                child: Semantics(
                  slider: true,
                  label: l.sidePanelWidth(width.round()),
                  value: width.round().toString(),
                  increasedValue: (width + 16).round().toString(),
                  decreasedValue: (width - 16).round().toString(),
                  onIncrease: () {
                    changeWidth(-16);
                    saveWidth();
                  },
                  onDecrease: () {
                    changeWidth(16);
                    saveWidth();
                  },
                  child: Focus(
                    parentNode: _scope,
                    onKeyEvent: (_, event) {
                      if (event is! KeyDownEvent ||
                          !{
                            LogicalKeyboardKey.arrowLeft,
                            LogicalKeyboardKey.arrowRight,
                          }.contains(event.logicalKey)) {
                        return KeyEventResult.ignored;
                      }
                      changeWidth(
                        event.logicalKey == LogicalKeyboardKey.arrowLeft
                            ? -16
                            : 16,
                      );
                      saveWidth();
                      return KeyEventResult.handled;
                    },
                    child: GestureDetector(
                      onDoubleTap: () => _controller.setPreferredWidth(520),
                      child: SidebarResizeHandle(
                        key: const ValueKey('sidePanelResizeHandle'),
                        visible: true,
                        hitWidth: 9,
                        onDrag: changeWidth,
                        onDragEnd: saveWidth,
                      ),
                    ),
                  ),
                ),
              ),
            if (_dragWidth != null && docked)
              Positioned(
                top: 12,
                right: width + 16,
                child: IgnorePointer(
                  child: Material(
                    color: Color.alphaBlend(
                      AppOverlayColors.desktopPopoverSurface(cs),
                      cs.surface,
                    ),
                    borderRadius: BorderRadius.circular(AppRadii.capsule),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        '${l.sidePanelWidth(width.round())}${width == DesktopSidePanelController.minWidth
                            ? ' · ${l.sidePanelWidthMin}'
                            : width == DesktopSidePanelController.maxWidthFor(_available)
                            ? ' · ${l.sidePanelWidthMax}'
                            : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
