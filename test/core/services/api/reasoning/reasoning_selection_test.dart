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
}
