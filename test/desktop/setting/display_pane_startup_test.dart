import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/desktop_settings_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('startup switches enforce prerequisites and apply changes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var enabled = false;
    const channel = MethodChannel('app.desktop_startup');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'setEnabled') {
        enabled = call.arguments as bool;
        return null;
      }
      return {'supported': true, 'enabled': enabled};
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(settings.dispose);
    await settings.loaded;
    await settings.setDesktopShowTray(true);
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
    Finder toggle(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
      matching: find.byType(IosSwitch),
    );
    final launch = toggle('Launch at startup');
    final hidden = toggle('Hide to tray on automatic startup');
    expect(tester.widget<IosSwitch>(launch).value, isFalse);
    expect(tester.widget<IosSwitch>(hidden).onChanged, isNull);
    await tester.ensureVisible(launch);
    await tester.tap(launch);
    await tester.pumpAndSettle();
    expect(enabled, isTrue);
    expect(tester.widget<IosSwitch>(hidden).onChanged, isNotNull);
    await tester.ensureVisible(hidden);
    await tester.tap(hidden);
    await tester.pumpAndSettle();
    expect(settings.desktopAutostartHidden, isTrue);
    await settings.setDesktopShowTray(false);
    await tester.pumpAndSettle();
    expect(tester.widget<IosSwitch>(hidden).onChanged, isNull);
    expect(tester.widget<IosSwitch>(hidden).value, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
