import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/linux_window_service.dart';
import 'package:Kelivo/desktop/desktop_window_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('window_manager');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method.startsWith('is')) return false;
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  for (final hidden in [null, true, false]) {
    testWidgets(
      'Linux applies the selected title bar before showing the window: $hidden',
      (tester) async {
        final controller = DesktopWindowController.forTesting((_) {});
        addTearDown(() => windowManager.removeListener(controller));

        if (hidden == null) {
          await controller.initializeAndShow(title: 'Kelivo');
        } else {
          await controller.initializeAndShow(
            title: 'Kelivo',
            linuxHideTitleBar: hidden,
          );
        }
        await tester.pump();

        final titleCall = calls.singleWhere(
          (call) => call.method == 'setTitleBarStyle',
        );
        expect(
          titleCall.arguments['titleBarStyle'],
          hidden == true ? 'hidden' : 'normal',
        );
        expect(
          calls.indexOf(titleCall),
          lessThan(calls.indexWhere((call) => call.method == 'show')),
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
  }

  testWidgets(
    'Linux hides, restores, and reloads its local title bar setting',
    (tester) async {
      final preferences = createBusinessTestPreferences();
      final settings = SettingsProvider(preferences);
      addTearDown(settings.dispose);
      await settings.loaded;
      expect(settings.linuxHideTitleBar, isFalse);

      await settings.setLinuxHideTitleBar(true);
      expect(settings.linuxHideTitleBar, isTrue);
      expect(settings.copyWith().linuxHideTitleBar, isTrue);
      final reloaded = SettingsProvider(preferences);
      addTearDown(reloaded.dispose);
      await reloaded.loaded;
      expect(reloaded.linuxHideTitleBar, isTrue);

      await reloaded.setLinuxHideTitleBar(false);
      expect(reloaded.linuxHideTitleBar, isFalse);
      final local = await SharedPreferences.getInstance();
      expect(local.getBool(LinuxWindowService.hideTitleBarKey), isFalse);
      expect(preferences.getBool(LinuxWindowService.hideTitleBarKey), isNull);
      expect(calls.map((call) => call.arguments['titleBarStyle']), [
        'hidden',
        'normal',
      ]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'native failure keeps the Linux setting and saved value unchanged',
    (tester) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      addTearDown(settings.dispose);
      await settings.loaded;
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'title_bar_failed');
      });

      await expectLater(
        settings.setLinuxHideTitleBar(true),
        throwsA(isA<PlatformException>()),
      );
      expect(settings.linuxHideTitleBar, isFalse);
      final local = await SharedPreferences.getInstance();
      expect(local.getBool(LinuxWindowService.hideTitleBarKey), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'other platforms ignore the Linux preference and never change decorations',
    (tester) async {
      final settings = SettingsProvider(
        createBusinessTestPreferences(
          localInitial: {LinuxWindowService.hideTitleBarKey: true},
        ),
      );
      addTearDown(settings.dispose);
      await settings.loaded;
      expect(settings.linuxHideTitleBar, isFalse);

      await LinuxWindowService.setTitleBarHidden(false);
      await settings.setLinuxHideTitleBar(true);

      expect(calls, isEmpty);
      expect(settings.linuxHideTitleBar, isFalse);
      final local = await SharedPreferences.getInstance();
      expect(local.getBool(LinuxWindowService.hideTitleBarKey), isTrue);
    },
    variant: TargetPlatformVariant(
      TargetPlatform.values.where((p) => p != TargetPlatform.linux).toSet(),
    ),
  );
}
