import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/database/business_settings_router.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/desktop_startup_service.dart';

import '../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.desktop_startup');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  bool enabled = false;
  bool supported = true;
  bool loginLaunch = false;
  bool failWrite = false;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    SharedPreferences.setMockInitialValues({});
    enabled = false;
    supported = true;
    loginLaunch = false;
    failWrite = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getState':
          return {'supported': supported, 'enabled': enabled};
        case 'wasLaunchedAtLogin':
          return loginLaunch;
        case 'setEnabled':
          if (failWrite) throw PlatformException(code: 'denied');
          enabled = call.arguments as bool;
          return null;
      }
      throw UnsupportedError(call.method);
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    DesktopStartupService.cancelDeferredLaunch();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'manual launch is visible even when the hidden preference is on',
    () async {
      await DesktopStartupService.setHidden(true);
      await DesktopStartupService.prepareLaunch(const []);
      expect(DesktopStartupService.deferWindow, isFalse);
    },
  );

  test('login launch stays hidden only with a usable tray', () async {
    loginLaunch = true;
    for (final hide in [false, true]) {
      for (final tray in [false, true]) {
        await DesktopStartupService.prepareLaunch(const []);
        expect(DesktopStartupService.deferWindow, isTrue);
        expect(
          DesktopStartupService.finishLaunch(hideToTray: hide, trayReady: tray),
          !(hide && tray),
        );
        expect(DesktopStartupService.deferWindow, isFalse);
      }
    }
  });

  test('Windows startup argument and recovery visibility', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await DesktopStartupService.prepareLaunch(const ['--autostart']);
    expect(DesktopStartupService.deferWindow, isTrue);
    DesktopStartupService.cancelDeferredLaunch();
    expect(
      DesktopStartupService.finishLaunch(hideToTray: true, trayReady: true),
      isFalse,
    );
    expect(DesktopStartupService.deferWindow, isFalse);
  });

  test('native detection failure keeps the normal launch visible', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'failed'),
    );
    await DesktopStartupService.prepareLaunch(const []);
    expect(DesktopStartupService.deferWindow, isFalse);
  });

  test(
    'OS state is refreshed and failed writes do not enable the switch',
    () async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      addTearDown(settings.dispose);
      await settings.loaded;
      expect(settings.desktopAutostartEnabled, isFalse);
      failWrite = true;
      await expectLater(
        settings.setDesktopAutostartEnabled(true),
        throwsA(isA<PlatformException>()),
      );
      expect(settings.desktopAutostartEnabled, isFalse);
      expect(settings.desktopAutostartBusy, isFalse);
      failWrite = false;
      await settings.setDesktopAutostartEnabled(true);
      expect(settings.desktopAutostartEnabled, isTrue);
      enabled = false; // User disables startup in the OS settings.
      await settings.refreshDesktopStartup();
      expect(settings.desktopAutostartEnabled, isFalse);
    },
  );

  test(
    'hidden preference stays local and disabling the tray clears it',
    () async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      addTearDown(settings.dispose);
      await settings.loaded;
      await settings.setDesktopAutostartEnabled(true);
      await settings.setDesktopShowTray(true);
      await settings.setDesktopAutostartHidden(true);
      expect(await DesktopStartupService.readHidden(), isTrue);
      await settings.setDesktopShowTray(false);
      expect(settings.desktopAutostartHidden, isFalse);
      expect(await DesktopStartupService.readHidden(), isFalse);
      expect(
        BusinessKeyRegistry.classify(DesktopStartupService.hiddenKey),
        BusinessKeyDisposition.localOnly,
      );
    },
  );

  test('unsupported OS cannot register startup', () async {
    supported = false;
    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(settings.dispose);
    await settings.loaded;
    expect(settings.desktopAutostartSupported, isFalse);
    await settings.setDesktopAutostartEnabled(true);
    expect(enabled, isFalse);
  });
}
