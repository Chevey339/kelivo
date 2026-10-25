import 'dart:async';

enum DesktopSettingsNavigationTarget { backup, mcp }

class DesktopSettingsNavigationBus {
  DesktopSettingsNavigationBus._();

  static final DesktopSettingsNavigationBus instance =
      DesktopSettingsNavigationBus._();

  final StreamController<DesktopSettingsNavigationTarget> _controller =
      StreamController<DesktopSettingsNavigationTarget>.broadcast();

  Stream<DesktopSettingsNavigationTarget> get stream => _controller.stream;

  void openBackup() {
    _controller.add(DesktopSettingsNavigationTarget.backup);
  }

  void openMcp() {
    _controller.add(DesktopSettingsNavigationTarget.mcp);
  }
}
