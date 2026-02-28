import '../core/providers/model_provider.dart';

class ModelGrouping {
  static String groupFor(
    ModelInfo m, {
    required String embeddingsLabel,
    required String otherLabel,
  }) {
    final id = m.id.toLowerCase();
    if (m.type == ModelType.embedding || ModelRegistry.isLikelyEmbeddingId(id)) {
      return embeddingsLabel;
    }
    if (id.contains('gpt') || RegExp(r'(^|[^a-z])o[134]').hasMatch(id)) return 'GPT';
    if (id.contains('gemini-3')) return 'Gemini 3';
    if (id.contains('gemini-2.5')) return 'Gemini 2.5';
    if (id.contains('gemini')) return 'Gemini';
    if (id.contains('claude-4')) return 'Claude 4';
    if (id.contains('claude-sonnet')) return 'Claude Sonnet';
    if (id.contains('claude-opus')) return 'Claude Opus';
    if (id.contains('claude-haiku')) return 'Claude Haiku';
    if (id.contains('claude-3.5')) return 'Claude 3.5';
    if (id.contains('claude-3')) return 'Claude 3';
    if (id.contains('deepseek')) return 'DeepSeek';
    if (id.contains('kimi')) return 'Kimi';
    if (RegExp(r'qwen|qwq|qvq|dashscope').hasMatch(id)) return 'Qwen';
    if (RegExp(r'doubao|ark|volc').hasMatch(id)) return 'Doubao';
    if (id.contains('glm') || id.contains('zhipu')) return 'GLM';
    if (id.contains('mistral')) return 'Mistral';
    if (id.contains('minimax')) return 'MiniMax';
    if (id.contains('grok') || id.contains('xai')) return 'Grok';
    if (id.contains('kat')) return 'KAT';
    return otherLabel;
  }
}
