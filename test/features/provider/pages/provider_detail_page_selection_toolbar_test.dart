import "../../../support/business_test_harness.dart";
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/provider/pages/provider_detail_page.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';

Future<SettingsProvider> _createSettings(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsProvider(createBusinessTestPreferences());
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
  await settings.setProviderConfig(
    'TestProvider',
    ProviderConfig(
      id: 'TestProvider',
      enabled: true,
      name: 'Test Provider',
      apiKey: 'test-key',
      baseUrl: 'https://example.test',
      providerType: ProviderKind.openai,
      models: const ['model-a', 'model-b'],
    ),
  );
  return settings;
}

Widget _buildHarness({
  required SettingsProvider settings,
  required Widget child,
  Locale? locale,
  TextScaler? textScaler,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ChangeNotifierProvider<ChatService>(create: (_) => ChatService()),
      ChangeNotifierProvider<AssistantProvider>(
        create: (_) =>
            AssistantProvider(preferences: createBusinessTestPreferences()),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      builder: (context, child) {
        final scaler = textScaler;
        if (scaler == null || child == null) return child ?? const SizedBox();
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: child,
        );
      },
      home: child,
    ),
  );
}

Future<void> _pumpSelectedToolbar(
  WidgetTester tester, {
  required double width,
  TextScaler? textScaler,
}) async {
  tester.view.physicalSize = Size(width, 720);
  tester.view.devicePixelRatio = 1;

  final settings = await _createSettings(tester);
  await tester.pumpWidget(
    _buildHarness(
      settings: settings,
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      textScaler: textScaler,
      child: const ProviderDetailPage(
        keyName: 'TestProvider',
        displayName: 'Test Provider',
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('模型'));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Lucide.CheckSquare).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Lucide.CheckSquare).first);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile conversation cache key switch saves and restores', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = await _createSettings(tester);
    addTearDown(settings.dispose);
    Widget page() => _buildHarness(
      settings: settings,
      locale: const Locale('en'),
      child: const ProviderDetailPage(
        keyName: 'TestProvider',
        displayName: 'Test Provider',
      ),
    );
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    final cacheSwitch = find.byWidgetPredicate(
      (widget) =>
          widget is IosSwitch &&
          widget.semanticLabel == 'Send Conversation Cache Key',
    );
    expect(cacheSwitch, findsOneWidget);
    expect(tester.widget<IosSwitch>(cacheSwitch).value, isFalse);
    await tester.ensureVisible(cacheSwitch);
    await tester.tap(cacheSwitch);
    await tester.pumpAndSettle();
    expect(
      settings.getProviderConfig('TestProvider').promptCacheKeyEnabled,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(tester.widget<IosSwitch>(cacheSwitch).value, isTrue);
    await tester.ensureVisible(cacheSwitch);
    await tester.tap(cacheSwitch);
    await tester.pumpAndSettle();
    expect(
      settings.getProviderConfig('TestProvider').promptCacheKeyEnabled,
      isFalse,
    );
    await tester.pumpWidget(const SizedBox());
    await settings.setProviderConfig(
      'TestProvider',
      settings
          .getProviderConfig('TestProvider')
          .copyWith(providerType: ProviderKind.google),
    );
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(cacheSwitch, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'model selection toolbar keeps detect label before delete label on narrow phones',
    (tester) async {
      tester.view.physicalSize = const Size(400, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpSelectedToolbar(tester, width: 400);

      final detectText = find.text('检测');
      expect(find.text('全不选'), findsOneWidget);
      expect(detectText, findsOneWidget);
      expect(tester.getSize(detectText).width, greaterThan(20));
      expect(find.text('删除'), findsNothing);
      expect(find.byIcon(Lucide.HeartPulse), findsOneWidget);
      expect(find.byIcon(Lucide.Trash2), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('model selection toolbar does not overflow on narrow phones', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in const <double>[320, 360, 375, 390, 400]) {
      await _pumpSelectedToolbar(tester, width: width);

      expect(find.byIcon(Lucide.HeartPulse), findsOneWidget);
      expect(find.byIcon(Lucide.Trash2), findsWidgets);
      expect(tester.takeException(), isNull, reason: 'width $width');

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('model selection toolbar shows tooltip on long press', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpSelectedToolbar(tester, width: 320);

    expect(find.text('使用流式'), findsNothing);

    await tester.longPress(find.byIcon(Lucide.SquareEqual));
    await tester.pumpAndSettle();

    expect(find.text('使用流式'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile provider config persists custom request rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = await _createSettings(tester);
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      _buildHarness(
        settings: settings,
        locale: const Locale('en'),
        child: const ProviderDetailPage(
          keyName: 'TestProvider',
          displayName: 'Test Provider',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Custom request editor lives on a dedicated page after the UI refactor.
    final customRequestEntry = find.text('Custom Request');
    await tester.ensureVisible(customRequestEntry);
    await tester.pumpAndSettle();
    await tester.tap(customRequestEntry);
    await tester.pumpAndSettle();

    final addHeader = find.byKey(const ValueKey('provider-custom-header-add'));
    await tester.ensureVisible(addHeader);
    await tester.pumpAndSettle();
    await tester.tap(addHeader);
    await tester.pump();

    expect(
      settings.getProviderConfig('TestProvider').customHeaders,
      hasLength(1),
    );
    await tester.enterText(
      find.byKey(const ValueKey('provider-custom-header-name-0')),
      'X-Mobile',
    );
    await tester.enterText(
      find.byKey(const ValueKey('provider-custom-header-value-0')),
      'saved',
    );
    await tester.pump();

    expect(settings.getProviderConfig('TestProvider').customHeaders, [
      {'name': 'X-Mobile', 'value': 'saved'},
    ]);
  });
}
