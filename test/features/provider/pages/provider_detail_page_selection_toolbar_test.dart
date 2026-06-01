import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/provider/pages/provider_detail_page.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

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
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'model selection toolbar hides all action labels on narrow phones',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settings = await _createSettings(tester);
      await tester.pumpWidget(
        _buildHarness(
          settings: settings,
          child: const ProviderDetailPage(
            keyName: 'TestProvider',
            displayName: 'Test Provider',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Models'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Lucide.CheckSquare).first);
      await tester.pumpAndSettle();

      expect(find.text('Detect'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Select All'), findsNothing);
      expect(find.byIcon(Lucide.HeartPulse), findsOneWidget);
      expect(find.byIcon(Lucide.Trash2), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
