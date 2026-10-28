import 'dart:async';
import 'package:flutter/foundation.dart';
import '../side_panel/desktop_side_panel_controller.dart';

/// Existing entry points forward into the shared panel. Its mounted host owns
/// cold browser initialization, so opening the frame never waits for storage.
class BrowserPanelController extends ChangeNotifier {
  BrowserPanelController({DesktopSidePanelController? panel})
    : panel = panel ?? DesktopSidePanelController.instance {
    this.panel.addListener(_panelChanged);
  }
  static final instance = BrowserPanelController();
  final DesktopSidePanelController panel;
  int _hosts = 0;
  bool _pending = false;
  String? _conversationId, _initialTabId;
  bool get isOpen =>
      hasHost && panel.isOpen && (_pending || panel.activeTab is WebTab);
  bool get hasHost => _hosts > 0;
  String? get conversationId => _conversationId;
  String? get initialTabId => _initialTabId;
  void attachHost() => _hosts++;
  void detachHost() {
    if (_hosts > 0) _hosts--;
    if (_hosts == 0) {
      _pending = false;
      _conversationId = null;
      _initialTabId = null;
    }
  }

  bool open({String? conversationId, String? initialTabId}) {
    if (!hasHost) return false;
    _conversationId = conversationId;
    _initialTabId = initialTabId;
    _pending = true;
    panel.open(kind: SidePanelTabKind.web);
    _fulfill();
    return true;
  }

  void _panelChanged() {
    if (!panel.isOpen) {
      _pending = false;
      _initialTabId = null;
    }
    _fulfill();
    notifyListeners();
  }

  void _fulfill() {
    if (!_pending ||
        !hasHost ||
        !panel.isOpen ||
        !panel.browser.isInitialized) {
      return;
    }
    _pending = false;
    final tab =
        panel.browser.tabs
            .where((tab) => tab.id == _initialTabId)
            .firstOrNull ??
        panel.browser.selectedTabForSession(
          _conversationId ?? panel.conversationId,
        );
    if (tab != null) {
      panel.openWebTab(tab.id);
    } else {
      unawaited(_createTab());
    }
  }

  Future<void> _createTab() async {
    try {
      await panel.newWebTab();
    } catch (error) {
      panel.persistenceError = error.toString();
      notifyListeners();
    }
  }

  void close() {
    _pending = false;
    _initialTabId = null;
    panel.close();
  }

  @override
  void dispose() {
    panel.removeListener(_panelChanged);
    super.dispose();
  }
}
