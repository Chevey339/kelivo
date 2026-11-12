import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/settings/pages/display_settings_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

void main() {
  const title = 'iOS 26+ native selection menu';

  Future<SettingsProvider> show(WidgetTester tester) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(settings.dispose);
    await settings.loaded;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BehaviorStartupSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return settings;
  }

  testWidgets('iOS exposes the native menu rollback switch', (tester) async {
    final settings = await show(tester);
    expect(find.text(title), findsOneWidget);
    expect(settings.iosNativeSelectionMenuEnabled, isTrue);
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
    expect(settings.iosNativeSelectionMenuEnabled, isFalse);
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
    expect(settings.iosNativeSelectionMenuEnabled, isTrue);
  }, variant: TargetPlatformVariant({TargetPlatform.iOS}));

  testWidgets(
    'other platforms do not expose the iOS menu switch',
    (tester) async {
      await show(tester);
      expect(find.text(title), findsNothing);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }),
  );
}
