import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../../features/browser/models/browser_models.dart';
import '../../../features/browser/models/browser_agent_activity.dart';
import '../api/tool_call_cancellation.dart';
import 'browser_engine.dart';
import 'browser_favicon_loader.dart';
import 'browser_native_engine.dart';
import 'browser_store.dart';

/// Owns browsing state independently of pages and conversation widget lifetimes.
class BrowserService extends ChangeNotifier with WidgetsBindingObserver {
  BrowserService({
    BrowserStore? store,
    BrowserEngineFactory? engineFactory,
    this._supported,
  }) : _store = store ?? BrowserStore(),
       _engineFactory = engineFactory ?? NativeBrowserEngine.create;

  static final BrowserService instance = BrowserService();
  // Bound agent fan-out and native memory separately from saved/user tabs.
  static const int maxAgentTabsPerSession = 3;
  static const int maxLiveViews = 3;
  static const int maxCachedPreviews = 8;
  static const int maxHistory = 2000;
  static const _uuid = Uuid();
  static final Object _actionKey = Object();
  final BrowserStore _store;
  final BrowserEngineFactory _engineFactory;

  /// Scroll drives only the browser chrome, never persistence or all listeners.
  final ValueNotifier<({String tabId, BrowserScrollState state})?>
  scrollPosition = ValueNotifier(null);
  final Map<String, BrowserScrollState> _scrollStates = {};
  BrowserScrollState? scrollStateForTab(String? id) => _scrollStates[id];
  final bool? _supported;
  final List<BrowserTab> _tabs = [];
  final List<BrowserBookmark> _bookmarks = [];
  final List<BrowserHistoryEntry> _history = [];
  final List<BrowserDownload> _downloads = [];
  final _favicons = <String, Uint8List>{};

  /// Cached site icons only: reading a saved page never makes a network request.
  Uint8List? faviconForUrl(String url) => _favicons[browserFaviconSite(url)];

  void _cacheFavicon(String url, Uint8List bytes) {
    final site = browserFaviconSite(url);
    if (site == null || !isBrowserFavicon(bytes)) return;
    if (listEquals(_favicons[site], bytes)) return;
    _favicons.remove(site);
    _favicons[site] = Uint8List.fromList(bytes).asUnmodifiableView();
    while (_favicons.length > browserFaviconMaxSites) {
      _favicons.remove(_favicons.keys.first);
    }
    _scheduleSave();
  }

  final Map<String, BrowserEngine> _engines = {};
  final Map<String, String> _engineGroups = {};
  final Map<String, Future<void>> _closingGroups = {};
  final Map<String, CancelToken> _downloadTokens = {};
  final Map<String, int> _sessionEpochs = {};
  final Map<String, Completer<void>> _sessionCancellation = {};
  final Map<String, int> _mountedTabs = {};
  final Map<String, List<_BrowserViewHostState>> _viewHosts = {};
  final Map<String, ({String html, String? baseUrl, String documentUrl})>
  _htmlDocuments = {};
  final Map<String, int> _navigationRevisions = {};
  final Map<String, Uint8List> _tabPreviews = {};
  final Map<String, int> _previewEpochs = {};
  final Map<String, int> _previewCompletedEpochs = {};
  final Map<String, ({int epoch, bool wasLoading, Future<void> future})>
  _previewFlights = {};
  final Set<String> _previewPending = {};
  final Map<String, ({BrowserEngine engine, Future<Uint8List?> future})>
  _nativePreviewFlights = {};
  final Map<String, int> _previewWatchers = {};
  final Map<String, Timer> _chatPreviewTimers = {};
  final Map<String, DateTime> _chatPreviewTimes = {};
  bool _previewForeground = true;
  Future<void>? _runtimeQueue;
  Future<void>? _agentQueue;
  Future<void>? _initializing;
  Timer? _saveTimer;
  Timer? _idleTimer;
  bool _disposed = false;
  bool _initialized = false;
  int _controlEpoch = 0;
  Completer<void> _controlCancelled = Completer<void>();
  String? _activeTabId;
  String? _selectedSessionId;
  final Map<String, String> _lastTabBySession = {};
  String? _agentSessionId;
  String? _agentAction;
  String? _agentTabId;
  bool _agentPaused = false;
  bool _clearingWebsiteData = false;
  BrowserAgentPauseReason? _agentPauseReason;
  String? _pausedAgentSessionId;
  String? _pausedAgentTabId;
  _BrowserAction? _runningAgentGuard;
  // Content mode follows the host OS, never a tablet/window-width breakpoint.
  BrowserSettings _settings = BrowserSettings(
    desktopMode:
        !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux),
  );
  String? persistenceError;

  bool get isSupported =>
      _supported ??
      (!kIsWeb &&
          (Platform.isAndroid ||
              Platform.isIOS ||
              Platform.isMacOS ||
              Platform.isWindows));
  bool get supportsWebsiteDataClear => isSupported && !Platform.isWindows;
  bool get isInitialized => _initialized;
  List<BrowserTab> get tabs => List.unmodifiable(_tabs);
  List<BrowserTab> tabsForSession(String? sessionId) => _tabs
      .where((tab) => tab.ownerSessionId == sessionId)
      .toList(growable: false);
  List<BrowserBookmark> get bookmarks => List.unmodifiable(_bookmarks);
  List<BrowserHistoryEntry> get history => List.unmodifiable(_history);
  List<BrowserDownload> get downloads => List.unmodifiable(_downloads);
  BrowserSettings get settings => _settings;
  String? get activeTabId => _activeTabId;
  BrowserTab? get activeTab =>
      _tabs.where((tab) => tab.id == _activeTabId).firstOrNull;
  String? get agentSessionId => _agentSessionId;
  String? get agentAction => _agentAction;
  bool get agentPaused => _agentPaused;
  BrowserAgentPauseReason? get agentPauseReason => _agentPauseReason;
  String? get pausedAgentSessionId => _pausedAgentSessionId;
  String? get pausedAgentTabId => _pausedAgentTabId;
  String? get agentTabId => _agentTabId;

  /// Scoped display state; enabling permission or resuming never starts a task.
  BrowserAgentActivity agentActivityFor({String? sessionId, String? tabId}) {
    if (!_settings.agentEnabled) return BrowserAgentActivity.idle;
    bool matches(String? owner, String? target) =>
        (sessionId == null || owner == sessionId) &&
        (tabId == null || target == null || target == tabId);
    if (_agentPaused &&
        _agentPauseReason != null &&
        (sessionId == null || _pausedAgentSessionId == sessionId)) {
      return BrowserAgentActivity.paused;
    }
    if (_isRunningAgentAction && matches(_agentSessionId, _agentTabId)) {
      return BrowserAgentActivity.running;
    }
    return BrowserAgentActivity.idle;
  }

  bool get _isRunningAgentAction {
    final guard = _runningAgentGuard;
    return guard != null &&
        _agentAction != null &&
        _settings.agentEnabled &&
        !_agentPaused &&
        guard.epoch == _controlEpoch &&
        guard.sessionEpoch == (_sessionEpochs[guard.sessionId] ?? 0) &&
        guard.cancellation?.isCancelled() != true;
  }

  int get controlEpoch => _controlEpoch;
  int get liveViewCount => _engines.length;

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    final existing = _initializing;
    if (existing != null) return existing;
    final initializing = _initialize();
    _initializing = initializing;
    unawaited(
      initializing.then<void>(
        (_) {},
        onError: (Object _, StackTrace __) {
          if (identical(_initializing, initializing)) _initializing = null;
        },
      ),
    );
    return initializing;
  }

  Future<void> _initialize() async {
    final state = await _store.read();
    if (_disposed) return;
    final icons = state['favicons'];
    if (icons is List) {
      for (final item in icons.take(browserFaviconMaxSites)) {
        if (item is! Map || item['site'] is! String) continue;
        final site = browserFaviconSite(item['site'] as String);
        final bytes = decodeBrowserFavicon(item['png']);
        if (site != null && bytes != null) {
          _favicons[site] = bytes.asUnmodifiableView();
        }
      }
    }
    final settings = state['settings'];
    if (settings is Map<String, dynamic>) {
      _settings = BrowserSettings.fromJson(
        settings,
        defaultDesktopMode: _settings.desktopMode,
      );
    }
    _readRecords(state['bookmarks'], BrowserBookmark.fromJson, _bookmarks);
    _readRecords(state['history'], BrowserHistoryEntry.fromJson, _history);
    _readRecords(state['downloads'], BrowserDownload.fromJson, _downloads);
    if (_settings.restoreTabs) {
      final saved = <BrowserTab>[];
      _readRecords(state['tabs'], BrowserTab.fromJson, saved);
      final seen = <String>{};
      _tabs.addAll(
        saved.where(
          (tab) => tab.id.isNotEmpty && _isPageUrl(tab.url) && seen.add(tab.id),
        ),
      );
      final active = state['activeTabId'];
      _activeTabId = _tabs.any((tab) => tab.id == active)
          ? active as String
          : _tabs.firstOrNull?.id;
      final selected = state['lastTabBySession'];
      if (selected is Map) {
        for (final tab in _tabs) {
          final owner = tab.ownerSessionId;
          if (owner != null && selected[owner] == tab.id) {
            _lastTabBySession[owner] = tab.id;
          }
        }
      }
      _selectedSessionId = activeTab?.ownerSessionId;
      if (_selectedSessionId != null && _activeTabId != null) {
        _lastTabBySession.putIfAbsent(_selectedSessionId!, () => _activeTabId!);
      }
    }
    if (_history.length > maxHistory) {
      _history.removeRange(maxHistory, _history.length);
    }
    WidgetsBinding.instance.addObserver(this);
    _initialized = true;
    _notify();
  }

  static void _readRecords<T>(
    Object? value,
    T Function(Map<String, dynamic>) decode,
    List<T> target,
  ) {
    if (value is! List) return;
    for (final row in value) {
      if (row is! Map<String, dynamic>) continue;
      try {
        target.add(decode(row));
      } on Object {
        /* Ignore one malformed record, retaining the rest. */
      }
    }
  }

  static bool _isPageUrl(String value) {
    if (value == 'about:blank') return true;
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  static String normalizeAddress(
    String input, {
    BrowserSearchEngine searchEngine = BrowserSearchEngine.bing,
  }) {
    final value = input.trim();
    if (value.isEmpty || value == 'about:blank') return 'about:blank';
    final hostLike =
        !RegExp(r'\s').hasMatch(value) &&
        (value.contains('.') ||
            RegExp(r'^localhost(?::\d+)?(?:/|$)').hasMatch(value) ||
            value.startsWith('['));
    final explicit = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(value);
    final hostWithPort = RegExp(
      r'^(?:localhost|[^/:\s]+\.[^/:\s]+):\d+(?:/|$)',
    ).hasMatch(value);
    if (explicit && !hostWithPort) {
      if (!_isPageUrl(value)) {
        throw const FormatException('Only HTTP and HTTPS pages are supported');
      }
      return Uri.parse(value).toString();
    }
    if (hostLike) {
      final scheme =
          value.startsWith('localhost') ||
              value.startsWith('127.') ||
              value.startsWith('[::1]')
          ? 'http'
          : 'https';
      final candidate = '$scheme://$value';
      if (_isPageUrl(candidate)) return Uri.parse(candidate).toString();
    }
    final (host, path, key) = switch (searchEngine) {
      BrowserSearchEngine.bing => ('www.bing.com', '/search', 'q'),
      BrowserSearchEngine.google => ('www.google.com', '/search', 'q'),
      BrowserSearchEngine.duckDuckGo => ('duckduckgo.com', '/', 'q'),
      BrowserSearchEngine.baidu => ('www.baidu.com', '/s', 'wd'),
    };
    return Uri.https(host, path, {key: value}).toString();
  }

  BrowserTab requireTab(String id) =>
      _tabs.where((tab) => tab.id == id).firstOrNull ??
      (throw StateError('browser_tab_not_found'));

  BrowserTab requireAgentTab(String sessionId, String? tabId) {
    final tab = tabId == null
        ? selectedTabForSession(sessionId)
        : requireTab(tabId);
    if (tab == null) throw StateError('browser_no_session_tab');
    if (tab.ownerSessionId != sessionId) {
      throw StateError('browser_tab_not_owned');
    }
    return tab;
  }

  BrowserTab? selectedTabForSession(String sessionId) {
    final owned = tabsForSession(sessionId);
    return owned
            .where((tab) => tab.id == _lastTabBySession[sessionId])
            .firstOrNull ??
        owned.lastOrNull;
  }

  /// Enter a conversation without allocating a blank page or borrowing a tab
  /// from another conversation. Each conversation remembers its own selection.
  Future<void> selectSession(String sessionId) async {
    await initialize();
    _checkAction();
    final action = Zone.current[_actionKey] as _BrowserAction?;
    if (action != null && action.sessionId != sessionId) {
      throw StateError('browser_tab_not_owned');
    }
    final selected = selectedTabForSession(sessionId);
    if (_selectedSessionId == sessionId && _activeTabId == selected?.id) return;
    if (_activeTabId != selected?.id) unawaited(refreshActivePreview());
    _selectedSessionId = sessionId;
    _activeTabId = selected?.id;
    if (selected != null) _lastTabBySession[sessionId] = selected.id;
    _changed();
  }

  void _selectTab(BrowserTab tab) {
    final owner = tab.ownerSessionId;
    if (owner != null) _lastTabBySession[owner] = tab.id;
    final action = Zone.current[_actionKey] as _BrowserAction?;
    // Background conversations must not replace the page the user is viewing.
    if (action != null &&
        (_selectedSessionId != null || _activeTabId != null) &&
        _selectedSessionId != action.sessionId) {
      return;
    }
    if (_activeTabId != tab.id) unawaited(refreshActivePreview());
    _activeTabId = tab.id;
    _selectedSessionId = owner;
  }

  Future<BrowserTab> createTab({
    String? url,
    String? ownerSessionId,
    int? windowId,
    String? openerTabId,
    String? popupGroupId,
  }) async {
    await initialize();
    _checkAction();
    final action = Zone.current[_actionKey] as _BrowserAction?;
    if (action != null && ownerSessionId != action.sessionId) {
      throw StateError('browser_tab_not_owned');
    }
    if (action != null &&
        tabsForSession(action.sessionId).length >= maxAgentTabsPerSession) {
      throw StateError(
        'browser_session_tab_limit: This conversation already has '
        '$maxAgentTabsPerSession or more tabs. Use list_tabs, then reuse '
        'an existing tab with open and tab_id, or close one of your tabs.',
      );
    }
    final tab = BrowserTab(
      id: 'tab-${_uuid.v4()}',
      url: normalizeAddress(url ?? '', searchEngine: _settings.searchEngine),
      ownerSessionId: ownerSessionId,
      windowId: windowId,
      openerTabId: openerTabId,
      popupGroupId: popupGroupId,
      hasContent: windowId != null,
    );
    _tabs.add(tab);
    if (openerTabId != null && _activeTabId != openerTabId) {
      // A popup from a background page belongs to its parent, but must not
      // switch the visible conversation away from the user's current page.
      if (ownerSessionId != null) _lastTabBySession[ownerSessionId] = tab.id;
    } else {
      _selectTab(tab);
    }
    _changed();
    return tab;
  }

  Future<void> selectTab(String id) async {
    _checkAction(id);
    final tab = requireTab(id);
    if (_activeTabId == id &&
        (tab.ownerSessionId == null ||
            _lastTabBySession[tab.ownerSessionId] == id)) {
      return;
    }
    _selectTab(tab);
    _changed();
  }

  /// An explicit user handoff. Popup families move together so login flows
  /// and future popup callbacks cannot retain another conversation's owner.
  Future<void> moveTabToSession(String id, String sessionId) async {
    _checkAction();
    if (sessionId.isEmpty || Zone.current[_actionKey] != null) {
      throw StateError('browser_user_handoff_required');
    }
    final tab = requireTab(id);
    final group = tab.popupGroupId ?? tab.id;
    final family = _tabs.where((tab) => (tab.popupGroupId ?? tab.id) == group);
    final ids = family.map((tab) => tab.id).toSet();
    if (_runningAgentGuard != null &&
        (_agentTabId == null ||
            ids.contains(_agentTabId) ||
            _engineGroups[_agentTabId] == group)) {
      throw StateError('browser_tab_busy');
    }
    _lastTabBySession.removeWhere((_, tabId) => ids.contains(tabId));
    for (var index = 0; index < _tabs.length; index++) {
      if (ids.contains(_tabs[index].id)) {
        _tabs[index] = _tabs[index].copyWith(
          ownerSessionId: sessionId,
          error: _tabs[index].error,
        );
      }
    }
    _selectTab(requireTab(id));
    _changed();
  }

  Future<void> closeTab(String id) async {
    _checkAction(id);
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index < 0) return;
    final owner = _tabs[index].ownerSessionId;
    final opener = _tabs[index].openerTabId;
    final popupGroupId = _tabs[index].popupGroupId ?? id;
    final wasMounted = _mountedTabs.containsKey(id);
    _tabs.removeAt(index);
    _scrollStates.remove(id);
    _htmlDocuments.remove(id);
    _navigationRevisions.remove(id);
    _tabPreviews.remove(id);
    _previewEpochs.remove(id);
    _previewCompletedEpochs.remove(id);
    _previewPending.remove(id);
    _lastTabBySession.removeWhere((_, selected) => selected == id);
    if (_activeTabId == id) {
      final owned = tabsForSession(owner);
      _activeTabId = opener != null && _tabs.any((tab) => tab.id == opener)
          ? opener
          : owned.lastOrNull?.id;
      if (owner != null && _activeTabId != null) {
        _lastTabBySession[owner] = _activeTabId!;
      }
    }
    _changed();
    if (wasMounted) {
      await WidgetsBinding.instance.endOfFrame;
      // Flutter queues iOS platform-view removal for the next submitted
      // frame. The first Dart endOfFrame only schedules that removal.
      WidgetsBinding.instance.scheduleFrame();
      await WidgetsBinding.instance.endOfFrame;
    }
    final survivingEngines = _tabs
        .where((tab) => (tab.popupGroupId ?? tab.id) == popupGroupId)
        .map((tab) => _engines[tab.id])
        .whereType<BrowserEngine>()
        .toList();
    await Future.wait(
      survivingEngines.map((engine) async {
        try {
          // Native detach emits blur/focus bridge messages. Let surviving
          // popup-family renderers drain tasks while their source still exists;
          // WebKit rejects a late postMessage from an already destroyed page.
          await engine
              .evaluate(
                'new Promise(resolve => setTimeout(() => resolve(true), 0))',
                awaitPromise: true,
              )
              .timeout(const Duration(seconds: 3));
        } catch (_) {
          // A terminated or suspended renderer cannot acknowledge the handoff.
        }
      }),
    );
    final familySurvives = _tabs.any(
      (tab) => (tab.popupGroupId ?? tab.id) == popupGroupId,
    );
    if (!familySurvives) {
      await _disposeEngineGroup(popupGroupId);
    } else if (id != popupGroupId) {
      await _engines.remove(id)?.dispose();
      _nativePreviewFlights.remove(id);
      _engineGroups.remove(id);
    } else {
      final retained = _engines[id];
      if (retained != null) {
        try {
          await retained.stop();
          await retained.navigate('about:blank');
          await retained.waitForLoad(const Duration(seconds: 3));
        } catch (_) {
          // The native context still owns its descendants' shared resources.
        }
        await retained.pause();
      }
    }
    // WK popup configurations share the root's user-content controller. A
    // logically closed root remains in the bounded native pool until the
    // family's last tab closes or the whole family is evicted.
  }

  String _target(String? id) =>
      id ?? _activeTabId ?? (throw StateError('browser_no_active_tab'));

  Future<void> navigate(String input, {String? tabId}) async {
    final id = _target(tabId);
    _checkAction(id);
    final url = normalizeAddress(input, searchEngine: _settings.searchEngine);
    _htmlDocuments.remove(id);
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index >= 0) _tabs[index] = _tabs[index].copyWith(hasContent: false);
    final revision = (_navigationRevisions[id] ?? 0) + 1;
    _navigationRevisions[id] = revision;
    var created = false;
    _updateTab(id, BrowserPageState(url: url, isLoading: true, progress: 0));
    final engine = await _engine(id, onCreated: () => created = true);
    _checkAction(id);
    requireTab(id);
    if (_navigationRevisions[id] != revision) return;
    if (!created) {
      await engine.navigate(url).timeout(const Duration(seconds: 30));
    }
  }

  Future<void> loadHtml(
    String html, {
    required String tabId,
    String? baseUrl,
    String? title,
  }) async {
    if (baseUrl != null && !_isPageUrl(baseUrl)) {
      throw const FormatException('Invalid base URL');
    }
    _checkAction(tabId);
    if (html.length > 1024 * 1024) {
      throw ArgumentError('Browser HTML exceeds 1 MiB');
    }
    _invalidatePreview(tabId);
    _notify();
    await _call(tabId, (engine) => engine.loadHtml(html, baseUrl: baseUrl));
    _htmlDocuments[tabId] = (
      html: html,
      baseUrl: baseUrl,
      documentUrl: baseUrl ?? 'about:blank',
    );
    final index = _tabs.indexWhere((tab) => tab.id == tabId);
    if (index >= 0) _tabs[index] = _tabs[index].copyWith(hasContent: true);
    _notify();
    if (title != null) _updateTab(tabId, BrowserPageState(title: title));
  }

  Future<void> back({String? tabId}) {
    final id = _target(tabId);
    return _call(id, (engine) {
      _invalidatePreview(id);
      _notify();
      return engine.back();
    });
  }

  Future<void> forward({String? tabId}) {
    final id = _target(tabId);
    return _call(id, (engine) {
      _invalidatePreview(id);
      _notify();
      return engine.forward();
    });
  }

  Future<void> reload({String? tabId}) {
    final id = _target(tabId);
    return _call(id, (engine) {
      _invalidatePreview(id);
      _notify();
      return engine.reload();
    });
  }

  Future<void> stop({String? tabId}) =>
      _call(_target(tabId), (engine) => engine.stop());
  Future<Object?> evaluateJavascript(
    String source, {
    required String tabId,
    bool awaitPromise = false,
  }) => _call(
    tabId,
    (engine) => engine.evaluate(source, awaitPromise: awaitPromise),
  );
  Future<Uint8List?> captureScreenshot({required String tabId}) =>
      _call(tabId, (engine) => engine.screenshot());

  /// Memory-only last views survive panel dismissal and ordinary engine eviction.
  /// A separate cache budget bounds their count; navigation/close discards the
  /// old image without imposing a limit on saved tabs.
  Uint8List? previewForTab(String id) => _tabPreviews[id];

  /// A visible chat card requests snapshots of an already-existing renderer.
  /// This never creates, selects, resizes or resumes a WebView. Updates are
  /// event driven (page loaded / action finished), merged and capped at 1 Hz.
  VoidCallback watchTabPreview(String id) {
    _previewWatchers.update(id, (count) => count + 1, ifAbsent: () => 1);
    if (!_tabPreviews.containsKey(id) && !_hasVisibleView(id)) {
      _scheduleChatPreview(id);
    }
    var released = false;
    return () {
      if (released) return;
      released = true;
      final remaining = (_previewWatchers[id] ?? 1) - 1;
      if (remaining > 0) {
        _previewWatchers[id] = remaining;
      } else {
        _previewWatchers.remove(id);
        _chatPreviewTimers.remove(id)?.cancel();
        _chatPreviewTimes.remove(id);
      }
    };
  }

  void _scheduleChatPreview(String id) {
    if (_disposed ||
        !_previewForeground ||
        !_previewWatchers.containsKey(id) ||
        _chatPreviewTimers.containsKey(id)) {
      return;
    }
    final elapsed = DateTime.now()
        .difference(
          _chatPreviewTimes[id] ?? DateTime.fromMillisecondsSinceEpoch(0),
        )
        .inMilliseconds;
    final delay = (1000 - elapsed).clamp(150, 1000);
    _chatPreviewTimers[id] = Timer(Duration(milliseconds: delay), () {
      _chatPreviewTimers.remove(id);
      if (_disposed ||
          !_previewForeground ||
          !_previewWatchers.containsKey(id)) {
        return;
      }
      final tab = _tabs.where((tab) => tab.id == id).firstOrNull;
      final engine = _engines[id];
      if (tab == null ||
          engine == null ||
          tab.isLoading ||
          tab.error != null ||
          (tab.url == 'about:blank' && !tab.hasContent)) {
        return;
      }
      final existing = _previewFlights[id];
      if (existing != null) {
        // One trailing request, not another capture alongside the native one.
        unawaited(existing.future.then((_) => _scheduleChatPreview(id)));
        return;
      }
      _chatPreviewTimes[id] = DateTime.now();
      unawaited(
        _startPreviewCapture(tab, engine, allowLoading: false, observed: true),
      );
    });
  }

  void _invalidatePreview(String id) {
    _previewEpochs[id] = (_previewEpochs[id] ?? 0) + 1;
    _tabPreviews.remove(id);
    _previewCompletedEpochs.remove(id);
    _previewPending.remove(id);
  }

  bool _canPreview(BrowserTab? tab, {bool allowLoading = false}) =>
      !_disposed &&
      tab != null &&
      tab.id == _activeTabId &&
      _mountedTabs.containsKey(tab.id) &&
      (_viewHosts[tab.id]?.any(
            (host) =>
                host._previewVisible &&
                !host._duplicate &&
                host._nativeView != null &&
                (defaultTargetPlatform != TargetPlatform.android ||
                    !host._attaching),
          ) ??
          false) &&
      _engines.containsKey(tab.id) &&
      (allowLoading || !tab.isLoading) &&
      tab.error == null &&
      (tab.url != 'about:blank' || tab.hasContent);

  void _captureLoadedPreview(String id) {
    final tab = activeTab;
    if (tab?.id != id || !_canPreview(tab)) return;
    final epoch = _previewEpochs[id] ?? 0;
    if (_previewCompletedEpochs[id] == epoch) return;
    if (_previewFlights[id]?.wasLoading == true) {
      _previewPending.add(id);
      return;
    }
    unawaited(refreshActivePreview());
  }

  /// Never creates/resumes an inactive renderer. Tab changes start this before
  /// detaching the old host, without waiting for image encoding to finish.
  Future<void> refreshActivePreview({bool fresh = false}) {
    final tab = activeTab;
    if (!_canPreview(tab, allowLoading: fresh)) return Future<void>.value();
    final id = tab!.id;
    final epoch = _previewEpochs[id] ?? 0;
    final existing = _previewFlights[id];
    if (existing != null) {
      // A tab-overview request must sample the current viewport, not join an
      // older idle capture that may have started before the last scroll.
      if (fresh) {
        return existing.future.then((_) {
          if (activeTabId == id && (_previewEpochs[id] ?? 0) == epoch) {
            return refreshActivePreview(fresh: true);
          }
        });
      }
      if (existing.epoch != epoch) _previewPending.add(id);
      return existing.future;
    }
    return _startPreviewCapture(tab, _engines[id]!, allowLoading: fresh);
  }

  Future<void> _startPreviewCapture(
    BrowserTab tab,
    BrowserEngine engine, {
    required bool allowLoading,
    bool observed = false,
  }) {
    final id = tab.id;
    final epoch = _previewEpochs[id] ?? 0;
    late final Future<void> future;
    future =
        _capturePreview(
          tab,
          engine,
          epoch,
          allowLoading: allowLoading,
          observed: observed,
        ).whenComplete(() {
          if (identical(_previewFlights[id]?.future, future)) {
            _previewFlights.remove(id);
          }
          if (_previewPending.remove(id) && activeTabId == id) {
            unawaited(refreshActivePreview());
          }
        });
    _previewFlights[id] = (
      epoch: epoch,
      wasLoading: tab.isLoading,
      future: future,
    );
    return future;
  }

  Future<void> _capturePreview(
    BrowserTab before,
    BrowserEngine engine,
    int epoch, {
    required bool allowLoading,
    required bool observed,
  }) async {
    try {
      // A timed-out native encoder may still be running. Wait for it, but
      // discard its pixels: they belong to an older document or viewport.
      final pending = _nativePreviewFlights[before.id];
      if (pending != null && identical(pending.engine, engine)) {
        try {
          await pending.future.timeout(const Duration(seconds: 2));
        } on TimeoutException {
          return;
        } catch (_) {
          // Its failure does not prevent a new snapshot of the current page.
        }
        if (_disposed ||
            (_previewEpochs[before.id] ?? 0) != epoch ||
            !identical(_engines[before.id], engine) ||
            (observed
                ? !_previewForeground ||
                      !_previewWatchers.containsKey(before.id)
                : !_canPreview(activeTab, allowLoading: allowLoading) ||
                      activeTabId != before.id)) {
          return;
        }
      }
      final future = Future<Uint8List?>.sync(engine.thumbnail);
      _nativePreviewFlights[before.id] = (engine: engine, future: future);
      void clear() {
        if (identical(_nativePreviewFlights[before.id]?.future, future)) {
          _nativePreviewFlights.remove(before.id);
        }
      }

      unawaited(future.then((_) => clear(), onError: (Object _) => clear()));
      final bytes = await future.timeout(const Duration(seconds: 2));
      final current = _tabs.where((tab) => tab.id == before.id).firstOrNull;
      if (_disposed ||
          bytes == null ||
          bytes.isEmpty ||
          bytes.length > 2 * 1024 * 1024 ||
          current == null ||
          current.url != before.url ||
          current.runtimeVersion != before.runtimeVersion ||
          (!allowLoading && current.isLoading) ||
          current.error != null ||
          (_previewEpochs[before.id] ?? 0) != epoch ||
          !identical(_engines[before.id], engine)) {
        return;
      }
      _tabPreviews.remove(before.id);
      _tabPreviews[before.id] = bytes;
      while (_tabPreviews.length > maxCachedPreviews) {
        final oldest = _tabPreviews.keys.firstWhere(
          (id) => id != _activeTabId && id != before.id,
        );
        _tabPreviews.remove(oldest);
        _previewCompletedEpochs.remove(oldest);
      }
      if (!before.isLoading && !current.isLoading) {
        _previewCompletedEpochs[before.id] = epoch;
      }
      _notify();
    } catch (_) {
      // A hidden/terminated native view may not produce a snapshot. Keep its
      // previous valid last-view image and never fail navigation for a preview.
    }
  }

  Future<void> findInPage(String text, {String? tabId}) =>
      _call(_target(tabId), (engine) => engine.find(text));
  Future<void> findNext({bool forward = true, String? tabId}) =>
      _call(_target(tabId), (engine) => engine.findNext(forward));
  Future<void> clearFind({String? tabId}) =>
      _call(_target(tabId), (engine) => engine.clearFind());

  Future<T> _call<T>(
    String id,
    Future<T> Function(BrowserEngine) action,
  ) async {
    _checkAction(id);
    final engine = await _engine(id);
    _checkAction(id);
    requireTab(id);
    final T result;
    try {
      result = await action(engine).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      if (Zone.current[_actionKey] != null) {
        _pauseAgentActions(BrowserAgentPauseReason.timeout);
      }
      rethrow;
    }
    _checkAction(id);
    return result;
  }

  Future<void> waitForLoad({
    required String tabId,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    await _call(tabId, (engine) => engine.waitForLoad(timeout));
  }

  Future<BrowserEngine> _engine(String id, {VoidCallback? onCreated}) {
    _checkAction(id);
    requireTab(id);
    _idleTimer?.cancel();
    final ready = _engines.remove(id);
    if (ready != null) {
      _engines[id] = ready;
      return Future<BrowserEngine>.sync(() async {
        await ready.resume();
        _checkAction(id);
        requireTab(id);
        return ready;
      });
    }
    final completer = Completer<BrowserEngine>();
    final operation = (_runtimeQueue ?? Future<void>.value()).then((_) async {
      _checkAction(id);
      var tab = requireTab(id);
      if (!isSupported) throw UnsupportedError('browser_platform_unsupported');
      final existing = _engines.remove(id);
      if (existing != null) {
        _engines[id] = existing;
        await existing.resume();
        return existing;
      }
      if (_engines.length >= maxLiveViews) {
        String? evictionGroup() {
          for (final key in _engines.keys) {
            final group = _engineGroups[key] ?? key;
            if (tab.windowId != null && group == tab.popupGroupId) continue;
            final pinned = _engines.keys.any(
              (candidate) =>
                  (_engineGroups[candidate] ?? candidate) == group &&
                  (_hasVisibleView(candidate) ||
                      candidate == _activeTabId ||
                      (_runningAgentGuard != null && candidate == _agentTabId)),
            );
            if (!pinned) return group;
          }
          return null;
        }

        var oldestGroup = evictionGroup();
        if (oldestGroup == null &&
            _mountedTabs.keys.any((key) => key != id && key != _activeTabId)) {
          // The incoming host can be built before the previous host's
          // disposal in this frame. Give that host its scheduled detach.
          await WidgetsBinding.instance.endOfFrame.timeout(
            const Duration(seconds: 3),
          );
          oldestGroup = evictionGroup();
        }
        if (oldestGroup == null) throw StateError('browser_live_view_limit');
        await _disposeEngineGroup(oldestGroup);
      }
      // Evicting a popup family detaches its saved URLs, including a crashed
      // member being reopened. Use that member's new runtime identity.
      _checkAction(id);
      tab = requireTab(id);
      var abandoned = false;
      bool isCurrent() =>
          !_disposed &&
          !abandoned &&
          _tabs
                  .where((candidate) => candidate.id == id)
                  .firstOrNull
                  ?.runtimeVersion ==
              tab.runtimeVersion;
      final creating = runZoned(
        () => _engineFactory(
          tab: tab,
          settings: _settings,
          onChanged: (state) {
            if (isCurrent()) _updateTab(id, state);
          },
          onDownload: (url, name) {
            if (isCurrent()) {
              unawaited(
                download(
                  url,
                  fileName: name,
                  tabId: id,
                ).catchError((Object _) {}),
              );
            }
          },
          onNewWindow: (url, windowId) async {
            if (!isCurrent()) return false;
            final group = tab.popupGroupId ?? id;
            final popupGuard =
                _isRunningAgentAction &&
                    (_agentTabId == id || _engineGroups[_agentTabId] == group)
                ? _runningAgentGuard
                : null;
            BrowserTab? child;
            try {
              // Native events outlive the action that created their engine.
              // Apply only the triggering action's tab quota and selection;
              // later engine completion must not retarget a newer action.
              child = await runZoned<Future<BrowserTab>>(
                () => createTab(
                  url: url,
                  ownerSessionId: requireTab(id).ownerSessionId,
                  windowId: windowId,
                  openerTabId: id,
                  popupGroupId: group,
                ),
                zoneValues: {_actionKey: popupGuard},
              );
              await _engine(child.id);
              return true;
            } catch (_) {
              if (child != null) await closeTab(child.id);
              return false;
            }
          },
          isAgentActive: () => _isRunningAgentAction && _agentTabId == id,
        ),
        zoneValues: {_actionKey: null},
      );
      unawaited(
        creating.then<void>((engine) async {
          if (abandoned) await engine.dispose();
        }, onError: (Object _, StackTrace __) {}),
      );
      final engine = await creating.timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          abandoned = true;
          throw TimeoutException('browser_engine_creation_timeout');
        },
      );
      if (_disposed || !_tabs.any((tab) => tab.id == id)) {
        await engine.dispose();
        throw StateError('browser_tab_closed');
      }
      try {
        _checkAction(id);
      } catch (_) {
        await engine.dispose();
        rethrow;
      }
      if (requireTab(id).runtimeVersion != tab.runtimeVersion) {
        await engine.dispose();
        throw StateError('browser_renderer_terminated');
      }
      _engines[id] = engine;
      _engineGroups[id] = tab.popupGroupId ?? id;
      final currentIndex = _tabs.indexWhere((candidate) => candidate.id == id);
      if (currentIndex >= 0) {
        _tabs[currentIndex] = _tabs[currentIndex].copyWith(clearWindowId: true);
      }
      onCreated?.call();
      final document = _htmlDocuments[id];
      if (document != null) {
        await engine.loadHtml(document.html, baseUrl: document.baseUrl);
      }
      _scheduleIdleRelease();
      return engine;
    });
    operation.then(completer.complete, onError: completer.completeError);
    _runtimeQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return completer.future;
  }

  void _updateTab(String id, BrowserPageState state) {
    if (_disposed) return;
    if (state.scroll != null) {
      _scrollStates[id] = state.scroll!;
      scrollPosition.value = (tabId: id, state: state.scroll!);
      return;
    }
    if (state.closeRequested) {
      unawaited(closeTab(id));
      return;
    }
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index < 0) return;
    var old = _tabs[index];
    if (state.favicon != null) {
      if (state.faviconPageUrl != null &&
          !old.isLoading &&
          browserFaviconDocument(state.faviconPageUrl!) ==
              browserFaviconDocument(old.url)) {
        _cacheFavicon(old.url, state.favicon!);
        _notify();
      }
      return;
    }
    if (state.isLoading == true ||
        state.replacesRenderedDocument ||
        (state.url != null && state.url != old.url)) {
      _invalidatePreview(id);
    }
    final document = _htmlDocuments[id];
    if (document != null &&
        (state.replacesRenderedDocument ||
            (state.isLoading == true &&
                state.url != null &&
                Uri.tryParse(state.url!)?.replace(fragment: '').toString() !=
                    Uri.tryParse(
                      document.documentUrl,
                    )?.replace(fragment: '').toString()))) {
      _htmlDocuments.remove(id);
      old = old.copyWith(hasContent: false, error: old.error);
    }
    final tab = old.copyWith(
      url: state.url,
      title: state.title,
      isLoading: state.isLoading,
      progress: state.progress,
      canGoBack: state.canGoBack,
      canGoForward: state.canGoForward,
      error: state.error ?? (state.isLoading == true ? null : old.error),
    );
    _tabs[index] = tab;
    if (state.rendererTerminated) {
      _tabs[index] = tab.copyWith(
        runtimeVersion: tab.runtimeVersion + 1,
        error: tab.error,
      );
      final retired = _engines.remove(id);
      _nativePreviewFlights.remove(id);
      _engineGroups.remove(id);
      if (retired != null) unawaited(_disposeRetired(id, retired));
    }
    if (state.completedNavigation &&
        state.error == null &&
        _settings.saveHistory &&
        tab.url != 'about:blank' &&
        _isPageUrl(tab.url)) {
      _history.removeWhere((entry) => entry.url == tab.url);
      _history.insert(
        0,
        BrowserHistoryEntry(
          url: tab.url,
          title: tab.title,
          visitedAt: DateTime.now(),
        ),
      );
      if (_history.length > maxHistory) _history.removeLast();
    }
    // Progress updates only repaint listeners; persistent snapshots omit them.
    if (old.url != tab.url ||
        old.title != tab.title ||
        state.isLoading == false) {
      _scheduleSave();
    }
    _notify();
    if (state.completedNavigation && state.error == null) {
      _captureLoadedPreview(id);
      if (!_hasVisibleView(id)) _scheduleChatPreview(id);
    }
  }

  Future<void> _disposeEngineGroup(String group) async {
    final pending = _closingGroups[group];
    if (pending != null) {
      await pending;
      return;
    }
    final releasing = _releaseEngineGroup(group);
    _closingGroups[group] = releasing;
    try {
      await releasing;
    } finally {
      if (identical(_closingGroups[group], releasing)) {
        _closingGroups.remove(group);
      }
    }
  }

  Future<void> _releaseEngineGroup(String group) async {
    final ids = _engines.keys
        .where((id) => (_engineGroups[id] ?? id) == group)
        .toList();
    // Children release their scoped resources before the root releases the
    // shared WKUserContentController and its message handlers.
    ids.sort((a, b) => (a == group ? 1 : 0).compareTo(b == group ? 1 : 0));
    // Remove the whole family from acquisition before yielding to detach.
    // A tab selected during eviction must queue a fresh runtime, never bind
    // the old instance that this operation is about to destroy.
    final retired = {for (final id in ids) id: _engines.remove(id)};
    for (final id in ids) {
      _nativePreviewFlights.remove(id);
      _engineGroups.remove(id);
    }
    for (var index = 0; index < _tabs.length; index++) {
      final tab = _tabs[index];
      if ((tab.popupGroupId ?? tab.id) == group) {
        _tabs[index] = tab.copyWith(
          detachPopup: true,
          clearWindowId: true,
          runtimeVersion: tab.runtimeVersion + 1,
          error: tab.error,
        );
      }
    }
    if (ids.any(_mountedTabs.containsKey)) {
      _notify();
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
    }
    Object? failure;
    StackTrace? failureStack;
    for (final id in ids) {
      try {
        await retired[id]?.dispose();
      } catch (error, stack) {
        failure ??= error;
        failureStack ??= stack;
      }
    }
    if (failure != null) Error.throwWithStackTrace(failure, failureStack!);
  }

  Future<void> _disposeRetired(String id, BrowserEngine engine) async {
    if (_mountedTabs.containsKey(id)) await WidgetsBinding.instance.endOfFrame;
    await engine.dispose();
  }

  Future<void> toggleBookmark({String? tabId}) async {
    final tab = requireTab(_target(tabId));
    if (_bookmarks.any((entry) => entry.url == tab.url)) {
      await removeBookmark(tab.url);
    } else {
      await addBookmark(url: tab.url, title: tab.title);
    }
  }

  Future<void> addBookmark({required String url, required String title}) async {
    await initialize();
    if (!_isPageUrl(url) || url == 'about:blank') {
      throw const FormatException('Bookmark requires a web page');
    }
    _bookmarks.removeWhere((entry) => entry.url == url);
    _bookmarks.insert(
      0,
      BrowserBookmark(url: url, title: title, createdAt: DateTime.now()),
    );
    _notify();
    await flush();
  }

  Future<void> removeBookmark(String url) async {
    _bookmarks.removeWhere((entry) => entry.url == url);
    _notify();
    await flush();
  }

  Future<void> clearHistory() async {
    _history.clear();
    _notify();
    await flush();
  }

  Future<void> removeHistory(String url) async {
    _history.removeWhere((entry) => entry.url == url);
    _notify();
    await flush();
  }

  Future<void> updateSettings(BrowserSettings settings) async {
    if (!BrowserSettings.isValidUserAgent(settings.customUserAgent)) {
      throw const FormatException('Invalid browser User-Agent');
    }
    settings = settings.copyWith(
      customUserAgent: settings.customUserAgent.trim(),
    );
    await initialize();
    final old = _settings;
    _settings = settings;
    if (!settings.agentEnabled && old.agentEnabled) {
      _clearAgentPause();
      _invalidateAgentActions();
    }
    final userAgentChanged =
        settings.desktopMode != old.desktopMode ||
        settings.customUserAgent != old.customUserAgent;
    // Merely opening settings is observation. Applying a different UA reloads
    // the document, so hand control over before changing a running task's page.
    if (userAgentChanged && _isRunningAgentAction) {
      takeOver(sessionId: _agentSessionId, tabId: _agentTabId);
    }
    if (userAgentChanged || settings.surfaceStyle != old.surfaceStyle) {
      for (final engine in _engines.values.toList()) {
        await engine.updateSettings(settings);
      }
    }
    if (userAgentChanged) {
      final tab = activeTab;
      if (tab != null &&
          tab.url != 'about:blank' &&
          _engines.containsKey(tab.id)) {
        await reload(tabId: tab.id);
      }
    }
    _notify();
    await flush();
  }

  Future<void> clearWebsiteData() async {
    if (!supportsWebsiteDataClear) {
      throw UnsupportedError('browser_website_data_clear_unsupported');
    }
    _clearingWebsiteData = true;
    try {
      _clearAgentPause();
      _invalidateAgentActions();
      for (final id in _tabs.map((tab) => tab.id).toList()) {
        await closeTab(id);
      }
      _favicons.clear();
      _notify();
      await NativeBrowserEngine.clearWebsiteData();
      await flush();
    } finally {
      _clearingWebsiteData = false;
    }
  }

  Future<T> runAgentAction<T>({
    required String sessionId,
    required String label,
    String? tabId,
    required Future<T> Function() action,
  }) async {
    await initialize();
    if (!_settings.agentEnabled) throw StateError('browser_agent_disabled');
    if (_clearingWebsiteData) throw StateError('browser_clearing_website_data');
    if (_agentPaused) throw StateError('browser_human_control');
    if (sessionId.isEmpty) {
      throw ArgumentError('Browser actions require a session');
    }
    final cancellation = ToolCallCancellation.current;
    cancellation?.throwIfCancelled();
    final guard = _BrowserAction(
      sessionId,
      _controlEpoch,
      _sessionEpochs[sessionId] ?? 0,
      cancellation,
    );
    final controlCancelled = _controlCancelled.future;
    final sessionCancelled =
        (_sessionCancellation[sessionId] ??= Completer<void>()).future;
    final result = Completer<T>();
    final operation = (_agentQueue ?? Future<void>.value()).then(
      (_) => runZoned(() async {
        _checkAction(tabId);
        _agentSessionId = sessionId;
        _agentAction = label;
        _runningAgentGuard = guard;
        _notify();
        final running = Future<T>.sync(action);
        var cancellationRelevant = true;
        try {
          final value = await Future.any<T>([
            running,
            controlCancelled.then<T>(
              (_) =>
                  throw StateError('browser_action_cancelled_outcome_unknown'),
            ),
            sessionCancelled.then<T>(
              (_) =>
                  throw StateError('browser_action_cancelled_outcome_unknown'),
            ),
            if (cancellation != null)
              cancellation.cancelled.then<T>((_) {
                if (cancellationRelevant) cancelAgentActions(sessionId);
                throw StateError('browser_action_cancelled_outcome_unknown');
              }),
          ]);
          _checkAction();
          if (_agentTabId case final id?) _scheduleChatPreview(id);
          result.complete(value);
        } catch (error, stack) {
          result.completeError(error, stack);
        } finally {
          // Cancellation returns immediately, but the native-operation queue
          // remains occupied until the existing operation actually settles.
          try {
            await running;
          } catch (_) {}
          cancellationRelevant = false;
          _agentSessionId = null;
          _agentAction = null;
          _agentTabId = null;
          _runningAgentGuard = null;
          _pauseDetachedViews();
          _scheduleIdleRelease();
          _notify();
        }
      }, zoneValues: {_actionKey: guard}),
    );
    _agentQueue = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        if (!result.isCompleted) result.completeError(error, stack);
      },
    );
    return result.future;
  }

  void _checkAction([String? tabId]) {
    if (_disposed) throw StateError('browser_disposed');
    final guard = Zone.current[_actionKey] as _BrowserAction?;
    if (guard == null) return;
    guard.cancellation?.throwIfCancelled();
    if (!_settings.agentEnabled ||
        _agentPaused ||
        guard.epoch != _controlEpoch ||
        guard.sessionEpoch != (_sessionEpochs[guard.sessionId] ?? 0)) {
      throw StateError('browser_action_cancelled_outcome_unknown');
    }
    if (tabId != null) {
      requireAgentTab(guard.sessionId, tabId);
      _agentTabId = tabId;
      if (_lastTabBySession[guard.sessionId] != tabId) {
        _lastTabBySession[guard.sessionId] = tabId;
        _scheduleSave();
      }
    }
  }

  void takeOver({String? sessionId, String? tabId}) {
    _pauseAgentActions(
      BrowserAgentPauseReason.user,
      sessionId: sessionId,
      tabId: tabId,
    );
  }

  void _pauseAgentActions(
    BrowserAgentPauseReason reason, {
    String? sessionId,
    String? tabId,
  }) {
    _agentPaused = true;
    _agentPauseReason = reason;
    _pausedAgentSessionId =
        sessionId ?? _agentSessionId ?? activeTab?.ownerSessionId;
    _pausedAgentTabId = tabId ?? _agentTabId ?? _activeTabId;
    _invalidateAgentActions();
  }

  void _invalidateAgentActions() {
    _controlEpoch++;
    _controlCancelled.complete();
    _controlCancelled = Completer<void>();
    for (final engine in _engines.values) {
      unawaited(engine.stop().catchError((Object _) {}));
    }
    _notify();
  }

  void allowAgentControl({String? sessionId}) {
    if (sessionId != null &&
        _pausedAgentSessionId != null &&
        sessionId != _pausedAgentSessionId) {
      return;
    }
    _clearAgentPause();
    _notify();
  }

  void _clearAgentPause() {
    _agentPaused = false;
    _agentPauseReason = null;
    _pausedAgentSessionId = null;
    _pausedAgentTabId = null;
  }

  void cancelAgentActions(String sessionId) {
    _sessionEpochs[sessionId] = (_sessionEpochs[sessionId] ?? 0) + 1;
    _sessionCancellation.remove(sessionId)?.complete();
    for (final tab in _tabs.where((tab) => tab.ownerSessionId == sessionId)) {
      unawaited(
        _engines[tab.id]?.stop().catchError((Object _) {}) ??
            Future<void>.value(),
      );
    }
    _notify();
  }

  bool _hasVisibleView(String id) =>
      _viewHosts[id]?.any((host) => !host._duplicate && host._previewVisible) ??
      false;

  void _pauseDetachedViews() {
    for (final entry in _engines.entries) {
      if (!_hasVisibleView(entry.key)) {
        unawaited(entry.value.setVisible(false).catchError((Object _) {}));
      }
    }
  }

  void _scheduleIdleRelease() {
    _idleTimer?.cancel();
    if (_mountedTabs.isNotEmpty || _agentAction != null || _disposed) return;
    _idleTimer = Timer(const Duration(minutes: 30), () {
      final operation = (_runtimeQueue ?? Future<void>.value()).then((_) async {
        if (_mountedTabs.isNotEmpty || _agentAction != null || _disposed) {
          return;
        }
        for (final group in _engineGroups.values.toSet().toList()) {
          await _disposeEngineGroup(group);
        }
      });
      _runtimeQueue = operation.then<void>(
        (_) {},
        onError: (Object _, StackTrace __) {},
      );
    });
  }

  Future<void> download(String url, {String? fileName, String? tabId}) async {
    if (!_isPageUrl(url) || url == 'about:blank') {
      throw const FormatException('Only HTTP downloads are supported');
    }
    final id = _uuid.v4();
    var name = p.basename(fileName ?? Uri.parse(url).path);
    name = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_');
    if (name.isEmpty || name == '.' || name == '..') name = 'download';
    if (name.length > 160) name = name.substring(name.length - 160);
    final directory = Directory(
      p.join((await _store.directory).path, 'downloads'),
    );
    await directory.create(recursive: true);
    final path = p.join(directory.path, '$id-$name');
    final token = CancelToken();
    _downloadTokens[id] = token;
    _downloads.insert(0, BrowserDownload(id: id, url: url, fileName: name));
    _notify();
    final client = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
    try {
      final engine = _engines[tabId ?? _activeTabId];
      var lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
      var current = Uri.parse(url);
      for (var redirects = 0; ; redirects++) {
        final headers =
            await engine?.downloadHeaders(current.toString()) ??
            <String, String>{};
        final response = await client.download(
          current.toString(),
          path,
          cancelToken: token,
          options: Options(
            headers: headers,
            followRedirects: false,
            validateStatus: (status) =>
                status != null && status >= 200 && status < 400,
          ),
          onReceiveProgress: (received, total) {
            final now = DateTime.now();
            if (now.difference(lastUpdate).inMilliseconds < 100 &&
                received != total) {
              return;
            }
            lastUpdate = now;
            _updateDownload(
              id,
              (entry) =>
                  entry.copyWith(receivedBytes: received, totalBytes: total),
            );
          },
        );
        if ((response.statusCode ?? 0) < 300) break;
        final location = response.headers.value('location');
        if (location == null || redirects >= 5) {
          throw const HttpException('Invalid download redirect');
        }
        final next = current.resolve(location);
        if (!_isPageUrl(next.toString()) ||
            (current.scheme == 'https' && next.scheme != 'https')) {
          throw const HttpException('Unsafe download redirect');
        }
        current = next;
      }
      _updateDownload(
        id,
        (entry) =>
            entry.copyWith(path: path, status: BrowserDownloadStatus.completed),
      );
    } catch (error) {
      _updateDownload(
        id,
        (entry) => entry.copyWith(
          status: token.isCancelled
              ? BrowserDownloadStatus.cancelled
              : BrowserDownloadStatus.failed,
          error: error.toString(),
        ),
      );
      final file = File(path);
      if (await file.exists()) await file.delete();
    } finally {
      client.close();
      _downloadTokens.remove(id);
      await flush();
    }
  }

  void _updateDownload(
    String id,
    BrowserDownload Function(BrowserDownload) update,
  ) {
    final index = _downloads.indexWhere((entry) => entry.id == id);
    if (index >= 0) {
      _downloads[index] = update(_downloads[index]);
      _notify();
    }
  }

  void cancelDownload(String id) {
    _downloadTokens[id]?.cancel();
  }

  Future<void> removeDownload(String id) async {
    cancelDownload(id);
    _downloads.removeWhere((entry) => entry.id == id);
    _notify();
    await flush();
  }

  /// Keep already visited platform views mounted until their bounded runtime
  /// is evicted. Tab selection only changes which child is painted.
  Widget buildViewport({
    bool deferNewViews = false,
    double previewTopInset = 0,
  }) => _BrowserTabViewport(
    service: this,
    deferNewViews: deferNewViews,
    previewTopInset: previewTopInset,
  );

  /// A retained viewport has completed its native attachment (or displayed its
  /// error). Used to hand off a tab flight without exposing an empty UIKit frame.
  bool isTabPresented(String id) =>
      _viewHosts[id]?.any(
        (host) =>
            host.mounted &&
            !host._duplicate &&
            host._previewVisible &&
            (host._attachmentError != null ||
                (host._nativeView != null && !host._attaching)),
      ) ??
      false;

  Widget buildView(
    String tabId, {
    bool visible = true,
    bool deferCreation = false,
    double previewTopInset = 0,
  }) => _BrowserViewHost(
    key: ValueKey('$tabId:${requireTab(tabId).runtimeVersion}'),
    service: this,
    tabId: tabId,
    visible: visible,
    deferCreation: deferCreation,
    previewTopInset: previewTopInset,
  );

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _changed() {
    _notify();
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(
        flush().catchError((Object error) {
          persistenceError = error.toString();
          _notify();
        }),
      );
    });
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    if (!_initialized) return;
    // The icon cache must not become a second history when history/tab
    // persistence is disabled or the user clears the saved page lists.
    final retainedSites = <String?>{
      for (final entry in _bookmarks) browserFaviconSite(entry.url),
      for (final entry in _history) browserFaviconSite(entry.url),
      if (_settings.restoreTabs)
        for (final tab in _tabs) browserFaviconSite(tab.url),
    };
    await _store.write({
      'settings': _settings.toJson(),
      'tabs': _settings.restoreTabs
          ? _tabs.map((tab) => tab.toJson()).toList()
          : [],
      'activeTabId': _settings.restoreTabs ? _activeTabId : null,
      'lastTabBySession': _settings.restoreTabs ? _lastTabBySession : {},
      'bookmarks': _bookmarks.map((entry) => entry.toJson()).toList(),
      'history': _history.map((entry) => entry.toJson()).toList(),
      'downloads': _downloads.map((entry) => entry.toJson()).toList(),
      'favicons': [
        for (final icon in _favicons.entries)
          if (retainedSites.contains(icon.key))
            {'site': icon.key, 'png': base64Encode(icon.value)},
      ],
    });
    persistenceError = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    _previewForeground = resumed;
    if (!resumed) {
      for (final timer in _chatPreviewTimers.values) {
        timer.cancel();
      }
      _chatPreviewTimers.clear();
    } else {
      for (final id in _previewWatchers.keys) {
        _scheduleChatPreview(id);
      }
    }
    for (final entry in _engines.entries) {
      unawaited(
        entry.value
            .setVisible(resumed && _hasVisibleView(entry.key))
            .catchError((Object _) {}),
      );
    }
    if (!resumed) {
      unawaited(
        flush().catchError((Object error) {
          persistenceError = error.toString();
        }),
      );
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _clearAgentPause();
    _invalidateAgentActions();
    _disposed = true;
    _tabPreviews.clear();
    _nativePreviewFlights.clear();
    _favicons.clear();
    _previewPending.clear();
    for (final timer in _chatPreviewTimers.values) {
      timer.cancel();
    }
    _chatPreviewTimers.clear();
    _previewWatchers.clear();
    _chatPreviewTimes.clear();
    scrollPosition.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _idleTimer?.cancel();
    for (final token in _downloadTokens.values) {
      token.cancel();
    }
    final groups = _engineGroups.values.toSet().toList();
    unawaited(
      () async {
        for (final group in groups) {
          await _disposeEngineGroup(group);
        }
      }().catchError((Object _) {}),
    );
    super.dispose();
  }
}

class _BrowserAction {
  const _BrowserAction(
    this.sessionId,
    this.epoch,
    this.sessionEpoch,
    this.cancellation,
  );
  final String sessionId;
  final int epoch;
  final int sessionEpoch;
  final ToolCallCancellation? cancellation;
}

class _BrowserTabViewport extends StatefulWidget {
  const _BrowserTabViewport({
    required this.service,
    required this.deferNewViews,
    required this.previewTopInset,
  });
  final BrowserService service;
  final bool deferNewViews;
  final double previewTopInset;

  @override
  State<_BrowserTabViewport> createState() => _BrowserTabViewportState();
}

class _BrowserTabViewportState extends State<_BrowserTabViewport> {
  final Map<String, int> _visited = {};

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.service,
    builder: (context, _) {
      final service = widget.service;
      _visited.removeWhere(
        (id, version) => !service.tabs.any(
          (tab) => tab.id == id && tab.runtimeVersion == version,
        ),
      );
      final active = service.activeTab;
      if (active != null &&
          (active.hasContent || active.url != 'about:blank')) {
        _visited[active.id] = active.runtimeVersion;
      }
      final activeId = active?.id;
      // AppKit remounts platform-view mutators when their paint is omitted;
      // keeping its small native pool in the scene prevents desktop tab flashes.
      // UIKit/Android must not pay that composition cost for covered web pages.
      // Stable outer keys still retain their engines and navigation state.
      if (defaultTargetPlatform != TargetPlatform.macOS) {
        return Stack(
          fit: StackFit.expand,
          children: [
            for (final id in _visited.keys)
              Positioned.fill(
                key: ValueKey(id),
                child: Visibility(
                  visible: id == activeId,
                  maintainState: true,
                  child: service.buildView(
                    id,
                    visible: id == activeId,
                    deferCreation: widget.deferNewViews,
                    previewTopInset: widget.previewTopInset,
                  ),
                ),
              ),
          ],
        );
      }
      final hidden = _visited.keys.where((id) => id != activeId);
      final background = Theme.of(context).colorScheme.surface;
      return Stack(
        fit: StackFit.expand,
        children: [
          // Offstage preserves Dart state but removes the native NSView from
          // Flutter's compositor. Keep the bounded native pool in the scene;
          // switching tabs only changes its z order, never its attachment.
          for (final id in hidden)
            Positioned.fill(
              key: ValueKey(id),
              child: ExcludeFocus(
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: service.buildView(id, visible: false),
                  ),
                ),
              ),
            ),
          // A new tab's renderer may not exist yet and some pages are clear.
          // Never expose another tab through either gap. This backing stays
          // below the active WebView and outside the browser's glass chrome.
          ColoredBox(color: background),
          if (_visited.containsKey(activeId))
            Positioned.fill(
              key: ValueKey(activeId!),
              child: ExcludeFocus(
                excluding: false,
                child: ExcludeSemantics(
                  excluding: false,
                  child: IgnorePointer(
                    ignoring: false,
                    child: service.buildView(activeId),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _BrowserViewHost extends StatefulWidget {
  const _BrowserViewHost({
    super.key,
    required this.service,
    required this.tabId,
    required this.visible,
    required this.deferCreation,
    required this.previewTopInset,
  });
  final BrowserService service;
  final String tabId;
  final bool visible;
  final bool deferCreation;
  final double previewTopInset;
  @override
  State<_BrowserViewHost> createState() => _BrowserViewHostState();
}

class _BrowserViewHostState extends State<_BrowserViewHost> {
  final _engineCompletion = Completer<BrowserEngine>();
  late final Future<BrowserEngine> _engine = _engineCompletion.future;
  Animation<double>? _entryAnimation;
  Animation<double>? _coverAnimation;
  bool _engineStarted = false;
  bool _engineStartScheduled = false;
  int _attachmentEpoch = 0;
  Widget? _nativeView;
  bool _duplicate = false;
  bool _previewVisible = true;
  bool _attaching = true;
  Object? _attachmentError;
  @override
  void initState() {
    super.initState();
    final mounted = widget.service._mountedTabs;
    _duplicate = mounted.containsKey(widget.tabId);
    mounted[widget.tabId] = (mounted[widget.tabId] ?? 0) + 1;
    (widget.service._viewHosts[widget.tabId] ??= []).add(this);
    _engine.ignore();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_entryAnimation != route?.animation ||
        _coverAnimation != route?.secondaryAnimation) {
      _entryAnimation?.removeStatusListener(_routeMotionChanged);
      _coverAnimation?.removeStatusListener(_routeMotionChanged);
      _entryAnimation = route?.animation;
      _coverAnimation = route?.secondaryAnimation;
      _entryAnimation?.addStatusListener(_routeMotionChanged);
      _coverAnimation?.addStatusListener(_routeMotionChanged);
    }
    _synchronizeVisibility();
    _startEngineWhenSettled();
  }

  void _routeMotionChanged(AnimationStatus _) => _startEngineWhenSettled();

  bool get _presentationSettled =>
      !widget.deferCreation &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          ((_entryAnimation == null ||
                  _entryAnimation!.status == AnimationStatus.completed) &&
              (_coverAnimation == null ||
                  _coverAnimation!.status == AnimationStatus.dismissed)));

  void _startEngineWhenSettled() {
    if (_engineStarted ||
        _engineStartScheduled ||
        !_presentationSettled ||
        !_previewVisible) {
      return;
    }
    _engineStartScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _engineStartScheduled = false;
      if (!mounted ||
          _engineStarted ||
          !_presentationSettled ||
          !_previewVisible) {
        return;
      }
      _engineStarted = true;
      // Native WKWebView/process creation can block UIKit's main thread. Paint
      // the route first, and keep it out of entry and covered-route animations.
      widget.service
          ._engine(widget.tabId)
          .then(
            _engineCompletion.complete,
            onError: (Object error, StackTrace stack) {
              _engineCompletion.completeError(error, stack);
              if (!mounted) return;
              _attachmentError = error;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) widget.service._notify();
              });
            },
          );
    });
  }

  @override
  void didUpdateWidget(_BrowserViewHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible ||
        oldWidget.deferCreation != widget.deferCreation) {
      _synchronizeVisibility();
      _startEngineWhenSettled();
    }
  }

  void _synchronizeVisibility() {
    // Overlay retains a route below an opaque settings/library page with
    // TickerMode disabled, without inserting a Visibility scope. Such a page
    // must not keep native playback or request new thumbnail snapshots.
    final visible =
        widget.visible &&
        Visibility.of(context) &&
        TickerMode.valuesOf(context).enabled;
    if (visible && !_previewVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_duplicate && _previewVisible) {
          widget.service._captureLoadedPreview(widget.tabId);
        }
      });
    }
    if (_previewVisible != visible) {
      _attachmentEpoch++;
      if (visible && _nativeView != null) {
        // An opaque route removes UIKit's paint but retains its Dart host.
        // Re-cover that reattachment with the already decoded page image.
        _attaching = true;
        _engine.then((engine) {
          if (mounted && !_duplicate && _previewVisible) {
            unawaited(_finishAttachment(engine));
          }
        }, onError: (Object _) {});
      }
      _engine.then((engine) {
        if (!mounted || _duplicate) return;
        unawaited(engine.setVisible(_previewVisible).catchError((Object _) {}));
      }, onError: (Object _) {});
    }
    _previewVisible = visible;
  }

  Widget _preview() {
    final bytes = widget.service.previewForTab(widget.tabId);
    return bytes == null
        ? const SizedBox.expand()
        : Padding(
            padding: EdgeInsets.only(top: widget.previewTopInset),
            child: ClipRect(
              child: Image.memory(
                bytes,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const SizedBox.expand(),
              ),
            ),
          );
  }

  Future<void> _finishAttachment(BrowserEngine engine) async {
    final epoch = ++_attachmentEpoch;
    try {
      await engine.viewReady;
    } catch (error) {
      if (mounted && epoch == _attachmentEpoch) {
        setState(() {
          _attachmentError = error;
          _attaching = false;
        });
        widget.service._notify();
      }
      return;
    }
    if (!mounted) return;
    // The old owner may have paused the shared engine while this duplicate
    // host waited for promotion. Apply the new owner's current visibility
    // after its native view has attached, including rapid tab changes.
    try {
      await engine.setVisible(_previewVisible);
    } catch (_) {
      // Focus or media controls must not strand the viewport behind a preview.
    }
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && epoch == _attachmentEpoch) {
      setState(() => _attaching = false);
      widget.service._notify();
      if (defaultTargetPlatform == TargetPlatform.android) {
        widget.service._captureLoadedPreview(widget.tabId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_duplicate) return _preview();
    return FutureBuilder<BrowserEngine>(
      future: _engine,
      builder: (context, snapshot) {
        final error = snapshot.error ?? _attachmentError;
        if (error != null) {
          return Center(child: Text(error.toString()));
        }
        final engine = snapshot.data;
        if (engine == null) return _preview();
        if (_nativeView == null) {
          _nativeView = engine.buildView();
          unawaited(_finishAttachment(engine));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_duplicate) {
              widget.service._captureLoadedPreview(widget.tabId);
            }
          });
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            _nativeView!,
            // Keep the image subscribed while live content is showing, so
            // a later layout handoff can reuse already decoded pixels. Only
            // this ordinary Flutter image fades; the native view stays in the
            // scene and keeps sampling/compositing normally.
            IgnorePointer(
              child: AnimatedOpacity(
                key: ValueKey('browserAttachmentPreview-${widget.tabId}'),
                opacity: _attaching ? 1 : 0,
                duration: Duration(
                  milliseconds:
                      MediaQuery.maybeOf(context)?.disableAnimations == true
                      ? 0
                      : 80,
                ),
                child: _preview(),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _entryAnimation?.removeStatusListener(_routeMotionChanged);
    _coverAnimation?.removeStatusListener(_routeMotionChanged);
    _attachmentEpoch++;
    final hosts = widget.service._viewHosts[widget.tabId];
    hosts?.remove(this);
    if (hosts?.isEmpty ?? false) widget.service._viewHosts.remove(widget.tabId);
    if (!_duplicate && (hosts?.isNotEmpty ?? false)) {
      // Layout changes can mount a replacement before disposing the old
      // platform view. Promote only after this frame has detached the old one.
      final replacement = hosts!.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (replacement.mounted) {
          replacement.setState(() => replacement._duplicate = false);
        }
      });
    }
    final count = widget.service._mountedTabs[widget.tabId] ?? 1;
    if (count == 1) {
      widget.service._mountedTabs.remove(widget.tabId);
    } else {
      widget.service._mountedTabs[widget.tabId] = count - 1;
    }
    widget.service._pauseDetachedViews();
    widget.service._scheduleIdleRelease();
    super.dispose();
  }
}
