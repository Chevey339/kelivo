import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'dart:math' as math;
import 'dart:ui' show FlutterView, lerpDouble;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/browser/browser_service.dart';
import '../../../core/services/browser/browser_engine.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import '../../../shared/widgets/snackbar.dart';
import '../models/browser_models.dart';
import '../widgets/browser_controls.dart';
import '../widgets/browser_favicon.dart';
import '../widgets/browser_find_bar.dart';
import '../widgets/browser_glass.dart';
import '../widgets/browser_scroll_configuration.dart';
import '../widgets/browser_library.dart';
import '../widgets/browser_settings.dart';
import '../widgets/browser_tabs.dart';
import '../widgets/browser_surface_controls.dart';
import '../widgets/browser_menu.dart';
import '../widgets/browser_progressive_edge.dart';
import '../widgets/browser_switch_lens.dart';
import '../widgets/browser_desktop_toolbar.dart';
import '../widgets/browser_window_chrome.dart';
import '../widgets/browser_viewport_insets.dart';
import '../widgets/browser_agent_status_chip.dart';
import '../browser_ai_entry.dart';
import '../browser_tabs_route.dart';
import '../browser_management_route.dart';
import 'browser_desktop_layout.dart';
import 'browser_mobile_layout.dart';
import 'browser_management_page.dart';

enum _BrowserMenu {
  newTab,
  moveToConversation,
  reopenInConversation,
  tabs,
  bookmark,
  bookmarks,
  history,
  downloads,
  find,
  copy,
  external,
  agent,
  askAi,
  settings,
  close,
}

class BrowserPage extends StatefulWidget {
  const BrowserPage({
    super.key,
    this.conversationId,
    this.initialTabId,
    this.service,
    this.embedded = false,
    this.shortcutsEnabled = true,
    this.onClose,
    this.onExpand,
    this.onDock,
  });

  final String? conversationId;

  /// Presentation handoffs preserve the selected tab without changing its owner.
  /// Normal chat entry leaves this unset and resolves the conversation's tab.
  final String? initialTabId;
  final BrowserService? service;
  final bool embedded;
  final bool shortcutsEnabled;
  final VoidCallback? onClose;
  final VoidCallback? onExpand;
  final VoidCallback? onDock;

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> with WidgetsBindingObserver {
  late final BrowserService _service =
      widget.service ?? BrowserService.instance;
  final GlobalKey _startPageBoundary = GlobalKey();
  final GlobalKey _mobileLayoutKey = GlobalKey();
  ({String id, int version, double? offset, Uint8List bytes})? _tabsPreview;
  Timer? _previewIdleTimer;

  bool get _hasCurrentTabPreview {
    final tab = _service.activeTab;
    final preview = _tabsPreview;
    return tab != null &&
        preview != null &&
        preview.id == tab.id &&
        preview.version == tab.runtimeVersion &&
        preview.offset == _service.scrollStateForTab(tab.id)?.offset &&
        identical(preview.bytes, _service.previewForTab(tab.id));
  }

  bool get _canPrepareIdlePreview =>
      mounted &&
      _ready &&
      !_blank &&
      !_desktop &&
      !_menuOpen &&
      !_showFind &&
      !_openingMobileTabs &&
      !_addressFocus.hasFocus &&
      (_view?.viewInsets.bottom ?? 0) <= 0 &&
      _viewportPointers.isEmpty &&
      _service.activeTab?.isLoading == false &&
      ModalRoute.of(context)?.isCurrent != false;

  void _scheduleIdlePreview() {
    _previewIdleTimer?.cancel();
    if (!_canPrepareIdlePreview || _hasCurrentTabPreview) return;
    // Native capture still draws the webpage on Android's UI thread. Keep it
    // outside pointer/keyboard/menu motion, including the settling animation.
    _previewIdleTimer = Timer(const Duration(seconds: 1), () {
      if (!_canPrepareIdlePreview || _hasCurrentTabPreview) return;
      if (WidgetsBinding.instance.transientCallbackCount > 0) {
        _scheduleIdlePreview();
        return;
      }
      unawaited(_prepareTabPreview());
    });
  }

  final GlobalKey _menuButtonKey = GlobalKey();
  final GlobalKey _menuRestKey = GlobalKey();
  final TextEditingController _address = TextEditingController();
  final FocusNode _addressFocus = FocusNode();
  final FocusNode _pageFocus = FocusNode(debugLabel: 'Browser page');
  final TextEditingController _find = TextEditingController();
  final FocusNode _findFocus = FocusNode();
  Timer? _findDebounce;
  BuildContext? _surfaceContext;
  bool _ready = false;
  bool _showFind = false;
  bool _showDesktopTabs = false;
  bool _openingMobileTabs = false;
  bool _deferNativeViews = false;
  ({int epoch, String id, Rect rect, Uint8List? bytes, ui.Image? raster})?
  _tabReturnCover;
  bool _tabReturnCoverFading = false;
  bool _tabChromeHidden = false;
  int _tabReturnCoverEpoch = 0;
  bool _editingAddress = false;
  bool _addressKeyboardSession = false;
  bool _keyboardWasVisible = false;
  FlutterView? _view;
  Animation<double>? _entryAnimation;
  bool _opticsScheduled = false;
  final _chromeMotion = ValueNotifier((progress: 0.0, animate: false));
  double _visibleCollapseProgress = 0;
  bool _menuOpen = false;
  bool _menuTransitionStarted = false;
  double _lastScroll = 0;
  double _scrollIntent = 0;
  bool _scrollTouchActive = false;
  bool _scrollTouchHasIntent = false;
  final _viewportPointers = <int>{};
  bool _androidPointerInputSeen = false;
  bool _androidMultiTouch = false;
  double _androidScrollIntent = 0;

  void _viewportPointerDown(PointerDownEvent event) {
    _previewIdleTimer?.cancel();
    _tabsPreview = null;
    final firstPointer = _viewportPointers.isEmpty;
    _viewportPointers.add(event.pointer);
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (firstPointer) {
      _androidMultiTouch = false;
      _androidScrollIntent = 0;
    }
    _androidPointerInputSeen = true;
    if (_viewportPointers.length > 1) _androidMultiTouch = true;
  }

  void _viewportPointerEnd(PointerEvent event) {
    _viewportPointers.remove(event.pointer);
    if (_viewportPointers.isEmpty) {
      _androidScrollIntent = 0;
      _scheduleIdlePreview();
    }
  }

  void _androidPointerMove(PointerMoveEvent event) {
    if (defaultTargetPlatform != TargetPlatform.android ||
        !_viewportPointers.contains(event.pointer) ||
        _androidMultiTouch ||
        _desktop ||
        _blank ||
        _editingAddress ||
        _showFind ||
        (_view?.viewInsets.bottom ?? 0) > 0 ||
        event.delta.dy.abs() <= event.delta.dx.abs()) {
      return;
    }
    final delta = -event.delta.dy;
    if (delta.sign != _androidScrollIntent.sign) _androidScrollIntent = 0;
    _androidScrollIntent += delta;
    final scroll = _service.scrollStateForTab(_service.activeTabId ?? '');
    if (scroll == null || scroll.viewportExtent <= 0) return;
    final scale = _viewportHeight > 0
        ? _viewportHeight / scroll.viewportExtent
        : 1.0;
    final maxOffset = math.max(
      0.0,
      scroll.contentExtent - scroll.viewportExtent,
    );
    if (maxOffset * scale <= 16 ||
        (maxOffset - scroll.offset.clamp(0.0, maxOffset)) * scale <= 8) {
      _androidScrollIntent = 0;
      _chromeMotion.value = (progress: 0, animate: true);
      return;
    }
    // Android's compositor cancels DOM touch events when it takes ownership of
    // scrolling. Flutter's raw pointer route continues for the whole gesture;
    // it observes input without competing with WebView's gesture recognizer.
    if (_androidScrollIntent >= 12) {
      _chromeMotion.value = (progress: 1, animate: true);
    } else if (_androidScrollIntent <= -6) {
      _chromeMotion.value = (progress: 0, animate: true);
    }
  }

  double _viewportHeight = 0;
  String? _initializationError;
  String? _addressTabId;
  String? _findTabId;

  String? get _visibleConversationId =>
      _service.activeTab?.ownerSessionId ?? widget.conversationId;

  String? get _visibleTabScope => _service.activeTab == null
      ? widget.conversationId
      : _service.activeTab!.ownerSessionId;

  String _conversationTitle(String? id) {
    final l = AppLocalizations.of(context)!;
    if (id == null) return l.browserTabsUnassigned;
    final chat = context.read<ChatService?>();
    final title = chat?.getConversation(id)?.title.trim();
    return title == null || title.isEmpty
        ? l.browserTabsUnknownConversation
        : title;
  }

  bool get _desktop =>
      widget.embedded ||
      ResponsiveHelper.isDesktop(context) ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  bool get _blank {
    final url = _service.activeTab?.url;
    return _service.activeTab?.hasContent != true &&
        (url == null || url.isEmpty || url == 'about:blank');
  }

  bool get _hasWebAddress {
    final uri = Uri.tryParse(_service.activeTab?.url ?? '');
    return uri != null &&
        const {'http', 'https'}.contains(uri.scheme) &&
        uri.host.isNotEmpty;
  }

  bool get _bookmarked =>
      _service.bookmarks.any((item) => item.url == _service.activeTab?.url);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final active = _service.activeTab;
    // A presentation handoff already has a selected, initialized document.
    // Do not flash the loading scaffold while awaiting completed futures.
    _ready =
        _service.isInitialized &&
        active != null &&
        (widget.initialTabId == active.id ||
            (widget.initialTabId == null &&
                (widget.conversationId == null ||
                    widget.conversationId == active.ownerSessionId)));
    if (_ready) _syncAddress(force: true);
    _service.addListener(_serviceChanged);
    _service.scrollPosition.addListener(_scrollChanged);
    _addressFocus.addListener(_addressFocusChanged);
    unawaited(_initialize());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _view = View.of(context);
    final animation = ModalRoute.of(context)?.animation;
    if (_entryAnimation != animation) {
      _entryAnimation?.removeStatusListener(_prepareOpticsWhenSettled);
      _entryAnimation = animation;
      _entryAnimation?.addStatusListener(_prepareOpticsWhenSettled);
    }
    _prepareOpticsWhenSettled();
  }

  void _prepareOpticsWhenSettled([AnimationStatus? _]) {
    if (_opticsScheduled ||
        !mounted ||
        !_service.isInitialized ||
        _service.settings.surfaceStyle == BrowserSurfaceStyle.solid ||
        (_entryAnimation != null && !_entryAnimation!.isCompleted)) {
      return;
    }
    _opticsScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_service.settings.surfaceStyle != BrowserSurfaceStyle.solid) {
        unawaited(BrowserProgressiveEdge.prewarm());
        unawaited(BrowserSwitchLens.prewarm());
        if (_service.settings.surfaceStyle == BrowserSurfaceStyle.liquid) {
          unawaited(BrowserGlass.prewarm(nativeBackdrop: false));
        }
      }
    });
  }

  @override
  void didChangeMetrics() {
    if (!mounted || _desktop) return;
    if ((_view?.viewInsets.bottom ?? 0) <= 0) {
      final dismissed = _keyboardWasVisible;
      _keyboardWasVisible = false;
      if (dismissed && _addressFocus.hasFocus) _addressFocus.unfocus();
      if (dismissed) _scheduleIdlePreview();
      if (_addressKeyboardSession && !_addressFocus.hasFocus) {
        setState(() => _addressKeyboardSession = false);
      }
      return;
    }
    _previewIdleTimer?.cancel();
    _tabsPreview = null;
    _keyboardWasVisible = true;
    // Webpage fields are native responders, so Flutter's address FocusNode
    // cannot report their keyboard session. Keep navigation expanded throughout
    // either keyboard's animation, including the final dismissal frame.
    _scrollIntent = 0;
    _chromeMotion.value = (progress: 0, animate: false);
  }

  Future<void> _initialize() async {
    try {
      await _service.initialize();
      if (_service.settings.surfaceStyle == BrowserSurfaceStyle.liquid) {
        await BrowserGlass.prewarm();
      }
      if (!mounted) return;
      if (_service.isSupported) {
        final conversationId = widget.conversationId;
        final initialTab = _service.tabs
            .where((tab) => tab.id == widget.initialTabId)
            .firstOrNull;
        if (initialTab != null) {
          await _service.selectTab(initialTab.id);
        } else if (conversationId != null) {
          await _service.selectSession(conversationId);
        }
      }
      _finishInitialization();
    } catch (error) {
      if (mounted) {
        setState(() => _initializationError = error.toString());
      }
    }
  }

  void _finishInitialization() {
    if (!mounted) return;
    _syncAddress(force: true);
    setState(() {
      _ready = true;
      _initializationError = null;
    });
    _scheduleIdlePreview();
  }

  void _addressFocusChanged() {
    _editingAddress = _addressFocus.hasFocus;
    if (_addressFocus.hasFocus) {
      _addressKeyboardSession = true;
      _chromeMotion.value = (progress: 0, animate: false);
      _address.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _address.text.length,
      );
    } else {
      if ((_view?.viewInsets.bottom ?? 0) <= 0) {
        _addressKeyboardSession = false;
      }
      _syncAddress(force: true);
    }
    if (mounted && _ready) {
      setState(() {});
      _scheduleIdlePreview();
    }
  }

  void _scrollChanged() {
    final position = _service.scrollPosition.value;
    if (!mounted ||
        position == null ||
        position.tabId != _service.activeTabId) {
      return;
    }
    final scroll = position.state;
    final maxOffset = math.max(
      0.0,
      scroll.contentExtent - scroll.viewportExtent,
    );
    final offset = scroll.offset.clamp(0.0, maxOffset);
    final cssDelta = offset - _lastScroll;
    if (offset != _lastScroll) _tabsPreview = null;
    _lastScroll = offset;
    if (scroll.isUserInteracting) {
      _previewIdleTimer?.cancel();
    } else {
      _scheduleIdlePreview();
    }
    if (defaultTargetPlatform == TargetPlatform.android &&
        _androidPointerInputSeen) {
      if (scroll.phase == BrowserScrollPhase.reset) {
        _androidScrollIntent = 0;
        _chromeMotion.value = (progress: 0, animate: false);
      } else {
        final scale = scroll.viewportExtent > 0 && _viewportHeight > 0
            ? _viewportHeight / scroll.viewportExtent
            : 1.0;
        if (maxOffset * scale <= 16 ||
            (offset * scale <= 8 && cssDelta < 0) ||
            (_viewportPointers.isNotEmpty &&
                _androidScrollIntent != 0 &&
                (maxOffset - offset) * scale <= 8)) {
          _androidScrollIntent = 0;
          _chromeMotion.value = (progress: 0, animate: true);
        }
      }
      return;
    }
    if (scroll.phase == BrowserScrollPhase.reset) {
      _scrollIntent = 0;
      _scrollTouchActive = false;
      _scrollTouchHasIntent = false;
      _chromeMotion.value = (progress: 0, animate: false);
      return;
    }
    if (scroll.isUserInteracting != _scrollTouchActive) {
      _scrollTouchActive = scroll.isUserInteracting;
      _scrollTouchHasIntent = false;
    }
    if (scroll.gestureDelta != 0) _scrollTouchHasIntent = true;
    if (_desktop ||
        _editingAddress ||
        _showFind ||
        _blank ||
        (_view?.viewInsets.bottom ?? 0) > 0) {
      _scrollIntent = 0;
      return;
    }
    if (scroll.viewportExtent <= 0 || _viewportHeight <= 0) return;
    // Scroll events can be coalesced by the native compositor. They choose a
    // direction; they never set the geometry of a Flutter frame directly.
    // Normalizing CSS pixels keeps desktop-layout pages equally responsive.
    final scale = _viewportHeight / scroll.viewportExtent;
    // Touch movement can precede WebKit's coalesced scroll position. A real
    // upward finger movement can leave the top before scrollY catches up;
    // the matching release must not reopen the dock using that stale offset.
    final returningToTop =
        offset * scale <= 8 &&
        (cssDelta < 0 ||
            (scroll.isUserInteracting && scroll.gestureDelta <= 0));
    if (returningToTop || maxOffset * scale <= 16) {
      _scrollIntent = 0;
      _chromeMotion.value = (progress: 0, animate: true);
      return;
    }
    // DOM scroll events are trusted during momentum and rubber-band recovery
    // too. Only a finger that is still down may choose a new chrome direction.
    // Consume every offset above so the next gesture never inherits a rebound.
    if (!scroll.isUserInteracting) {
      _scrollIntent = 0;
      return;
    }
    if ((maxOffset - offset) * scale <= 8 &&
        (scroll.gestureDelta != 0 ||
            (scroll.phase == BrowserScrollPhase.update && cssDelta != 0))) {
      _scrollIntent = 0;
      _chromeMotion.value = (progress: 0, animate: true);
      return;
    }
    if (scroll.phase != BrowserScrollPhase.update) return;
    // Prefer finger intent for the whole gesture once it is available. iOS
    // can deliver scrollY only after touchend, or deliver an older offset
    // after a direction reversal. Counting both would double a single move.
    final delta =
        (_scrollTouchHasIntent ? scroll.gestureDelta : cssDelta) * scale;
    if (delta == 0) return;
    if (delta.sign != _scrollIntent.sign) _scrollIntent = 0;
    _scrollIntent += delta;
    if (_scrollIntent >= 12) {
      _chromeMotion.value = (progress: 1, animate: true);
    } else if (_scrollIntent <= -6) {
      _chromeMotion.value = (progress: 0, animate: true);
    }
  }

  void _serviceChanged() {
    _prepareOpticsWhenSettled();
    if (_addressTabId != _service.activeTabId) {
      _scrollIntent = 0;
      _scrollTouchActive = false;
      _scrollTouchHasIntent = false;
      _chromeMotion.value = (progress: 0, animate: false);
      _visibleCollapseProgress = 0;
      _lastScroll = math.max(
        0.0,
        _service.scrollStateForTab(_service.activeTabId)?.offset ?? 0,
      );
    }
    _syncAddress();
    _releaseTabReturnCoverWhenReady();
    if (_showFind && _findTabId != _service.activeTabId) {
      _findDebounce?.cancel();
      final previous = _findTabId;
      if (previous != null && _service.tabs.any((tab) => tab.id == previous)) {
        unawaited(_run(() => _service.clearFind(tabId: previous)));
      }
      _findTabId = null;
      if (mounted) setState(() => _showFind = false);
    }
    _scheduleIdlePreview();
  }

  void _syncAddress({bool force = false}) {
    final tab = _service.activeTab;
    if (force || !_addressFocus.hasFocus || _addressTabId != tab?.id) {
      final value = _blank ? '' : tab!.url;
      if (_address.text != value) _address.text = value;
      _addressTabId = tab?.id;
    }
  }

  @override
  void dispose() {
    _entryAnimation?.removeStatusListener(_prepareOpticsWhenSettled);
    WidgetsBinding.instance.removeObserver(this);
    _service.removeListener(_serviceChanged);
    _previewIdleTimer?.cancel();
    _service.scrollPosition.removeListener(_scrollChanged);
    _addressFocus.removeListener(_addressFocusChanged);
    _findDebounce?.cancel();
    if (_showFind) {
      // The shared engine lives beyond this route; remove page highlights.
      unawaited(
        _service.clearFind(tabId: _findTabId).catchError((Object _) {}),
      );
    }
    _address.dispose();
    _addressFocus.dispose();
    _pageFocus.dispose();
    _find.dispose();
    _findFocus.dispose();
    _chromeMotion.dispose();
    _tabReturnCover?.raster?.dispose();
    super.dispose();
  }

  void _notify(String message, {bool error = false}) {
    if (!mounted) return;
    AppSnackBarManager().show(
      context,
      AppNotification(
        message: message,
        type: error ? NotificationType.error : NotificationType.info,
      ),
    );
  }

  Future<void> _run(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error) {
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      _notify(switch (error) {
        StateError(message: 'browser_tab_busy') => l.browserTabBusy,
        StateError(message: 'browser_live_view_limit') =>
          l.browserLiveViewLimit,
        _ => error.toString(),
      }, error: true);
    }
  }

  Future<void> _userRun(Future<void> Function() operation) async {
    if (_service.agentActivityFor(
          sessionId: _visibleConversationId,
          tabId: _service.activeTabId,
        ) ==
        BrowserAgentActivity.running) {
      _service.takeOver(
        sessionId: _visibleConversationId,
        tabId: _service.activeTabId,
      );
    }
    await _run(operation);
  }

  void _focusAddress() {
    setState(() {
      _editingAddress = true;
      _showDesktopTabs = false;
      _chromeMotion.value = (progress: 0, animate: false);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _addressFocus.requestFocus();
    });
  }

  void _navigate(String value) {
    if (value.trim().isEmpty) return;
    _addressFocus.unfocus();
    setState(() {
      _editingAddress = false;
      _showDesktopTabs = false;
      _chromeMotion.value = (progress: 0, animate: false);
      _lastScroll = 0;
    });
    unawaited(
      _userRun(() async {
        if (_service.activeTab == null) {
          await _service.createTab(
            url: value,
            ownerSessionId: widget.conversationId,
          );
        } else {
          await _service.navigate(value);
        }
      }),
    );
  }

  Future<void> _newTab() => _run(() async {
    await _service.createTab(ownerSessionId: widget.conversationId);
    if (mounted) _focusAddress();
  });

  void _exit() {
    if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
    _addressFocus.unfocus();
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  void _handleSystemBack() {
    if (_showFind) {
      _toggleFind();
    } else if (_addressFocus.hasFocus) {
      _addressFocus.unfocus();
    } else if (_service.activeTab?.canGoBack == true) {
      unawaited(_userRun(() => _service.back()));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _service,
    builder: (context, _) {
      return BrowserScrollConfiguration(
        child: BrowserGlassScope(
          style: _service.settings.surfaceStyle,
          child: Theme(
            data: Theme.of(context).copyWith(
              splashFactory: NoSplash.splashFactory,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
            ),
            child: BrowserGlassBackdrop(
              native: _desktop || !_blank,
              child: BrowserMenuHost(child: Builder(builder: _buildBrowser)),
            ),
          ),
        ),
      );
    },
  );

  Widget _buildBrowser(BuildContext context) {
    _surfaceContext = context;
    final l = AppLocalizations.of(context)!;
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final retainKeyboardBackdrop =
        _addressFocus.hasFocus ||
        (_addressKeyboardSession && keyboardInset > 0);
    return CallbackShortcuts(
      bindings: widget.shortcutsEnabled
          ? {
              SingleActivator(
                LogicalKeyboardKey.keyL,
                meta: mac,
                control: !mac,
              ): () =>
                  _handleWindowShortcut('l'),
              SingleActivator(
                LogicalKeyboardKey.keyT,
                meta: mac,
                control: !mac,
              ): () =>
                  _handleWindowShortcut('t'),
              SingleActivator(
                LogicalKeyboardKey.keyW,
                meta: mac,
                control: !mac,
              ): () =>
                  _handleWindowShortcut('w'),
              SingleActivator(
                LogicalKeyboardKey.keyF,
                meta: mac,
                control: !mac,
              ): () =>
                  _handleWindowShortcut('f'),
              SingleActivator(
                LogicalKeyboardKey.keyR,
                meta: mac,
                control: !mac,
              ): () =>
                  _handleWindowShortcut('r'),
              const SingleActivator(
                LogicalKeyboardKey.arrowLeft,
                alt: true,
              ): () {
                if (_service.activeTab?.canGoBack == true) {
                  unawaited(_userRun(() => _service.back()));
                }
              },
              const SingleActivator(
                LogicalKeyboardKey.arrowRight,
                alt: true,
              ): () {
                if (_service.activeTab?.canGoForward == true) {
                  unawaited(_userRun(() => _service.forward()));
                }
              },
              const SingleActivator(LogicalKeyboardKey.escape): () {
                if (_showDesktopTabs) {
                  setState(() => _showDesktopTabs = false);
                } else if (_showFind) {
                  _toggleFind();
                } else {
                  _addressFocus.unfocus();
                }
              },
            }
          : const {},
      child: Focus(
        focusNode: _pageFocus,
        autofocus: true,
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          // Keep the scene behind the system keyboard while editing the URL.
          // Webpage form keyboards retain normal viewport avoidance.
          resizeToAvoidBottomInset: _desktop || !retainKeyboardBackdrop,
          body: !_ready
              ? SafeArea(
                  child: Column(
                    children: [
                      _mobileHeader(context),
                      Expanded(
                        child: _initializationError == null
                            ? const Center(child: CircularProgressIndicator())
                            : BrowserEmptyState(
                                icon: LucideIcons.circleAlert,
                                title: l.browserLoadFailed,
                                subtitle: _initializationError,
                                action: BrowserTextButton(
                                  onPressed: _initialize,
                                  child: Text(l.browserRetry),
                                ),
                              ),
                      ),
                    ],
                  ),
                )
              : Builder(
                  builder: (context) {
                    final tab = _service.activeTab;
                    final address = BrowserAddressBar(
                      controller: _address,
                      focusNode: _addressFocus,
                      onSubmitted: _navigate,
                      loading: tab?.isLoading ?? false,
                      progress: tab?.progress ?? 0,
                      secure: tab?.url.startsWith('https://') ?? false,
                      compact: _desktop,
                      editing: _editingAddress || _addressFocus.hasFocus,
                      displayText: _displayHost,
                      onEdit: _focusAddress,
                      onPageMenu: _openMenu,
                      onReload: _blank
                          ? null
                          : () => unawaited(
                              _userRun(
                                () => tab?.isLoading == true
                                    ? _service.stop()
                                    : _service.reload(),
                              ),
                            ),
                    );
                    final layout = _desktop
                        ? BrowserWindowChrome(
                            windowSpacing: !widget.embedded,
                            shortcutsEnabled: widget.shortcutsEnabled,
                            onShortcut: _handleWindowShortcut,
                            child: BrowserViewportInsets(
                              tabId: _service.activeTabId,
                              viewIdentity: tab?.runtimeVersion,
                              top: BrowserDesktopLayout.headerHeight,
                              builder: (context, underlap) =>
                                  BrowserDesktopLayout(
                                    embedded: widget.embedded,
                                    underlapHeader: underlap,
                                    tabBar: BrowserTabStrip(
                                      service: _service,
                                      tabs: _service.tabsForSession(
                                        _visibleTabScope,
                                      ),
                                      activeId: _service.activeTabId,
                                      onSelect: _selectDesktopTab,
                                      onClose: (id) => unawaited(
                                        _userRun(() => _service.closeTab(id)),
                                      ),
                                    ),
                                    tabActions: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        BrowserActionButton(
                                          compact: true,
                                          iconSize: 16,
                                          label: l.browserTabsAll,
                                          icon: LucideIcons.panelsTopLeft,
                                          onPressed: _openTabs,
                                        ),
                                        BrowserActionButton(
                                          compact: true,
                                          iconSize: 16,
                                          label: l.browserNewTab,
                                          icon: LucideIcons.plus,
                                          onPressed: () => unawaited(_newTab()),
                                        ),
                                        if (widget.onExpand != null)
                                          BrowserActionButton(
                                            compact: true,
                                            iconSize: 15,
                                            label: l.browserOpenFullPage,
                                            icon: LucideIcons.expand,
                                            onPressed: widget.onExpand,
                                          ),
                                        if (widget.onDock != null)
                                          BrowserActionButton(
                                            compact: true,
                                            iconSize: 15,
                                            label: l.browserOpenInSidebar,
                                            icon: LucideIcons.panelRightClose,
                                            onPressed: widget.onDock,
                                          ),
                                        if (widget.embedded)
                                          BrowserActionButton(
                                            compact: true,
                                            iconSize: 15,
                                            label: l.browserClosePanel,
                                            icon: LucideIcons.x,
                                            onPressed: _exit,
                                          ),
                                      ],
                                    ),
                                    toolbar: _desktopToolbar(context, address),
                                    agentStatus: _agentStatus(context),
                                    findBar: _showFind
                                        ? _findBar(context)
                                        : null,
                                    content: _desktopContent(context, underlap),
                                  ),
                            ),
                          )
                        : BrowserViewportInsets(
                            tabId: _blank ? null : _service.activeTabId,
                            viewIdentity: tab?.runtimeVersion,
                            top: MediaQuery.viewPaddingOf(context).top,
                            builder: (context, underlap) =>
                                ValueListenableBuilder<bool>(
                                  valueListenable:
                                      BrowserViewportInsets.reduceTransparency,
                                  builder: (context, reduceTransparency, _) =>
                                      BrowserMobileLayout(
                                        key: _mobileLayoutKey,
                                        underlapStatusBar: _blank || underlap,
                                        fadeBehindToolbar:
                                            !_blank &&
                                            underlap &&
                                            !reduceTransparency,
                                        viewPadding: viewPadding,
                                        keyboardInset: keyboardInset,
                                        viewportResizesForKeyboard:
                                            !retainKeyboardBackdrop,
                                        onViewportHeight: (height) =>
                                            _viewportHeight = height,
                                        toolbar: _mobileToolbar(
                                          context,
                                          bottomSafeInset: viewPadding.bottom,
                                          foregroundShadows:
                                              defaultTargetPlatform ==
                                                      TargetPlatform.iOS &&
                                                  !_blank &&
                                                  underlap &&
                                                  !reduceTransparency &&
                                                  !MediaQuery.highContrastOf(
                                                    context,
                                                  ) &&
                                                  Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.dark &&
                                                  _service
                                                          .settings
                                                          .surfaceStyle ==
                                                      BrowserSurfaceStyle.liquid
                                              ? const [
                                                  Shadow(
                                                    color: Color(0x66000000),
                                                    offset: Offset(0, .5),
                                                    blurRadius: 0,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        agentStatus: _agentStatus(context),
                                        findBar: _showFind
                                            ? _findBar(context)
                                            : null,
                                        content: _content(
                                          context,
                                          previewTopInset: underlap
                                              ? viewPadding.top
                                              : 0,
                                        ),
                                        transitionOverlay: _tabReturnOverlay(
                                          context,
                                        ),
                                      ),
                                ),
                          );
                    return PopScope(
                      canPop:
                          _menuOpen ||
                          (!_showFind &&
                              !_addressFocus.hasFocus &&
                              _service.activeTab?.canGoBack != true),
                      onPopInvokedWithResult: (didPop, _) {
                        if (!didPop) _handleSystemBack();
                      },
                      child: layout,
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _mobileHeader(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          BrowserActionButton(
            label: l.browserClose,
            icon: LucideIcons.chevronDown,
            onPressed: _exit,
          ),
          Expanded(
            child: Text(
              l.browserTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          BrowserActionButton(
            label: l.browserNewTab,
            icon: LucideIcons.plus,
            onPressed: () => unawaited(_newTab()),
          ),
        ],
      ),
    );
  }

  String get _displayHost {
    final uri = Uri.tryParse(_service.activeTab?.url ?? '');
    return uri?.host.replaceFirst(RegExp(r'^www\.'), '') ?? '';
  }

  Widget _mobileToolbar(
    BuildContext context, {
    required double bottomSafeInset,
    List<Shadow>? foregroundShadows,
  }) => TweenAnimationBuilder<double>(
    key: const ValueKey('browserTabChromeReveal'),
    tween: Tween(begin: 1, end: _tabChromeHidden || _showFind ? 0 : 1),
    duration: Duration(
      milliseconds:
          _tabChromeHidden ||
              _showFind ||
              MediaQuery.disableAnimationsOf(context)
          ? 0
          : 220,
    ),
    curve: Curves.easeOutCubic,
    builder: (context, opacity, _) => IgnorePointer(
      ignoring: opacity < 1,
      child: ExcludeSemantics(
        excluding: opacity < 1,
        child: _mobileToolbarContents(
          context,
          bottomSafeInset: bottomSafeInset,
          revealOpacity: opacity,
          foregroundShadows: foregroundShadows,
        ),
      ),
    ),
  );

  Widget _mobileToolbarContents(
    BuildContext context, {
    required double bottomSafeInset,
    required double revealOpacity,
    List<Shadow>? foregroundShadows,
  }) {
    final l = AppLocalizations.of(context)!;
    final tab = _service.activeTab;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final canGoForward = tab?.canGoForward == true;
    // Measure once outside the per-frame chrome builder. Only labels that need
    // ellipsis use two stable layouts; fitting hosts keep continuous scaling.
    double measureHost(double fontSize) {
      final painter = TextPainter(
        text: TextSpan(
          text: _displayHost,
          style: DefaultTextStyle.of(context).style.merge(
            TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              height: 1.15,
            ),
          ),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final expandedHostWidth = measureHost(16);
    final hostWidth = expandedHostWidth * 13 / 16;
    final backControl = BrowserActionButton(
      label: l.browserBack,
      icon: LucideIcons.chevronLeft,
      iconSize: 22,
      foregroundShadows: foregroundShadows,
      useParentFeedback: true,
      onPressed: tab?.canGoBack == true
          ? () => unawaited(_userRun(() => _service.back()))
          : null,
      onLongPress: () => _openLibrary(BrowserLibrarySection.history),
    );
    final forwardControl = BrowserActionButton(
      label: l.browserForward,
      icon: LucideIcons.chevronRight,
      iconSize: 22,
      foregroundShadows: foregroundShadows,
      useParentFeedback: true,
      onPressed: canGoForward
          ? () => unawaited(_userRun(() => _service.forward()))
          : null,
    );
    final editing = _editingAddress || _addressFocus.hasFocus;
    return TweenAnimationBuilder<double>(
      key: const ValueKey('browserAddressEditingTransition'),
      tween: Tween(begin: editing ? 1 : 0, end: editing ? 1 : 0),
      duration: Duration(milliseconds: reduced ? 0 : 240),
      curve: Curves.easeOutCubic,
      builder: (context, editProgress, _) => TweenAnimationBuilder<double>(
        tween: Tween(begin: canGoForward ? 1 : 0, end: canGoForward ? 1 : 0),
        duration: Duration(milliseconds: reduced ? 0 : 220),
        curve: Curves.easeInOutCubic,
        builder: (context, forwardProgress, _) {
          final navigationWidth = 48 + 36 * forwardProgress;
          return ValueListenableBuilder<({double progress, bool animate})>(
            valueListenable: _chromeMotion,
            builder: (context, motion, _) => TweenAnimationBuilder<double>(
              tween: Tween(begin: 1, end: _menuTransitionStarted ? 0 : 1),
              duration: Duration(milliseconds: reduced ? 0 : 180),
              curve: Curves.easeOutCubic,
              builder: (context, toolbarOpacity, _) => LayoutBuilder(
                builder: (context, constraints) {
                  final expandedWidth = math.max(
                    0.0,
                    constraints.maxWidth - navigationWidth - 68,
                  );
                  final collapsedWidth = (hostWidth + 32).clamp(
                    math.min(94.0, expandedWidth),
                    expandedWidth,
                  );
                  return BrowserChromeTransition(
                    progress: editing ? 0 : motion.progress,
                    animate: !editing && motion.animate,
                    reducedMotion: reduced,
                    onProgress: (value) => _visibleCollapseProgress = value,
                    builder: (context, t) {
                      final width = constraints.maxWidth;
                      final drop = BrowserMobileLayout.collapseDropFor(
                        bottomSafeInset,
                      );
                      final sideOpacity =
                          (1 - editProgress) *
                          toolbarOpacity *
                          revealOpacity *
                          (1 - t);
                      final moreOpacity = _menuTransitionStarted
                          ? 0.0
                          : (1 - editProgress) * (1 - t) * revealOpacity;
                      final pillWidth = lerpDouble(
                        lerpDouble(expandedWidth, width, editProgress),
                        collapsedWidth,
                        t,
                      )!;
                      final height = lerpDouble(48, 34, t)!;
                      return SizedBox(
                        height: BrowserMobileLayout.expandedChromeHeight + drop,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              key: const ValueKey('browserBackPosition'),
                              left: 0,
                              bottom: drop,
                              child: Transform.translate(
                                offset: Offset(42 * t, drop * t),
                                child: SizedBox(
                                  width: navigationWidth,
                                  height: 48,
                                  child: ExcludeSemantics(
                                    excluding: editing || t >= .995,
                                    child: IgnorePointer(
                                      ignoring: editing || t >= .995,
                                      child: BrowserPress(
                                        draggable: true,
                                        child: BrowserGlass(
                                          key: const ValueKey(
                                            'browserMobileNavigationGroup',
                                          ),
                                          radius: 1000,
                                          opacity: sideOpacity,
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 48 - 6 * forwardProgress,
                                                child: backControl,
                                              ),
                                              if (forwardProgress > 0)
                                                SizedBox(
                                                  width: 42 * forwardProgress,
                                                  height: 48,
                                                  child: ClipRect(
                                                    child: OverflowBox(
                                                      minWidth: 42,
                                                      maxWidth: 42,
                                                      alignment:
                                                          Alignment.centerRight,
                                                      child: IgnorePointer(
                                                        ignoring: !canGoForward,
                                                        child: ExcludeSemantics(
                                                          excluding:
                                                              !canGoForward,
                                                          child: Opacity(
                                                            opacity:
                                                                forwardProgress,
                                                            child:
                                                                forwardControl,
                                                          ),
                                                        ),
                                                      ),
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
                            Positioned(
                              key: const ValueKey('browserAddressPosition'),
                              left: lerpDouble(
                                (navigationWidth + 10) * (1 - editProgress),
                                (width - collapsedWidth) / 2,
                                t,
                              ),
                              bottom: drop * (1 - t),
                              width: pillWidth,
                              height: height,
                              child: BrowserAddressBar(
                                stabilizeTruncation:
                                    expandedHostWidth > expandedWidth - 86 ||
                                    hostWidth > collapsedWidth - 24,
                                expandedContentWidth: expandedWidth,
                                collapsedContentWidth: collapsedWidth
                                    .toDouble(),
                                siteIcon: BrowserFavicon(
                                  url: tab?.url ?? '',
                                  service: _service,
                                  size: 20,
                                ),
                                foregroundShadows: foregroundShadows,
                                opacity: toolbarOpacity * revealOpacity,
                                controller: _address,
                                focusNode: _addressFocus,
                                onSubmitted: _navigate,
                                loading: tab?.isLoading ?? false,
                                progress: tab?.progress ?? 0,
                                secure:
                                    tab?.url.startsWith('https://') ?? false,
                                editing: editing,
                                collapseProgress: t,
                                displayText: _displayHost,
                                onEdit: () {
                                  if (_visibleCollapseProgress > 0) {
                                    setState(() {
                                      _chromeMotion.value = (
                                        progress: 0,
                                        animate: true,
                                      );
                                    });
                                  } else {
                                    _focusAddress();
                                  }
                                },
                                onPageMenu: _openMenu,
                                onReload: _blank
                                    ? null
                                    : () => unawaited(
                                        _userRun(
                                          () => tab?.isLoading == true
                                              ? _service.stop()
                                              : _service.reload(),
                                        ),
                                      ),
                              ),
                            ),
                            Positioned(
                              key: const ValueKey('browserMorePosition'),
                              right: 0,
                              bottom: drop,
                              child: Transform.translate(
                                offset: Offset(-42 * t, drop * t),
                                child: SizedBox(
                                  // Keep the resting anchor outside the hidden control so
                                  // a hidden held source still returns to 48x48.
                                  key: _menuRestKey,
                                  width: 48,
                                  height: 48,
                                  child: ExcludeSemantics(
                                    excluding: editing || t >= .995,
                                    child: IgnorePointer(
                                      // Retain its material through keyboard and
                                      // collapse transitions; alpha owns visibility.
                                      ignoring: editing || t >= .995,
                                      child: BrowserActionButton(
                                        foregroundShadows: foregroundShadows,
                                        surface: true,
                                        // The menu owns this lens until its final frame.
                                        // Only the companion controls use the fade above.
                                        opacity: moreOpacity,
                                        anchorKey: _menuButtonKey,
                                        label: l.browserMore,
                                        icon: LucideIcons.ellipsis,
                                        onPressed: _openMenu,
                                        onLongPress: _openMenu,
                                        onLongPressStart: (pointer, details) =>
                                            _openMenu(
                                              heldPointer: pointer,
                                              pressPosition:
                                                  details.globalPosition,
                                            ),
                                      ),
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
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _desktopToolbar(BuildContext context, Widget address) {
    final l = AppLocalizations.of(context)!;
    final tab = _service.activeTab;
    Widget navigation({bool includeClose = false}) =>
        BrowserDesktopControlGroup(
          children: [
            if (includeClose && !widget.embedded)
              BrowserActionButton(
                compact: true,
                label: l.browserClose,
                icon: LucideIcons.panelLeftClose,
                onPressed: _exit,
              ),
            BrowserActionButton(
              compact: true,
              label: l.browserBack,
              icon: LucideIcons.chevronLeft,
              onPressed: tab?.canGoBack == true
                  ? () => unawaited(_userRun(() => _service.back()))
                  : null,
            ),
            BrowserActionButton(
              compact: true,
              label: l.browserForward,
              icon: LucideIcons.chevronRight,
              onPressed: tab?.canGoForward == true
                  ? () => unawaited(_userRun(() => _service.forward()))
                  : null,
            ),
          ],
        );
    Widget more() => BrowserActionButton(
      compact: true,
      anchorKey: _menuButtonKey,
      label: l.browserMore,
      icon: LucideIcons.ellipsis,
      onPressed: _openMenu,
    );
    return BrowserDesktopToolbar(
      navigation: navigation(includeClose: true),
      compactNavigation: navigation(),
      addressBar: address,
      compactActions: more(),
      actions: BrowserDesktopControlGroup(
        children: [
          BrowserActionButton(
            compact: true,
            label: l.browserTabs,
            icon: LucideIcons.panelsTopLeft,
            onPressed: _openTabs,
          ),
          more(),
        ],
      ),
    );
  }

  Widget? _agentStatus(BuildContext context) {
    final activity = _service.agentActivityFor(
      sessionId: _visibleConversationId,
      tabId: _service.activeTabId,
    );
    if (activity == BrowserAgentActivity.idle) return null;
    return BrowserAgentStatusChip(
      activity: activity,
      pauseReason: _service.agentPauseReason,
      onPause: () => _service.takeOver(
        sessionId: _visibleConversationId,
        tabId: _service.activeTabId,
      ),
      onResume: () =>
          _service.allowAgentControl(sessionId: _visibleConversationId),
    );
  }

  Widget _content(BuildContext context, {double previewTopInset = 0}) {
    final l = AppLocalizations.of(context)!;
    if (!_service.isSupported) {
      return BrowserEmptyState(
        icon: LucideIcons.globe,
        title: l.browserUnsupported,
      );
    }
    final tab = _service.activeTab;
    final observing =
        _service.agentActivityFor(
          sessionId: _visibleConversationId,
          tabId: tab?.id,
        ) ==
        BrowserAgentActivity.running;
    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            onPointerDown: (event) {
              if (!observing) _viewportPointerDown(event);
              // A tap outside the address field starts keyboard dismissal.
              // Keep its full-height viewport until the final zero-inset
              // frame; changing avoidance here briefly shrinks the webpage.
              _addressFocus.unfocus();
            },
            onPointerMove: observing ? null : _androidPointerMove,
            onPointerUp: _viewportPointerEnd,
            onPointerCancel: _viewportPointerEnd,
            child: Semantics(
              readOnly: observing,
              label: observing ? l.browserObserverHint : null,
              child: ExcludeFocus(
                excluding: observing,
                child: AbsorbPointer(
                  key: const ValueKey('browserObserverInputShield'),
                  absorbing: observing,
                  child: _service.buildViewport(
                    deferNewViews: _deferNativeViews,
                    previewTopInset: previewTopInset,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (tab == null || _blank)
          Positioned.fill(
            child: RepaintBoundary(
              key: _startPageBoundary,
              child: BrowserStartPage(
                service: _service,
                bookmarks: _service.bookmarks,
                onNavigate: _navigate,
                onFocusAddress: _focusAddress,
              ),
            ),
          ),
        if (tab?.error != null)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: BrowserEmptyState(
                icon: LucideIcons.cloudOff,
                title: l.browserLoadFailed,
                subtitle: tab!.error,
                action: BrowserTextButton(
                  icon: LucideIcons.rotateCw,
                  child: Text(l.browserRetry),
                  onPressed: () => unawaited(_userRun(() => _service.reload())),
                ),
              ),
            ),
          ),
        if (observing && defaultTargetPlatform == TargetPlatform.macOS)
          Positioned.fill(
            // AppKit embeds a real NSView: an input-only Flutter render object
            // does not occlude it. Match the menu's painted hit-test surface,
            // without a dimming layer or a captured copy of the webpage.
            child: Listener(
              key: const ValueKey('browserNativeObserverSurface'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _addressFocus.unfocus(),
              child: const ColoredBox(color: Color(0x01000000)),
            ),
          ),
      ],
    );
  }

  Widget? _tabReturnOverlay(BuildContext context) {
    final cover = _tabReturnCover;
    if (cover == null) return null;
    return IgnorePointer(
      child: AnimatedOpacity(
        key: ValueKey('browserTabReturnCover-${cover.epoch}'),
        opacity: _tabReturnCoverFading ? 0 : 1,
        duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 100,
        ),
        onEnd: () {
          // Zero-duration accessibility motion may finish during widget update.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                _tabReturnCoverFading &&
                _tabReturnCover?.epoch == cover.epoch) {
              _clearTabReturnCover();
            }
          });
        },
        child: Stack(
          children: [
            Positioned.fromRect(
              rect: cover.rect,
              child: ClipRect(
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.surface,
                  child: cover.raster != null
                      ? RawImage(
                          image: cover.raster,
                          fit: BoxFit.fitWidth,
                          alignment: Alignment.topCenter,
                        )
                      : Image.memory(
                          cover.bytes!,
                          fit: BoxFit.fitWidth,
                          alignment: Alignment.topCenter,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.low,
                          excludeFromSemantics: true,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Keep precisely the flight's pixels until the destination platform view has
  // been composited. Route completion alone does not mean UIKit is ready.
  void _holdTabReturnCover(BrowserTabTransitionController motion) {
    if (!mounted) return;
    // The flight contains page content only. Keep the existing toolbar's native
    // hosts mounted and dissolve their materials after the tab route finishes;
    // an Opacity around the whole toolbar would isolate native backdrops.
    setState(() => _tabChromeHidden = true);
    if (motion.tabId == null || !motion.hasImageSnapshot) return;
    final previous = _tabReturnCover?.raster;
    setState(() {
      _tabReturnCover = (
        epoch: ++_tabReturnCoverEpoch,
        id: motion.tabId!,
        rect: motion.contentRect,
        bytes: motion.previewBytes,
        raster: motion.cloneReturnRaster(),
      );
      _tabReturnCoverFading = false;
    });
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  void _clearTabReturnCover() {
    final raster = _tabReturnCover?.raster;
    setState(() {
      _tabReturnCover = null;
      _tabReturnCoverFading = false;
    });
    if (raster != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => raster.dispose());
    }
  }

  void _releaseTabReturnCoverWhenReady() {
    final cover = _tabReturnCover;
    if (!mounted || cover == null || _deferNativeViews) return;
    final tab = _service.activeTab;
    if (tab?.id != cover.id) {
      _clearTabReturnCover();
    } else if (_blank ||
        tab?.error != null ||
        _service.isTabPresented(cover.id)) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _clearTabReturnCover();
      } else if (!_tabReturnCoverFading) {
        setState(() => _tabReturnCoverFading = true);
      }
    }
  }

  void _handleWindowShortcut(String key) {
    switch (key) {
      case 'l':
        _focusAddress();
      case 't':
        unawaited(_newTab());
      case 'w':
        final id = _service.activeTabId;
        if (id != null) unawaited(_userRun(() => _service.closeTab(id)));
      case 'f':
        _focusFind();
      case 'r':
        if (!_blank) unawaited(_userRun(() => _service.reload()));
    }
  }

  void _focusFind() {
    if (_blank) return;
    if (_showFind) {
      _findFocus.requestFocus();
      return;
    }
    _toggleFind();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showFind) _findFocus.requestFocus();
    });
  }

  void _toggleFind() {
    if (_blank) return;

    if (_showFind) {
      _findDebounce?.cancel();
      unawaited(_run(() => _service.clearFind(tabId: _findTabId)));
      _find.clear();
    } else {
      _findTabId = _service.activeTabId;
    }
    setState(() {
      _showFind = !_showFind;
      if (_showFind) _showDesktopTabs = false;
    });
  }

  Widget _findBar(BuildContext context) => BrowserFindBar(
    controller: _find,
    focusNode: _findFocus,
    compact: _desktop,
    onChanged: (text) {
      _findDebounce?.cancel();
      final tabId = _findTabId;
      _findDebounce = Timer(const Duration(milliseconds: 180), () {
        unawaited(_userRun(() => _service.findInPage(text, tabId: tabId)));
      });
    },
    onSubmitted: (_) => unawaited(_userRun(() => _service.findNext())),
    onPrevious: () =>
        unawaited(_userRun(() => _service.findNext(forward: false))),
    onNext: () => unawaited(_userRun(() => _service.findNext())),
    onDone: _toggleFind,
  );

  void _closeManagementThen(BuildContext panelContext, VoidCallback action) {
    final route = ModalRoute.of(panelContext);
    Navigator.of(panelContext).pop();
    unawaited(() async {
      await route?.completed;
      if (mounted) action();
    }());
  }

  Future<void> _prepareManagementMaterials() async {
    if (_service.settings.surfaceStyle == BrowserSurfaceStyle.solid ||
        !ui.ImageFilter.isShaderFilterSupported) {
      return;
    }
    // Resolve optical programs before the transition captures its first frame.
    // The browser has already started this preload after its entry animation.
    await Future.wait([
      BrowserGlass.prewarm(nativeBackdrop: false),
      BrowserProgressiveEdge.prewarm(),
    ]);
  }

  Future<void> _pushManagementRoute(PageRoute<void> route) async {
    setState(() => _deferNativeViews = true);
    try {
      await Navigator.of(context).push<void>(route);
      // push completes at the beginning of pop, not the end of its animation.
      await route.completed;
    } finally {
      if (mounted) {
        setState(() {
          _deferNativeViews = false;
          if (route is BrowserTabsRoute) _tabChromeHidden = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _releaseTabReturnCoverWhenReady();
        });
      }
    }
  }

  Future<void> _showPanel({
    required String title,
    required Widget Function(BuildContext, ScrollController?) builder,
    double desktopWidth = 480,
    double preferredHeight = 560,
    bool mobileHeader = true,
    bool mobileOwnsPage = false,
  }) async {
    _addressFocus.unfocus();
    final desktop = _desktop;
    if (!desktop) {
      await _prepareManagementMaterials();
      if (!mounted) return;
    }
    final themes = InheritedTheme.capture(
      from: _surfaceContext ?? context,
      to: Navigator.of(context, rootNavigator: true).context,
    );
    Widget withSurfaceStyle(Widget child) =>
        ListenableProvider<BrowserService>.value(
          value: _service,
          child: Selector<BrowserService, BrowserSurfaceStyle>(
            selector: (_, service) => service.settings.surfaceStyle,
            builder: (_, style, child) => BrowserGlassBackdrop(
              native: desktop,
              child: BrowserGlassScope(style: style, child: child!),
            ),
            child: child,
          ),
        );
    if (!desktop) {
      await _pushManagementRoute(
        browserManagementRoute<void>(
          context: context,
          builder: (pageContext) => themes.wrap(
            withSurfaceStyle(
              mobileOwnsPage
                  ? builder(pageContext, null)
                  : BrowserManagementPage(
                      title: title,
                      showHeader: mobileHeader,
                      child: builder(pageContext, null),
                    ),
            ),
          ),
        ),
      );
      return;
    }
    final reduced = MediaQuery.disableAnimationsOf(context);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: title,
      barrierColor: Colors.black.withValues(alpha: .12),
      transitionDuration: Duration(milliseconds: reduced ? 0 : 160),
      pageBuilder: (panelContext, _, __) {
        final content = builder(panelContext, null);
        return themes.wrap(
          BrowserScrollConfiguration(
            child: withSurfaceStyle(
              Builder(
                builder: (context) => SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      12,
                      12,
                      12 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) => Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          key: const ValueKey('browserPanel'),
                          width: math.min(desktopWidth, constraints.maxWidth),
                          height: math.min(
                            preferredHeight,
                            constraints.maxHeight * .9,
                          ),
                          child: BrowserGlass(
                            radius: 20,
                            child: DefaultTextStyle(
                              style: Theme.of(context).textTheme.bodyMedium!
                                  .copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    decoration: TextDecoration.none,
                                  ),
                              child: Column(
                                children: [
                                  BrowserDialogHeader(title: title),
                                  Expanded(child: content),
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
        );
      },
      transitionBuilder: (context, animation, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0, .012), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    );
  }

  void _openLibrary(BrowserLibrarySection section) {
    final l = AppLocalizations.of(context)!;
    unawaited(
      _showPanel(
        title: switch (section) {
          BrowserLibrarySection.bookmarks => l.browserBookmarks,
          BrowserLibrarySection.history => l.browserHistory,
          BrowserLibrarySection.downloads => l.browserDownloads,
        },
        mobileOwnsPage: true,
        builder: (panelContext, controller) => BrowserLibrary(
          service: _service,
          mobileManagement: !_desktop,
          section: section,
          scrollController: controller,
          onError: (error) => _notify(error.toString(), error: true),
          onOpen: (url) =>
              _closeManagementThen(panelContext, () => _navigate(url)),
        ),
      ),
    );
  }

  void _selectDesktopTab(String id) {
    _pageFocus.requestFocus();
    setState(() => _showDesktopTabs = false);
    unawaited(_userRun(() => _service.selectTab(id)));
  }

  Widget _desktopContent(BuildContext context, bool underlap) => IndexedStack(
    index: _showDesktopTabs ? 1 : 0,
    sizing: StackFit.expand,
    children: [
      _content(context),
      if (_showDesktopTabs)
        ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: EdgeInsets.only(
              top: underlap ? BrowserDesktopLayout.headerHeight : 0,
            ),
            child: BrowserTabOverview(
              service: _service,
              conversationId: widget.conversationId,
              conversationTitle: _conversationTitle,
              onDone: () => setState(() => _showDesktopTabs = false),
              onSelect: _selectDesktopTab,
              onClose: (id) => unawaited(_userRun(() => _service.closeTab(id))),
              onNew: () => unawaited(_newTab()),
            ),
          ),
        )
      else
        const SizedBox.shrink(),
    ],
  );

  void _openTabs() {
    if (_desktop) {
      if (_showFind) _toggleFind();
      _addressFocus.unfocus();
      setState(() => _showDesktopTabs = !_showDesktopTabs);
      _pageFocus.requestFocus();
      return;
    }
    unawaited(_showMobileTabs());
  }

  Future<void> _showMobileTabs() async {
    if (_openingMobileTabs) return;
    _openingMobileTabs = true;
    try {
      await _pushMobileTabs();
    } finally {
      _openingMobileTabs = false;
    }
  }

  Rect _tabContentRect() {
    final viewport = _mobileLayoutKey.currentContext?.findRenderObject();
    final navigator = Navigator.of(context).context.findRenderObject();
    final media = MediaQuery.of(context);
    final size = viewport is RenderBox && viewport.hasSize
        ? viewport.size
        : media.size;
    final origin = viewport is RenderBox && navigator is RenderBox
        ? viewport.localToGlobal(Offset.zero, ancestor: navigator)
        : Offset.zero;
    final top = math.min(media.viewPadding.top, size.height);
    return Rect.fromLTWH(
      origin.dx,
      origin.dy + top,
      size.width,
      size.height - top,
    );
  }

  ui.Image _cropStartPreview(RenderRepaintBoundary boundary) {
    const ratio = 1.5;
    final full = boundary.toImageSync(pixelRatio: ratio);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final viewport = _tabContentRect();
    final navigator =
        Navigator.of(context).context.findRenderObject() as RenderBox;
    final origin = boundary.localToGlobal(Offset.zero, ancestor: navigator);
    final local = viewport
        .shift(-origin)
        .intersect(Offset.zero & boundary.size);
    final source = Rect.fromLTWH(
      local.left * ratio,
      local.top * ratio,
      local.width * ratio,
      local.height * ratio,
    );
    canvas.drawImageRect(full, source, Offset.zero & source.size, Paint());
    final picture = recorder.endRecording();
    try {
      return picture.toImageSync(source.width.ceil(), source.height.ceil());
    } finally {
      picture.dispose();
      full.dispose();
    }
  }

  Future<void> _pushMobileTabs() async {
    _previewIdleTimer?.cancel();
    // Capture before covering/detaching the live view. An idle image is only
    // a head start: it cannot represent a page the user has just scrolled.
    await Future.wait([
      _prepareManagementMaterials(),
      _prepareTabPreview(fresh: true),
    ]);
    if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
    // A frozen overview must not capture an Image widget before its first
    // decoded frame. Freeze the identities before awaiting decoding: an idle
    // in-flight native capture may replace the service bytes during this wait.
    final previews = Map<String, Uint8List>.unmodifiable({
      for (final tab in _service.tabs)
        if (_service.previewForTab(tab.id) case final bytes?) tab.id: bytes,
    });
    await Future.wait([
      for (final bytes in previews.values)
        precacheImage(MemoryImage(bytes), context, onError: (_, _) {}),
    ]);
    if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
    _addressFocus.unfocus();
    final openingId = _service.activeTabId;
    ui.Image? startPageSnapshot;
    if (_blank) {
      final boundary = _startPageBoundary.currentContext?.findRenderObject();
      if (boundary is RenderRepaintBoundary && boundary.hasSize) {
        try {
          // Keep an existing painted page as a GPU image; do not rebuild its
          // glass shaders in a second tree or encode/decode a PNG for motion.
          startPageSnapshot = _cropStartPreview(boundary);
        } catch (_) {
          // A route removed during capture can no longer supply its layer.
        }
      }
    }
    if (!mounted ||
        ModalRoute.of(context)?.isCurrent == false ||
        openingId != _service.activeTabId) {
      startPageSnapshot?.dispose();
      return;
    }
    final preview = _tabsPreview;
    final openingPreviewReady =
        _blank ||
        (preview != null &&
            preview.id == openingId &&
            preview.version == _service.activeTab?.runtimeVersion &&
            preview.offset == _service.scrollStateForTab(openingId)?.offset &&
            identical(preview.bytes, previews[openingId]));
    final navigator = Navigator.of(context);
    final themes = InheritedTheme.capture(
      from: _surfaceContext ?? context,
      to: navigator.context,
    );
    final motion = BrowserTabTransitionController(
      service: _service,
      initialTabId: _service.activeTabId,
      initialContentRect: _tabContentRect(),
      contentRectForTab: (_) => _tabContentRect(),
      openingPreviewReady: openingPreviewReady,
      startPageSnapshot: startPageSnapshot,
      previews: previews,
      fallbackBuilder: (context, tab) => themes.wrap(
        BrowserGlassBackdrop(
          native: false,
          child: BrowserGlassScope(
            style: BrowserSurfaceStyle.solid,
            child:
                tab == null ||
                    (!tab.hasContent &&
                        (tab.url.isEmpty || tab.url == 'about:blank'))
                ? BrowserStartPage(
                    service: _service,
                    bookmarks: _service.bookmarks,
                    onNavigate: (_) {},
                    onFocusAddress: () {},
                  )
                : BrowserEmptyState(
                    icon: LucideIcons.globe,
                    title: tab.title.isEmpty ? tab.url : tab.title,
                  ),
          ),
        ),
      ),
    );
    startPageSnapshot?.dispose();
    await _pushManagementRoute(
      BrowserTabsRoute(
        transition: motion,
        onReturnStarted: () => _holdTabReturnCover(motion),
        reduceMotion: MediaQuery.disableAnimationsOf(context),
        builder: (panelContext) => themes.wrap(
          BrowserGlassBackdrop(
            native: false,
            child: BrowserManagementPage(
              title: AppLocalizations.of(context)!.browserTabs,
              showHeader: false,
              child: BrowserTabOverview(
                service: _service,
                conversationId: widget.conversationId,
                conversationTitle: _conversationTitle,
                transition: motion,
                onDone: () => Navigator.of(panelContext).pop(),
                onSelect: (id) {
                  motion.prepareReturn(id);
                  unawaited(_userRun(() => _service.selectTab(id)));
                  Navigator.of(panelContext).pop();
                },
                onClose: (id) =>
                    unawaited(_userRun(() => _service.closeTab(id))),
                onNew: () {
                  motion.prepareReturn(null);
                  _closeManagementThen(
                    panelContext,
                    () => unawaited(_newTab()),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openSettings() {
    final l = AppLocalizations.of(context)!;
    unawaited(
      _showPanel(
        title: l.browserSettings,
        desktopWidth: 440,
        preferredHeight: _desktop ? 520 : 600,
        builder: (_, controller) => BrowserSettingsPanel(
          service: _service,
          scrollController: controller,
          onError: (error) => _notify(error.toString(), error: true),
          onDataCleared: () => _notify(l.browserDataCleared),
        ),
      ),
    );
  }

  Rect _menuAnchor() {
    final box = _menuButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return MatrixUtils.transformRect(
        box.getTransformTo(null),
        Offset.zero & box.size,
      );
    }
    final media = MediaQuery.of(context);
    return Rect.fromLTWH(
      media.size.width - 64,
      _desktop ? 44 : media.size.height - media.padding.bottom - 58,
      48,
      48,
    );
  }

  Rect? _menuRestAnchor() {
    // This key is outside BrowserPress's deformation, so a held 68pt lens
    // returns to the control's current 48pt layout instead of its lifted pose.
    final box = _menuRestKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
  }

  Future<void> _prepareTabPreview({bool fresh = false}) async {
    if (!fresh && _hasCurrentTabPreview) return;
    final tab = _service.activeTab;
    if (tab == null || _blank) return;
    final offset = _service.scrollStateForTab(tab.id)?.offset;
    final previous = _service.previewForTab(tab.id);
    await _service.refreshActivePreview(fresh: fresh);
    final bytes = _service.previewForTab(tab.id);
    if (!mounted ||
        bytes == null ||
        identical(previous, bytes) ||
        _service.activeTabId != tab.id ||
        _service.activeTab?.runtimeVersion != tab.runtimeVersion ||
        _service.scrollStateForTab(tab.id)?.offset != offset) {
      return;
    }
    _tabsPreview = (
      id: tab.id,
      version: tab.runtimeVersion,
      offset: offset,
      bytes: bytes,
    );
  }

  Future<void> _openMenu({int? heldPointer, Offset? pressPosition}) async {
    if (_menuOpen) return;
    _previewIdleTimer?.cancel();

    final l = AppLocalizations.of(context)!;
    if (!_desktop) setState(() => _menuOpen = true);
    final action = await showBrowserMenu<_BrowserMenu>(
      _surfaceContext ?? context,
      title: l.browserMore,
      desktop: _desktop,
      anchorRect: _menuAnchor(),
      resolveAnchor: _menuRestAnchor,
      onTransitionStart: () {
        if (mounted && _menuOpen) {
          setState(() => _menuTransitionStarted = true);
        }
      },
      heldPointer: heldPointer,
      pressPosition: pressPosition,
      items: [
        BrowserMenuEntry(
          value: _BrowserMenu.newTab,
          group: BrowserMenuGroup.navigation,
          icon: LucideIcons.plus,
          label: l.browserNewTab,
        ),
        BrowserMenuEntry(
          value: _BrowserMenu.tabs,
          footer: true,
          group: BrowserMenuGroup.navigation,
          icon: LucideIcons.panelsTopLeft,
          label:
              '${l.browserTabs} (${_service.tabsForSession(_visibleTabScope).length})',
        ),
        if (widget.conversationId != null &&
            _service.activeTab != null &&
            _service.activeTab!.ownerSessionId != widget.conversationId) ...[
          BrowserMenuEntry(
            value: _BrowserMenu.moveToConversation,
            icon: LucideIcons.folderInput,
            label: l.browserMoveToConversation,
          ),
          if (_hasWebAddress)
            BrowserMenuEntry(
              value: _BrowserMenu.reopenInConversation,
              icon: LucideIcons.copy,
              label: l.browserReopenInConversation,
            ),
        ],
        if (_hasWebAddress)
          BrowserMenuEntry(
            value: _BrowserMenu.bookmark,
            icon: LucideIcons.bookmark,
            label: _bookmarked ? l.browserRemoveBookmark : l.browserAddBookmark,
          ),
        BrowserMenuEntry(
          value: _BrowserMenu.bookmarks,
          footer: true,
          group: BrowserMenuGroup.library,
          icon: LucideIcons.bookOpen,
          label: l.browserBookmarks,
        ),
        BrowserMenuEntry(
          value: _BrowserMenu.history,
          group: BrowserMenuGroup.library,
          icon: LucideIcons.history,
          label: l.browserHistory,
        ),
        BrowserMenuEntry(
          value: _BrowserMenu.downloads,
          group: BrowserMenuGroup.library,
          icon: LucideIcons.download,
          label: l.browserDownloads,
        ),
        if (!_blank)
          BrowserMenuEntry(
            value: _BrowserMenu.find,
            secondary: true,
            icon: LucideIcons.search,
            label: l.browserFind,
          ),
        if (_hasWebAddress) ...[
          BrowserMenuEntry(
            value: _BrowserMenu.copy,
            secondary: true,
            icon: LucideIcons.link,
            label: l.browserCopyLink,
          ),
          BrowserMenuEntry(
            value: _BrowserMenu.external,
            secondary: true,
            icon: LucideIcons.externalLink,
            label: l.browserOpenExternal,
          ),
        ],
        BrowserMenuEntry(
          value: _BrowserMenu.askAi,
          group: BrowserMenuGroup.application,
          icon: LucideIcons.sparkles,
          label:
              widget.conversationId != null &&
                  _visibleConversationId != widget.conversationId
              ? l.browserAskAiInOwnerConversation
              : l.browserAskAi,
        ),
        if (_service.agentActivityFor(
              sessionId: _visibleConversationId,
              tabId: _service.activeTabId,
            ) !=
            BrowserAgentActivity.idle)
          BrowserMenuEntry(
            value: _BrowserMenu.agent,
            group: BrowserMenuGroup.application,
            icon: LucideIcons.hand,
            label: _service.agentPaused
                ? l.browserAllowAgent
                : l.browserTakeOver,
          ),
        BrowserMenuEntry(
          value: _BrowserMenu.settings,
          footer: true,
          group: BrowserMenuGroup.application,
          icon: LucideIcons.settings2,
          label: l.browserSettings,
        ),
        BrowserMenuEntry(
          value: _BrowserMenu.close,
          group: BrowserMenuGroup.application,
          icon: LucideIcons.x,
          label: l.browserClose,
        ),
      ],
    );
    if (!mounted) return;
    if (_menuOpen) {
      setState(() {
        _menuOpen = false;
        _menuTransitionStarted = false;
      });
    }
    if (action == null) {
      _scheduleIdlePreview();
      return;
    }
    switch (action) {
      case _BrowserMenu.newTab:
        await _newTab();
      case _BrowserMenu.moveToConversation:
        final id = _service.activeTabId;
        final sessionId = widget.conversationId;
        if (id != null && sessionId != null) {
          await _run(() => _service.moveTabToSession(id, sessionId));
        }
      case _BrowserMenu.reopenInConversation:
        final url = _service.activeTab?.url;
        if (url != null) {
          await _run(() async {
            await _service.createTab(
              url: url,
              ownerSessionId: widget.conversationId,
            );
          });
        }
      case _BrowserMenu.tabs:
        _openTabs();
      case _BrowserMenu.bookmark:
        await _run(() => _service.toggleBookmark());
      case _BrowserMenu.bookmarks:
        _openLibrary(BrowserLibrarySection.bookmarks);
      case _BrowserMenu.history:
        _openLibrary(BrowserLibrarySection.history);
      case _BrowserMenu.downloads:
        _openLibrary(BrowserLibrarySection.downloads);
      case _BrowserMenu.find:
        _toggleFind();
      case _BrowserMenu.copy:
        await Clipboard.setData(
          ClipboardData(text: _service.activeTab?.url ?? ''),
        );
        _notify(l.browserLinkCopied);
      case _BrowserMenu.external:
        final url = _service.activeTab?.url;
        if (url != null) {
          await _run(() async {
            if (!await launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            )) {
              throw StateError(l.browserLoadFailed);
            }
          });
        }
      case _BrowserMenu.agent:
        if (_service.agentPaused) {
          _service.allowAgentControl(sessionId: _visibleConversationId);
        } else {
          _service.takeOver(
            sessionId: _visibleConversationId,
            tabId: _service.activeTabId,
          );
        }
      case _BrowserMenu.askAi:
        final result = await requestBrowserAiDraft(
          context,
          browser: _service,
          conversationId: _visibleConversationId,
          tab: _service.activeTab,
        );
        if (!mounted) return;
        switch (result) {
          case BrowserAiEntryResult.requested:
            _service.allowAgentControl(sessionId: _visibleConversationId);
            _exit();
          case BrowserAiEntryResult.unavailable:
            _notify(l.browserAskAiUnavailable);
          case BrowserAiEntryResult.assistantToolDisabled:
            _notify(l.browserAskAiAssistantDisabled);
          case BrowserAiEntryResult.browserPermissionDisabled:
            _notify(l.browserAskAiBrowserDisabled);
        }
      case _BrowserMenu.settings:
        _openSettings();
      case _BrowserMenu.close:
        _exit();
    }
  }
}

class BrowserStartPage extends StatelessWidget {
  const BrowserStartPage({
    super.key,
    required this.bookmarks,
    required this.onNavigate,
    required this.onFocusAddress,
    this.service,
  });

  final BrowserService? service;
  final List<BrowserBookmark> bookmarks;
  final ValueChanged<String> onNavigate;
  final VoidCallback onFocusAddress;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return BrowserWallpaper(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(28, 60, 28, 130),
            children: [
              Text(
                'Kelivo',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.4,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 38),
              Text(
                l.browserFavorites,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              if (bookmarks.isEmpty)
                BrowserGlass(
                  radius: 26,
                  elevated: false,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        LucideIcons.bookOpen,
                        size: 25,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l.browserNoBookmarks,
                        style: TextStyle(
                          fontSize: 15,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      BrowserTextButton(
                        onPressed: onFocusAddress,
                        icon: LucideIcons.search,
                        child: Text(l.browserSearchHint),
                      ),
                    ],
                  ),
                ),
              if (bookmarks.isNotEmpty)
                Wrap(
                  spacing: 18,
                  runSpacing: 24,
                  children: [
                    for (final bookmark in bookmarks.take(12))
                      SizedBox(
                        width: 82,
                        child: Column(
                          children: [
                            BrowserActionButton(
                              surface: true,
                              label: bookmark.title,
                              icon: LucideIcons.globe,
                              child: BrowserFavicon(
                                url: bookmark.url,
                                service: service,
                                size: 24,
                              ),
                              onPressed: () => onNavigate(bookmark.url),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              bookmark.title.isEmpty
                                  ? browserDisplayUrl(bookmark.url)
                                  : bookmark.title,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
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
