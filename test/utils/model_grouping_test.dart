import 'dart:io';

import 'package:Kelivo/core/models/model_types.dart';
import 'package:Kelivo/utils/brand_assets.dart';
import 'package:Kelivo/utils/model_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

String groupFor(String id, {ModelType type = ModelType.chat}) {
  return ModelGrouping.groupFor(
    ModelInfo(id: id, displayName: id, type: type),
    embeddingsLabel: '嵌入模型',
    otherLabel: '其他模型',
  );
}

void main() {
  group('Fetched model groups and icons', () {
    final families = <(String, String), List<String>>{
      ('Kimi', 'kimi-color.svg'): [
        'k3',
        ' K3-256K ',
        'kimi/k3',
        'gemini-relay/k3',
        'openrouter/moonshotai/kimi-k3',
        'moonshot-v1-128k',
        'kimi-for-coding-highspeed',
      ],
      ('Hunyuan', 'hunyuan-color.svg'): [
        'hy3',
        'hy3-preview',
        'hy4',
        'tencent/Hy4-preview',
        'hunyuan-turbos-latest',
      ],
      ('Doubao', 'doubao-color.svg'): [
        'seed',
        'seed-2.0-pro',
        'Seed2.1',
        'bytedance/seed-oss-36b-instruct',
        'doubao-seed-2-0-code-preview-260215',
        'seed-evolving',
        'Seedream-5.0',
        'Seedance-2.0',
        'Seeduplex',
      ],
      ('MiMo', 'mimo.svg'): [
        'mimo-v2.5-pro',
        'xiaomi/mimo-v2.5',
        'XiaomiMiMo/MiMo-V2-Flash',
      ],
      ('StepFun', 'stepfun.svg'): ['step-3.5-flash', 'stepfun/step-3'],
      ('LongCat', 'longcat.png'): ['meituan/longcat-flash-chat'],
      ('SenseNova', 'sensenova-color.svg'): ['sensenova-6.7-flash-lite'],
      ('InternLM', 'internlm-color.svg'): [
        'internlm/intern-s1',
        'internlm3-8b',
      ],
      ('InclusionAI', 'ling.png'): ['inclusionai/ling-2.6', 'ring-1t'],
      ('Mistral', 'mistral-color.svg'): [
        'mistral-large-latest',
        'mistralai/mixtral-8x7b-instruct',
        'magistral-medium-latest',
        'ministral-8b-latest',
        'labs-devstral-small-2512',
        'codestral-latest',
        'pixtral-12b',
        'voxtral-small-latest',
      ],
      ('Llama', 'meta-color.svg'): [
        'meta-llama/llama-4-scout',
        'codellama:7b',
        'codellama/CodeLlama-7b-Instruct-hf',
        'tinyllama:1.1b',
      ],
      ('Muse', 'meta-color.svg'): ['muse-spark-1', 'meta/muse-spark-1.2'],
      ('Gemma', 'gemma-color.svg'): [
        'google/gemma-4-27b',
        'gemma3:27b',
        'codegemma:7b',
        'google/codegemma-7b-it',
        'recurrentgemma:2b',
        'shieldgemma:2b',
        'paligemma:3b',
      ],
      ('Cohere', 'cohere-color.svg'): ['command-r-plus', 'command-a-03-2025'],
      ('Perplexity', 'perplexity-color.svg'): [
        'sonar-pro',
        'sonar-deep-research',
      ],
      ('KAT', 'katkwaipilot-color.svg'): ['kwaipilot/kat-coder-pro'],
      ('GPT', 'openai.svg'): [
        'gpt-5.4',
        'chatgpt-4o-latest',
        'openai/o3',
        'o4-mini',
        'gpt-oss-120b',
      ],
      ('GPT', 'codex.svg'): ['codex-mini-latest'],
      ('DeepSeek', 'deepseek-color.svg'): [
        'deepseek-v4-pro',
        'deepseek-ai/DeepSeek-R1-Distill-Qwen-32B',
      ],
      ('Qwen', 'qwen-color.svg'): [
        'qwen3.8-max',
        'Qwen/QwQ-32B',
        'qvq-max',
        'codeqwen:7b',
        'Qwen/CodeQwen1.5-7B-Chat',
      ],
      ('GLM', 'zhipu-color.svg'): [
        'z-ai/glm-5.3',
        'chatglm3-6b',
        'THUDM/chatglm3-6b',
      ],
      ('MiniMax', 'minimax-color.svg'): ['MiniMaxAI/MiniMax-M3'],
      ('Grok', 'grok.svg'): ['x-ai/grok-4'],
      ('Sora', 'sora-color.svg'): ['sora-2'],
    };

    for (final entry in families.entries) {
      for (final id in entry.value) {
        test('$id has the expected group and bundled icon', () {
          expect(groupFor(id), entry.key.$1);
          final asset = BrandAssets.assetForName(id);
          expect(asset, 'assets/icons/${entry.key.$2}');
          expect(File(asset!).existsSync(), isTrue);
          expect(BrandAssets.selectableAssetOrNull(asset), asset);
        });
      }
    }

    test('short aliases do not match inside unrelated names', () {
      for (final id in [
        'task3',
        'k30',
        'hy30',
        'hy40',
        'phylm-hy4x',
        'seedling',
        'seedbank',
        'stepping',
        'o300',
        'video3',
        'skating',
        'sterling',
        'ringbuffer',
        'custom-model',
      ]) {
        expect(groupFor(id), '其他模型', reason: id);
        expect(BrandAssets.assetForName(id), isNull, reason: id);
      }
    });

    test('model names take precedence over hosting providers', () {
      expect(
        BrandAssets.assetForName('openai/gemma-4'),
        'assets/icons/gemma-color.svg',
      );
      expect(
        BrandAssets.assetForName('ollama/k3'),
        'assets/icons/kimi-color.svg',
      );
      expect(
        BrandAssets.assetForName('google'),
        'assets/icons/google-color.svg',
      );
      expect(BrandAssets.assetForName('ollama'), 'assets/icons/ollama.svg');
      expect(
        BrandAssets.assetForName('metaso'),
        'assets/icons/metaso-color.svg',
      );
    });

    test('embedding grouping takes precedence over the brand', () {
      for (final id in [
        'qwen3-embedding-8b',
        'mistral-embed',
        'jina-embeddings-v3',
      ]) {
        expect(groupFor(id), '嵌入模型');
      }
      expect(groupFor('k3', type: ModelType.embedding), '嵌入模型');
    });

    test('keeps the existing Gemini and Claude subgroups', () {
      final cases = {
        'google/gemini-3.1-pro-preview': 'Gemini 3',
        'gemini-2.5-flash': 'Gemini 2.5',
        'gemini-flash-latest': 'Gemini',
        'claude-sonnet-4-6': 'Claude Sonnet',
        'anthropic/claude-opus-4.6': 'Claude Opus',
        'claude-haiku-4-5': 'Claude Haiku',
        'claude-4-sonnet': 'Claude 4',
        'claude-3.5-sonnet': 'Claude 3.5',
        'claude-3-5-sonnet': 'Claude 3.5',
        'claude-3-opus': 'Claude 3',
        'claude': 'Claude',
      };
      for (final entry in cases.entries) {
        expect(groupFor(entry.key), entry.value, reason: entry.key);
      }
    });
  });
}
