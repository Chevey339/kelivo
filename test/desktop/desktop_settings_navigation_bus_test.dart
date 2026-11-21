import 'package:Kelivo/desktop/desktop_settings_navigation_bus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'cold settings opens the requested pane and receives subsequent links',
    () async {
      final bus = DesktopSettingsNavigationBus.instance;
      for (final (first, open) in [
        (DesktopSettingsNavigationTarget.backup, bus.openBackup),
        (DesktopSettingsNavigationTarget.mcp, bus.openMcp),
        (DesktopSettingsNavigationTarget.topicPosition, bus.openTopicPosition),
      ]) {
        open();
        final selected = <DesktopSettingsNavigationTarget>[];
        final listener = bus.listenForPane(selected.add);
        expect(selected, [first]);
        bus.openBackup();
        bus.openMcp();
        await Future<void>.delayed(Duration.zero);
        expect(selected, [
          first,
          DesktopSettingsNavigationTarget.backup,
          DesktopSettingsNavigationTarget.mcp,
        ]);
        await listener.cancel();
        final reopened = bus.listenForPane(selected.add);
        expect(selected, hasLength(3));
        await reopened.cancel();
      }
    },
  );
}
