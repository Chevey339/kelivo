import 'package:flutter/foundation.dart';

import '../../models/model_spec.dart';
import '../../providers/settings_provider.dart';
import '../model_catalog/catalog_entry.dart';
import '../model_catalog/model_catalog_service.dart';
import 'model_defaults_guesser.dart';
import 'vendor_defaults.dart';

enum SpecSource { override, catalog, guess, vendor, fallback }

enum ModelSpecField {
  type,
  input,
  output,
  abilities,
  reasoningDialect,
  reasoningLevels,
  reasoningCanDisable,
  reasoningDefaultLevel,
  reasoningBudgets,
  reasoningReplay,
  sampling,
  contextWindow,
  maxOutput,
  pricing,
  dynamicWebSearch,
  remoteImageUrls,
  promptCacheControl,
}

@immutable
class ResolvedModelSpec {
  const ResolvedModelSpec({
    required this.spec,
    required this.base,
    required this.override,
    required this.sources,
    this.catalog,
  });

  final ModelSpec spec;
  final ModelSpec base;
  final ModelSpecOverride override;
  final Map<ModelSpecField, SpecSource> sources;
  final CatalogMatch? catalog;
}

class _MemoEntry {
  const _MemoEntry({
    required this.resolved,
    required this.rawOverride,
    required this.catalogVersion,
    required this.fingerprint,
  });

  final ResolvedModelSpec resolved;
  final Object? rawOverride;
  final int catalogVersion;
  final int fingerprint;
}

class ModelSpecResolver {
  ModelSpecResolver({ModelCatalogService? catalog})
    : _catalog = catalog ?? ModelCatalogService.instance {
    _catalog.addListener(_onCatalogChanged);
  }

  static final ModelSpecResolver instance = ModelSpecResolver();

  static const int _memoCap = 4096;
  static const List<ReasoningLevel> _effortLadder = [
    ReasoningLevel.low,
    ReasoningLevel.medium,
    ReasoningLevel.high,
  ];
  static const List<ReasoningLevel> _budgetLadder = [
    ReasoningLevel.low,
    ReasoningLevel.medium,
    ReasoningLevel.high,
    ReasoningLevel.xhigh,
    ReasoningLevel.max,
  ];
  static const Map<ReasoningLevel, double> _budgetPct = {
    ReasoningLevel.minimal: 0.05,
    ReasoningLevel.low: 0.05,
    ReasoningLevel.medium: 0.5,
    ReasoningLevel.high: 0.8,
    ReasoningLevel.xhigh: 0.9,
    ReasoningLevel.max: 1.0,
  };
  static const Map<ReasoningLevel, int> _fixedBudgets = {
    ReasoningLevel.minimal: 512,
    ReasoningLevel.low: 1024,
    ReasoningLevel.medium: 4096,
    ReasoningLevel.high: 8192,
    ReasoningLevel.xhigh: 16000,
    ReasoningLevel.max: 32000,
  };
  static const Set<ReasoningDialect> _budgetDialects = {
    ReasoningDialect.anthropicBudget,
    ReasoningDialect.geminiThinkingBudget,
    ReasoningDialect.qwenEnableThinking,
    ReasoningDialect.siliconflowEnableThinking,
    ReasoningDialect.openrouterReasoning,
  };

  final ModelCatalogService _catalog;
  final Map<(String, String), _MemoEntry> _memo = {};
  int _seenCatalogVersion = -1;

  ModelSpec spec(ProviderConfig cfg, String modelKey, {String? displayName}) =>
      resolve(cfg, modelKey, displayName: displayName).spec;

  ResolvedModelSpec resolve(
    ProviderConfig cfg,
    String modelKey, {
    String? displayName,
  }) {
    final rawOverride = _rawOverride(cfg, modelKey);
    final catalogVersion = _catalog.version;
    final fingerprint = _fingerprint(cfg, displayName);
    final key = (cfg.id, modelKey);
    final cached = _memo[key];
    if (cached != null &&
        identical(cached.rawOverride, rawOverride) &&
        cached.catalogVersion == catalogVersion &&
        cached.fingerprint == fingerprint) {
      return cached.resolved;
    }

    final resolved = _resolveUncached(
      cfg,
      modelKey,
      displayName: displayName,
      rawOverride: rawOverride,
    );
    if (_memo.length >= _memoCap) {
      _memo.clear();
    }
    _memo[key] = _MemoEntry(
      resolved: resolved,
      rawOverride: rawOverride,
      catalogVersion: catalogVersion,
      fingerprint: fingerprint,
    );
    _seenCatalogVersion = catalogVersion;
    return resolved;
  }

  void invalidate() {
    _memo.clear();
    _seenCatalogVersion = _catalog.version;
  }

  void _onCatalogChanged() {
    if (_catalog.version != _seenCatalogVersion) {
      invalidate();
    }
  }

  ResolvedModelSpec _resolveUncached(
    ProviderConfig cfg,
    String modelKey, {
    required String? displayName,
    required Object? rawOverride,
  }) {
    final ov = rawOverride is Map
        ? ModelSpecOverride.fromJson(rawOverride)
        : const ModelSpecOverride();
    final upstreamId = ov.apiModelId ?? modelKey;
    final match =
        _catalog.lookup(cfg, upstreamId) ??
        (upstreamId != modelKey ? _catalog.lookup(cfg, modelKey) : null);
    final guess = ModelDefaultsGuesser.guess(upstreamId);
    final vendor = VendorDefaults.forProvider(cfg);
    final sources = <ModelSpecField, SpecSource>{};

    final type = _resolveType(guess: guess, match: match, sources: sources);
    final input = _resolveModalities(
      catalogValues: match?.model.inputModalities,
      guessValues: guess.input,
      field: ModelSpecField.input,
      sources: sources,
    );
    final output = _resolveModalities(
      catalogValues: match?.model.outputModalities,
      guessValues: guess.output,
      field: ModelSpecField.output,
      sources: sources,
    );
    final abilities = _resolveAbilities(
      match: match,
      guess: guess,
      sources: sources,
    );

    final reasoning = _resolveReasoning(
      guess: guess,
      vendor: vendor,
      match: match,
      sources: sources,
    );
    final sampling = _resolveSampling(
      match: match,
      guess: guess,
      sources: sources,
    );
    final contextWindow = _pick<int?>(
      catalog: match?.model.contextLimit,
      fallback: null,
      field: ModelSpecField.contextWindow,
      sources: sources,
    );
    final maxOutput = _pick<int?>(
      catalog: match?.model.outputLimit,
      guess: guess.maxOutput,
      fallback: null,
      field: ModelSpecField.maxOutput,
      sources: sources,
    );
    final pricing = _resolvePricing(match: match, sources: sources);

    final base = ModelSpec(
      id: modelKey,
      displayName: displayName ?? modelKey,
      type: type,
      input: type == ModelType.chat
          ? _protocolInput(cfg, upstreamId, input)
          : input,
      output: output,
      abilities: abilities,
      reasoning: reasoning,
      sampling: sampling,
      contextWindow: contextWindow,
      maxOutput: maxOutput,
      pricing: pricing,
      dynamicWebSearch: guess.dynamicWebSearch,
      remoteImageUrls: guess.remoteImageUrls,
      promptCacheControl: guess.promptCacheControl,
    );
    sources[ModelSpecField.dynamicWebSearch] = SpecSource.guess;
    sources[ModelSpecField.remoteImageUrls] = SpecSource.guess;
    sources[ModelSpecField.promptCacheControl] = SpecSource.guess;
    final spec = ov.applyTo(base, applyDisplayName: true);
    _markOverrideSources(ov, sources);

    return ResolvedModelSpec(
      spec: spec,
      base: base,
      override: ov,
      sources: Map<ModelSpecField, SpecSource>.unmodifiable(sources),
      catalog: match,
    );
  }

  static Object? _rawOverride(ProviderConfig cfg, String modelKey) {
    final raw = cfg.modelOverrides[modelKey];
    return raw is Map ? raw : null;
  }

  // Model capabilities alone do not imply the selected API can transport
  // them. Explicit user overrides are applied afterwards and are validated
  // when an attachment is sent.
  static List<Modality> _protocolInput(
    ProviderConfig cfg,
    String modelId,
    List<Modality> input,
  ) {
    final kind = ProviderConfig.classify(
      cfg.id,
      explicitType: cfg.providerType,
    );
    final pdfOnly =
        kind == ProviderKind.claude ||
        (kind == ProviderKind.google &&
            cfg.vertexAI == true &&
            modelId.toLowerCase().startsWith('claude-')) ||
        (kind == ProviderKind.openai && cfg.useResponseApi == true);
    final officialOpenAi =
        kind == ProviderKind.openai &&
        Uri.tryParse(cfg.baseUrl)?.host.toLowerCase() == 'api.openai.com';
    return [
      for (final modality in input)
        if (!(pdfOnly &&
                (modality == Modality.audio || modality == Modality.video)) &&
            !(officialOpenAi && modality == Modality.video))
          modality,
    ];
  }

  static int _fingerprint(ProviderConfig cfg, String? displayName) {
    return Object.hash(
      cfg.baseUrl,
      cfg.providerType,
      cfg.vertexAI,
      cfg.useResponseApi,
      cfg.oauthProvider,
      cfg.chatPath,
      displayName,
    );
  }

  static ModelType _resolveType({
    required ModelGuess guess,
    required CatalogMatch? match,
    required Map<ModelSpecField, SpecSource> sources,
  }) {
    if (guess.type == ModelType.embedding) {
      sources[ModelSpecField.type] = SpecSource.guess;
      return ModelType.embedding;
    }
    if (match != null) {
      final outs = match.model.outputModalities;
      sources[ModelSpecField.type] = SpecSource.catalog;
      if (outs.contains('image') && !outs.contains('text')) {
        return ModelType.image;
      }
      return ModelType.chat;
    }
    sources[ModelSpecField.type] = SpecSource.guess;
    return guess.type;
  }

  static List<Modality> _resolveModalities({
    required List<String>? catalogValues,
    required List<Modality> guessValues,
    required ModelSpecField field,
    required Map<ModelSpecField, SpecSource> sources,
  }) {
    if (catalogValues != null && catalogValues.isNotEmpty) {
      final mapped = <Modality>[
        for (final raw in catalogValues)
          if (_modalityFromCatalog(raw) != null) _modalityFromCatalog(raw)!,
      ];
      if (mapped.isNotEmpty) {
        sources[field] = SpecSource.catalog;
        return mapped;
      }
    }
    sources[field] = SpecSource.guess;
    return guessValues;
  }

  static Modality? _modalityFromCatalog(String raw) {
    return switch (raw) {
      'text' => Modality.text,
      'image' => Modality.image,
      'audio' => Modality.audio,
      'video' => Modality.video,
      'pdf' => Modality.pdf,
      _ => null,
    };
  }

  static List<ModelAbility> _resolveAbilities({
    required CatalogMatch? match,
    required ModelGuess guess,
    required Map<ModelSpecField, SpecSource> sources,
  }) {
    if (match != null) {
      sources[ModelSpecField.abilities] = SpecSource.catalog;
      return <ModelAbility>[
        if (match.model.toolCall) ModelAbility.tool,
        if (match.model.reasoning) ModelAbility.reasoning,
        if (match.model.structuredOutput) ModelAbility.structuredOutput,
      ];
    }
    sources[ModelSpecField.abilities] = SpecSource.guess;
    return guess.abilities;
  }

  static ReasoningSpec _resolveReasoning({
    required ModelGuess guess,
    required VendorDefaults vendor,
    required CatalogMatch? match,
    required Map<ModelSpecField, SpecSource> sources,
  }) {
    final dialect = _resolveDialect(
      vendor: vendor,
      guess: guess,
      sources: sources,
    );
    final levels = _resolveLevels(
      vendor: vendor,
      match: match,
      guess: guess,
      dialect: dialect,
      sources: sources,
    );
    final canDisable = _resolveCanDisable(
      vendor: vendor,
      match: match,
      guess: guess,
      sources: sources,
    );
    final budgets = _resolveBudgets(
      dialect: dialect,
      levels: levels,
      match: match,
      sources: sources,
    );
    final defaultLevel = guess.reasoning?.defaultLevel;
    if (defaultLevel != null) {
      sources[ModelSpecField.reasoningDefaultLevel] = SpecSource.guess;
    } else {
      sources[ModelSpecField.reasoningDefaultLevel] = SpecSource.fallback;
    }

    final replay = _resolveReplay(
      guess: guess,
      match: match,
      vendor: vendor,
      sources: sources,
    );

    return ReasoningSpec(
      levels: levels,
      canDisable: canDisable,
      defaultLevel: defaultLevel ?? ReasoningLevel.auto,
      dialect: dialect,
      budgets: budgets,
      replay: replay.policy,
      replayField: replay.field,
    );
  }

  static ReasoningDialect _resolveDialect({
    required VendorDefaults vendor,
    required ModelGuess guess,
    required Map<ModelSpecField, SpecSource> sources,
  }) {
    if (vendor.dialect != null) {
      sources[ModelSpecField.reasoningDialect] = SpecSource.vendor;
      return vendor.dialect!;
    }
    if (guess.reasoning?.dialect != null) {
      sources[ModelSpecField.reasoningDialect] = SpecSource.guess;
      return guess.reasoning!.dialect;
    }
    sources[ModelSpecField.reasoningDialect] = SpecSource.vendor;
    return vendor.protocolDefault;
  }

  static List<ReasoningLevel> _resolveLevels({
    required VendorDefaults vendor,
    required CatalogMatch? match,
    required ModelGuess guess,
    required ReasoningDialect dialect,
    required Map<ModelSpecField, SpecSource> sources,
  }) {
    if (vendor.levels != null) {
      sources[ModelSpecField.reasoningLevels] = SpecSource.vendor;
      return vendor.levels!;
    }
    final catalogLevels = _catalogEffortLevels(match?.model);
    if (catalogLevels != null) {
      sources[ModelSpecField.reasoningLevels] = SpecSource.catalog;
      return catalogLevels;
    }
    final guessLevels = guess.reasoning?.levels;
    if (guessLevels != null && guessLevels.isNotEmpty) {
      sources[ModelSpecField.reasoningLevels] = SpecSource.guess;
      return guessLevels;
    }
    if (_budgetDialects.contains(dialect)) {
      sources[ModelSpecField.reasoningLevels] = SpecSource.fallback;
      return _budgetLadder;
    }
    if (guess.reasoning != null) {
      sources[ModelSpecField.reasoningLevels] = SpecSource.guess;
      return const [];
    }
    sources[ModelSpecField.reasoningLevels] = SpecSource.fallback;
    return _effortLadder;
  }

  static List<ReasoningLevel>? _catalogEffortLevels(CatalogModel? model) {
    if (model == null) return null;
    for (final option in model.reasoningOptions) {
      if (option.type != 'effort') continue;
      final levels = <ReasoningLevel>[
        for (final raw in option.values)
          if (_levelFromCatalog(raw) != null) _levelFromCatalog(raw)!,
      ];
      return levels;
    }
    return null;
  }

  static ReasoningLevel? _levelFromCatalog(String? raw) {
    if (raw == null) return null;
    final value = raw.trim().toLowerCase();
    if (value.isEmpty ||
        value == 'default' ||
        value == 'null' ||
        value == 'none') {
      return null;
    }
    for (final level in ReasoningLevel.values) {
      if (level.name == value) return level;
    }
    return null;
  }

  static bool _resolveCanDisable({
    required VendorDefaults vendor,
    required CatalogMatch? match,
    required ModelGuess guess,
    required Map<ModelSpecField, SpecSource> sources,
  }) {
    if (vendor.canDisable != null) {
      sources[ModelSpecField.reasoningCanDisable] = SpecSource.vendor;
      return vendor.canDisable!;
    }
    final catalog = _catalogCanDisable(match?.model);
    if (catalog != null) {
      sources[ModelSpecField.reasoningCanDisable] = SpecSource.catalog;
      return catalog;
    }
    if (guess.reasoning?.canDisable != null) {
      sources[ModelSpecField.reasoningCanDisable] = SpecSource.guess;
      return guess.reasoning!.canDisable;
    }
    sources[ModelSpecField.reasoningCanDisable] = SpecSource.fallback;
    return true;
  }

  static bool? _catalogCanDisable(CatalogModel? model) {
    if (model == null || model.reasoningOptions.isEmpty) return null;
    var hasToggle = false;
    CatalogReasoningOption? effort;
    for (final option in model.reasoningOptions) {
      if (option.type == 'toggle') hasToggle = true;
      if (option.type == 'effort') effort = option;
    }
    if (hasToggle || (effort?.values.contains('none') ?? false)) {
      return true;
    }
    if (effort != null) {
      return false;
    }
    return null;
  }

  static Map<ReasoningLevel, int> _resolveBudgets({
    required ReasoningDialect dialect,
    required List<ReasoningLevel> levels,
    required CatalogMatch? match,
    required Map<ModelSpecField, SpecSource> sources,
  }) {
    if (!_budgetDialects.contains(dialect)) {
      sources[ModelSpecField.reasoningBudgets] = SpecSource.fallback;
      return const {};
    }
    CatalogReasoningOption? budget;
    for (final option in match?.model.reasoningOptions ?? const []) {
      if (option.type == 'budget_tokens') {
        budget = option;
        break;
      }
    }
    if (budget?.max != null) {
      sources[ModelSpecField.reasoningBudgets] = SpecSource.catalog;
      final max = budget!.max!;
      final optionMin = budget.min ?? 0;
      final floor = optionMin > 1024 ? optionMin : 1024;
      final budgets = <ReasoningLevel, int>{};
      for (final level in levels) {
        final pct = _budgetPct[level];
        if (pct == null) continue;
        budgets[level] = _budgetFromCatalogMax(
          pct: pct,
          max: max,
          floor: floor,
        );
      }
      return budgets;
    }
    sources[ModelSpecField.reasoningBudgets] = SpecSource.fallback;
    return <ReasoningLevel, int>{
      for (final level in levels)
        if (_fixedBudgets.containsKey(level)) level: _fixedBudgets[level]!,
    };
  }

  static int _budgetFromCatalogMax({
    required double pct,
    required int max,
    required int floor,
  }) {
    final raw = (pct * max).floor();
    final aligned = raw - (raw % 256);
    final lifted = aligned < floor ? floor : aligned;
    return lifted > max ? max : lifted;
  }

  static ({ReasoningReplayPolicy policy, ReasoningReplayField field})
  _resolveReplay({
    required ModelGuess guess,
    required CatalogMatch? match,
    required VendorDefaults vendor,
    required Map<ModelSpecField, SpecSource> sources,
  }) {
    if (guess.replay != null) {
      sources[ModelSpecField.reasoningReplay] = SpecSource.guess;
      return (
        policy: guess.replay!,
        field: guess.replayField ?? ReasoningReplayField.reasoningContent,
      );
    }
    final interleaved = match?.model.interleavedField;
    if (interleaved == 'reasoning_content') {
      sources[ModelSpecField.reasoningReplay] = SpecSource.catalog;
      return (
        policy: ReasoningReplayPolicy.toolTurns,
        field: ReasoningReplayField.reasoningContent,
      );
    }
    if (interleaved == 'reasoning_details') {
      sources[ModelSpecField.reasoningReplay] = SpecSource.catalog;
      return (
        policy: ReasoningReplayPolicy.toolTurns,
        field: ReasoningReplayField.reasoningDetails,
      );
    }
    if (vendor.replay != null) {
      sources[ModelSpecField.reasoningReplay] = SpecSource.vendor;
      return (
        policy: vendor.replay!,
        field: vendor.replayField ?? ReasoningReplayField.reasoningContent,
      );
    }
    sources[ModelSpecField.reasoningReplay] = SpecSource.fallback;
    return (
      policy: ReasoningReplayPolicy.none,
      field: ReasoningReplayField.reasoningContent,
    );
  }

  static SamplingPolicy _resolveSampling({
    required CatalogMatch? match,
    required ModelGuess guess,
    required Map<ModelSpecField, SpecSource> sources,
  }) {
    if (match != null && match.model.temperature == false) {
      sources[ModelSpecField.sampling] = SpecSource.catalog;
      return SamplingPolicy.never;
    }
    if (guess.sampling != null) {
      sources[ModelSpecField.sampling] = SpecSource.guess;
      return guess.sampling!;
    }
    sources[ModelSpecField.sampling] = SpecSource.fallback;
    return SamplingPolicy.always;
  }

  static T _pick<T>({
    required T catalog,
    T? guess,
    required T fallback,
    required ModelSpecField field,
    required Map<ModelSpecField, SpecSource> sources,
  }) {
    if (catalog != null) {
      sources[field] = SpecSource.catalog;
      return catalog;
    }
    if (guess != null) {
      sources[field] = SpecSource.guess;
      return guess;
    }
    sources[field] = SpecSource.fallback;
    return fallback;
  }

  static ModelPricing? _resolvePricing({
    required CatalogMatch? match,
    required Map<ModelSpecField, SpecSource> sources,
  }) {
    final model = match?.model;
    if (model != null &&
        (model.costInput != null || model.costOutput != null)) {
      sources[ModelSpecField.pricing] = SpecSource.catalog;
      return ModelPricing(
        input: model.costInput,
        output: model.costOutput,
        cacheRead: model.costCacheRead,
        cacheWrite: model.costCacheWrite,
        currency: 'USD',
      );
    }
    sources[ModelSpecField.pricing] = SpecSource.fallback;
    return null;
  }

  static void _markOverrideSources(
    ModelSpecOverride ov,
    Map<ModelSpecField, SpecSource> sources,
  ) {
    if (ov.type != null) sources[ModelSpecField.type] = SpecSource.override;
    if (ov.input != null) sources[ModelSpecField.input] = SpecSource.override;
    if (ov.output != null) sources[ModelSpecField.output] = SpecSource.override;
    if (ov.abilities != null) {
      sources[ModelSpecField.abilities] = SpecSource.override;
    }
    if (ov.sampling != null) {
      sources[ModelSpecField.sampling] = SpecSource.override;
    }
    if (ov.contextWindow != null) {
      sources[ModelSpecField.contextWindow] = SpecSource.override;
    }
    if (ov.maxOutput != null) {
      sources[ModelSpecField.maxOutput] = SpecSource.override;
    }
    if (ov.pricing != null) {
      sources[ModelSpecField.pricing] = SpecSource.override;
    }
    if (ov.dynamicWebSearch != null) {
      sources[ModelSpecField.dynamicWebSearch] = SpecSource.override;
    }
    if (ov.remoteImageUrls != null) {
      sources[ModelSpecField.remoteImageUrls] = SpecSource.override;
    }
    if (ov.promptCacheControl != null) {
      sources[ModelSpecField.promptCacheControl] = SpecSource.override;
    }
    final reasoning = ov.reasoning;
    if (reasoning == null || reasoning.isEmpty) return;
    if (reasoning.dialect != null) {
      sources[ModelSpecField.reasoningDialect] = SpecSource.override;
    }
    if (reasoning.levels != null) {
      sources[ModelSpecField.reasoningLevels] = SpecSource.override;
    }
    if (reasoning.canDisable != null) {
      sources[ModelSpecField.reasoningCanDisable] = SpecSource.override;
    }
    if (reasoning.defaultLevel != null) {
      sources[ModelSpecField.reasoningDefaultLevel] = SpecSource.override;
    }
    if (reasoning.budgets != null) {
      sources[ModelSpecField.reasoningBudgets] = SpecSource.override;
    }
    if (reasoning.replay != null || reasoning.replayField != null) {
      sources[ModelSpecField.reasoningReplay] = SpecSource.override;
    }
  }
}
