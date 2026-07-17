import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Cuplivo/core/providers/model_provider.dart';
import 'package:Cuplivo/core/providers/settings_provider.dart';

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

    test('default Zhipu preset stays user-configured only', () {
      final zhipu = ProviderConfig.defaultsFor('Zhipu AI');

      expect(zhipu.baseUrl, 'https://open.bigmodel.cn/api/paas/v4');
      expect(zhipu.models, isEmpty);
      expect(zhipu.modelOverrides, isEmpty);
    });

    test('default Moonshot preset stays user-configured only', () {
      final moonshot = ProviderConfig.defaultsFor('Moonshot');

      expect(moonshot.baseUrl, 'https://api.moonshot.cn/v1');
      expect(moonshot.models, isEmpty);
      expect(moonshot.modelOverrides, isEmpty);
    });

    test('built-in provider order does not add Kimi preset', () async {
      SharedPreferences.setMockInitialValues({
        'providers_order_v1': <String>['OpenAI', 'Zhipu AI', 'Grok'],
      });
      final settings = SettingsProvider();

      await _waitForSettingsLoad();

      expect(settings.providersOrder, isNot(contains('Kimi')));
      expect(settings.providersOrder.take(3), ['OpenAI', 'Zhipu AI', 'Grok']);
    });

    test('latest GLM and Kimi model ids infer expected capabilities', () {
      final glm = ModelRegistry.infer(
        ModelInfo(id: 'glm-5.2', displayName: 'glm-5.2'),
      );
      final kimi = ModelRegistry.infer(
        ModelInfo(id: 'kimi-k2.7-code', displayName: 'kimi-k2.7-code'),
      );

      expect(glm.input, const [Modality.text]);
      expect(glm.output, const [Modality.text]);
      expect(
        glm.abilities,
        containsAll([ModelAbility.tool, ModelAbility.reasoning]),
      );
      expect(kimi.input, contains(Modality.image));
      expect(kimi.output, const [Modality.text]);
      expect(
        kimi.abilities,
        containsAll([ModelAbility.tool, ModelAbility.reasoning]),
      );
    });

    test('Kimi K3 model ids infer expected capabilities', () {
      for (final id in const ['kimi-k3', 'k3']) {
        final m = ModelRegistry.infer(ModelInfo(id: id, displayName: id));
        expect(m.input, contains(Modality.image), reason: '$id vision');
        expect(m.output, const [Modality.text], reason: '$id output');
        expect(
          m.abilities,
          containsAll([ModelAbility.tool, ModelAbility.reasoning]),
          reason: '$id abilities',
        );
      }
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
          'OpenRouter',
          ProviderConfig(
            id: 'OpenRouter',
            enabled: true,
            name: 'OpenRouter',
            apiKey: 'test-key',
            baseUrl: 'https://openrouter.ai/api/v1',
            providerType: ProviderKind.claude,
            models: const ['deepseek/deepseek-v3.2'],
            modelOverrides: const {
              'deepseek/deepseek-v3.2': <String, dynamic>{
                'apiModelId': 'deepseek/deepseek-v3.2',
              },
            },
          ),
        );

        expect(
          settings.supportsXhighReasoning(
            'OpenRouter',
            'deepseek/deepseek-v3.2',
          ),
          isTrue,
        );
      },
    );

    test('Claude supports xhigh and max for fable / mythos series', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();
      await settings.setProviderConfig(
        'Claude',
        ProviderConfig(
          id: 'Claude',
          enabled: true,
          name: 'Claude',
          apiKey: 'test-key',
          baseUrl: 'https://api.anthropic.com/v1',
          providerType: ProviderKind.claude,
          models: const ['claude-fable-5', 'claude-opus-4-8'],
        ),
      );

      for (final model in const ['claude-fable-5', 'claude-opus-4-8']) {
        expect(settings.supportsXhighReasoning('Claude', model), isTrue);
        expect(settings.supportsMaxReasoning('Claude', model), isTrue);
      }
      expect(settings.getProviderConfig('Claude').models, [
        'claude-fable-5',
        'claude-opus-4-8',
      ]);
    });

    test('OpenRouter Anthropic format exposes Claude max reasoning', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();
      await settings.setProviderConfig(
        'OpenRouterAnthropic',
        ProviderConfig(
          id: 'OpenRouterAnthropic',
          enabled: true,
          name: 'OpenRouter Anthropic',
          apiKey: 'test-key',
          baseUrl: 'https://openrouter.ai/api/v1',
          providerType: ProviderKind.claude,
          models: const ['anthropic/claude-fable-5'],
        ),
      );

      expect(
        settings.supportsXhighReasoning(
          'OpenRouterAnthropic',
          'anthropic/claude-fable-5',
        ),
        isTrue,
      );
      expect(
        settings.supportsMaxReasoning(
          'OpenRouterAnthropic',
          'anthropic/claude-fable-5',
        ),
        isTrue,
      );
    });

    test('Kimi K3 supports max but not xhigh reasoning (kimi-k3)', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();
      await settings.setProviderConfig(
        'Moonshot',
        ProviderConfig(
          id: 'Moonshot',
          enabled: true,
          name: 'Moonshot',
          apiKey: 'test-key',
          baseUrl: 'https://api.moonshot.cn/v1',
          providerType: ProviderKind.openai,
          models: const ['kimi-k3'],
        ),
      );

      expect(settings.supportsXhighReasoning('Moonshot', 'kimi-k3'), isFalse);
      expect(settings.supportsMaxReasoning('Moonshot', 'kimi-k3'), isTrue);
    });

    test('Kimi K3 supports max but not xhigh reasoning (bare k3)', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();
      await settings.setProviderConfig(
        'Moonshot',
        ProviderConfig(
          id: 'Moonshot',
          enabled: true,
          name: 'Moonshot',
          apiKey: 'test-key',
          baseUrl: 'https://api.moonshot.cn/v1',
          providerType: ProviderKind.openai,
          models: const ['k3'],
        ),
      );

      expect(settings.supportsXhighReasoning('Moonshot', 'k3'), isFalse);
      expect(settings.supportsMaxReasoning('Moonshot', 'k3'), isTrue);
    });
  });
}
