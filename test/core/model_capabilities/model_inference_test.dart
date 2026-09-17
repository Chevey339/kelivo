import 'package:Kelivo/core/providers/model_provider.dart';
import 'package:flutter_test/flutter_test.dart';

ModelInfo _infer(String id) =>
    ModelRegistry.infer(ModelInfo(id: id, displayName: id));

void expectCaps(
  String id, {
  required bool image,
  required bool tool,
  required bool reasoning,
}) {
  final info = _infer(id);
  expect(info.input.contains(Modality.image), image, reason: '$id image input');
  expect(info.abilities.contains(ModelAbility.tool), tool, reason: '$id tool');
  expect(
    info.abilities.contains(ModelAbility.reasoning),
    reasoning,
    reason: '$id reasoning',
  );
}

void main() {
  group('OpenAI inference', () {
    test('vision and reasoning families', () {
      expectCaps('gpt-4o', image: true, tool: true, reasoning: true);
      expectCaps('gpt-4o-mini', image: true, tool: true, reasoning: true);
      expectCaps('gpt-4.1', image: true, tool: true, reasoning: true);
      expectCaps('gpt-5', image: true, tool: true, reasoning: true);
      expectCaps('o3-mini', image: true, tool: true, reasoning: true);
    });

    test('chat-latest is excluded but dated chat-latest is not', () {
      expectCaps(
        'gpt-5-chat-latest',
        image: false,
        tool: false,
        reasoning: false,
      );
      expectCaps(
        'gpt-5.2-chat-latest',
        image: true,
        tool: true,
        reasoning: true,
      );
    });

    test('gpt-oss reasons without vision', () {
      expectCaps('gpt-oss-120b', image: false, tool: true, reasoning: true);
    });
  });

  group('Gemini / Anthropic / Qwen / GLM', () {
    test('gemini vision is broad but reasoning is versioned', () {
      expectCaps('gemini-2.5-flash', image: true, tool: true, reasoning: true);
      expectCaps(
        'gemini-flash-latest',
        image: true,
        tool: true,
        reasoning: true,
      );
      expectCaps('gemini-1.5-pro', image: true, tool: true, reasoning: false);
    });

    test('claude and qwen are multimodal with tools', () {
      expectCaps('claude-sonnet-4-5', image: true, tool: true, reasoning: true);
      expectCaps('qwen3-8b', image: false, tool: true, reasoning: true);
      expectCaps('qwen3.5-plus', image: true, tool: true, reasoning: true);
    });

    test('qwen 3.7 max vision needs a late enough snapshot', () {
      expectCaps('qwen3.7-max', image: false, tool: true, reasoning: true);
      expectCaps(
        'qwen3.7-max-2026-06-08',
        image: true,
        tool: true,
        reasoning: true,
      );
      expectCaps(
        'qwen3.7-max-2026-05-20',
        image: false,
        tool: true,
        reasoning: true,
      );
    });

    test('glm-5.3-flash is multimodal, plain glm-5.3 is not', () {
      expectCaps('glm-5.3-flash', image: true, tool: true, reasoning: true);
      expectCaps('glm-5.3', image: false, tool: true, reasoning: true);
      expectCaps('glm-4.6', image: false, tool: true, reasoning: true);
    });
  });

  group('DeepSeek and others', () {
    test('deepseek reasoning excludes v3 and chat', () {
      expectCaps('deepseek-v3', image: false, tool: true, reasoning: false);
      expectCaps('deepseek-chat', image: false, tool: true, reasoning: false);
      expectCaps('deepseek-v3.1', image: false, tool: true, reasoning: true);
      expectCaps(
        'deepseek-reasoner',
        image: false,
        tool: true,
        reasoning: true,
      );
      expectCaps('deepseek-flash', image: true, tool: true, reasoning: true);
      expectCaps('deepseek-v4-pro', image: false, tool: true, reasoning: true);
    });

    test('minimax, grok, step, intern, laguna, sensenova', () {
      expectCaps('minimax-m2.5', image: false, tool: true, reasoning: true);
      expectCaps('minimax-m3', image: true, tool: true, reasoning: true);
      expectCaps('grok-4.5', image: true, tool: true, reasoning: true);
      expectCaps('step-3.7-flash', image: true, tool: true, reasoning: true);
      expectCaps('intern-s1', image: true, tool: true, reasoning: true);
      expectCaps('laguna-x', image: false, tool: true, reasoning: true);
      expectCaps(
        'sensenova-6.7-flash-lite',
        image: true,
        tool: true,
        reasoning: true,
      );
    });

    test('mimo vision is limited to omni and v2.5', () {
      expectCaps('mimo-v2.5', image: true, tool: true, reasoning: true);
      expectCaps('mimo-v2-flash', image: false, tool: true, reasoning: true);
    });

    test('gemma reasons without tools', () {
      expectCaps('gemma-4-26b', image: false, tool: false, reasoning: true);
    });
  });

  group('structural overrides', () {
    test('embedding ids become embedding models', () {
      final info = _infer('text-embedding-3-large');
      expect(info.type, ModelType.embedding);
      expect(info.abilities, isEmpty);
      expect(info.output, const [Modality.text]);
    });

    test('image ids take image in and out and drop abilities', () {
      final info = _infer('gpt-image-1');
      expect(info.input, contains(Modality.image));
      expect(info.output, contains(Modality.image));
      expect(info.abilities, isEmpty);
    });
  });
}
