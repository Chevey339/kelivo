import 'dart:async';

/// App-wide hotkey actions broadcast bus.
enum HotkeyAction {
  toggleAppVisibility,
  closeWindow,
  openSettings,
  newTopic,
  switchModel,
  toggleLeftPanelAssistants,
  toggleLeftPanelTopics,
}

class HotkeyEventBus {
  HotkeyEventBus._();
  static final HotkeyEventBus instance = HotkeyEventBus._();

  final _controller = StreamController<HotkeyAction>.broadcast();
  Stream<HotkeyAction> get stream => _controller.stream;

  void fire(HotkeyAction action) {
    if (!_controller.isClosed) {
      _controller.add(action);
    }
  }

  void dispose() {
    _controller.close();
  }
}
