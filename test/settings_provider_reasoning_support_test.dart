import "support/business_test_harness.dart";
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/model_spec/model_defaults_guesser.dart';

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
      final glm = ModelDefaultsGuesser.guess('glm-5.2');
      final kimiK2 = ModelDefaultsGuesser.guess('kimi-k2.7-code');
      final kimiK3 = ModelDefaultsGuesser.guess('kimi-k3');
      final muse = ModelDefaultsGuesser.guess('muse-spark-1.1');

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
    });

    test('spec ladders drive xhigh / max support', () async {
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
        ),
      );

      const cases = <({String provider, String model, bool xhigh, bool max})>[
        (provider: 'OpenAI', model: 'gpt-5.6-sol', xhigh: true, max: true),
        (
          provider: 'OpenRouter',
          model: 'openai/gpt-5.6-sol',
          xhigh: true,
          max: true,
        ),
        (provider: 'OpenAI', model: 'kimi-k3', xhigh: false, max: true),
        (
          provider: 'OpenRouter',
          model: 'moonshotai/kimi-k3',
          xhigh: false,
          max: true,
        ),
        (provider: 'OpenAI', model: 'grok-4.5', xhigh: false, max: false),
        (provider: 'OpenAI', model: 'grok-4.6', xhigh: true, max: false),
        (provider: 'OpenAI', model: 'deepseek-v4-pro', xhigh: false, max: true),
        (provider: 'OpenAI', model: 'muse-spark-1.1', xhigh: true, max: false),
        (provider: 'OpenAI', model: 'muse-spark-1.3', xhigh: true, max: true),
        (provider: 'OpenAI', model: 'gpt-6-astra', xhigh: true, max: true),
        (provider: 'OpenAI', model: 'glm-5.3', xhigh: false, max: true),
        (provider: 'OpenAI', model: 'glm-5.3-flash', xhigh: false, max: true),
        (provider: 'OpenAI', model: 'glm-5.2', xhigh: true, max: true),
        (provider: 'OpenAI', model: 'gpt-5.3-codex', xhigh: true, max: false),
        (provider: 'OpenAI', model: 'gpt-5.1-codex', xhigh: false, max: false),
        (
          provider: 'OpenAI',
          model: 'gpt-5.1-codex-max',
          xhigh: true,
          max: false,
        ),
        (provider: 'Claude', model: 'claude-fable-5-1', xhigh: true, max: true),
        (provider: 'Claude', model: 'claude-fable-5', xhigh: true, max: true),
        (provider: 'Claude', model: 'claude-mythos-5', xhigh: true, max: true),
        (provider: 'Claude', model: 'claude-opus-4-8', xhigh: true, max: true),
        (provider: 'Claude', model: 'claude-opus-5', xhigh: true, max: true),
        (provider: 'Claude', model: 'claude-sonnet-5', xhigh: true, max: true),
        (
          provider: 'Claude',
          model: 'claude-haiku-4-5',
          xhigh: false,
          max: false,
        ),
        (
          provider: 'Claude',
          model: 'claude-sonnet-4-6',
          xhigh: false,
          max: true,
        ),
      ];

      for (final c in cases) {
        expect(
          settings.supportsXhighReasoning(c.provider, c.model),
          c.xhigh,
          reason: '${c.provider}/${c.model} xhigh',
        );
        expect(
          settings.supportsMaxReasoning(c.provider, c.model),
          c.max,
          reason: '${c.provider}/${c.model} max',
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
