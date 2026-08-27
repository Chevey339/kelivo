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

    test('default ZenMux preset uses the Anthropic-compatible API', () {
      final zenmux = ProviderConfig.defaultsFor('ZenMux');

      expect(zenmux.baseUrl, 'https://zenmux.ai/api/anthropic/v1');
      expect(zenmux.providerType, ProviderKind.claude);
      expect(zenmux.chatPath, isNull);
      expect(zenmux.useResponseApi, isNull);
      expect(zenmux.enabled, isFalse);
      expect(
        ProviderConfig.zenMuxBaseUrlFor(ProviderKind.openai),
        'https://zenmux.ai/api/v1',
      );
      expect(
        ProviderConfig.zenMuxBaseUrlFor(ProviderKind.google),
        'https://zenmux.ai/api/vertex-ai/v1/publishers/google',
      );
      expect(
        ProviderConfig.zenMuxModelSlug('openai/gpt-image-2'),
        'gpt-image-2',
      );
      expect(
        ProviderConfig.zenMuxModelSlug('anthropic/claude-sonnet-4.6'),
        'claude-sonnet-4.6',
      );
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

    test('latest model ids infer only their documented capabilities', () {
      final glm = ModelRegistry.infer(
        ModelInfo(id: 'glm-5.2', displayName: 'glm-5.2'),
      );
      final kimiK2 = ModelRegistry.infer(
        ModelInfo(id: 'kimi-k2.7-code', displayName: 'kimi-k2.7-code'),
      );
      final kimiK3 = ModelRegistry.infer(
        ModelInfo(id: 'kimi-k3', displayName: 'kimi-k3'),
      );
      final muse = ModelRegistry.infer(
        ModelInfo(id: 'muse-spark-1.1', displayName: 'muse-spark-1.1'),
      );

      expect(glm.input, const [Modality.text]);
      expect(glm.output, const [Modality.text]);
      expect(
        glm.abilities,
        containsAll([ModelAbility.tool, ModelAbility.reasoning]),
      );
      for (final model in [kimiK2, kimiK3, muse]) {
        expect(model.input, contains(Modality.image));
        expect(model.output, const [Modality.text]);
        expect(
          model.abilities,
          containsAll([ModelAbility.tool, ModelAbility.reasoning]),
        );
      }
      expect(kimiK2.id, 'kimi-k2.7-code');
      expect(kimiK3.id, 'kimi-k3');
      expect(muse.id, 'muse-spark-1.1');
    });

    test(
      'OpenAI-compatible latest models expose documented effort caps',
      () async {
        final harness = await createBusinessTestHarness(initial: {});
        final settings = SettingsProvider(harness.preferences);

        await settings.loaded;

        expect(
          settings.supportsXhighReasoning('OpenAI', 'gpt-5.6-sol'),
          isTrue,
        );
        expect(settings.supportsMaxReasoning('OpenAI', 'gpt-5.6-sol'), isTrue);
        expect(
          settings.supportsXhighReasoning('OpenRouter', 'openai/gpt-5.6-sol'),
          isTrue,
        );
        expect(
          settings.supportsMaxReasoning('OpenRouter', 'openai/gpt-5.6-sol'),
          isTrue,
        );
        expect(settings.supportsMaxReasoning('OpenAI', 'kimi-k3'), isTrue);
        expect(
          settings.supportsMaxReasoning('OpenRouter', 'moonshotai/kimi-k3'),
          isTrue,
        );
        expect(settings.supportsMaxReasoning('OpenAI', 'grok-4.5'), isFalse);
        expect(settings.supportsXhighReasoning('OpenAI', 'grok-4.6'), isTrue);
        expect(settings.supportsMaxReasoning('OpenAI', 'grok-4.6'), isFalse);
        expect(
          settings.supportsXhighReasoning('OpenAI', 'deepseek-v4-pro'),
          isFalse,
        );
        expect(
          settings.supportsMaxReasoning('OpenAI', 'deepseek-v4-pro'),
          isTrue,
        );
        expect(
          settings.supportsMaxReasoning('OpenAI', 'muse-spark-1.1'),
          isFalse,
        );
      },
    );

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
      'Claude provider resolves apiModelId before DeepSeek max check',
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
          isFalse,
        );
        expect(
          settings.supportsMaxReasoning('ClaudeProxy', 'pro-alias'),
          isTrue,
        );
      },
    );

    group('title generation thinking', () {
      test('defaults to disabled', () async {
        final harness = await createBusinessTestHarness(
          initial: {'thinking_budget_v1': 16000},
        );
        final settings = SettingsProvider(harness.preferences);

        await settings.loaded;

        expect(settings.titleGenerationThinkingEnabled, isFalse);
        expect(settings.titleGenerationThinkingBudgetFor(null), 0);
        expect(settings.titleGenerationThinkingBudgetFor(1024), 0);
      });

      test(
        'disabled title generation thinking resolves to off budget',
        () async {
          final harness = await createBusinessTestHarness(initial: {});
          final settings = SettingsProvider(harness.preferences);

          await settings.loaded;
          await settings.setThinkingBudget(16000);
          await settings.setTitleGenerationThinkingEnabled(true);
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

      test('reset restores disabled default', () async {
        final harness = await createBusinessTestHarness(
          initial: {
            'title_generation_thinking_enabled_v1': true,
            'thinking_budget_v1': 64000,
          },
        );
        final settings = SettingsProvider(harness.preferences);

        await settings.loaded;
        await settings.resetTitleGenerationThinkingEnabled();

        expect(settings.titleGenerationThinkingEnabled, isFalse);
        expect(settings.titleGenerationThinkingBudgetFor(null), 0);

        final prefs = harness.preferences;
        expect(prefs.getBool('title_generation_thinking_enabled_v1'), isFalse);
      });

      test(
        'all utility model thinking toggles default off and persist',
        () async {
          final harness = await createBusinessTestHarness(
            initial: {'thinking_budget_v1': 16000},
          );
          final settings = SettingsProvider(harness.preferences);

          await settings.loaded;

          expect(settings.summaryGenerationThinkingBudgetFor(1024), 0);
          expect(settings.suggestionGenerationThinkingBudgetFor(1024), 0);
          expect(settings.compressGenerationThinkingBudgetFor(1024), 0);
          expect(settings.translateGenerationThinkingBudgetFor(1024), 0);
          expect(settings.ocrGenerationThinkingBudgetFor(1024), 0);

          await settings.setSummaryGenerationThinkingEnabled(true);
          await settings.setSuggestionGenerationThinkingEnabled(true);
          await settings.setCompressGenerationThinkingEnabled(true);
          await settings.setTranslateGenerationThinkingEnabled(true);
          await settings.setOcrGenerationThinkingEnabled(true);

          expect(settings.summaryGenerationThinkingBudgetFor(null), 16000);
          expect(settings.suggestionGenerationThinkingBudgetFor(1024), 1024);
          expect(settings.compressGenerationThinkingBudgetFor(1024), 1024);
          expect(settings.translateGenerationThinkingBudgetFor(1024), 1024);
          expect(settings.ocrGenerationThinkingBudgetFor(1024), 1024);
          expect(
            harness.preferences.getBool(
              'summary_generation_thinking_enabled_v1',
            ),
            isTrue,
          );
          expect(
            harness.preferences.getBool(
              'suggestion_generation_thinking_enabled_v1',
            ),
            isTrue,
          );
          expect(
            harness.preferences.getBool(
              'compress_generation_thinking_enabled_v1',
            ),
            isTrue,
          );
          expect(
            harness.preferences.getBool(
              'translate_generation_thinking_enabled_v1',
            ),
            isTrue,
          );
          expect(
            harness.preferences.getBool('ocr_generation_thinking_enabled_v1'),
            isTrue,
          );
        },
      );
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
            models: const [
              'claude-fable-5',
              'claude-mythos-5',
              'claude-opus-4-8',
              'claude-opus-5',
              'claude-sonnet-5',
            ],
          ),
        );

        for (final model in const [
          'claude-fable-5',
          'claude-mythos-5',
          'claude-opus-4-8',
          'claude-opus-5',
          'claude-sonnet-5',
        ]) {
          expect(settings.supportsXhighReasoning('Claude', model), isTrue);
          expect(settings.supportsMaxReasoning('Claude', model), isTrue);
        }
        expect(settings.getProviderConfig('Claude').models, [
          'claude-fable-5',
          'claude-mythos-5',
          'claude-opus-4-8',
          'claude-opus-5',
          'claude-sonnet-5',
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
