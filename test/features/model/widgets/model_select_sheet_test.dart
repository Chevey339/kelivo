import "../../../support/business_test_harness.dart";
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/model/widgets/model_select_sheet.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
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
  final settings = SettingsProvider(createBusinessTestPreferences());
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

Future<SettingsProvider> _settingsWithOnlyTestProviders(
  WidgetTester tester,
) async {
  final settings = await _settingsWithProviders(tester);
  for (final key in settings.providerConfigs.keys.toList()) {
    if (!key.startsWith('provider-')) {
      await settings.removeProviderConfig(key);
    }
  }
  return settings;
}

Future<SettingsProvider> _settingsWithLongSingleProvider(
  WidgetTester tester,
) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsProvider(createBusinessTestPreferences());
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();

  const key = 'provider-long';
  final models = [
    for (var model = 0; model < 20; model++)
      '$key-model-${model.toString().padLeft(2, '0')}',
  ];
  await settings.setProviderConfig(
    key,
    _providerConfig(key, 'Provider Long Name', models),
  );
  await settings.setProvidersOrder(const [key]);
  await settings.setCurrentModel(key, '$key-model-19');
  return settings;
}

Future<void> _pumpModelSelector(
  WidgetTester tester, {
  required SettingsProvider settings,
  String? limitProviderKey,
  String? initialProviderKey,
  String? initialModelId,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<AssistantProvider>(
          create: (_) =>
              AssistantProvider(preferences: createBusinessTestPreferences()),
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
                    initialProviderKey: initialProviderKey,
                    initialModelId: initialModelId,
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

bool _hasInvisibleAncestor(WidgetTester tester, Finder finder) {
  final element = tester.element(finder);
  var hidden = false;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is Visibility && !widget.visible) hidden = true;
    if (widget is Offstage && widget.offstage) hidden = true;
    if (widget is Opacity && widget.opacity == 0) hidden = true;
    return !hidden;
  });
  return hidden;
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
    'mobile model selector uses explicit initial model over global current model',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      try {
        final settings = await _settingsWithOnlyTestProviders(tester);
        await settings.setCurrentModel('provider-0', 'provider-0-model-00');
        await _pumpModelSelector(
          tester,
          settings: settings,
          initialProviderKey: 'provider-6',
          initialModelId: 'provider-6-model-02',
        );
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
          reason:
              'Explicit initial model should drive first-open positioning, '
              'not the global current model.',
        );
        expect(_providerTabSelected(tester, 'provider-6'), isTrue);
        expect(_providerTabSelected(tester, 'provider-0'), isFalse);
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
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

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
    'mobile model selector keeps bottom current model fully visible without top alignment',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      try {
        final settings = await _settingsWithLongSingleProvider(tester);
        await _pumpModelSelector(
          tester,
          settings: settings,
          limitProviderKey: 'provider-long',
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        final listRect = tester.getRect(find.byType(ScrollablePositionedList));
        final modelText = find.text('provider-long-model-19');
        expect(modelText, findsOneWidget);

        final modelTile = find.ancestor(
          of: modelText,
          matching: find.byType(IosCardPress),
        );
        expect(modelTile, findsOneWidget);
        final modelRect = tester.getRect(modelTile);

        expect(
          modelRect.top,
          greaterThan(listRect.top + listRect.height * 0.45),
          reason:
              'Bottom current model should settle near the reachable bottom '
              'instead of being forced toward the top edge.',
        );
        expect(
          modelRect.bottom,
          lessThanOrEqualTo(listRect.bottom),
          reason: 'Bottom current model should remain fully visible.',
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
    'mobile model selector keeps reachable current model near the top',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      try {
        final settings = await _settingsWithOnlyTestProviders(tester);
        await settings.setCurrentModel('provider-6', 'provider-6-model-03');
        await _pumpModelSelector(tester, settings: settings);
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        final listRect = tester.getRect(find.byType(ScrollablePositionedList));
        final modelText = find.text('provider-6-model-03');
        expect(modelText, findsOneWidget);

        final modelTile = find.ancestor(
          of: modelText,
          matching: find.byType(IosCardPress),
        );
        expect(modelTile, findsOneWidget);
        final modelRect = tester.getRect(modelTile);

        expect(
          modelRect.top,
          lessThan(listRect.top + listRect.height * 0.25),
          reason:
              'Reachable current model should keep the original top-biased '
              'auto-scroll position.',
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
    'mobile model selector keeps provider headers visible with compact overlay',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      try {
        final settings = await _settingsWithProviders(tester);
        await _pumpModelSelector(tester, settings: settings);
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        final stickyRect = tester.getRect(
          find.byKey(const ValueKey('model-selector-sticky-provider')),
        );
        final seamCoverRect = tester.getRect(
          find.byKey(const ValueKey('model-selector-top-seam-cover')),
        );

        expect(stickyRect.height, lessThan(38));
        expect(seamCoverRect.height, 1);

        final currentProviderHeaderInList = find.descendant(
          of: find.byType(ScrollablePositionedList),
          matching: find.text('Provider 0 Long Name'),
        );
        expect(currentProviderHeaderInList, findsOneWidget);
        expect(
          _hasInvisibleAncestor(tester, currentProviderHeaderInList),
          isFalse,
        );

        final nextProviderHeaderInList = find.descendant(
          of: find.byType(ScrollablePositionedList),
          matching: find.text('Provider 1 Long Name'),
        );
        expect(nextProviderHeaderInList, findsOneWidget);
        expect(
          _hasInvisibleAncestor(tester, nextProviderHeaderInList),
          isFalse,
        );

        final listRect = tester.getRect(find.byType(ScrollablePositionedList));
        final nextHeaderRect = tester.getRect(nextProviderHeaderInList);
        expect(nextHeaderRect.top, greaterThanOrEqualTo(listRect.top));
        expect(nextHeaderRect.bottom, lessThanOrEqualTo(listRect.bottom));
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
    'mobile model selector does not reserve sticky space above favorites',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      try {
        final settings = await _settingsWithProviders(tester);
        await settings.togglePinModel('provider-0', 'provider-0-model-00');
        await _pumpModelSelector(tester, settings: settings);
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        await tester.tap(find.byIcon(Lucide.Bookmark));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        expect(
          find.byKey(const ValueKey('model-selector-sticky-provider')),
          findsNothing,
        );
        final seamCoverRect = tester.getRect(
          find.byKey(const ValueKey('model-selector-top-seam-cover')),
        );
        expect(seamCoverRect.height, 1);

        final favoritesHeader = find.descendant(
          of: find.byType(ScrollablePositionedList),
          matching: find.text('Favorites'),
        );
        expect(favoritesHeader, findsOneWidget);
        expect(_hasInvisibleAncestor(tester, favoritesHeader), isFalse);

        final listRect = tester.getRect(find.byType(ScrollablePositionedList));
        final favoritesRect = tester.getRect(favoritesHeader);
        expect(favoritesRect.top, lessThan(listRect.top + 20));
        expect(favoritesRect.bottom, greaterThan(listRect.top));
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
