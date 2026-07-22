import "support/business_test_harness.dart";
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/model_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';

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

    test('default Atlas Cloud preset uses OpenAI-compatible settings', () {
      final atlas = ProviderConfig.defaultsFor('Atlas Cloud');

      expect(atlas.enabled, isTrue);
      expect(atlas.providerType, ProviderKind.openai);
      expect(atlas.baseUrl, 'https://api.atlascloud.ai/v1');
      expect(atlas.chatPath, '/chat/completions');
      expect(atlas.useResponseApi, isFalse);
      expect(atlas.models, const [
        'qwen/qwen3.5-flash',
        'deepseek-ai/deepseek-v4-pro',
      ]);

      final qwen =
          atlas.modelOverrides['qwen/qwen3.5-flash'] as Map<String, dynamic>;
      final deepseek =
          atlas.modelOverrides['deepseek-ai/deepseek-v4-pro']
              as Map<String, dynamic>;
      expect(qwen['abilities'], const ['tool']);
      expect(deepseek['abilities'], const ['tool', 'reasoning']);
    });

    test('built-in provider order does not add Kimi preset', () async {
      final harness = await createBusinessTestHarness(
        initial: {
          'providers_order_v1': <String>['OpenAI', 'Zhipu AI', 'Grok'],
          'provider_configs_v1': jsonEncode({
            for (final id in const ['OpenAI', 'Zhipu AI', 'Grok'])
              id: ProviderConfig.defaultsFor(id).toJson(),
          }),
        },
      );
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

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
        final harness = await createBusinessTestHarness(initial: {});
        final settings = SettingsProvider(harness.preferences);

        await settings.loaded;
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

    group('title generation thinking', () {
      test(
        'defaults to enabled and preserves existing budget fallback',
        () async {
          final harness = await createBusinessTestHarness(
            initial: {'thinking_budget_v1': 16000},
          );
          final settings = SettingsProvider(harness.preferences);

          await settings.loaded;

          expect(settings.titleGenerationThinkingEnabled, isTrue);
          expect(settings.titleGenerationThinkingBudgetFor(null), 16000);
          expect(settings.titleGenerationThinkingBudgetFor(1024), 1024);
        },
      );

      test(
        'disabled title generation thinking resolves to off budget',
        () async {
          final harness = await createBusinessTestHarness(initial: {});
          final settings = SettingsProvider(harness.preferences);

          await settings.loaded;
          await settings.setThinkingBudget(16000);
          await settings.setTitleGenerationThinkingEnabled(false);

          expect(settings.titleGenerationThinkingEnabled, isFalse);
          expect(settings.titleGenerationThinkingBudgetFor(null), 0);
          expect(settings.titleGenerationThinkingBudgetFor(1024), 0);

          final prefs = harness.preferences;
          expect(
            prefs.getBool('title_generation_thinking_enabled_v1'),
            isFalse,
          );
        },
      );

      test('loads persisted disabled state', () async {
        final harness = await createBusinessTestHarness(
          initial: {'title_generation_thinking_enabled_v1': false},
        );
        final settings = SettingsProvider(harness.preferences);

        await settings.loaded;

        expect(settings.titleGenerationThinkingEnabled, isFalse);
        expect(settings.titleGenerationThinkingBudgetFor(32000), 0);
      });

      test('reset restores enabled fallback behavior', () async {
        final harness = await createBusinessTestHarness(
          initial: {
            'title_generation_thinking_enabled_v1': false,
            'thinking_budget_v1': 64000,
          },
        );
        final settings = SettingsProvider(harness.preferences);

        await settings.loaded;
        await settings.resetTitleGenerationThinkingEnabled();

        expect(settings.titleGenerationThinkingEnabled, isTrue);
        expect(settings.titleGenerationThinkingBudgetFor(null), 64000);

        final prefs = harness.preferences;
        expect(prefs.getBool('title_generation_thinking_enabled_v1'), isTrue);
      });
    });

    test(
      'Claude latest models expose xhigh and max reasoning without presets',
      () async {
        final harness = await createBusinessTestHarness(initial: {});
        final settings = SettingsProvider(harness.preferences);

        await settings.loaded;
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
      },
    );

    test('OpenRouter Anthropic format exposes Claude max reasoning', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;
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
  });
}
