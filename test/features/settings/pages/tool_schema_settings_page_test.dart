import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/memory/memory_prompts.dart';
import 'package:Kelivo/core/services/search/search_tool_service.dart';
import 'package:Kelivo/core/services/tools/built_in_tool_catalog.dart';
import 'package:Kelivo/features/home/services/local_tools_service.dart';
import 'package:Kelivo/features/settings/pages/tool_schema_settings_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';

import '../../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    DeviceLocalTools.debugResetIosCapabilities();
  });

  tearDown(DeviceLocalTools.debugResetIosCapabilities);

  testWidgets(
    'iOS weather and health appear after the capability probe completes',
    (tester) async {
      tester.view.physicalSize = const Size(400, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final weatherReady = Completer<bool>();
      const channel = MethodChannel('app.device_tools');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'isWeatherKitAvailable') {
              return weatherReady.future;
            }
            if (call.method == 'isHealthDataAvailable') return true;
            return null;
          });
      addTearDown(() {
        if (!weatherReady.isCompleted) weatherReady.complete(false);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final settings = SettingsProvider(createBusinessTestPreferences());
      addTearDown(settings.dispose);
      await settings.loaded;

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(
          ChangeNotifierProvider<SettingsProvider>.value(
            value: settings,
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: Locale('en'),
              home: ToolSchemaSettingsPage(),
            ),
          ),
        );
        await tester.pump();

        expect(find.text(SearchToolService.toolName), findsOneWidget);
        expect(DeviceLocalTools.weatherSupported, isFalse);
        expect(DeviceLocalTools.healthSupported, isFalse);
        expect(_catalogNames(), isNot(contains(LocalToolNames.weather)));
        expect(find.text(LocalToolNames.weather), findsNothing);
        expect(find.text(LocalToolNames.healthSummary), findsNothing);

        weatherReady.complete(true);
        await tester.pump();
        await tester.pump();

        expect(DeviceLocalTools.weatherSupported, isTrue);
        expect(DeviceLocalTools.healthSupported, isTrue);
        expect(_catalogNames(), contains(LocalToolNames.weather));
        expect(_catalogNames(), contains(LocalToolNames.healthSummary));
        expect(find.text(LocalToolNames.weather), findsOneWidget);
        expect(find.text(LocalToolNames.healthSummary), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('tool rows are app-native and have no list dividers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(settings.dispose);
    await settings.loaded;

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: ToolSchemaSettingsPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(SearchToolService.toolName), findsOneWidget);
    expect(find.byType(IosCardPress), findsWidgets);
    expect(find.byType(Divider), findsNothing);
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(InkWell), findsNothing);
  });
}

Iterable<String> _catalogNames() {
  return BuiltInToolCatalog.entries(
    lang: MemoryPromptLang.en,
    legacyMemoryMode: false,
  ).map((e) => e.name);
}
