import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/business_preferences.dart';
import '../../core/services/browser/browser_service.dart';
import '../browser/models/browser_agent_activity.dart';
import 'models/side_panel_tab.dart';

export 'models/side_panel_tab.dart';

enum SidePanelPresentation { hidden, docked, overlay, expanded }

/// One desktop surface. BrowserStore owns web documents; this controller owns
/// presentation and references to those documents, never native engines.
class DesktopSidePanelController extends ChangeNotifier {
  DesktopSidePanelController({BrowserService? browser})
    : browser = browser ?? BrowserService.instance {
    this.browser.addListener(_browserChanged);
  }

  static final instance = DesktopSidePanelController();
  static const defaultWidth = 520.0;
  static const minWidth = 360.0;
  static const dockThreshold = 849.0;
  static const _prefix = 'desktop_side_panel_';
  final BrowserService browser;
  BusinessPreferences? _preferences;
  final Map<String, List<SidePanelTab>> _resources = {};
  final Map<String, String> _active = {};
  final Map<String, List<Map<String, Object?>>> _closed = {};
  String _conversationId = '';
  bool _open = false;
  int _openEpoch = 0;
  bool _disposed = false;
  bool _expanded = false;
  bool _topicsOnRight = false;
  bool _browserReady = false;
  double _width = defaultWidth;
  SidePanelTabKind _lastKind = SidePanelTabKind.files;
  FocusScopeNode? _focusScope;
  String? persistenceError;
  Future<void> _writes = Future<void>.value();
  String? _lastSavedTabs;
  bool? _lastSavedOpen;
  double? _lastSavedWidth;
  String? _lastSavedKind;

  bool get isOpen => _open;
  bool get isExpanded => _expanded;
  bool get topicsOnRight => _topicsOnRight;
  double get preferredWidth => _width;
  SidePanelTabKind get lastKind => _lastKind;
  String get conversationId => _conversationId;
  bool hostVisible = true;
  bool hostIsCurrent = true;
  bool get isAvailable => hostVisible && hostIsCurrent && _focusScope != null;
  bool get hasFocus => isAvailable && _open && (_focusScope?.hasFocus ?? false);
  List<SidePanelTab> get tabs => tabsFor(_conversationId);
  SidePanelTab get activeTab => tabs.firstWhere(
    (tab) => tab.id == activeTabId(_conversationId),
    orElse: () => const PinnedTab(SidePanelTabKind.files),
  );

  void attachFocusScope(FocusScopeNode? scope) => _focusScope = scope;

  /// Called with the already loaded settings snapshot, before browser startup.
  /// Legacy keys are intentionally read-only for the requested rollback window.
  void bindPreferences(BusinessPreferences preferences) {
    if (identical(_preferences, preferences)) return;
    assert(preferences.isLoaded);
    _preferences = preferences;
    _browserReady = false;
    _resources.clear();
    _active.clear();
    _closed.clear();
    _lastSavedTabs = null;
    _lastSavedOpen = preferences.getBool('${_prefix}open_v1');
    _lastSavedWidth = (preferences.get('${_prefix}width_v1') as num?)
        ?.toDouble();
    _lastSavedKind = preferences.getString('${_prefix}last_kind_v1');
    _expanded = false;
    _topicsOnRight =
        preferences.getString('desktop_topic_position_v1') == 'right';
    final migrated = preferences.getBool('${_prefix}migrated_v1') == true;
    final oldFiles =
        preferences.getBool('desktop_workspace_bar_open_v1') == true;
    final oldTopics =
        _topicsOnRight &&
        (preferences.getBool('desktop_right_sidebar_open_v1') ?? true);
    _open =
        preferences.getBool('${_prefix}open_v1') ??
        (!migrated && (oldFiles || oldTopics));
    final storedWidth =
        preferences.get('${_prefix}width_v1') ??
        (!migrated ? preferences.get('desktop_right_sidebar_width_v1') : null);
    _width = storedWidth is num && storedWidth.isFinite
        ? storedWidth.toDouble().clamp(minWidth, 900)
        : defaultWidth;
    final savedKind = preferences.getString('${_prefix}last_kind_v1');
    _lastKind =
        SidePanelTabKind.values
            .where((kind) => kind.name == savedKind)
            .firstOrNull ??
        (!migrated && oldTopics
            ? SidePanelTabKind.topics
            : SidePanelTabKind.files);
    final raw = preferences.getString('${_prefix}tabs_v1');
    if (raw != null) {
      try {
        final data = jsonDecode(raw);
        if (data is Map<String, dynamic>) {
          for (final entry in data.entries) {
            if (entry.value is! Map) continue;
            final value = entry.value as Map;
            final rows = value['tabs'];
            if (rows is List) {
              final ids = <String>{};
              _resources[entry.key] = [
                for (final row in rows)
                  if (_decode(row) case final tab? when ids.add(tab.id)) tab,
              ];
            }
            if (value['active'] is String) {
              _active[entry.key] = value['active'] as String;
            }
          }
        }
      } on FormatException {
        // Malformed panel state must not prevent access to files or topics.
      }
    }
    if (!migrated) {
      final open = _open, width = _width, kind = _lastKind.name;
      _enqueue(() async {
        await preferences.setBool('${_prefix}open_v1', open);
        await preferences.setDouble('${_prefix}width_v1', width);
        await preferences.setString('${_prefix}last_kind_v1', kind);
        // Mark completion only when every migrated setting is durable.
        return preferences.setBool('${_prefix}migrated_v1', true);
      });
    }
    _browserChanged();
  }

  SidePanelTab? _decode(Object? row) {
    if (row is! Map) return null;
    if (row['kind'] == 'web' && row['browserTabId'] is String) {
      return WebTab(
        browserTabId: row['browserTabId'] as String,
        browser: browser,
      );
    }
    if (row['kind'] == 'preview' &&
        row['id'] is String &&
        row['path'] is String) {
      return PreviewTab(
        id: row['id'] as String,
        path: row['path'] as String,
        source: row['source'] is String ? row['source'] as String : 'workspace',
      );
    }
    return null;
  }

  void setContext({
    required String? conversationId,
    required bool topicsOnRight,
  }) {
    final id = conversationId ?? '';
    if (id == _conversationId && topicsOnRight == _topicsOnRight) return;
    _conversationId = id;
    _topicsOnRight = topicsOnRight;
    _selectBrowser();
    notifyListeners();
  }

  List<SidePanelTab> tabsFor(String conversationId) => [
    if (_topicsOnRight) const PinnedTab(SidePanelTabKind.topics),
    const PinnedTab(SidePanelTabKind.files),
    ...?_resources[conversationId],
  ];

  String activeTabId(String conversationId) {
    final list = tabsFor(conversationId);
    final saved = _active[conversationId];
    if (list.any((tab) => tab.id == saved)) return saved!;
    return list.where((tab) => tab.kind == _lastKind).firstOrNull?.id ??
        'files';
  }

  SidePanelPresentation presentationFor(double availableWidth) {
    if (!_open) return SidePanelPresentation.hidden;
    if (_expanded) return SidePanelPresentation.expanded;
    return availableWidth >= dockThreshold
        ? SidePanelPresentation.docked
        : SidePanelPresentation.overlay;
  }

  static double maxWidthFor(double availableWidth) =>
      math.max(minWidth, math.min(900, availableWidth - 489));

  double widthFor(double availableWidth) =>
      switch (presentationFor(availableWidth)) {
        SidePanelPresentation.expanded => availableWidth,
        SidePanelPresentation.overlay => math.min(_width, availableWidth),
        _ => _width.clamp(minWidth, maxWidthFor(availableWidth)),
      };

  static int resourceCapacity(double width, int pinnedCount) =>
      math.max(0, ((width - pinnedCount * 70 - 140) / 108).floor());

  static List<SidePanelTab> visibleResources(
    List<SidePanelTab> resources,
    int capacity,
    String? activeId,
  ) {
    if (resources.isEmpty) return const [];
    final active = resources.where((tab) => tab.id == activeId).firstOrNull;
    final count = math.max(active == null ? 0 : 1, capacity);
    final visible = resources.take(count).toList();
    if (active != null && !visible.contains(active)) {
      visible[visible.length - 1] = active;
    }
    return visible;
  }

  void toggle() => _open ? close() : open();

  void open({SidePanelTabKind? kind, String? tabId}) {
    _open = true;
    final target =
        tabId ??
        (kind == null
            ? activeTabId(_conversationId)
            : tabs.where((tab) => tab.kind == kind).firstOrNull?.id);
    if (target != null) _activate(target);
    _changed();
  }

  void close() {
    _openEpoch++;
    _open = false;
    _expanded = false;
    _changed();
  }

  void activate(String tabId) {
    if (!tabs.any((tab) => tab.id == tabId)) return;
    _activate(tabId);
    _changed();
  }

  void _activate(String id) {
    _active[_conversationId] = id;
    _lastKind = activeTab.kind;
    _selectBrowser();
  }

  void _selectBrowser() {
    final active = activeTab;
    if (active is WebTab && active.page != null) {
      unawaited(browser.selectTab(active.browserTabId));
    }
  }

  Future<void> newWebTab({String? url}) async {
    final epoch = _openEpoch;
    final owner = _conversationId;
    final tab = await browser.createTab(
      ownerSessionId: owner.isEmpty ? null : owner,
      url: url,
    );
    if (_disposed || epoch != _openEpoch || owner != _conversationId) return;
    openWebTab(tab.id);
    if (browser.isSupported && tab.url != 'about:blank') {
      await browser.navigate(tab.url, tabId: tab.id);
    }
  }

  void openWebTab(String browserTabId) {
    final tab = WebTab(browserTabId: browserTabId, browser: browser);
    if (tab.page == null) return;
    final list = _resources.putIfAbsent(_conversationId, () => []);
    if (!list.any((item) => item.id == tab.id)) list.add(tab);
    open(tabId: tab.id);
  }

  void openPreview(String path, {String source = 'workspace'}) {
    final list = _resources.putIfAbsent(_conversationId, () => []);
    final existing = list
        .whereType<PreviewTab>()
        .where((tab) => tab.path == path)
        .firstOrNull;
    final tab =
        existing ??
        PreviewTab(
          id: 'preview:${const Uuid().v4()}',
          path: path,
          source: source,
        );
    if (existing == null) list.add(tab);
    open(tabId: tab.id);
  }

  void relocatePreview(String id, String path) {
    final list = _resources[_conversationId];
    final index = list?.indexWhere((tab) => tab.id == id) ?? -1;
    if (index < 0 || list![index] is! PreviewTab) return;
    list[index] = PreviewTab(
      id: id,
      path: path,
      source: (list[index] as PreviewTab).source,
    );
    _changed();
  }

  bool closeTab(String id) {
    final list = _resources[_conversationId];
    final index = list?.indexWhere((tab) => tab.id == id) ?? -1;
    if (index < 0 || !list![index].closable) return false;
    final tab = list[index];
    final history = _closed.putIfAbsent(_conversationId, () => []);
    history.add(tab.toJson());
    if (history.length > 10) history.removeAt(0);
    final selected = activeTabId(_conversationId) == id;
    list.removeAt(index);
    if (selected || list.isEmpty) {
      _activate(index > 0 && list.isNotEmpty ? list[index - 1].id : 'files');
    }
    if (tab is WebTab) {
      final page = tab.page;
      final agentPage = browser.tabs
          .where((page) => page.id == browser.agentTabId)
          .firstOrNull;
      if (page != null &&
          browser.agentSessionId == page.ownerSessionId &&
          browser.agentActivityFor(sessionId: page.ownerSessionId) ==
              BrowserAgentActivity.running &&
          (agentPage == null ||
              (agentPage.popupGroupId ?? agentPage.id) ==
                  (page.popupGroupId ?? page.id))) {
        browser.takeOver(
          sessionId: page.ownerSessionId,
          tabId: agentPage?.id ?? page.id,
        );
      }
      unawaited(browser.closeTab(tab.browserTabId));
    }
    _changed();
    return true;
  }

  void closeOthers(String id) {
    for (final tab
        in tabs.where((tab) => tab.closable && tab.id != id).toList()) {
      closeTab(tab.id);
    }
  }

  void closeRight(String id) {
    final list = tabs;
    final index = list.indexWhere((tab) => tab.id == id);
    if (index < 0) return;
    for (final tab in list.skip(index + 1)) {
      closeTab(tab.id);
    }
  }

  Future<void> reopenClosedTab() async {
    final epoch = _openEpoch;
    final owner = _conversationId;
    final history = _closed[owner];
    if (history == null || history.isEmpty) return;
    final row = history.removeLast();
    if (row['kind'] == 'web') {
      final page = await browser.createTab(
        url: row['url'] as String?,
        ownerSessionId: row['conversationId'] as String?,
        title: row['title'] as String?,
      );
      if (!_disposed && epoch == _openEpoch && owner == _conversationId) {
        openWebTab(page.id);
        if (browser.isSupported && page.url != 'about:blank') {
          await browser.navigate(page.url, tabId: page.id);
        }
      }
    } else {
      final tab = _decode(row);
      if (tab == null) return;
      _resources.putIfAbsent(owner, () => []).add(tab);
      if (owner == _conversationId) open(tabId: tab.id);
    }
  }

  /// Returns true even for a fixed entry: a focused panel owns the command.
  bool handleCloseWindow() {
    if (!hasFocus) return false;
    closeTab(activeTab.id);
    return true;
  }

  void cycleTab({bool backwards = false}) {
    final list = tabs;
    final index = list.indexWhere((tab) => tab.id == activeTab.id);
    activate(list[(index + (backwards ? -1 : 1)) % list.length].id);
  }

  void setPreferredWidth(double value) {
    if (!value.isFinite) return;
    _width = value.clamp(minWidth, 900);
    _changed();
  }

  void setExpanded(bool value) {
    _expanded = value;
    if (value) _open = true;
    _changed();
  }

  void _browserChanged() {
    if (!browser.isInitialized) return;
    final live = browser.tabs.map((tab) => 'web:${tab.id}').toSet();
    for (final entry in _resources.entries) {
      final old = entry.value;
      final selectedIndex = old.indexWhere(
        (tab) => tab.id == _active[entry.key],
      );
      final previous = selectedIndex > 0 ? old[selectedIndex - 1].id : 'files';
      old.removeWhere((tab) => tab is WebTab && !live.contains(tab.id));
      if (_active[entry.key]?.startsWith('web:') == true &&
          !live.contains(_active[entry.key])) {
        _active[entry.key] = old.any((tab) => tab.id == previous)
            ? previous
            : 'files';
      }
    }
    for (final page in browser.tabs) {
      final list = _resources.putIfAbsent(page.ownerSessionId ?? '', () => []);
      if (!list.any((tab) => tab is WebTab && tab.browserTabId == page.id)) {
        list.add(WebTab(browserTabId: page.id, browser: browser));
      }
      final current = _resources[_conversationId];
      if (page.openerTabId != null &&
          current != null &&
          current.any(
            (tab) => tab is WebTab && tab.browserTabId == page.openerTabId,
          ) &&
          !current.any((tab) => tab is WebTab && tab.browserTabId == page.id)) {
        current.add(WebTab(browserTabId: page.id, browser: browser));
      }
    }
    if (!_browserReady) {
      _browserReady = true;
      _selectBrowser();
    } else {
      // Native popups and the existing browser menus can select a document.
      // Reflect it only while browsing; background activity must not replace
      // files/topics or another conversation's remembered selection.
      final page = browser.activeTab;
      if (activeTab is WebTab &&
          page != null &&
          tabs.any((tab) => tab is WebTab && tab.browserTabId == page.id)) {
        _active[_conversationId] = 'web:${page.id}';
      }
    }
    _changed();
  }

  void _changed() {
    _save();
    notifyListeners();
  }

  void _enqueue(Future<Object?> Function() write) {
    _writes = _writes
        .then((_) async {
          await write();
        })
        .catchError((Object error) {
          persistenceError = error.toString();
          _lastSavedTabs = null;
          _lastSavedOpen = null;
          _lastSavedWidth = null;
          _lastSavedKind = null;
          if (!_disposed) notifyListeners();
        });
  }

  Future<void> flush() => _writes;

  void retryPersistence() {
    persistenceError = null;
    _lastSavedTabs = null;
    _lastSavedOpen = null;
    _lastSavedWidth = null;
    _lastSavedKind = null;
    _changed();
  }

  void _save() {
    final prefs = _preferences;
    if (prefs == null) return;
    final open = _open, width = _width, kind = _lastKind.name;
    final tabs = jsonEncode({
      for (final id in {..._resources.keys, ..._active.keys})
        id: {
          'tabs': [
            for (final tab in _resources[id] ?? <SidePanelTab>[]) tab.toJson(),
          ],
          'active': activeTabId(id),
        },
    });
    if (_lastSavedOpen != open) {
      _lastSavedOpen = open;
      _enqueue(() => prefs.setBool('${_prefix}open_v1', open));
    }
    if (_lastSavedWidth != width) {
      _lastSavedWidth = width;
      _enqueue(() => prefs.setDouble('${_prefix}width_v1', width));
    }
    if (_lastSavedKind != kind) {
      _lastSavedKind = kind;
      _enqueue(() => prefs.setString('${_prefix}last_kind_v1', kind));
    }
    if (_lastSavedTabs != tabs) {
      _lastSavedTabs = tabs;
      _enqueue(() => prefs.setString('${_prefix}tabs_v1', tabs));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    browser.removeListener(_browserChanged);
    super.dispose();
  }
}
