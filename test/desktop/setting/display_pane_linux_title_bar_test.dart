import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/linux_window_service.dart';
import 'package:Kelivo/desktop/desktop_settings_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'title bar toggle is available only on Linux and applies both directions',
    (tester) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      addTearDown(settings.dispose);
      await settings.loaded;
      final titleStyles = <String>[];
      const channel = MethodChannel('window_manager');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'setTitleBarStyle');
        titleStyles.add(call.arguments['titleBarStyle'] as String);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: DesktopSettingsPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final label = find.text('Hide system title bar');
      if (defaultTargetPlatform != TargetPlatform.linux) {
        expect(label, findsNothing);
        expect(titleStyles, isEmpty);
        return;
      }
      expect(label, findsOneWidget);
      final toggle = find.descendant(
        of: find.ancestor(of: label, matching: find.byType(Row)).first,
        matching: find.byType(IosSwitch),
      );
      await tester.ensureVisible(toggle);
      expect(tester.widget<IosSwitch>(toggle).value, isFalse);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<IosSwitch>(toggle).value, isTrue);
      expect(settings.linuxHideTitleBar, isTrue);
      final local = await SharedPreferences.getInstance();
      expect(local.getBool(LinuxWindowService.hideTitleBarKey), isTrue);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<IosSwitch>(toggle).value, isFalse);
      expect(local.getBool(LinuxWindowService.hideTitleBarKey), isFalse);
      expect(titleStyles, ['hidden', 'normal']);
    },
    variant: TargetPlatformVariant.all(),
  );
}
