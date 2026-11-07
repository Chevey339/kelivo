import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/model/widgets/model_spec_form/model_spec_form_controller.dart';
import 'package:Kelivo/features/model/widgets/model_spec_form/strategy_section.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

import '../../../../support/business_test_harness.dart';

ProviderConfig _mistralConfig() {
  return ProviderConfig(
    id: 'Mistral',
    enabled: true,
    name: 'Mistral',
    apiKey: 'test-key',
    baseUrl: 'https://api.mistral.ai/v1',
    providerType: ProviderKind.openai,
    models: const ['mistral-large-latest'],
  );
}

ProviderConfig _openAiConfig() {
  return ProviderConfig(
    id: 'OpenAI',
    enabled: true,
    name: 'OpenAI',
    apiKey: 'test-key',
    baseUrl: 'https://api.openai.com/v1',
    providerType: ProviderKind.openai,
    models: const ['gpt-4o'],
  );
}

ModelSpecFormController _mistralController() {
  return ModelSpecFormController(
    config: _mistralConfig(),
    modelKey: 'mistral-large-latest',
    isNew: false,
  );
}

Future<void> _pump(WidgetTester tester, ModelSpecFormController c) {
  return tester.pumpWidget(
    ChangeNotifierProvider<SettingsProvider>(
      create: (_) => SettingsProvider(createBusinessTestPreferences()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: StrategySection(controller: c)),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Mistral replay field row shows the typed thinking subtitle', (
    tester,
  ) async {
    final c = _mistralController();
    addTearDown(c.dispose);

    await _pump(tester, c);

    expect(c.spec.reasoning.replayField, ReasoningReplayField.mistralThinking);
    expect(find.text('content[].thinking'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('model-spec-mistral-replay-field-warning')),
      findsNothing,
    );
  });

  testWidgets('typed thinking without the Mistral dialect warns', (
    tester,
  ) async {
    final c = _mistralController();
    addTearDown(c.dispose);
    c.setDialect(ReasoningDialect.openaiReasoningEffort);

    await _pump(tester, c);

    expect(
      find.byKey(const ValueKey('model-spec-mistral-replay-field-warning')),
      findsOneWidget,
    );
    expect(
      find.text(
        'History is still replayed as content[].thinking; check that the '
        'current provider supports this format.',
      ),
      findsOneWidget,
    );
    expect(c.spec.reasoning.replayField, ReasoningReplayField.mistralThinking);
  });

  testWidgets(
    'replay field sheet lists Mistral typed thinking and applies it',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final c = _mistralController();
      addTearDown(c.dispose);
      c.setReplayField(ReasoningReplayField.reasoningContent);

      await _pump(tester, c);
      await tester.tap(find.text('reasoning_content'));
      await tester.pumpAndSettle();

      expect(find.text('Mistral typed thinking'), findsOneWidget);
      expect(find.text('content[].thinking'), findsOneWidget);

      final option = find.text('Mistral typed thinking');
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      await tester.tap(option);
      await tester.pumpAndSettle();

      expect(
        c.spec.reasoning.replayField,
        ReasoningReplayField.mistralThinking,
      );
      expect(find.text('content[].thinking'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('non-Mistral providers keep the wire name and no warning', (
    tester,
  ) async {
    final c = ModelSpecFormController(
      config: _openAiConfig(),
      modelKey: 'gpt-4o',
      isNew: false,
    );
    addTearDown(c.dispose);

    await _pump(tester, c);

    expect(c.spec.reasoning.replayField, ReasoningReplayField.reasoningContent);
    expect(find.text('reasoning_content'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('model-spec-mistral-replay-field-warning')),
      findsNothing,
    );
  });
}
