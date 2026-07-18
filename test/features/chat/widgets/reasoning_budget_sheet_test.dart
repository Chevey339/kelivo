import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/chat/widgets/reasoning_budget_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

Future<SettingsProvider> _settingsForClaudeModel(
  WidgetTester tester,
  String modelId,
) async {
  return _settingsForModel(
    tester,
    providerId: 'Claude',
    providerType: ProviderKind.claude,
    baseUrl: 'https://api.anthropic.com/v1',
    modelId: modelId,
  );
}

Future<SettingsProvider> _settingsForModel(
  WidgetTester tester, {
  required String providerId,
  required ProviderKind providerType,
  required String baseUrl,
  required String modelId,
}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsProvider();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();

  await settings.setProviderConfig(
    providerId,
    ProviderConfig(
      id: providerId,
      enabled: true,
      name: providerId,
      apiKey: 'test-key',
      baseUrl: baseUrl,
      providerType: providerType,
      models: <String>[modelId],
    ),
  );
  await settings.setCurrentModel(providerId, modelId);
  return settings;
}

Future<void> _pumpSheetLauncher(
  WidgetTester tester, {
  required SettingsProvider settings,
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
                key: const ValueKey('open-reasoning-sheet'),
                onPressed: () => showReasoningBudgetSheet(context),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open-reasoning-sheet')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReasoningBudgetSheet', () {
    testWidgets('shows max reasoning for Claude Fable 5', (tester) async {
      final settings = await _settingsForClaudeModel(tester, 'claude-fable-5');
      await _pumpSheetLauncher(tester, settings: settings);

      await _openSheet(tester);

      expect(find.text('Extreme Reasoning'), findsOneWidget);
      expect(find.text('Maximum Reasoning'), findsOneWidget);

      await tester.tap(find.text('Maximum Reasoning'));
      await tester.pumpAndSettle();

      expect(settings.thinkingBudget, 128000);
    });

    testWidgets('keeps max reasoning hidden for older Claude models', (
      tester,
    ) async {
      final settings = await _settingsForClaudeModel(
        tester,
        'claude-sonnet-4-5',
      );
      await _pumpSheetLauncher(tester, settings: settings);

      await _openSheet(tester);

      expect(find.text('Extreme Reasoning'), findsNothing);
      expect(find.text('Maximum Reasoning'), findsNothing);
    });

    testWidgets('shows max reasoning for GPT-5.6 models', (tester) async {
      final settings = await _settingsForModel(
        tester,
        providerId: 'OpenAI',
        providerType: ProviderKind.openai,
        baseUrl: 'https://api.openai.com/v1',
        modelId: 'gpt-5.6-luna',
      );
      await _pumpSheetLauncher(tester, settings: settings);

      await _openSheet(tester);

      expect(find.text('Extreme Reasoning'), findsOneWidget);
      expect(find.text('Maximum Reasoning'), findsOneWidget);

      await tester.tap(find.text('Maximum Reasoning'));
      await tester.pumpAndSettle();

      expect(settings.thinkingBudget, 128000);
    });
  });
}
