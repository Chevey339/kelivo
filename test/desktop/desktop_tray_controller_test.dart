import 'package:Kelivo/desktop/desktop_tray_controller.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'failed tray creation does not report readiness or intercept closing',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      const trayChannel = MethodChannel('tray_manager');
      const windowChannel = MethodChannel('window_manager');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var failMethod = 'setIcon';
      var preventClose = true;
      messenger.setMockMethodCallHandler(trayChannel, (call) async {
        if (call.method == failMethod) {
          throw PlatformException(code: 'tray_unavailable');
        }
        return null;
      });
      messenger.setMockMethodCallHandler(windowChannel, (call) async {
        if (call.method == 'setPreventClose') {
          preventClose = call.arguments['isPreventClose'] as bool;
        }
        return null;
      });
      final controller = DesktopTrayController.instance;
      addTearDown(() {
        trayManager.removeListener(controller);
        windowManager.removeListener(controller);
        messenger.setMockMethodCallHandler(trayChannel, null);
        messenger.setMockMethodCallHandler(windowChannel, null);
        debugDefaultTargetPlatformOverride = null;
      });
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      for (final method in ['setIcon', 'setContextMenu', '']) {
        failMethod = method;
        await controller.syncFromSettings(
          l10n,
          showTray: true,
          minimizeToTrayOnClose: true,
        );
        expect(controller.isReady, method.isEmpty);
        expect(preventClose, method.isEmpty);
      }
      await controller.syncFromSettings(
        l10n,
        showTray: false,
        minimizeToTrayOnClose: false,
      );
      expect(controller.isReady, isFalse);
      expect(preventClose, isFalse);
    },
  );
}
