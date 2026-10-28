import 'dart:async';

enum DesktopSettingsNavigationTarget { backup, mcp, topicPosition }

class DesktopSettingsNavigationBus {
  DesktopSettingsNavigationBus._();

  static final DesktopSettingsNavigationBus instance =
      DesktopSettingsNavigationBus._();

  final StreamController<DesktopSettingsNavigationTarget> _controller =
      StreamController<DesktopSettingsNavigationTarget>.broadcast();

  Stream<DesktopSettingsNavigationTarget> get stream => _controller.stream;

  bool _topicPositionRequested = false;

  bool consumeTopicPositionRequest() {
    final requested = _topicPositionRequested;
    _topicPositionRequested = false;
    return requested;
  }

  void openTopicPosition() {
    _topicPositionRequested = true;
    _controller.add(DesktopSettingsNavigationTarget.topicPosition);
  }

  void openBackup() {
    _controller.add(DesktopSettingsNavigationTarget.backup);
  }

  void openMcp() {
    _controller.add(DesktopSettingsNavigationTarget.mcp);
  }
}
