import '../../../core/models/model_types.dart';

class ModelTypeSwitchResult {
  const ModelTypeSwitchResult({
    required this.input,
    required this.output,
    required this.abilities,
    required this.cachedChatInput,
    required this.cachedChatOutput,
    required this.cachedChatAbilities,
    required this.cachedEmbeddingInput,
  });

  final Set<Modality> input;
  final Set<Modality> output;
  final Set<ModelAbility> abilities;
  final Set<Modality>? cachedChatInput;
  final Set<Modality>? cachedChatOutput;
  final Set<ModelAbility>? cachedChatAbilities;
  final Set<Modality>? cachedEmbeddingInput;
}

class ModelEditTypeSwitch {
  /// Applies a model type switch and returns new sets (no in-place mutation).
  ///
  /// This helper assumes it is called on the UI isolate. The main risk is
  /// shared references, so callers should pass state-owned sets (not shared
  /// across widgets) to avoid unintended side effects.
  static ModelTypeSwitchResult apply({
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
    Set<Modality> ensureText(Set<Modality> mods) {
      if (!mods.contains(Modality.text)) mods.add(Modality.text);
      return mods;
    }

    Set<T> freezeSet<T>(Set<T> set) => Set.unmodifiable(Set<T>.from(set));
    Set<T>? freezeNullableSet<T>(Set<T>? set) => set == null ? null : freezeSet(set);

    if (prev == next) {
      return ModelTypeSwitchResult(
        input: freezeSet(input),
        output: freezeSet(output),
        abilities: freezeSet(abilities),
        cachedChatInput: freezeNullableSet(cachedChatInput),
        cachedChatOutput: freezeNullableSet(cachedChatOutput),
        cachedChatAbilities: freezeNullableSet(cachedChatAbilities),
        cachedEmbeddingInput: freezeNullableSet(cachedEmbeddingInput),
      );
    }

    var nextCachedChatInput = cachedChatInput;
    var nextCachedChatOutput = cachedChatOutput;
    var nextCachedChatAbilities = cachedChatAbilities;
    var nextCachedEmbeddingInput = cachedEmbeddingInput;

    var nextInput = {...input};
    var nextOutput = {...output};
    var nextAbilities = {...abilities};

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
      nextAbilities.clear();
      final resolvedInput = {...(nextCachedEmbeddingInput ?? const {Modality.text})};
      nextInput
        ..clear()
        ..addAll(resolvedInput);
      nextInput = ensureText(nextInput);
      nextOutput
        ..clear()
        ..add(Modality.text);
      return ModelTypeSwitchResult(
        input: freezeSet(nextInput),
        output: freezeSet(nextOutput),
        abilities: freezeSet(nextAbilities),
        cachedChatInput: freezeNullableSet(nextCachedChatInput),
        cachedChatOutput: freezeNullableSet(nextCachedChatOutput),
        cachedChatAbilities: freezeNullableSet(nextCachedChatAbilities),
        cachedEmbeddingInput: freezeNullableSet(nextCachedEmbeddingInput),
      );
    }

    // Restore cached chat state when flipping embedding -> chat.
    if (prev == ModelType.embedding && next == ModelType.chat) {
      nextInput
        ..clear()
        ..addAll(nextCachedChatInput ?? const {Modality.text});
      nextInput = ensureText(nextInput);

      nextOutput
        ..clear()
        ..addAll(nextCachedChatOutput ?? const {Modality.text});
      nextOutput = ensureText(nextOutput);

      nextAbilities
        ..clear()
        ..addAll(nextCachedChatAbilities ?? const <ModelAbility>{});
    }

    return ModelTypeSwitchResult(
      input: freezeSet(nextInput),
      output: freezeSet(nextOutput),
      abilities: freezeSet(nextAbilities),
      cachedChatInput: freezeNullableSet(nextCachedChatInput),
      cachedChatOutput: freezeNullableSet(nextCachedChatOutput),
      cachedChatAbilities: freezeNullableSet(nextCachedChatAbilities),
      cachedEmbeddingInput: freezeNullableSet(nextCachedEmbeddingInput),
    );
  }
}

