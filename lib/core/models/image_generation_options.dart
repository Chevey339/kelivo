/// Options for the Responses API's hosted image generation tool.
class ImageGenerationOptions {
  const ImageGenerationOptions({this.model, this.complexity});

  // Only GPT Image 2.6 documents complexity support. Keep the picker and
  // request validation together; OAuth servers may still substitute a model.
  // https://developers.openai.com/api/docs/guides/image-generation
  static const models = <String, bool>{
    'gpt-image-2.6-sunburst': true,
    'gpt-image-2.6-flare': true,
    'gpt-image-2.5-sunburst': false,
    'gpt-image-2.5-flare': false,
    'gpt-image-2': false,
    'gpt-image-1.5': false,
    'gpt-image-1-mini': false,
    'chatgpt-image-latest': false,
  };
  static const complexities = ['low', 'medium', 'high'];

  final String? model;
  final String? complexity;

  bool get supportsComplexity => models[model] == true;

  factory ImageGenerationOptions.fromJson(Object? json) {
    if (json is! Map) return const ImageGenerationOptions();
    final rawModel = json['model'];
    final model = rawModel is String ? rawModel.trim() : '';
    final complexity = json['complexity'];
    return ImageGenerationOptions(
      model: model.isEmpty || model == 'auto' ? null : model,
      complexity: complexities.contains(complexity)
          ? complexity as String
          : null,
    );
  }

  /// Defaults and unsupported complexity values are omitted on both disk and
  /// the wire. They must never be copied from the chat reasoning level.
  Map<String, dynamic> toJson() => {
    if (model != null) 'model': model,
    if (supportsComplexity && complexities.contains(complexity))
      'complexity': complexity,
  };
}
