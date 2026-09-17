import '../../../support/business_test_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/chat/widgets/token_detail_popup.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

class _PricedSettings extends SettingsProvider {
  _PricedSettings() : super(createBusinessTestPreferences());

  @override
  ProviderConfig getProviderConfig(String key, {String? defaultName}) {
    return ProviderConfig(
      id: key,
      enabled: true,
      name: key,
      apiKey: '',
      baseUrl: 'https://api.example.com/v1',
      modelOverrides: {
        'priced-model': const ModelSpecOverride(
          pricing: ModelPricing(input: 1, output: 5, currency: 'USD'),
        ).toJson(),
      },
    );
  }
}

Widget _harness({required Widget child, SettingsProvider? settings}) {
  return ChangeNotifierProvider<SettingsProvider>.value(
    value: settings ?? SettingsProvider(createBusinessTestPreferences()),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows reasoning and cache write rows when non-zero', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      _harness(
        settings: settings,
        child: const TokenDetailPopup(
          promptTokens: 10,
          completionTokens: 4,
          reasoningTokens: 7,
          cacheWriteTokens: 3,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('7 tokens'), findsOneWidget);
    expect(find.text('3 cache write tokens'), findsOneWidget);
    expect(find.text(r'$0'), findsNothing);
  });

  testWidgets('shows a formatted cost row when the model has pricing', (
    tester,
  ) async {
    final settings = _PricedSettings();
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      _harness(
        settings: settings,
        child: const TokenDetailPopup(
          promptTokens: 1000,
          completionTokens: 2000,
          providerId: 'openai',
          modelId: 'priced-model',
        ),
      ),
    );
    await tester.pump();

    expect(find.text(r'$0.011'), findsOneWidget);
  });

  testWidgets('omits the cost row without provider, model, or pricing', (
    tester,
  ) async {
    final settings = _PricedSettings();
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      _harness(
        settings: settings,
        child: const TokenDetailPopup(
          promptTokens: 1000,
          completionTokens: 2000,
          providerId: 'openai',
          modelId: 'unknown-model',
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining(r'$'), findsNothing);

    await tester.pumpWidget(
      _harness(
        settings: settings,
        child: const TokenDetailPopup(
          promptTokens: 1000,
          completionTokens: 2000,
          modelId: 'priced-model',
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining(r'$'), findsNothing);
  });
}
