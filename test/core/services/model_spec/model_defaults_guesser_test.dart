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

    test(
      'guesser preserves historical text/image capabilities and abilities',
      () {
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
            [
              for (final m in guess.input)
                if (m == Modality.text || m == Modality.image) m.name,
            ],
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
      },
    );
  });

  test('known chat families infer native file input modes', () {
    for (final id in [
      'gemini-2.5-pro',
      'google/gemini-3-flash-preview',
      'gemini-flash-latest',
    ]) {
      expect(
        ModelDefaultsGuesser.guess(id).input,
        containsAll([Modality.audio, Modality.video, Modality.pdf]),
        reason: id,
      );
    }
    for (final id in [
      'claude-sonnet-4-6',
      'anthropic/claude-opus-4.6',
      'gpt-4o',
      'gpt-4.1',
      'gpt-5.4',
    ]) {
      expect(
        ModelDefaultsGuesser.guess(id).input,
        contains(Modality.pdf),
        reason: id,
      );
    }
    expect(
      ModelDefaultsGuesser.guess('gpt-audio-1.5').input,
      contains(Modality.audio),
    );
    expect(
      ModelDefaultsGuesser.guess('qwen3-omni-flash').input,
      containsAll([Modality.audio, Modality.video]),
    );
    for (final id in [
      'gemini-3.1-flash-image',
      'gemini-2.5-flash-preview-tts',
      'text-embedding-3-small',
      'claude-2',
    ]) {
      expect(
        ModelDefaultsGuesser.guess(id).input,
        isNot(contains(Modality.pdf)),
        reason: id,
      );
    }
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

    test('only dall-e-2 and gpt-image families accept image input', () {
      expect(ModelDefaultsGuesser.guess('dall-e-2').input, [
        Modality.text,
        Modality.image,
      ]);
      expect(ModelDefaultsGuesser.guess('dall-e-3').input, [Modality.text]);
      expect(ModelDefaultsGuesser.guess('agnes-image-1').input, [
        Modality.text,
      ]);
      expect(ModelDefaultsGuesser.guess('sensenova-u1-fast').input, [
        Modality.text,
      ]);
      expect(
        ModelDefaultsGuesser.guess('gpt-image-1').input,
        contains(Modality.image),
      );
    });
  });

  group('Kimi Code ids', () {
    test('aliases infer image, tool and reasoning', () {
      for (final id in const [
        'k3',
        'k3-256k',
        'kimi-for-coding',
        'kimi-for-coding-highspeed',
        'moonshotai/kimi-for-coding:fast',
        'kimi-k2.8',
        'moonshotai/kimi-k2.8-preview',
      ]) {
        final model = ModelDefaultsGuesser.guess(id);
        expect(model.input, [Modality.text, Modality.image], reason: id);
        expect(
          model.abilities,
          containsAll([ModelAbility.tool, ModelAbility.reasoning]),
          reason: id,
        );
      }
    });

    test('near-miss ids stay text-only without those abilities', () {
      for (final id in const ['k30', 'my-k3', 'kimi-for-coding-other']) {
        final model = ModelDefaultsGuesser.guess(id);
        expect(model.abilities, isEmpty, reason: id);
        expect(model.input, [Modality.text], reason: id);
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
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
        ],
        canDisable: true,
        maxOutput: 8192,
      );
      expectHit(
        'claude-3-haiku@20240307',
        dialect: ReasoningDialect.anthropicBudget,
        levels: const [
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
        ],
        canDisable: true,
        maxOutput: 8000,
      );
      expectHit(
        'claude-sonnet-4-6@20260101',
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
        replay: ReasoningReplayPolicy.all,
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
        replay: ReasoningReplayPolicy.all,
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
        replay: ReasoningReplayPolicy.all,
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
        replay: ReasoningReplayPolicy.all,
      );
      expectHit(
        'gemini-3.1-flash-image',
        dialect: ReasoningDialect.geminiThinkingLevel,
        levels: const [ReasoningLevel.minimal, ReasoningLevel.high],
        canDisable: false,
        sampling: SamplingPolicy.never,
        replay: ReasoningReplayPolicy.all,
      );
      expectHit(
        'gemini-3.1-flash-tts-preview',
        dialect: ReasoningDialect.none,
        levels: const [],
        canDisable: true,
        replay: ReasoningReplayPolicy.all,
      );
      expectHit(
        'gemini-3-pro-image-preview',
        dialect: ReasoningDialect.none,
        levels: const [],
        canDisable: true,
        replay: ReasoningReplayPolicy.all,
      );
      expect(
        ModelDefaultsGuesser.guess(
          'gemini-3.1-flash-tts-preview',
        ).abilities.contains(ModelAbility.reasoning),
        isTrue,
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
        maxOutput: 32000,
        replay: ReasoningReplayPolicy.toolTurns,
        replayField: ReasoningReplayField.reasoningContent,
      );
      expectHit(
        'kimi-k2.6',
        dialect: ReasoningDialect.kimiThinking,
        levels: const [],
        canDisable: true,
        maxOutput: 32000,
        replay: ReasoningReplayPolicy.toolTurns,
        replayField: ReasoningReplayField.reasoningContent,
      );
      expectHit(
        'kimi-k2.7',
        dialect: ReasoningDialect.kimiThinking,
        levels: const [],
        canDisable: false,
        sampling: SamplingPolicy.never,
        maxOutput: 32000,
        replay: ReasoningReplayPolicy.toolTurns,
        replayField: ReasoningReplayField.reasoningContent,
      );
      expectHit(
        'kimi-k2.7-code',
        dialect: ReasoningDialect.kimiThinking,
        levels: const [],
        canDisable: false,
        sampling: SamplingPolicy.never,
        maxOutput: 32000,
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
        maxOutput: 32000,
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
        maxOutput: 32000,
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
        maxOutput: 32000,
        replay: ReasoningReplayPolicy.all,
        replayField: ReasoningReplayField.reasoningContent,
      );
      expectHit(
        'kimi-for-coding-highspeed',
        dialect: ReasoningDialect.kimiThinking,
        levels: const [],
        canDisable: true,
        maxOutput: 32000,
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

  group('request quirks', () {
    test('dynamic web search follows the Claude generation', () {
      for (final id in const [
        'claude-opus-4-6',
        'claude-opus-4-7',
        'claude-opus-4.8',
        'claude-sonnet-4-6',
        'claude-fable-5',
        'claude-fable-5-1',
        'claude-mythos-preview',
        'claude-opus-5',
        'claude-opus-5-5',
        'claude-sonnet-5',
      ]) {
        expect(
          ModelDefaultsGuesser.guess(id).dynamicWebSearch,
          isTrue,
          reason: id,
        );
      }
      for (final id in const ['claude-sonnet-4-20250514', 'gpt-5.5']) {
        expect(
          ModelDefaultsGuesser.guess(id).dynamicWebSearch,
          isFalse,
          reason: id,
        );
      }
    });

    test('only the K3 wire rejects remote image URLs', () {
      for (final id in const [
        'k3',
        'k3-256k',
        'kimi-k3',
        'moonshotai/kimi-k3',
      ]) {
        expect(
          ModelDefaultsGuesser.guess(id).remoteImageUrls,
          isFalse,
          reason: id,
        );
      }
      for (final id in const ['kimi-k2.6', 'gpt-5.5']) {
        expect(
          ModelDefaultsGuesser.guess(id).remoteImageUrls,
          isTrue,
          reason: id,
        );
      }
    });

    test('prompt cache control marks Claude routes', () {
      expect(
        ModelDefaultsGuesser.guess(
          'anthropic/claude-opus-5',
        ).promptCacheControl,
        isTrue,
      );
      expect(
        ModelDefaultsGuesser.guess('openai/gpt-5.5').promptCacheControl,
        isFalse,
      );
    });
  });
}
