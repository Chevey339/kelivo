import 'dart:async';

enum DesktopSettingsNavigationTarget { backup, mcp, topicPosition }

class DesktopSettingsNavigationBus {
  DesktopSettingsNavigationBus._();

  static final DesktopSettingsNavigationBus instance =
      DesktopSettingsNavigationBus._();

  final StreamController<DesktopSettingsNavigationTarget> _controller =
      StreamController<DesktopSettingsNavigationTarget>.broadcast();

  Stream<DesktopSettingsNavigationTarget> get stream => _controller.stream;

  DesktopSettingsNavigationTarget? _pending;

  /// A request can both open the settings tab for the first time and select a pane.
  StreamSubscription<DesktopSettingsNavigationTarget> listenForPane(
    void Function(DesktopSettingsNavigationTarget) select,
  ) {
    final subscription = stream.listen((target) {
      if (_pending == target) _pending = null;
      select(target);
    });
    final pending = _pending;
    _pending = null;
    if (pending != null) select(pending);
    return subscription;
  }

  void _open(DesktopSettingsNavigationTarget target) {
    _pending = target;
    _controller.add(target);
  }

  void openTopicPosition() =>
      _open(DesktopSettingsNavigationTarget.topicPosition);
  void openBackup() => _open(DesktopSettingsNavigationTarget.backup);
  void openMcp() => _open(DesktopSettingsNavigationTarget.mcp);
}
