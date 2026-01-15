import '../../../core/models/model_types.dart';

class ModelTypeSwitchCache {
  const ModelTypeSwitchCache({
    required this.cachedChatInput,
    required this.cachedChatOutput,
    required this.cachedChatAbilities,
    required this.cachedEmbeddingInput,
  });

  final Set<Modality>? cachedChatInput;
  final Set<Modality>? cachedChatOutput;
  final Set<ModelAbility>? cachedChatAbilities;
  final Set<Modality>? cachedEmbeddingInput;
}

class ModelEditTypeSwitch {
  /// Applies a model type switch and updates the provided sets in place.
  ///
  /// This helper assumes it is called on the UI isolate. The main risk is
  /// shared references, so callers should pass state-owned sets (not shared
  /// across widgets) to avoid unintended side effects.
  static ModelTypeSwitchCache apply({
    required ModelType prev,
    required ModelType next,
    required Set<Modality> input,
    required Set<Modality> output,
    required Set<ModelAbility> abilities,
    required Set<Modality>? cachedChatInput,
    required Set<Modality>? cachedChatOutput,
    required Set<ModelAbility>? cachedChatAbilities,
    required Set<Modality>? cachedEmbeddingInput,
  }) {
    var nextCachedChatInput = cachedChatInput;
    var nextCachedChatOutput = cachedChatOutput;
    var nextCachedChatAbilities = cachedChatAbilities;
    var nextCachedEmbeddingInput = cachedEmbeddingInput;

    // Cache chat state before switching to embedding.
    if (prev == ModelType.chat && next == ModelType.embedding) {
      nextCachedChatInput = {...input};
      nextCachedChatOutput = {...output};
      nextCachedChatAbilities = {...abilities};
    }
    // Cache embedding input before switching to chat.
    if (prev == ModelType.embedding && next == ModelType.chat) {
      nextCachedEmbeddingInput = {...input};
    }

    if (next == ModelType.embedding) {
      // Prevent chat-only state from leaking into embedding configs.
      abilities.clear();
      final nextInput = nextCachedEmbeddingInput ?? <Modality>{Modality.text};
      input
        ..clear()
        ..addAll(nextInput);
      if (input.isEmpty) input.add(Modality.text);
      output
        ..clear()
        ..add(Modality.text);
      return ModelTypeSwitchCache(
        cachedChatInput: nextCachedChatInput,
        cachedChatOutput: nextCachedChatOutput,
        cachedChatAbilities: nextCachedChatAbilities,
        cachedEmbeddingInput: nextCachedEmbeddingInput,
      );
    }

    // Restore cached chat state when flipping embedding -> chat.
    if (prev == ModelType.embedding && next == ModelType.chat) {
      input
        ..clear()
        ..addAll(nextCachedChatInput ?? const {Modality.text});
      if (input.isEmpty) input.add(Modality.text);

      output
        ..clear()
        ..addAll(nextCachedChatOutput ?? const {Modality.text});
      if (output.isEmpty) output.add(Modality.text);

      abilities
        ..clear()
        ..addAll(nextCachedChatAbilities ?? const <ModelAbility>{});
    }

    return ModelTypeSwitchCache(
      cachedChatInput: nextCachedChatInput,
      cachedChatOutput: nextCachedChatOutput,
      cachedChatAbilities: nextCachedChatAbilities,
      cachedEmbeddingInput: nextCachedEmbeddingInput,
    );
  }
}

