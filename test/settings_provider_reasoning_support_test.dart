import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';

Future<void> _waitForSettingsLoad() async {
  for (var i = 0; i < 25; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider reasoning support', () {
    test('default Claude and OpenRouter presets do not add latest models', () {
      final claude = ProviderConfig.defaultsFor('Claude');
      final openRouter = ProviderConfig.defaultsFor('OpenRouter');

      expect(claude.models, isEmpty);
      expect(claude.modelOverrides, isEmpty);
      expect(openRouter.models, isEmpty);
      expect(openRouter.modelOverrides, isEmpty);
    });

    test('OpenRouter can be routed through Anthropic format explicitly', () {
      final cfg = ProviderConfig(
        id: 'OpenRouterAnthropic',
        enabled: true,
        name: 'OpenRouter Anthropic',
        apiKey: 'test-key',
        baseUrl: 'https://openrouter.ai/api',
        providerType: ProviderKind.claude,
        models: const ['anthropic/claude-fable-5'],
      );

      expect(
        ProviderConfig.classify(cfg.id, explicitType: cfg.providerType),
        ProviderKind.claude,
      );
    });

    test(
      'Claude provider resolves apiModelId before DeepSeek xhigh check',
      () async {
        SharedPreferences.setMockInitialValues({});
        final settings = SettingsProvider();

        await _waitForSettingsLoad();
        await settings.setProviderConfig(
          'ClaudeProxy',
          ProviderConfig(
            id: 'ClaudeProxy',
            enabled: true,
            name: 'Claude Proxy',
            apiKey: 'test-key',
            baseUrl: 'https://proxy.example/anthropic',
            providerType: ProviderKind.claude,
            models: const ['pro-alias'],
            modelOverrides: const {
              'pro-alias': {
                'apiModelId': 'deepseek-v4-pro',
                'type': 'chat',
                'input': ['text'],
                'output': ['text'],
                'abilities': ['reasoning'],
              },
            },
          ),
        );

        expect(
          settings.supportsXhighReasoning('ClaudeProxy', 'pro-alias'),
          isTrue,
        );
      },
    );
  });
}
