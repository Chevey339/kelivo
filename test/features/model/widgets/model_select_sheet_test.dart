import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/model/widgets/model_select_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';

ProviderConfig _providerConfig(String key, String name, List<String> models) {
  return ProviderConfig(
    id: key,
    enabled: true,
    name: name,
    apiKey: '',
    baseUrl: '',
    providerType: ProviderKind.openai,
    models: models,
  );
}

Future<SettingsProvider> _settingsWithProviders(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsProvider();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();

  final providerKeys = <String>[];
  for (var i = 0; i < 10; i++) {
    final key = 'provider-$i';
    providerKeys.add(key);
    final models = [
      for (var model = 0; model < 4; model++)
        '$key-model-${model.toString().padLeft(2, '0')}',
    ];
    await settings.setProviderConfig(
      key,
      _providerConfig(key, 'Provider $i Long Name', models),
    );
  }
  await settings.setProvidersOrder(providerKeys);
  await settings.setCurrentModel('provider-0', 'provider-0-model-00');
  return settings;
}

Future<void> _pumpModelSelector(
  WidgetTester tester, {
  required SettingsProvider settings,
  String? limitProviderKey,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<AssistantProvider>(
          create: (_) => AssistantProvider(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                key: const ValueKey('open-model-selector'),
                onPressed: () {
                  showModelSelector(
                    context,
                    limitProviderKey: limitProviderKey,
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.byKey(const ValueKey('open-model-selector')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });
  await tester.pump(const Duration(milliseconds: 500));
}

bool _providerTabSelected(WidgetTester tester, String providerKey) {
  final semantics = tester.widget<Semantics>(
    find.descendant(
      of: find.byKey(ValueKey('model-selector-provider-tab-$providerKey')),
      matching: find.byType(Semantics),
    ),
  );
  return semantics.properties.selected ?? false;
}

Future<void> _dismissModelSelector(WidgetTester tester) async {
  final bottomSheet = find.byType(BottomSheet);
  if (bottomSheet.evaluate().isEmpty) return;
  Navigator.of(tester.element(bottomSheet)).pop();
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'mobile model selector keeps active provider sticky and bottom tab visible',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      try {
        final settings = await _settingsWithProviders(tester);
        await _pumpModelSelector(tester, settings: settings);
        expect(find.byType(ScrollablePositionedList), findsOneWidget);

        for (var i = 0; i < 8; i++) {
          await tester.drag(
            find.byType(ScrollablePositionedList),
            const Offset(0, -260),
          );
          await tester.pump(const Duration(milliseconds: 120));
        }
        await tester.pump(const Duration(milliseconds: 300));

        final stickyTextFinder = find.descendant(
          of: find.byKey(const ValueKey('model-selector-sticky-provider')),
          matching: find.byType(Text),
        );
        expect(stickyTextFinder, findsOneWidget);

        final stickyBox = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('model-selector-sticky-provider')),
        );
        expect((stickyBox.decoration as BoxDecoration).border, isNull);

        final stickyTitle = tester.widget<Text>(stickyTextFinder).data!;
        final providerIndex = RegExp(
          r'Provider (\d+) Long Name',
        ).firstMatch(stickyTitle)!.group(1)!;
        expect(providerIndex, isNot('0'));

        final chipRect = tester.getRect(
          find.byKey(
            ValueKey('model-selector-provider-tab-provider-$providerIndex'),
          ),
        );
        expect(chipRect.left, greaterThanOrEqualTo(0));
        expect(chipRect.right, lessThanOrEqualTo(390));
        expect(_providerTabSelected(tester, 'provider-0'), isTrue);
        expect(
          _providerTabSelected(tester, 'provider-$providerIndex'),
          isFalse,
        );
      } finally {
        await _dismissModelSelector(tester);
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );

  testWidgets(
    'mobile model selector auto-scroll keeps current model below sticky provider header',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      try {
        final settings = await _settingsWithProviders(tester);
        await settings.setCurrentModel('provider-6', 'provider-6-model-02');
        await _pumpModelSelector(tester, settings: settings);
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        final stickyRect = tester.getRect(
          find.byKey(const ValueKey('model-selector-sticky-provider')),
        );
        final modelText = find.text('provider-6-model-02');
        expect(modelText, findsOneWidget);

        final modelTile = find.ancestor(
          of: modelText,
          matching: find.byType(IosCardPress),
        );
        expect(modelTile, findsOneWidget);
        final modelRect = tester.getRect(modelTile);

        expect(
          modelRect.top,
          greaterThanOrEqualTo(stickyRect.bottom),
          reason: 'Current model should not be hidden by the sticky provider.',
        );
      } finally {
        await _dismissModelSelector(tester);
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );

  testWidgets(
    'mobile model selector omits sticky provider header when limited to one provider',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      try {
        final settings = await _settingsWithProviders(tester);
        await settings.setCurrentModel('provider-6', 'provider-6-model-02');
        await _pumpModelSelector(
          tester,
          settings: settings,
          limitProviderKey: 'provider-6',
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        expect(
          find.byKey(const ValueKey('model-selector-sticky-provider')),
          findsNothing,
        );
        expect(find.text('provider-6-model-02'), findsOneWidget);
      } finally {
        await _dismissModelSelector(tester);
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}
