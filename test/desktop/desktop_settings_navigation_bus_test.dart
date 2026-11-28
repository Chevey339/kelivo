import 'package:Kelivo/desktop/desktop_settings_navigation_bus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'cold settings opens the requested pane and receives subsequent links',
    () async {
      final bus = DesktopSettingsNavigationBus.instance;
      for (final (first, open) in [
        ((pane: DesktopSettingsPane.backup, providerKey: null), bus.openBackup),
        ((pane: DesktopSettingsPane.mcp, providerKey: null), bus.openMcp),
        (
          (pane: DesktopSettingsPane.topicPosition, providerKey: null),
          bus.openTopicPosition,
        ),
        (
          (pane: DesktopSettingsPane.providers, providerKey: 'custom'),
          () => bus.openProviders(providerKey: 'custom'),
        ),
      ]) {
        open();
        final selected = <DesktopSettingsNavigationTarget>[];
        final listener = bus.listenForPane(selected.add);
        expect(selected, [first]);
        bus.openBackup();
        bus.openProviders(providerKey: 'fal');
        await Future<void>.delayed(Duration.zero);
        expect(selected, [
          first,
          (pane: DesktopSettingsPane.backup, providerKey: null),
          (pane: DesktopSettingsPane.providers, providerKey: 'fal'),
        ]);
        await listener.cancel();
        final reopened = bus.listenForPane(selected.add);
        expect(selected, hasLength(3));
        await reopened.cancel();
      }
    },
  );
}
