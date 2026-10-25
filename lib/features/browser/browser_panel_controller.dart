import 'package:flutter/foundation.dart';

/// Desktop home owns the actual pane; browser entry points can request it even
/// from a popover whose context is above that pane in the navigator overlay.
class BrowserPanelController extends ChangeNotifier {
  static final instance = BrowserPanelController();

  int _hosts = 0;
  bool _open = false;
  String? _conversationId;
  String? _initialTabId;

  bool get isOpen => _open;
  bool get hasHost => _hosts > 0;
  String? get conversationId => _conversationId;
  String? get initialTabId => _initialTabId;

  void attachHost() => _hosts++;

  void detachHost() {
    if (_hosts > 0) _hosts--;
    if (_hosts == 0) {
      _open = false;
      _conversationId = null;
      _initialTabId = null;
    }
  }

  bool open({String? conversationId, String? initialTabId}) {
    if (!hasHost) return false;
    _conversationId = conversationId;
    _initialTabId = initialTabId;
    _open = true;
    notifyListeners();
    return true;
  }

  void close() {
    if (!_open) return;
    _open = false;
    _initialTabId = null;
    notifyListeners();
  }
}
