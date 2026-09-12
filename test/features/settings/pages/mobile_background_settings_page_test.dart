import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/mobile_background.dart';
import 'package:Kelivo/features/settings/pages/mobile_background_settings_page.dart';
import 'package:Kelivo/features/settings/pages/background_overlay_settings_page.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/shared/widgets/form_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';

import '../../../support/business_test_harness.dart';

void main() {
  const channel = MethodChannel('test.background.settings');
  final calls = <MethodCall>[];
  var grants = <String, Object>{};
  late SettingsProvider settings;
  late MobileBackgroundCoordinator coordinator;

  setUp(() async {
    calls.clear();
    grants = {'notificationsAuthorized': false, 'overlayAuthorized': false};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'sync' || call.method == 'getStatus'
              ? grants
              : null;
        });
  });

  tearDown(() async {
    coordinator.dispose();
    settings.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> show(WidgetTester tester, TargetPlatform platform) async {
    final harness = await createBusinessTestHarness();
    settings = SettingsProvider(harness.preferences);
    await settings.loaded;

    coordinator = MobileBackgroundCoordinator(
      platform: platform,
      channel: channel,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MobileBackgroundSettingsPage(
            coordinator: coordinator,
            platform: platform,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await coordinator.flush();
  }

  Future<void> toggle(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    await tester.scrollUntilVisible(target, 250);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
    await coordinator.flush();
  }

  testWidgets(
    'Android page defaults off and opening it never requests permission',
    (tester) async {
      await show(tester, TargetPlatform.android);
      expect(find.byType(MobileBackgroundSettingsPage), findsOneWidget);
      expect(
        tester
            .widgetList<IosSwitch>(find.byType(IosSwitch))
            .map((s) => s.value),
        everyElement(isFalse),
      );
      expect(calls.where((c) => c.method == 'requestPermission'), isEmpty);
      await toggle(tester, 'execution');
      expect(settings.mobileBackground.androidEnabled, isTrue);
      expect(settings.mobileBackground.notificationsEnabled, isFalse);
      expect(settings.mobileBackground.overlayEnabled, isFalse);
      expect(calls.where((c) => c.method == 'requestPermission'), isEmpty);
    },
  );

  testWidgets(
    'denied permission keeps user intent separate and refreshes on return',
    (tester) async {
      await show(tester, TargetPlatform.android);
      await toggle(tester, 'notifications');
      expect(settings.mobileBackground.notificationsEnabled, isTrue);
      expect(coordinator.status.flag('notificationsAuthorized'), isFalse);
      expect(
        calls.where((c) => c.method == 'requestPermission').single.arguments,
        'notifications',
      );
      grants = {'notificationsAuthorized': true, 'overlayAuthorized': false};
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(coordinator.status.flag('notificationsAuthorized'), isTrue);
      expect(calls.where((c) => c.method == 'requestPermission'), hasLength(1));
      grants = {'notificationsAuthorized': false, 'overlayAuthorized': false};
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(coordinator.status.flag('notificationsAuthorized'), isFalse);
      expect(settings.mobileBackground.notificationsEnabled, isTrue);
      await toggle(tester, 'notifications');
      expect(calls.where((c) => c.method == 'requestPermission'), hasLength(1));
    },
  );

  testWidgets(
    'iOS location requests only on explicit enable and does not enable enhanced runtime',
    (tester) async {
      grants = {'locationAuthorization': 'notDetermined'};
      await show(tester, TargetPlatform.iOS);
      expect(calls.where((c) => c.method == 'requestPermission'), isEmpty);
      await toggle(tester, 'location');
      expect(settings.mobileBackground.locationEnabled, isTrue);
      expect(settings.mobileBackground.iosEnabled, isFalse);
      expect(settings.mobileBackground.silentAudioEnabled, isFalse);
      expect(
        calls.where((c) => c.method == 'requestPermission').single.arguments,
        'location',
      );
    },
  );

  testWidgets('iOS toggle and completion icons share the same leading slot', (
    tester,
  ) async {
    await show(tester, TargetPlatform.iOS);
    final locationIcon = find.byIcon(Lucide.MapPin).first;
    final timerIcon = find.byIcon(Lucide.Timer);
    await tester.scrollUntilVisible(timerIcon, 250);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(timerIcon).dx, tester.getTopLeft(locationIcon).dx);
  });

  testWidgets(
    'small screen can reach controls and persist completion choice without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester, TargetPlatform.android);
      final choiceRow = find.byKey(const ValueKey('completionVisibility'));
      await tester.scrollUntilVisible(choiceRow, 250);
      await tester.pumpAndSettle();
      await tester.tap(choiceRow);
      await tester.pumpAndSettle();
      expect(find.byType(FormSheet), findsOneWidget);
      expect(find.byType(DropdownButton), findsNothing);
      await tester.tap(find.text('5 minutes').last);
      await tester.pumpAndSettle();
      expect(settings.mobileBackground.completionVisibility.seconds, 300);
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsOneWidget);
    },
  );

  testWidgets(
    'overlay editor previews and persists customization without enabling permissions',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester, TargetPlatform.android);
      final entry = find.byKey(const ValueKey('overlayAppearance'));
      await tester.scrollUntilVisible(entry, 250);
      await tester.pumpAndSettle();
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byType(BackgroundOverlaySettingsPage), findsOneWidget);
      await tester.tap(find.text('Circular icon'));
      await tester.pumpAndSettle();
      await coordinator.flush();
      expect(settings.mobileBackground.overlayAppearance.isIconOnly, isTrue);
      expect(find.byKey(const ValueKey('overlayPreviewTitle')), findsNothing);
      expect(find.byKey(const ValueKey('overlayPreviewClose')), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('overlayPreviewFrame'))),
        const Size(64, 64),
      );

      final width = find.byKey(const ValueKey('overlayWidth'));
      await tester.scrollUntilVisible(width, 180);
      await tester.pumpAndSettle();
      // Dragging updates the preview; only the final value writes preferences.
      final drag = await tester.startGesture(tester.getCenter(width));
      await drag.moveBy(const Offset(20, 0));
      await tester.pump();
      final chosenWidth = tester.widget<SfSlider>(width).value as double;
      expect(
        tester.getSize(find.byKey(const ValueKey('overlayPreviewFrame'))).width,
        greaterThan(64),
      );
      expect(settings.mobileBackground.overlayAppearance.width, 64);
      await drag.up();
      await tester.pumpAndSettle();
      await coordinator.flush();
      expect(settings.mobileBackground.overlayAppearance.width, chosenWidth);

      final time = find.byKey(const ValueKey('overlayShowTime'));
      await tester.scrollUntilVisible(time, 240);
      await tester.pumpAndSettle();
      await tester.tap(time);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('overlayPreviewTime')), findsOneWidget);
      expect(settings.mobileBackground.overlayAppearance.showTime, isTrue);
      expect(settings.mobileBackground.overlayEnabled, isFalse);
      expect(settings.mobileBackground.androidEnabled, isFalse);
      expect(
        calls.where((call) => call.method == 'requestPermission'),
        isEmpty,
      );
      final native =
          calls.lastWhere((call) => call.method == 'sync').arguments as Map;
      expect(
        (native['settings'] as Map)['overlayAppearance'],
        settings.mobileBackground.overlayAppearance.toJson(),
      );

      final reset = find.byKey(const ValueKey('overlayAppearanceReset'));
      await tester.scrollUntilVisible(reset, 300);
      await tester.pumpAndSettle();
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(settings.mobileBackground.overlayAppearance.width, 290);
      expect(settings.mobileBackground.overlayEnabled, isFalse);
      tester.view.physicalSize = const Size(568, 320);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
