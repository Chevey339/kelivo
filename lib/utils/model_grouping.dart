import '../core/providers/model_provider.dart';
import 'model_brand.dart';

class ModelGrouping {
  static String groupFor(
    ModelInfo m, {
    required String embeddingsLabel,
    required String otherLabel,
  }) {
    final id = m.id.trim().toLowerCase();
    if (m.type == ModelType.embedding ||
        ModelRegistry.isLikelyEmbeddingId(id)) {
      return embeddingsLabel;
    }
    final brand = ModelBrand.match(id);
    final model = id.split('/').last;
    if (brand?.group == 'Gemini') {
      if (model.contains('gemini-3')) return 'Gemini 3';
      if (model.contains('gemini-2.5')) return 'Gemini 2.5';
    }
    if (brand?.group == 'Claude') {
      if (model.contains('claude-4')) return 'Claude 4';
      if (model.contains('claude-sonnet')) return 'Claude Sonnet';
      if (model.contains('claude-opus')) return 'Claude Opus';
      if (model.contains('claude-haiku')) return 'Claude Haiku';
      if (RegExp(r'claude-3[.-]5').hasMatch(model)) return 'Claude 3.5';
      if (model.contains('claude-3')) return 'Claude 3';
    }
    if (brand != null) return brand.group;
    if (RegExp(r'(^|[^a-z0-9])(?:ark|volc|bytedance)').hasMatch(id)) {
      return 'Doubao';
    }
    if (id.contains('xai')) return 'Grok';
    return otherLabel;
  }
}
