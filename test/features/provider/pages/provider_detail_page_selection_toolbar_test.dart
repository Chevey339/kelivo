import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Cuplivo/core/providers/assistant_provider.dart';
import 'package:Cuplivo/core/providers/settings_provider.dart';
import 'package:Cuplivo/features/provider/pages/provider_detail_page.dart';
import 'package:Cuplivo/icons/lucide_adapter.dart';
import 'package:Cuplivo/l10n/app_localizations.dart';

Future<SettingsProvider> _createSettings(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsProvider();
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
      ChangeNotifierProvider<AssistantProvider>(
        create: (_) => AssistantProvider(),
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
}
