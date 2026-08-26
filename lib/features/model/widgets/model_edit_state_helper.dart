import '../../../core/models/model_types.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/api/builtin_tools.dart';
import '../../../l10n/app_localizations.dart';

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
    Set<T>? freezeNullableSet<T>(Set<T>? set) =>
        set == null ? null : freezeSet(set);

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

    if (prev == ModelType.chat && next == ModelType.embedding) {
      nextCachedChatInput = {...input};
      nextCachedChatOutput = {...output};
      nextCachedChatAbilities = {...abilities};
    }
    if (prev == ModelType.embedding && next == ModelType.chat) {
      nextCachedEmbeddingInput = {...input};
    }

    if (next == ModelType.embedding) {
      nextAbilities.clear();
      final resolvedInput = {
        ...(nextCachedEmbeddingInput ?? const {Modality.text}),
      };
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

/// One built-in tool switch on a model's tools tab.
class ModelBuiltInToolTile {
  const ModelBuiltInToolTile({
    required this.name,
    required this.title,
    required this.desc,
    this.available = true,
  });

  final String name;
  final String title;
  final String desc;

  /// False for a tool the provider's current API mode cannot run: the switch
  /// stays visible but reads off and locked.
  final bool available;
}

class ModelBuiltInToolTiles {
  /// Switches for [cfg]'s tools tab, in display order. Kept in step with
  /// [BuiltInToolsHelper.modelSettingsToolNames], which decides whether the tab
  /// shows at all.
  static List<ModelBuiltInToolTile> forConfig({
    required ProviderConfig cfg,
    required AppLocalizations l10n,
  }) {
    final kind = ProviderConfig.classify(cfg.id, explicitType: cfg.providerType);
    final responses = cfg.useResponseApi == true;
    switch (kind) {
      case ProviderKind.google:
        return <ModelBuiltInToolTile>[
          ModelBuiltInToolTile(
            name: BuiltInToolNames.urlContext,
            title: l10n.modelDetailSheetUrlContextTool,
            desc: l10n.modelDetailSheetUrlContextToolDescription,
          ),
          ModelBuiltInToolTile(
            name: BuiltInToolNames.codeExecution,
            title: l10n.modelDetailSheetCodeExecutionTool,
            desc: l10n.modelDetailSheetCodeExecutionToolDescription,
          ),
          ModelBuiltInToolTile(
            name: BuiltInToolNames.youtube,
            title: l10n.modelDetailSheetYoutubeTool,
            desc: l10n.modelDetailSheetYoutubeToolDescription,
          ),
        ];
      case ProviderKind.claude:
        return <ModelBuiltInToolTile>[
          ModelBuiltInToolTile(
            name: BuiltInToolNames.webFetch,
            title: l10n.modelDetailSheetWebFetchTool,
            desc: l10n.modelDetailSheetClaudeWebFetchToolDescription,
          ),
          ModelBuiltInToolTile(
            name: BuiltInToolNames.codeExecution,
            title: l10n.modelDetailSheetCodeExecutionTool,
            desc: l10n.modelDetailSheetClaudeCodeExecutionToolDescription,
          ),
        ];
      case ProviderKind.openai:
        if (BuiltInToolsHelper.isOpenRouterProvider(cfg)) {
          return <ModelBuiltInToolTile>[
            ModelBuiltInToolTile(
              name: BuiltInToolNames.codeInterpreter,
              title: l10n.modelDetailSheetOpenaiCodeInterpreterTool,
              desc: l10n.modelDetailSheetOpenaiCodeInterpreterToolDescription,
              available: responses,
            ),
            ModelBuiltInToolTile(
              name: BuiltInToolNames.webFetch,
              title: l10n.modelDetailSheetWebFetchTool,
              desc: l10n.modelDetailSheetOpenrouterWebFetchToolDescription,
            ),
            ModelBuiltInToolTile(
              name: BuiltInToolNames.imageGeneration,
              title: l10n.modelDetailSheetOpenaiImageGenerationTool,
              desc: l10n.modelDetailSheetOpenaiImageGenerationToolDescription,
            ),
            ModelBuiltInToolTile(
              name: BuiltInToolNames.shell,
              title: l10n.modelDetailSheetOpenrouterShellTool,
              desc: l10n.modelDetailSheetOpenrouterShellToolDescription,
              available: responses,
            ),
          ];
        }
        return <ModelBuiltInToolTile>[
          ModelBuiltInToolTile(
            name: BuiltInToolNames.codeInterpreter,
            title: l10n.modelDetailSheetOpenaiCodeInterpreterTool,
            desc: l10n.modelDetailSheetOpenaiCodeInterpreterToolDescription,
            available: responses,
          ),
          ModelBuiltInToolTile(
            name: BuiltInToolNames.imageGeneration,
            title: l10n.modelDetailSheetOpenaiImageGenerationTool,
            desc: l10n.modelDetailSheetOpenaiImageGenerationToolDescription,
            available: responses,
          ),
        ];
    }
  }
}
