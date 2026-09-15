import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/services/model_spec/model_defaults_guesser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'model_spec_corpus.dart';

bool _isImagesApiId(String id) {
  final normalized = id.toLowerCase();
  return normalized.startsWith('gpt-image-') ||
      normalized.startsWith('chatgpt-image-') ||
      normalized.startsWith('agnes-image-') ||
      normalized == 'sensenova-u1-fast' ||
      normalized == 'dall-e-2' ||
      normalized == 'dall-e-3';
}

T _byName<T extends Enum>(Iterable<T> values, String name) {
  return values.firstWhere((value) => value.name == name);
}

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/core/services/model_spec/fixtures/model_registry_infer_golden.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  group('golden capabilities', () {
    test('corpus has at least 200 ids and matches the fixture', () {
      final ids = modelSpecCorpusIds();
      expect(ids.length, greaterThanOrEqualTo(200));
      expect(ids.length, fixture.length);
    });

    test('guesser reproduces the old ModelRegistry.infer fixture', () {
      final ids = modelSpecCorpusIds();
      for (final id in ids) {
        final raw = fixture[id];
        expect(raw, isA<Map>(), reason: 'missing fixture for $id');
        final expected = Map<String, dynamic>.from(raw as Map);
        final guess = ModelDefaultsGuesser.guess(id);
        final expectedType = _isImagesApiId(id)
            ? ModelType.image
            : _byName(ModelType.values, expected['type'] as String);
        expect(guess.type, expectedType, reason: id);
        expect(
          [for (final m in guess.input) m.name],
          expected['input'],
          reason: id,
        );
        expect(
          [for (final m in guess.output) m.name],
          expected['output'],
          reason: id,
        );
        expect(
          [for (final a in guess.abilities) a.name],
          expected['abilities'],
          reason: id,
        );
      }
    });
  });

  group('Images API type', () {
    test('routes documented Images API ids as ModelType.image', () {
      for (final id in const [
        'gpt-image-1',
        'gpt-image-2',
        'chatgpt-image-latest',
        'agnes-image-1',
        'sensenova-u1-fast',
        'dall-e-2',
        'dall-e-3',
      ]) {
        final guess = ModelDefaultsGuesser.guess(id);
        expect(guess.type, ModelType.image, reason: id);
      }
    });
  });

  group('embedding', () {
    test('isLikelyEmbeddingId matches historical heuristics', () {
      expect(
        ModelDefaultsGuesser.isLikelyEmbeddingId('text-embedding-3-large'),
        isTrue,
      );
      expect(
        ModelDefaultsGuesser.isLikelyEmbeddingId('qwen3-embedding-8b'),
        isTrue,
      );
      expect(ModelDefaultsGuesser.isLikelyEmbeddingId('mistral-embed'), isTrue);
      expect(
        ModelDefaultsGuesser.isLikelyEmbeddingId('jina-embeddings-v3'),
        isTrue,
      );
      expect(ModelDefaultsGuesser.isLikelyEmbeddingId('gpt-4o'), isFalse);
      expect(
        ModelDefaultsGuesser.isLikelyEmbeddingId('text-embedding-3-small'),
        isTrue,
      );
    });

    test('base.type embedding is terminal even when the id is not', () {
      final guess = ModelDefaultsGuesser.guess(
        'gpt-4o',
        base: ModelSpec(
          id: 'gpt-4o',
          displayName: 'gpt-4o',
          type: ModelType.embedding,
          abilities: const [ModelAbility.tool],
        ),
      );
      expect(guess.type, ModelType.embedding);
      expect(guess.abilities, isEmpty);
      expect(guess.output, const [Modality.text]);
      expect(guess.reasoning, isNull);
    });
  });

  group('reasoning defaults', () {
    void expectHit(
      String id, {
      required ReasoningDialect dialect,
      required List<ReasoningLevel> levels,
      required bool canDisable,
      SamplingPolicy? sampling,
      int? maxOutput,
      ReasoningReplayPolicy? replay,
      ReasoningReplayField? replayField,
    }) {
      final guess = ModelDefaultsGuesser.guess(id);
      expect(guess.reasoning, isNotNull, reason: id);
      expect(guess.reasoning!.dialect, dialect, reason: id);
      expect(guess.reasoning!.levels, levels, reason: id);
      expect(guess.reasoning!.canDisable, canDisable, reason: id);
      expect(guess.sampling, sampling, reason: id);
      expect(guess.maxOutput, maxOutput, reason: id);
      expect(guess.replay, replay, reason: id);
      expect(guess.replayField, replayField, reason: id);
    }

    test('OpenAI effort ladders', () {
      expectHit(
        'gpt-5',
        dialect: ReasoningDialect.openaiReasoningEffort,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
        ],
        canDisable: true,
      );
      expectHit(
        'gpt-5.2',
        dialect: ReasoningDialect.openaiReasoningEffort,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
          ReasoningLevel.xhigh,
        ],
        canDisable: true,
        sampling: SamplingPolicy.onlyWhenReasoningOff,
      );
      expectHit(
        'gpt-5-pro',
        dialect: ReasoningDialect.openaiReasoningEffort,
        levels: const [ReasoningLevel.high],
        canDisable: false,
      );
      expectHit(
        'gpt-5.6-sol',
        dialect: ReasoningDialect.openaiReasoningEffort,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
          ReasoningLevel.xhigh,
          ReasoningLevel.max,
        ],
        canDisable: true,
        sampling: SamplingPolicy.onlyWhenReasoningOff,
      );
      expectHit(
        'gpt-6-astra',
        dialect: ReasoningDialect.openaiReasoningEffort,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
          ReasoningLevel.xhigh,
          ReasoningLevel.max,
        ],
        canDisable: false,
        sampling: SamplingPolicy.onlyWhenReasoningOff,
      );
      expectHit(
        'o3-mini',
        dialect: ReasoningDialect.openaiReasoningEffort,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
        ],
        canDisable: false,
      );
      expect(ModelDefaultsGuesser.guess('gpt-5.3-pro').reasoning, isNull);
      expect(ModelDefaultsGuesser.guess('gpt-5-chat-latest').reasoning, isNull);
    });

    test('Claude families', () {
      expectHit(
        'claude-fable-5',
        dialect: ReasoningDialect.anthropicAdaptiveEffort,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
          ReasoningLevel.xhigh,
          ReasoningLevel.max,
        ],
        canDisable: false,
        sampling: SamplingPolicy.never,
        maxOutput: 128000,
      );
      expectHit(
        'claude-sonnet-5',
        dialect: ReasoningDialect.anthropicAdaptiveEffort,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
          ReasoningLevel.xhigh,
          ReasoningLevel.max,
        ],
        canDisable: true,
        sampling: SamplingPolicy.never,
        maxOutput: 128000,
      );
      expectHit(
        'claude-sonnet-4-6',
        dialect: ReasoningDialect.anthropicAdaptiveEffort,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
          ReasoningLevel.max,
        ],
        canDisable: true,
        maxOutput: 128000,
      );
      expectHit(
        'claude-3-5-sonnet',
        dialect: ReasoningDialect.anthropicBudget,
        levels: const [],
        canDisable: true,
        maxOutput: 64000,
      );
      expectHit(
        'claude-3-haiku@20240307',
        dialect: ReasoningDialect.anthropicBudget,
        levels: const [],
        canDisable: true,
        maxOutput: 8000,
      );
      expectHit(
        'claude-opus-4-8',
        dialect: ReasoningDialect.anthropicAdaptiveEffort,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
          ReasoningLevel.xhigh,
          ReasoningLevel.max,
        ],
        canDisable: true,
        sampling: SamplingPolicy.never,
        maxOutput: 128000,
      );
    });

    test('Gemini families', () {
      expectHit(
        'gemma-4',
        dialect: ReasoningDialect.geminiThinkingLevel,
        levels: const [ReasoningLevel.minimal, ReasoningLevel.high],
        canDisable: false,
      );
      expectHit(
        'gemini-3-pro',
        dialect: ReasoningDialect.geminiThinkingLevel,
        levels: const [ReasoningLevel.low, ReasoningLevel.high],
        canDisable: false,
        sampling: SamplingPolicy.never,
      );
      expectHit(
        'gemini-3.1-pro-preview',
        dialect: ReasoningDialect.geminiThinkingLevel,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
        ],
        canDisable: false,
        sampling: SamplingPolicy.never,
      );
      expectHit(
        'gemini-3.6-flash',
        dialect: ReasoningDialect.geminiThinkingLevel,
        levels: const [
          ReasoningLevel.minimal,
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
        ],
        canDisable: false,
        sampling: SamplingPolicy.never,
        maxOutput: 65536,
      );
      expectHit(
        'gemini-3.7-flash',
        dialect: ReasoningDialect.geminiThinkingLevel,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
        ],
        canDisable: false,
        sampling: SamplingPolicy.never,
        maxOutput: 65536,
      );
      expectHit(
        'gemini-3.1-flash-image',
        dialect: ReasoningDialect.geminiThinkingLevel,
        levels: const [ReasoningLevel.minimal, ReasoningLevel.high],
        canDisable: false,
        sampling: SamplingPolicy.never,
      );
      expectHit(
        'gemini-2.5-flash',
        dialect: ReasoningDialect.geminiThinkingBudget,
        levels: const [],
        canDisable: true,
      );
      expectHit(
        'gemini-2.5-pro',
        dialect: ReasoningDialect.geminiThinkingBudget,
        levels: const [],
        canDisable: false,
      );
    });

    test('Kimi families', () {
      expectHit(
        'kimi-k2.5',
        dialect: ReasoningDialect.kimiThinking,
        levels: const [],
        canDisable: true,
        sampling: SamplingPolicy.never,
        replay: ReasoningReplayPolicy.toolTurns,
        replayField: ReasoningReplayField.reasoningContent,
      );
      expectHit(
        'kimi-k2.6',
        dialect: ReasoningDialect.kimiThinking,
        levels: const [],
        canDisable: true,
        replay: ReasoningReplayPolicy.toolTurns,
        replayField: ReasoningReplayField.reasoningContent,
      );
      expectHit(
        'kimi-k2.7',
        dialect: ReasoningDialect.kimiThinking,
        levels: const [],
        canDisable: false,
        sampling: SamplingPolicy.never,
        replay: ReasoningReplayPolicy.toolTurns,
        replayField: ReasoningReplayField.reasoningContent,
      );
      expectHit(
        'kimi-k2.7-code',
        dialect: ReasoningDialect.kimiThinking,
        levels: const [],
        canDisable: false,
        sampling: SamplingPolicy.never,
        replay: ReasoningReplayPolicy.all,
        replayField: ReasoningReplayField.reasoningContent,
      );
      expectHit(
        'kimi-k3',
        dialect: ReasoningDialect.openaiReasoningEffort,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.high,
          ReasoningLevel.max,
        ],
        canDisable: false,
        sampling: SamplingPolicy.never,
        replay: ReasoningReplayPolicy.all,
        replayField: ReasoningReplayField.reasoningContent,
      );
      expectHit(
        'kimi-for-coding',
        dialect: ReasoningDialect.kimiThinking,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.high,
          ReasoningLevel.max,
        ],
        canDisable: true,
        replay: ReasoningReplayPolicy.all,
        replayField: ReasoningReplayField.reasoningContent,
      );
      expectHit(
        'kimi-k2.8',
        dialect: ReasoningDialect.kimiThinking,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.high,
          ReasoningLevel.max,
        ],
        canDisable: true,
        replay: ReasoningReplayPolicy.all,
        replayField: ReasoningReplayField.reasoningContent,
      );
      expectHit(
        'kimi-for-coding-highspeed',
        dialect: ReasoningDialect.kimiThinking,
        levels: const [],
        canDisable: true,
        replay: ReasoningReplayPolicy.all,
        replayField: ReasoningReplayField.reasoningContent,
      );
    });

    test('GLM, DeepSeek, MiMo, Qwen, Grok, Muse, Laguna, Doubao', () {
      expectHit(
        'glm-5.3',
        dialect: ReasoningDialect.thinkingType,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.high,
          ReasoningLevel.max,
        ],
        canDisable: false,
        replay: ReasoningReplayPolicy.toolTurns,
        replayField: ReasoningReplayField.reasoningContent,
      );
      expectHit(
        'glm-5.2',
        dialect: ReasoningDialect.thinkingType,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
          ReasoningLevel.xhigh,
          ReasoningLevel.max,
        ],
        canDisable: true,
        replay: ReasoningReplayPolicy.toolTurns,
        replayField: ReasoningReplayField.reasoningContent,
      );
      expectHit(
        'glm-4.5',
        dialect: ReasoningDialect.thinkingType,
        levels: const [],
        canDisable: true,
        replay: ReasoningReplayPolicy.toolTurns,
        replayField: ReasoningReplayField.reasoningContent,
      );
      expectHit(
        'deepseek-v4-pro',
        dialect: ReasoningDialect.thinkingType,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.high,
          ReasoningLevel.max,
        ],
        canDisable: true,
        replay: ReasoningReplayPolicy.toolTurns,
        replayField: ReasoningReplayField.reasoningContent,
      );
      expectHit(
        'mimo-v2',
        dialect: ReasoningDialect.thinkingType,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
        ],
        canDisable: true,
        replay: ReasoningReplayPolicy.toolTurns,
        replayField: ReasoningReplayField.reasoningContent,
      );
      expectHit(
        'qwen3-max',
        dialect: ReasoningDialect.qwenEnableThinking,
        levels: const [],
        canDisable: true,
      );
      expectHit(
        'qwen3-thinking',
        dialect: ReasoningDialect.qwenEnableThinking,
        levels: const [],
        canDisable: false,
      );
      expectHit(
        'qwq-32b',
        dialect: ReasoningDialect.qwenEnableThinking,
        levels: const [],
        canDisable: false,
      );
      expectHit(
        'grok-4.6',
        dialect: ReasoningDialect.openaiReasoningEffort,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
          ReasoningLevel.xhigh,
        ],
        canDisable: false,
      );
      expectHit(
        'grok-4.5',
        dialect: ReasoningDialect.openaiReasoningEffort,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
        ],
        canDisable: false,
      );
      expectHit(
        'muse-spark-1.3',
        dialect: ReasoningDialect.openaiReasoningEffort,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
          ReasoningLevel.xhigh,
          ReasoningLevel.max,
        ],
        canDisable: false,
      );
      expectHit(
        'muse-spark-1.3-contributor',
        dialect: ReasoningDialect.openaiReasoningEffort,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
          ReasoningLevel.xhigh,
        ],
        canDisable: false,
      );
      expectHit(
        'laguna-70b',
        dialect: ReasoningDialect.chatTemplateKwargs,
        levels: const [],
        canDisable: true,
        replay: ReasoningReplayPolicy.all,
        replayField: ReasoningReplayField.reasoningContent,
      );
      expectHit(
        'doubao-seed-2.0-pro',
        dialect: ReasoningDialect.thinkingType,
        levels: const [],
        canDisable: true,
      );
      expect(ModelDefaultsGuesser.guess('gpt-4o').reasoning, isNull);
      expect(ModelDefaultsGuesser.guess('minimax-m3').reasoning, isNull);
    });
  });
}
