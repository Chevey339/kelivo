import 'dart:async';

enum DesktopSettingsNavigationTarget {
  backup,
  troubleshoot,
  providers,
  defaultModel,
  search,
  assistant,
  about,
}

class SettingsNavigationEvent {
  final DesktopSettingsNavigationTarget target;
  final String? faqKey;
  final String? providerId;

  const SettingsNavigationEvent({
    required this.target,
    this.faqKey,
    this.providerId,
  });
}

class DesktopSettingsNavigationBus {
  DesktopSettingsNavigationBus._();

  static final DesktopSettingsNavigationBus instance =
      DesktopSettingsNavigationBus._();

  final StreamController<SettingsNavigationEvent> _controller =
      StreamController<SettingsNavigationEvent>.broadcast();

  Stream<SettingsNavigationEvent> get stream => _controller.stream;

  void openBackup() {
    _controller.add(
      const SettingsNavigationEvent(
        target: DesktopSettingsNavigationTarget.backup,
      ),
    );
  }

  void openTroubleshoot({String? faqKey}) {
    _controller.add(
      SettingsNavigationEvent(
        target: DesktopSettingsNavigationTarget.troubleshoot,
        faqKey: faqKey,
      ),
    );
  }

  void openProviders({String? providerId}) {
    _controller.add(
      SettingsNavigationEvent(
        target: DesktopSettingsNavigationTarget.providers,
        providerId: providerId,
      ),
    );
  }

  void openDefaultModel() {
    _controller.add(
      const SettingsNavigationEvent(
        target: DesktopSettingsNavigationTarget.defaultModel,
      ),
    );
  }

  void openSearch() {
    _controller.add(
      const SettingsNavigationEvent(
        target: DesktopSettingsNavigationTarget.search,
      ),
    );
  }

  void openAssistantSettings() {
    _controller.add(
      const SettingsNavigationEvent(
        target: DesktopSettingsNavigationTarget.assistant,
      ),
    );
  }

  void openAbout() {
    _controller.add(
      const SettingsNavigationEvent(
        target: DesktopSettingsNavigationTarget.about,
      ),
    );
  }
}
