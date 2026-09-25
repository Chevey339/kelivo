import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/model_spec.dart';

void main() {
  group('ModelSpec normalization', () {
    test('dedupes, sorts, and fills empty modalities', () {
      final spec = ModelSpec(
        id: 'm',
        displayName: 'M',
        input: const [
          Modality.image,
          Modality.text,
          Modality.image,
          Modality.pdf,
        ],
        output: const [Modality.audio, Modality.text, Modality.audio],
        abilities: const [
          ModelAbility.reasoning,
          ModelAbility.tool,
          ModelAbility.reasoning,
        ],
      );

      expect(spec.input, [Modality.text, Modality.image, Modality.pdf]);
      expect(spec.output, [Modality.text, Modality.audio]);
      expect(spec.abilities, [ModelAbility.tool, ModelAbility.reasoning]);
    });

    test('empty input and output fall back to text', () {
      final spec = ModelSpec(
        id: 'm',
        displayName: 'M',
        input: const [],
        output: const [],
      );

      expect(spec.input, const [Modality.text]);
      expect(spec.output, const [Modality.text]);
    });

    test('output drops video and pdf', () {
      final spec = ModelSpec(
        id: 'm',
        displayName: 'M',
        output: const [Modality.video, Modality.pdf, Modality.image],
      );

      expect(spec.output, const [Modality.image]);
    });

    test('embedding forces text output and empty abilities', () {
      final spec = ModelSpec(
        id: 'embed',
        displayName: 'Embed',
        type: ModelType.embedding,
        input: const [Modality.image],
        output: const [Modality.image, Modality.audio],
        abilities: const [ModelAbility.tool, ModelAbility.reasoning],
      );

      expect(spec.input, const [Modality.image]);
      expect(spec.output, const [Modality.text]);
      expect(spec.abilities, isEmpty);
      expect(spec.isEmbedding, isTrue);
      expect(spec.supportsTool, isFalse);
      expect(spec.supportsReasoning, isFalse);
    });

    test('convenience getters and upstreamId', () {
      final spec = ModelSpec(
        id: 'logical',
        apiModelId: 'upstream',
        displayName: 'Name',
        input: const [Modality.text, Modality.image],
        abilities: const [ModelAbility.tool, ModelAbility.reasoning],
      );

      expect(spec.upstreamId, 'upstream');
      expect(spec.supportsImageInput, isTrue);
      expect(spec.supportsAudioInput, isFalse);
      expect(spec.supportsVideoInput, isFalse);
      expect(spec.supportsTool, isTrue);
      expect(spec.supportsReasoning, isTrue);

      final raw = ModelSpec(id: 'logical', displayName: 'Name');
      expect(raw.upstreamId, 'logical');
    });
  });

  group('ModelSpec equality', () {
    test('value equality and hashCode cover all fields', () {
      final a = ModelSpec(
        id: 'm',
        apiModelId: 'api',
        displayName: 'Name',
        type: ModelType.image,
        input: const [Modality.text, Modality.audio],
        output: const [Modality.image],
        abilities: const [ModelAbility.structuredOutput],
        reasoning: const ReasoningSpec(canDisable: true),
        sampling: SamplingPolicy.never,
        contextWindow: 128000,
        maxOutput: 4096,
        pricing: const ModelPricing(input: 1, output: 2),
        headers: const [
          {'name': 'X', 'value': '1'},
        ],
        body: const [
          {'key': 'k', 'value': 'v'},
        ],
        builtInTools: const ['search'],
      );
      final b = ModelSpec(
        id: 'm',
        apiModelId: 'api',
        displayName: 'Name',
        type: ModelType.image,
        input: const [Modality.audio, Modality.text],
        output: const [Modality.image],
        abilities: const [ModelAbility.structuredOutput],
        reasoning: const ReasoningSpec(canDisable: true),
        sampling: SamplingPolicy.never,
        contextWindow: 128000,
        maxOutput: 4096,
        pricing: const ModelPricing(input: 1, output: 2),
        headers: const [
          {'name': 'X', 'value': '1'},
        ],
        body: const [
          {'key': 'k', 'value': 'v'},
        ],
        builtInTools: const ['search'],
      );
      final c = a.copyWith(displayName: 'Other');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('copyWith replaces every field', () {
      final next = ModelSpec(id: 'a', displayName: 'A').copyWith(
        id: 'b',
        apiModelId: 'api',
        displayName: 'B',
        type: ModelType.image,
        input: const [Modality.image],
        output: const [Modality.audio],
        abilities: const [ModelAbility.tool],
        reasoning: const ReasoningSpec(canDisable: true),
        sampling: SamplingPolicy.onlyWhenReasoningOff,
        contextWindow: 8,
        maxOutput: 2,
        pricing: const ModelPricing(input: 3),
        headers: const [
          {'name': 'H', 'value': 'v'},
        ],
        body: const [
          {'key': 'k', 'value': '1'},
        ],
        builtInTools: const ['code'],
      );

      expect(next.id, 'b');
      expect(next.apiModelId, 'api');
      expect(next.displayName, 'B');
      expect(next.type, ModelType.image);
      expect(next.input, const [Modality.image]);
      expect(next.output, const [Modality.audio]);
      expect(next.abilities, const [ModelAbility.tool]);
      expect(next.reasoning.canDisable, isTrue);
      expect(next.sampling, SamplingPolicy.onlyWhenReasoningOff);
      expect(next.contextWindow, 8);
      expect(next.maxOutput, 2);
      expect(next.pricing, const ModelPricing(input: 3));
      expect(next.headers, [
        {'name': 'H', 'value': 'v'},
      ]);
      expect(next.body, [
        {'key': 'k', 'value': '1'},
      ]);
      expect(next.builtInTools, const ['code']);
    });
  });

  group('ModelSpecOverride.fromJson', () {
    test('reads legacy aliases and ignores unknown values', () {
      final ov = ModelSpecOverride.fromJson({
        'api_model_id': 'gpt-4',
        'name': 'GPT',
        't': 'embeddings',
        'input': ['text', 'smell', 'image'],
        'output': ['unknown'],
        'abilities': ['tool', 'magic', 'reasoning'],
        'built_in_tools': ['search'],
        'sampling': 'not-a-policy',
      });

      expect(ov.apiModelId, 'gpt-4');
      expect(ov.displayName, 'GPT');
      expect(ov.type, ModelType.embedding);
      expect(ov.input, [Modality.text, Modality.image]);
      expect(ov.output, isNull);
      expect(ov.abilities, [ModelAbility.tool, ModelAbility.reasoning]);
      expect(ov.builtInTools, ['search']);
      expect(ov.sampling, isNull);
    });

    test('prefers canonical keys and maps image / embeddings types', () {
      expect(
        ModelSpecOverride.fromJson({
          'apiModelId': 'canonical',
          'api_model_id': 'legacy',
          'type': 'image',
          't': 'chat',
          'builtInTools': ['a'],
          'built_in_tools': ['b'],
        }).apiModelId,
        'canonical',
      );
      expect(
        ModelSpecOverride.fromJson({'type': 'image'}).type,
        ModelType.image,
      );
      expect(
        ModelSpecOverride.fromJson({'t': 'embeddings'}).type,
        ModelType.embedding,
      );
      expect(
        ModelSpecOverride.fromJson({
          'builtInTools': ['a'],
          'built_in_tools': ['b'],
        }).builtInTools,
        ['a'],
      );
    });

    test('empty lists mean unset modalities and explicit empty abilities', () {
      final ov = ModelSpecOverride.fromJson({
        'input': <String>[],
        'output': <String>[],
        'abilities': <String>[],
      });

      expect(ov.input, isEmpty);
      expect(ov.output, isEmpty);
      expect(ov.abilities, isEmpty);
    });

    test(
      'round-trips extra keys including webSearch and oauthThinkingMode',
      () {
        final original = ModelSpecOverride.fromJson({
          'name': 'Claude',
          'type': 'chat',
          'input': ['text'],
          'webSearch': {'enabled': true, 'max': 3},
          'oauthThinkingMode': 'adaptive',
          'oauthThinkingRequired': true,
        });
        final encoded = original.toJson();
        final restored = ModelSpecOverride.fromJson(encoded);

        expect(restored, original);
        expect(encoded.containsKey('api_model_id'), isFalse);
        expect(encoded.containsKey('t'), isFalse);
        expect(encoded.containsKey('built_in_tools'), isFalse);
        expect(encoded['name'], 'Claude');
        expect(encoded['webSearch'], {'enabled': true, 'max': 3});
        expect(encoded['oauthThinkingMode'], 'adaptive');
        expect(encoded['oauthThinkingRequired'], isTrue);
      },
    );

    test('round-trips new keys and header/body rows', () {
      final original = ModelSpecOverride.fromJson({
        'apiModelId': 'x',
        'reasoning': {
          'levels': ['low', 'high', 'auto', 'off', 'nope'],
          'canDisable': true,
          'defaultLevel': 'low',
          'dialect': 'openaiReasoningEffort',
          'budgets': {'low': 128, 'mystery': 1},
          'customPatches': {
            'low': {
              r'$remove': ['temperature'],
            },
          },
          'replay': 'toolTurns',
          'replayField': 'reasoningDetails',
        },
        'sampling': 'onlyWhenReasoningOff',
        'contextWindow': 200000,
        'maxOutput': 8192,
        'pricing': {
          'input': 1.5,
          'output': 6,
          'cacheRead': 0.1,
          'cacheWrite': 0.2,
          'currency': 'USD',
        },
        'headers': [
          {'name': 'Authorization', 'value': 'Bearer x'},
        ],
        'body': [
          {'key': 'foo', 'value': '1'},
        ],
      });

      expect(original.reasoning!.levels, [
        ReasoningLevel.low,
        ReasoningLevel.high,
      ]);
      expect(original.reasoning!.budgets, {ReasoningLevel.low: 128});
      expect(ModelSpecOverride.fromJson(original.toJson()), original);
    });

    test('sparse reasoning override keeps only present fields', () {
      final ov = ModelSpecOverride.fromJson({
        'reasoning': {'replay': 'all'},
      });

      expect(ov.reasoning, isNotNull);
      expect(ov.reasoning!.replay, ReasoningReplayPolicy.all);
      expect(ov.reasoning!.levels, isNull);
      expect(ov.reasoning!.canDisable, isNull);
      expect(ov.reasoning!.defaultLevel, isNull);
      expect(ov.reasoning!.dialect, isNull);
      expect(ov.reasoning!.budgets, isNull);
      expect(ov.reasoning!.customPatches, isNull);
      expect(ov.reasoning!.replayField, isNull);
      expect(ov.toJson(), {
        'reasoning': {'replay': 'all'},
      });
      expect(ModelSpecOverride.fromJson(ov.toJson()), ov);

      const catalog = ReasoningSpec(
        levels: [ReasoningLevel.low, ReasoningLevel.high],
        dialect: ReasoningDialect.openaiReasoningEffort,
        replay: ReasoningReplayPolicy.none,
      );
      final applied = ov.reasoning!.applyTo(catalog);
      expect(applied.replay, ReasoningReplayPolicy.all);
      expect(applied.levels, [ReasoningLevel.low, ReasoningLevel.high]);
      expect(applied.dialect, ReasoningDialect.openaiReasoningEffort);
    });

    test('empty reasoning map is treated as unset', () {
      expect(ModelSpecOverride.fromJson({'reasoning': {}}).reasoning, isNull);
      expect(ModelSpecOverride.fromJson({'reasoning': {}}).toJson(), isEmpty);
    });

    test('copyWith can clear fields back to null', () {
      const ov = ModelSpecOverride(
        displayName: 'X',
        type: ModelType.chat,
        contextWindow: 1000,
        sampling: SamplingPolicy.never,
      );
      final cleared = ov.copyWith(
        clearDisplayName: true,
        clearType: true,
        clearContextWindow: true,
        clearSampling: true,
      );
      expect(cleared.displayName, isNull);
      expect(cleared.type, isNull);
      expect(cleared.contextWindow, isNull);
      expect(cleared.sampling, isNull);
      expect(ov.copyWith().type, ModelType.chat);
    });

    test('isEmpty is true only when nothing is set', () {
      expect(const ModelSpecOverride().isEmpty, isTrue);
      expect(const ModelSpecOverride(displayName: 'x').isEmpty, isFalse);
      expect(
        const ModelSpecOverride(extra: {'webSearch': true}).isEmpty,
        isFalse,
      );
    });
  });

  group('ModelSpecOverride.applyTo', () {
    final base = ModelSpec(
      id: 'logical',
      displayName: 'Base',
      input: const [Modality.text, Modality.image],
      output: const [Modality.text],
      abilities: const [ModelAbility.tool],
    );

    test('does not apply displayName unless requested', () {
      final ov = ModelSpecOverride.fromJson({'name': 'Override'});
      expect(ov.applyTo(base).displayName, 'Base');
      expect(ov.applyTo(base, applyDisplayName: true).displayName, 'Override');
    });

    test('empty modality lists fall back to text; empty abilities clear', () {
      final ov = ModelSpecOverride.fromJson({
        'input': <String>[],
        'output': <String>[],
        'abilities': <String>[],
      });
      final next = ov.applyTo(base);
      expect(next.input, const [Modality.text]);
      expect(next.output, const [Modality.text]);
      expect(next.abilities, isEmpty);
    });

    test('embedding override forces output and abilities', () {
      final ov = ModelSpecOverride.fromJson({
        'type': 'embedding',
        'output': ['image'],
        'abilities': ['tool', 'reasoning'],
        'input': ['image'],
      });
      final next = ov.applyTo(base);
      expect(next.type, ModelType.embedding);
      expect(next.input, const [Modality.image]);
      expect(next.output, const [Modality.text]);
      expect(next.abilities, isEmpty);
    });

    test('sparse reasoning applyTo preserves catalog levels and dialect', () {
      final catalogued = ModelSpec(
        id: 'logical',
        displayName: 'Base',
        reasoning: const ReasoningSpec(
          levels: [ReasoningLevel.medium],
          dialect: ReasoningDialect.anthropicBudget,
        ),
      );
      final next = ModelSpecOverride.fromJson({
        'reasoning': {'replay': 'all'},
      }).applyTo(catalogued);

      expect(next.reasoning.replay, ReasoningReplayPolicy.all);
      expect(next.reasoning.levels, const [ReasoningLevel.medium]);
      expect(next.reasoning.dialect, ReasoningDialect.anthropicBudget);
    });

    test('keeps id and applies sparse fields', () {
      final ov = ModelSpecOverride.fromJson({
        'apiModelId': 'upstream',
        'type': 'image',
        'sampling': 'never',
        'contextWindow': 1000,
        'maxOutput': 20,
        'headers': [
          {'name': 'X', 'value': '1'},
        ],
      });
      final next = ov.applyTo(base);
      expect(next.id, 'logical');
      expect(next.apiModelId, 'upstream');
      expect(next.type, ModelType.image);
      expect(next.sampling, SamplingPolicy.never);
      expect(next.contextWindow, 1000);
      expect(next.maxOutput, 20);
      expect(next.headers, [
        {'name': 'X', 'value': '1'},
      ]);
      expect(next.abilities, base.abilities);
    });
  });

  group('ReasoningSpec and ModelPricing JSON', () {
    test('ReasoningSpec round-trips and skips unknown values', () {
      const spec = ReasoningSpec(
        levels: [ReasoningLevel.minimal, ReasoningLevel.max],
        canDisable: true,
        defaultLevel: ReasoningLevel.medium,
        dialect: ReasoningDialect.custom,
        budgets: {ReasoningLevel.minimal: 16},
        customPatches: {
          ReasoningLevel.max: {
            r'$remove': ['top_p'],
          },
        },
        replay: ReasoningReplayPolicy.all,
        replayField: ReasoningReplayField.reasoning,
      );
      final restored = ReasoningSpec.fromJson(spec.toJson());
      expect(restored, spec);
      expect(restored.hashCode, spec.hashCode);

      final messy = ReasoningSpec.fromJson({
        'levels': ['auto', 'off', 'low', 'low', 'zzz'],
        'defaultLevel': 'nope',
        'dialect': 'mystery',
        'replay': '???',
        'replayField': 'nope',
      });
      expect(messy.levels, [ReasoningLevel.low]);
      expect(messy.defaultLevel, ReasoningLevel.auto);
      expect(messy.dialect, ReasoningDialect.none);
      expect(messy.replay, ReasoningReplayPolicy.none);
      expect(messy.replayField, ReasoningReplayField.reasoningContent);
    });

    test('copyWith can clear nullable fields', () {
      const ov = ReasoningSpecOverride(
        levels: [ReasoningLevel.low],
        canDisable: true,
        dialect: ReasoningDialect.openaiReasoningEffort,
        replay: ReasoningReplayPolicy.all,
      );
      final cleared = ov.copyWith(
        clearLevels: true,
        clearCanDisable: true,
        clearDialect: true,
        clearReplay: true,
      );
      expect(cleared.levels, isNull);
      expect(cleared.canDisable, isNull);
      expect(cleared.dialect, isNull);
      expect(cleared.replay, isNull);
      expect(ov.copyWith().dialect, ReasoningDialect.openaiReasoningEffort);
    });

    test('copyWith strips auto/off from levels', () {
      final spec = const ReasoningSpec().copyWith(
        levels: const [
          ReasoningLevel.auto,
          ReasoningLevel.off,
          ReasoningLevel.high,
          ReasoningLevel.high,
        ],
      );
      expect(spec.levels, [ReasoningLevel.high]);
    });

    test('replay field wire names', () {
      expect(
        ReasoningReplayField.reasoningContent.wireName,
        'reasoning_content',
      );
      expect(ReasoningReplayField.reasoning.wireName, 'reasoning');
      expect(
        ReasoningReplayField.reasoningDetails.wireName,
        'reasoning_details',
      );
    });

    test('ModelPricing round-trips', () {
      const pricing = ModelPricing(
        input: 0.5,
        output: 1.5,
        cacheRead: 0.05,
        cacheWrite: 0.2,
        currency: 'EUR',
      );
      expect(ModelPricing.fromJson(pricing.toJson()), pricing);
      expect(ModelPricing.fromJson(const {}).currency, 'USD');
    });
  });
}
