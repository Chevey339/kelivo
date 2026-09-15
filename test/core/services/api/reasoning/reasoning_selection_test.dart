import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/models/reasoning_request.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/reasoning/reasoning_selection.dart';
import 'package:Kelivo/core/services/model_spec/model_spec_resolver.dart';

import '../../../../support/business_test_harness.dart';

ProviderConfig _config() {
  return ProviderConfig(
    id: 'OpenAI',
    enabled: true,
    name: 'OpenAI',
    apiKey: 'test-key',
    baseUrl: 'https://api.openai.com/v1',
    providerType: ProviderKind.openai,
    models: const ['custom-model'],
    modelOverrides: const {
      'custom-model': {
        'type': 'chat',
        'abilities': ['reasoning'],
        'reasoning': {'defaultLevel': 'high'},
      },
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('selectReasoningRequest', () {
    test(
      'uses per-model memory, then assistant, then spec defaultLevel',
      () async {
        final harness = await createBusinessTestHarness(initial: {});
        final settings = SettingsProvider(harness.preferences);
        await settings.loaded;
        final config = _config();
        await settings.setProviderConfig(config.id, config);

        final specDefault = ReasoningRequest(
          ModelSpecResolver.instance
              .spec(config, 'custom-model')
              .reasoning
              .defaultLevel,
        );
        expect(specDefault, const ReasoningRequest(ReasoningLevel.high));
        expect(
          selectReasoningRequest(
            settings: settings,
            config: config,
            modelId: 'custom-model',
          ),
          specDefault,
        );

        const assistant = Assistant(
          id: 'a',
          name: 'A',
          reasoning: ReasoningRequest(ReasoningLevel.low, budgetTokens: 1024),
        );
        expect(
          selectReasoningRequest(
            settings: settings,
            config: config,
            modelId: 'custom-model',
            assistant: assistant,
          ),
          assistant.reasoning,
        );

        const remembered = ReasoningRequest(
          ReasoningLevel.max,
          budgetTokens: 128000,
        );
        await settings.setReasoningChoice(
          config.id,
          'custom-model',
          remembered,
        );
        expect(
          selectReasoningRequest(
            settings: settings,
            config: config,
            modelId: 'custom-model',
            assistant: assistant,
          ),
          remembered,
        );
      },
    );
  });

  group('UI budget mapping', () {
    test('fixed stops map to the P2 levels', () {
      expect(reasoningFromUiBudget(0), ReasoningRequest.off);
      expect(reasoningFromUiBudget(-1), ReasoningRequest.auto);
      expect(
        reasoningFromUiBudget(1024),
        const ReasoningRequest(ReasoningLevel.low, budgetTokens: 1024),
      );
      expect(
        reasoningFromUiBudget(16000),
        const ReasoningRequest(ReasoningLevel.medium, budgetTokens: 16000),
      );
      expect(
        reasoningFromUiBudget(32000),
        const ReasoningRequest(ReasoningLevel.high, budgetTokens: 32000),
      );
      expect(
        reasoningFromUiBudget(64000),
        const ReasoningRequest(ReasoningLevel.xhigh, budgetTokens: 64000),
      );
      expect(
        reasoningFromUiBudget(128000),
        const ReasoningRequest(ReasoningLevel.max, budgetTokens: 128000),
      );
    });

    test('uiBudgetFromReasoning prefers explicit tokens', () {
      expect(uiBudgetFromReasoning(null), -1);
      expect(uiBudgetFromReasoning(ReasoningRequest.off), 0);
      expect(uiBudgetFromReasoning(ReasoningRequest.auto), -1);
      expect(
        uiBudgetFromReasoning(const ReasoningRequest(ReasoningLevel.high)),
        32000,
      );
      expect(
        uiBudgetFromReasoning(
          const ReasoningRequest(ReasoningLevel.low, budgetTokens: 2048),
        ),
        2048,
      );
    });
  });
}
