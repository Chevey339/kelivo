import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/models/provider_oauth.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/reasoning/reasoning_dialects.dart';
import 'package:Kelivo/core/services/model_catalog/catalog_entry.dart';
import 'package:Kelivo/core/services/model_catalog/model_catalog_service.dart';
import 'package:Kelivo/core/services/model_spec/model_spec_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late ModelCatalogService catalog;
  late ModelSpecResolver resolver;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    tempDir = await Directory.systemTemp.createTemp('model_spec_resolver_');
    catalog = ModelCatalogService(
      loadBundledJson: () async => '{}',
      cacheDirectory: () async => tempDir,
      clientFactory: () => MockClient((_) async => http.Response('{}', 500)),
      prefs: SharedPreferences.getInstance,
    )..debugSetData(_catalogData());
    resolver = ModelSpecResolver(catalog: catalog);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ModelSpecResolver', () {
    test(
      'default inputs respect transport while explicit overrides remain editable',
      () {
        final config = _cfg(
          id: 'proxy',
          kind: ProviderKind.openai,
          baseUrl: 'https://proxy.example.com',
        );
        expect(
          resolver.spec(config, 'gemini-3-flash-preview').input,
          containsAll([Modality.audio, Modality.video, Modality.pdf]),
        );
        final responses = config.copyWith(useResponseApi: true);
        expect(resolver.spec(responses, 'gemini-3-flash-preview').input, [
          Modality.text,
          Modality.image,
          Modality.pdf,
        ]);
        final claude = config.copyWith(providerType: ProviderKind.claude);
        expect(resolver.spec(claude, 'gemini-3-flash-preview').input, [
          Modality.text,
          Modality.image,
          Modality.pdf,
        ]);
        final overridden = responses.copyWith(
          modelOverrides: {
            'gemini-3-flash-preview': {
              'input': ['text', 'audio'],
            },
          },
        );
        expect(resolver.spec(overridden, 'gemini-3-flash-preview').input, [
          Modality.text,
          Modality.audio,
        ]);
      },
    );

    test('catalog beats guesser for gpt-5.1 levels and limits', () {
      final resolved = resolver.resolve(_openai(), 'gpt-5.1');
      final spec = resolved.spec;

      expect(spec.type, ModelType.chat);
      expect(resolved.sources[ModelSpecField.type], SpecSource.catalog);
      expect(spec.abilities, contains(ModelAbility.tool));
      expect(spec.abilities, contains(ModelAbility.reasoning));
      expect(resolved.sources[ModelSpecField.abilities], SpecSource.catalog);
      expect(spec.reasoning.levels, [
        ReasoningLevel.low,
        ReasoningLevel.medium,
        ReasoningLevel.high,
      ]);
      expect(
        resolved.sources[ModelSpecField.reasoningLevels],
        SpecSource.catalog,
      );
      expect(spec.reasoning.canDisable, isTrue);
      expect(
        resolved.sources[ModelSpecField.reasoningCanDisable],
        SpecSource.catalog,
      );
      expect(spec.contextWindow, 400000);
      expect(
        resolved.sources[ModelSpecField.contextWindow],
        SpecSource.catalog,
      );
      expect(spec.maxOutput, 128000);
      expect(resolved.sources[ModelSpecField.maxOutput], SpecSource.catalog);
      expect(spec.pricing?.input, 1.25);
      expect(spec.pricing?.output, 10);
      expect(spec.pricing?.currency, 'USD');
      expect(resolved.sources[ModelSpecField.pricing], SpecSource.catalog);
      expect(spec.sampling, SamplingPolicy.always);
    });

    test('gpt-image-1 is an image model from catalog output', () {
      final resolved = resolver.resolve(_openai(), 'gpt-image-1');
      expect(resolved.spec.type, ModelType.image);
      expect(resolved.sources[ModelSpecField.type], SpecSource.catalog);
      expect(resolved.spec.output, contains(Modality.image));
    });

    test('override beats catalog input on claude', () {
      final ov = <String, dynamic>{
        'claude-sonnet-4.6': <String, dynamic>{
          'input': <String>['text'],
        },
      };
      final cfg = _anthropic(overrides: ov);
      final resolved = resolver.resolve(cfg, 'claude-sonnet-4.6');

      expect(resolved.spec.input, [Modality.text]);
      expect(resolved.sources[ModelSpecField.input], SpecSource.override);
      expect(resolved.base.input, contains(Modality.pdf));
      expect(resolved.base.input, contains(Modality.image));
      expect(resolved.sources[ModelSpecField.abilities], SpecSource.catalog);
    });

    test('catalog supplies claude pdf input and effort levels', () {
      final resolved = resolver.resolve(_anthropic(), 'claude-sonnet-4.6');
      expect(resolved.spec.input, contains(Modality.pdf));
      expect(resolved.sources[ModelSpecField.input], SpecSource.catalog);
      expect(resolved.spec.reasoning.levels, [
        ReasoningLevel.low,
        ReasoningLevel.medium,
        ReasoningLevel.high,
        ReasoningLevel.max,
      ]);
      expect(
        resolved.sources[ModelSpecField.reasoningLevels],
        SpecSource.catalog,
      );
      expect(resolved.spec.reasoning.canDisable, isTrue);
      expect(resolved.spec.pricing?.cacheWrite, 3.75);
    });

    test('guesser is used when the host has no catalog match', () {
      final cfg = _cfg(
        id: 'proxy',
        kind: ProviderKind.openai,
        baseUrl: 'https://proxy.example.com',
      );
      final resolved = resolver.resolve(cfg, 'gpt-5.6-sol');
      expect(resolved.catalog, isNull);
      expect(resolved.sources[ModelSpecField.type], SpecSource.guess);
      expect(resolved.sources[ModelSpecField.abilities], SpecSource.guess);
      expect(resolved.spec.abilities, contains(ModelAbility.reasoning));
      expect(resolved.spec.reasoning.levels, [
        ReasoningLevel.low,
        ReasoningLevel.medium,
        ReasoningLevel.high,
        ReasoningLevel.xhigh,
        ReasoningLevel.max,
      ]);
      expect(
        resolved.sources[ModelSpecField.reasoningLevels],
        SpecSource.guess,
      );
    });

    test('gemini-2.5-pro budgets come from catalog max', () {
      final resolved = resolver.resolve(_google(), 'gemini-2.5-pro');
      final budgets = resolved.spec.reasoning.budgets;
      expect(
        resolved.spec.reasoning.dialect,
        ReasoningDialect.geminiThinkingBudget,
      );
      expect(
        resolved.sources[ModelSpecField.reasoningBudgets],
        SpecSource.catalog,
      );
      expect(budgets[ReasoningLevel.low], greaterThanOrEqualTo(1024));
      expect(budgets[ReasoningLevel.max], 32768);
      for (final entry in budgets.entries) {
        final value = entry.value;
        final multipleOf256 = value % 256 == 0;
        final clamped = value == 32768;
        expect(multipleOf256 || clamped, isTrue, reason: '${entry.key}=$value');
      }
    });

    test(
      'anthropicBudget dialect without catalog max uses the fixed table',
      () {
        final resolved = resolver.resolve(_anthropic(), 'claude-3-5-sonnet');
        expect(
          resolved.spec.reasoning.dialect,
          ReasoningDialect.anthropicBudget,
        );
        expect(
          resolved.sources[ModelSpecField.reasoningBudgets],
          SpecSource.fallback,
        );
        expect(resolved.spec.reasoning.budgets, {
          ReasoningLevel.low: 1024,
          ReasoningLevel.medium: 4096,
          ReasoningLevel.high: 8192,
        });
      },
    );

    test('canDisable is true via toggle and false for effort-only ladders', () {
      final deepseek = resolver.resolve(_deepseek(), 'deepseek-v4-pro');
      expect(deepseek.spec.reasoning.canDisable, isTrue);
      expect(
        deepseek.sources[ModelSpecField.reasoningCanDisable],
        SpecSource.catalog,
      );

      final o3 = resolver.resolve(_openai(), 'o3');
      expect(o3.spec.reasoning.canDisable, isFalse);
      expect(
        o3.sources[ModelSpecField.reasoningCanDisable],
        SpecSource.catalog,
      );
    });

    test('sampling never comes from catalog temperature false', () {
      final resolved = resolver.resolve(_deepseek(), 'deepseek-v4-pro');
      expect(resolved.spec.sampling, SamplingPolicy.never);
      expect(resolved.sources[ModelSpecField.sampling], SpecSource.catalog);
    });

    test('replay comes from catalog interleavedField', () {
      final resolved = resolver.resolve(_anthropic(), 'claude-sonnet-4.6');
      expect(resolved.spec.reasoning.replay, ReasoningReplayPolicy.all);
      expect(
        resolved.spec.reasoning.replayField,
        ReasoningReplayField.reasoningContent,
      );
      expect(
        resolved.sources[ModelSpecField.reasoningReplay],
        SpecSource.catalog,
      );
    });

    test('deepseek host dialect is vendor; guesser replay beats catalog', () {
      final resolved = resolver.resolve(_deepseek(), 'deepseek-v4-pro');
      expect(resolved.spec.reasoning.dialect, ReasoningDialect.thinkingType);
      expect(
        resolved.sources[ModelSpecField.reasoningDialect],
        SpecSource.vendor,
      );
      expect(resolved.spec.reasoning.replay, ReasoningReplayPolicy.all);
      expect(
        resolved.spec.reasoning.replayField,
        ReasoningReplayField.reasoningContent,
      );
      expect(
        resolved.sources[ModelSpecField.reasoningReplay],
        SpecSource.guess,
      );
    });

    test('supported replay defaults to all and explicit overrides win', () {
      for (final target in [
        (config: _deepseek(), model: 'deepseek-v4-pro'),
        (config: _openai(), model: 'kimi-k2.6'),
        (config: _openai(), model: 'glm-5.2'),
        (config: _anthropic(), model: 'claude-sonnet-4.6'),
        (config: _openai().copyWith(useResponseApi: true), model: 'gpt-5.1'),
        (
          config: _openai().copyWith(oauthProvider: OAuthProvider.chatgpt),
          model: 'gpt-5.1',
        ),
      ]) {
        for (final policy in [
          ReasoningReplayPolicy.none,
          ReasoningReplayPolicy.toolTurns,
        ]) {
          final config = target.config.copyWith(
            modelOverrides: {
              target.model: {
                'reasoning': {'replay': policy.name},
              },
            },
          );
          final resolved = resolver.resolve(config, target.model);
          expect(resolved.spec.reasoning.replay, policy);
          expect(resolved.base.reasoning.replay, ReasoningReplayPolicy.all);
          expect(
            resolved.sources[ModelSpecField.reasoningReplay],
            SpecSource.override,
          );
        }
      }
      // Chat Completions GPT does not accept the third-party reasoning field.
      expect(
        resolver.spec(_openai(), 'gpt-5.1').reasoning.replay,
        ReasoningReplayPolicy.none,
      );
    });

    test(
      'Kimi OAuth protocol is resolved per model without changing saved config',
      () {
        final config = _openai().copyWith(
          oauthProvider: OAuthProvider.kimi,
          modelOverrides: {
            'kimi-for-coding': {'oauthProtocol': 'anthropic'},
            'kimi-k2.5': {'oauthProtocol': 'openai'},
          },
        );
        expect(
          resolver.spec(config, 'kimi-for-coding').reasoning.dialect,
          ReasoningDialect.anthropicBudget,
        );
        expect(config.providerType, ProviderKind.openai);
        expect(config.forModelProtocol('kimi-k2.5'), same(config));
        expect(config.forModelProtocol('unknown'), same(config));
        final ordinary = _openai().copyWith(
          modelOverrides: config.modelOverrides,
        );
        expect(ordinary.forModelProtocol('kimi-for-coding'), same(ordinary));
      },
    );

    test('sparse reasoning override leaves catalog levels intact', () {
      final ov = <String, dynamic>{
        'claude-sonnet-4.6': <String, dynamic>{
          'reasoning': <String, dynamic>{'replay': 'all'},
        },
      };
      final resolved = resolver.resolve(
        _anthropic(overrides: ov),
        'claude-sonnet-4.6',
      );
      expect(resolved.spec.reasoning.replay, ReasoningReplayPolicy.all);
      expect(
        resolved.sources[ModelSpecField.reasoningReplay],
        SpecSource.override,
      );
      expect(resolved.spec.reasoning.levels, [
        ReasoningLevel.low,
        ReasoningLevel.medium,
        ReasoningLevel.high,
        ReasoningLevel.max,
      ]);
      expect(
        resolved.sources[ModelSpecField.reasoningLevels],
        SpecSource.catalog,
      );
      expect(resolved.base.reasoning.replay, ReasoningReplayPolicy.all);
    });

    test('base has no override while spec does', () {
      final ov = <String, dynamic>{
        'gpt-5.1': <String, dynamic>{
          'name': 'My GPT',
          'input': <String>['text'],
        },
      };
      final resolved = resolver.resolve(
        _openai(overrides: ov),
        'gpt-5.1',
        displayName: 'GPT-5.1',
      );
      expect(resolved.spec.displayName, 'My GPT');
      expect(resolved.base.displayName, 'GPT-5.1');
      expect(resolved.spec.input, [Modality.text]);
      expect(resolved.base.input, isNot([Modality.text]));
      expect(resolved.override.displayName, 'My GPT');
    });

    test(
      'memo returns the same instance until catalog or override changes',
      () {
        final overrides = <String, dynamic>{};
        final cfg = _openai(overrides: overrides);
        final first = resolver.resolve(cfg, 'gpt-5.1');
        final second = resolver.resolve(cfg, 'gpt-5.1');
        expect(identical(first, second), isTrue);

        catalog.debugSetData(_catalogData());
        final afterCatalog = resolver.resolve(cfg, 'gpt-5.1');
        expect(identical(first, afterCatalog), isFalse);

        final newOverrides = <String, dynamic>{
          'gpt-5.1': <String, dynamic>{
            'input': <String>['text'],
          },
        };
        final afterOverride = resolver.resolve(
          cfg.copyWith(modelOverrides: newOverrides),
          'gpt-5.1',
        );
        expect(identical(afterCatalog, afterOverride), isFalse);
        expect(
          afterOverride.sources[ModelSpecField.input],
          SpecSource.override,
        );
      },
    );

    test(
      'gemini-3-pro-preview keeps guesser levels when options are empty',
      () {
        final resolved = resolver.resolve(_google(), 'gemini-3-pro-preview');
        expect(
          resolved.spec.reasoning.dialect,
          ReasoningDialect.geminiThinkingLevel,
        );
        expect(resolved.spec.reasoning.levels, [
          ReasoningLevel.low,
          ReasoningLevel.high,
        ]);
        expect(
          resolved.sources[ModelSpecField.reasoningLevels],
          SpecSource.guess,
        );
        expect(resolved.spec.reasoning.canDisable, isFalse);
      },
    );

    test(
      'guessed toggle-only models keep empty levels; unknown ids get the effort ladder',
      () {
        final cfg = _cfg(
          id: 'Moonshot',
          kind: ProviderKind.openai,
          baseUrl: 'https://api.moonshot.cn/v1',
        );

        final kimi = resolver.resolve(cfg, 'kimi-k2.6');
        expect(kimi.catalog, isNull);
        expect(kimi.spec.reasoning.levels, isEmpty);
        expect(kimi.sources[ModelSpecField.reasoningLevels], SpecSource.guess);
        expect(kimi.spec.reasoning.dialect, ReasoningDialect.kimiThinking);

        final unknown = resolver.resolve(cfg, 'stealth/ox-alpha');
        expect(unknown.catalog, isNull);
        expect(unknown.spec.reasoning.levels, [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
        ]);
        expect(
          unknown.sources[ModelSpecField.reasoningLevels],
          SpecSource.fallback,
        );
      },
    );

    test('unknown chat models get the provider-default reasoning spec', () {
      const id = 'stealth/ox-alpha';

      final openai = resolver.resolve(_openai(), id);
      expect(openai.spec.abilities, isNot(contains(ModelAbility.reasoning)));
      expect(
        openai.spec.reasoning.dialect,
        ReasoningDialect.openaiReasoningEffort,
      );
      expect(
        openai.sources[ModelSpecField.reasoningDialect],
        SpecSource.vendor,
      );
      expect(openai.spec.reasoning.levels, [
        ReasoningLevel.low,
        ReasoningLevel.medium,
        ReasoningLevel.high,
      ]);
      expect(
        openai.sources[ModelSpecField.reasoningLevels],
        SpecSource.fallback,
      );
      expect(openai.spec.reasoning.canDisable, isTrue);
      expect(
        openai.sources[ModelSpecField.reasoningCanDisable],
        SpecSource.fallback,
      );
      expect(openai.spec.reasoning.defaultLevel, ReasoningLevel.auto);
      expect(
        openai.sources[ModelSpecField.reasoningDefaultLevel],
        SpecSource.fallback,
      );

      final claude = resolver.resolve(_anthropic(), id);
      expect(claude.spec.reasoning.dialect, ReasoningDialect.anthropicBudget);
      expect(
        claude.sources[ModelSpecField.reasoningDialect],
        SpecSource.vendor,
      );
      expect(claude.spec.reasoning.levels, [
        ReasoningLevel.low,
        ReasoningLevel.medium,
        ReasoningLevel.high,
        ReasoningLevel.xhigh,
        ReasoningLevel.max,
      ]);
      expect(
        claude.sources[ModelSpecField.reasoningLevels],
        SpecSource.fallback,
      );
      expect(claude.spec.reasoning.canDisable, isTrue);
      expect(claude.spec.reasoning.defaultLevel, ReasoningLevel.auto);

      final google = resolver.resolve(_google(), id);
      expect(
        google.spec.reasoning.dialect,
        ReasoningDialect.geminiThinkingBudget,
      );
      expect(
        google.sources[ModelSpecField.reasoningDialect],
        SpecSource.vendor,
      );
      expect(google.spec.reasoning.levels, [
        ReasoningLevel.low,
        ReasoningLevel.medium,
        ReasoningLevel.high,
        ReasoningLevel.xhigh,
        ReasoningLevel.max,
      ]);
      expect(
        google.sources[ModelSpecField.reasoningLevels],
        SpecSource.fallback,
      );
      expect(google.spec.reasoning.canDisable, isTrue);

      final responses = resolver.resolve(
        _openai().copyWith(useResponseApi: true),
        id,
      );
      expect(
        responses.spec.reasoning.dialect,
        ReasoningDialect.openaiResponsesReasoning,
      );
      expect(
        responses.sources[ModelSpecField.reasoningDialect],
        SpecSource.vendor,
      );
      expect(responses.spec.reasoning.levels, [
        ReasoningLevel.low,
        ReasoningLevel.medium,
        ReasoningLevel.high,
      ]);
      expect(responses.spec.reasoning.canDisable, isTrue);
      expect(responses.spec.reasoning.defaultLevel, ReasoningLevel.auto);
    });

    test('known gpt-5-pro keeps guesser canDisable false', () {
      final resolved = resolver.resolve(_openai(), 'gpt-5-pro');
      expect(resolved.spec.abilities, contains(ModelAbility.reasoning));
      expect(resolved.spec.reasoning.canDisable, isFalse);
      expect(
        resolved.sources[ModelSpecField.reasoningCanDisable],
        SpecSource.guess,
      );
      expect(
        resolved.spec.reasoning.dialect,
        ReasoningDialect.openaiReasoningEffort,
      );
      expect(
        resolved.sources[ModelSpecField.reasoningDialect],
        SpecSource.guess,
      );
    });

    test(
      'ability-only override keeps the provider-default dialect and levels',
      () {
        const id = 'stealth/ox-alpha';
        final ov = <String, dynamic>{
          id: <String, dynamic>{
            'abilities': <String>['reasoning'],
          },
        };
        final resolved = resolver.resolve(_openai(overrides: ov), id);

        expect(resolved.spec.abilities, contains(ModelAbility.reasoning));
        expect(resolved.sources[ModelSpecField.abilities], SpecSource.override);
        expect(
          resolved.spec.reasoning.dialect,
          ReasoningDialect.openaiReasoningEffort,
        );
        expect(
          resolved.sources[ModelSpecField.reasoningDialect],
          SpecSource.vendor,
        );
        expect(resolved.spec.reasoning.levels, [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
        ]);
        expect(
          resolved.sources[ModelSpecField.reasoningLevels],
          SpecSource.fallback,
        );
        expect(resolved.spec.reasoning.canDisable, isTrue);
        expect(
          resolved.sources[ModelSpecField.reasoningCanDisable],
          SpecSource.fallback,
        );
        expect(resolved.spec.reasoning.defaultLevel, ReasoningLevel.auto);
        expect(
          resolved.base.reasoning.dialect,
          resolved.spec.reasoning.dialect,
        );
        expect(resolved.base.reasoning.levels, resolved.spec.reasoning.levels);
      },
    );

    test('auto request does not emit reasoning fields without the ability', () {
      final resolved = resolver.resolve(_google(), 'stealth/ox-alpha');
      expect(resolved.spec.supportsReasoning, isFalse);
      expect(
        resolved.spec.reasoning.dialect,
        ReasoningDialect.geminiThinkingBudget,
      );
      expect(
        applyReasoning(
          <String, dynamic>{},
          resolved.spec,
          const ReasoningRequest(ReasoningLevel.auto),
          transport: ReasoningTransport.geminiGenerateContent,
        ),
        isEmpty,
      );
    });
  });
}

ProviderConfig _cfg({
  required String id,
  required ProviderKind kind,
  String baseUrl = '',
  Map<String, dynamic> overrides = const {},
}) {
  return ProviderConfig(
    id: id,
    enabled: true,
    name: id,
    apiKey: '',
    baseUrl: baseUrl,
    providerType: kind,
    modelOverrides: overrides,
  );
}

ProviderConfig _openai({Map<String, dynamic> overrides = const {}}) {
  return _cfg(
    id: 'openai',
    kind: ProviderKind.openai,
    baseUrl: 'https://api.openai.com/v1',
    overrides: overrides,
  );
}

ProviderConfig _anthropic({Map<String, dynamic> overrides = const {}}) {
  return _cfg(
    id: 'anthropic',
    kind: ProviderKind.claude,
    baseUrl: 'https://api.anthropic.com',
    overrides: overrides,
  );
}

ProviderConfig _google() {
  return _cfg(
    id: 'google',
    kind: ProviderKind.google,
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
  );
}

ProviderConfig _deepseek() {
  return _cfg(
    id: 'deepseek',
    kind: ProviderKind.openai,
    baseUrl: 'https://api.deepseek.com/v1',
  );
}

CatalogModel _model(
  String id, {
  List<String> input = const [],
  List<String> output = const [],
  bool tool = false,
  bool reasoning = false,
  bool structured = false,
  bool temperature = true,
  List<CatalogReasoningOption> reasoningOptions = const [],
  bool interleaved = false,
  String? interleavedField,
  int? contextLimit,
  int? outputLimit,
  double? costInput,
  double? costOutput,
  double? costCacheRead,
  double? costCacheWrite,
}) {
  return CatalogModel(
    id: id,
    name: id,
    toolCall: tool,
    reasoning: reasoning,
    structuredOutput: structured,
    temperature: temperature,
    reasoningOptions: reasoningOptions,
    interleaved: interleaved,
    interleavedField: interleavedField,
    inputModalities: input,
    outputModalities: output,
    contextLimit: contextLimit,
    outputLimit: outputLimit,
    costInput: costInput,
    costOutput: costOutput,
    costCacheRead: costCacheRead,
    costCacheWrite: costCacheWrite,
  );
}

CatalogProvider _provider(
  String id, {
  String? api,
  required List<CatalogModel> models,
}) {
  return CatalogProvider(
    id: id,
    name: id,
    api: api,
    models: <String, CatalogModel>{for (final model in models) model.id: model},
  );
}

ModelCatalogData _catalogData() {
  return ModelCatalogData(
    schemaVersion: 1,
    generatedAt: DateTime.utc(2026, 9, 15),
    providers: <String, CatalogProvider>{
      'openai': _provider(
        'openai',
        models: [
          _model(
            'gpt-5.1',
            tool: true,
            reasoning: true,
            temperature: true,
            reasoningOptions: const [
              CatalogReasoningOption(
                type: 'effort',
                values: ['none', 'low', 'medium', 'high'],
              ),
            ],
            contextLimit: 400000,
            outputLimit: 128000,
            costInput: 1.25,
            costOutput: 10,
          ),
          _model('gpt-image-1', output: const ['image']),
          _model(
            'o3',
            reasoning: true,
            reasoningOptions: const [
              CatalogReasoningOption(
                type: 'effort',
                values: ['low', 'medium', 'high'],
              ),
            ],
          ),
        ],
      ),
      'anthropic': _provider(
        'anthropic',
        models: [
          _model(
            'claude-sonnet-4.6',
            tool: true,
            reasoning: true,
            interleaved: true,
            interleavedField: 'reasoning_content',
            input: const ['text', 'image', 'pdf'],
            reasoningOptions: const [
              CatalogReasoningOption(
                type: 'effort',
                values: ['low', 'medium', 'high', 'max'],
              ),
              CatalogReasoningOption(type: 'budget_tokens', min: 1024),
              CatalogReasoningOption(type: 'toggle'),
            ],
            costInput: 3,
            costOutput: 15,
            costCacheWrite: 3.75,
          ),
        ],
      ),
      'google': _provider(
        'google',
        models: [
          _model(
            'gemini-2.5-pro',
            reasoning: true,
            temperature: true,
            reasoningOptions: const [
              CatalogReasoningOption(
                type: 'budget_tokens',
                min: 128,
                max: 32768,
              ),
            ],
          ),
          _model(
            'gemini-3-pro-preview',
            reasoning: true,
            reasoningOptions: const [],
          ),
        ],
      ),
      'deepseek': _provider(
        'deepseek',
        api: 'https://api.deepseek.com/v1',
        models: [
          _model(
            'deepseek-v4-pro',
            tool: true,
            reasoning: true,
            temperature: false,
            interleaved: true,
            interleavedField: 'reasoning_content',
            reasoningOptions: const [
              CatalogReasoningOption(type: 'toggle'),
              CatalogReasoningOption(
                type: 'effort',
                values: ['low', 'high', 'max'],
              ),
            ],
          ),
        ],
      ),
    },
  );
}
