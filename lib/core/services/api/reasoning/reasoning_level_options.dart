import 'package:flutter/foundation.dart';

import '../../../models/assistant.dart';
import '../../../models/model_spec.dart';
import '../../../providers/settings_provider.dart';
import '../../model_spec/model_spec_resolver.dart';
import 'reasoning_dialects.dart';
import 'reasoning_selection.dart';

enum ReasoningChoiceSource { perModel, assistant, modelDefault }

enum ReasoningLevelRowKind { auto, off, level, custom }

@immutable
class ReasoningLevelRow {
  const ReasoningLevelRow({
    required this.kind,
    required this.key,
    this.level,
    this.request,
    this.budget,
  });

  final ReasoningLevelRowKind kind;
  final String key;
  final ReasoningLevel? level;
  final ReasoningRequest? request;
  final int? budget;
}

@immutable
class ReasoningLevelPickerSnapshot {
  const ReasoningLevelPickerSnapshot({
    required this.spec,
    required this.selected,
    required this.source,
    required this.hasPerModelMemory,
    required this.isBudgetStyle,
    required this.customSelected,
    required this.rows,
  });

  final ModelSpec spec;
  final ReasoningRequest selected;
  final ReasoningChoiceSource source;
  final bool hasPerModelMemory;
  final bool isBudgetStyle;
  final bool customSelected;
  final List<ReasoningLevelRow> rows;

  ReasoningLevel get effectiveLevel =>
      resolveReasoning(spec, selected).effective;

  bool isSelected(ReasoningLevelRow row) {
    if (row.kind == ReasoningLevelRowKind.custom) return customSelected;
    if (customSelected) return false;
    return effectiveLevel == row.level;
  }

  /// Slider / popover stops in the original order: Off → Auto → levels.
  List<ReasoningLevelRow> get sliderStops {
    final off = <ReasoningLevelRow>[];
    final auto = <ReasoningLevelRow>[];
    final levels = <ReasoningLevelRow>[];
    for (final row in rows) {
      switch (row.kind) {
        case ReasoningLevelRowKind.off:
          off.add(row);
        case ReasoningLevelRowKind.auto:
          auto.add(row);
        case ReasoningLevelRowKind.level:
          levels.add(row);
        case ReasoningLevelRowKind.custom:
          break;
      }
    }
    return [...off, ...auto, ...levels];
  }

  int get sliderIndex {
    final stops = sliderStops;
    if (stops.isEmpty) return 0;
    if (customSelected && selected.budgetTokens != null) {
      final nearest = levelForCustomBudget(spec, selected.budgetTokens!);
      final index = stops.indexWhere((row) => row.level == nearest);
      return index >= 0 ? index : 0;
    }
    final index = stops.indexWhere((row) => row.level == effectiveLevel);
    return index >= 0 ? index : 0;
  }
}

/// Budget-style pickers show trailing token counts and a custom-budget row.
///
/// `openrouterReasoning` is budget-style only when the spec has no effort
/// levels; with levels it behaves like an effort dialect.
bool isBudgetStylePicker(ReasoningSpec spec) {
  if (spec.dialect == ReasoningDialect.openrouterReasoning) {
    return spec.levels.isEmpty;
  }
  return isBudgetDialect(spec.dialect);
}

bool isCustomBudgetSelection(ModelSpec spec, ReasoningRequest request) {
  if (request.budgetTokens == null) return false;
  if (request.level == ReasoningLevel.auto ||
      request.level == ReasoningLevel.off) {
    return false;
  }
  return request.budgetTokens != resolveBudget(spec, request.level);
}

ReasoningChoiceSource reasoningChoiceSource({
  required SettingsProvider settings,
  required ProviderConfig config,
  required String modelId,
  Assistant? assistant,
}) {
  if (settings.reasoningChoiceFor(config.id, modelId) != null) {
    return ReasoningChoiceSource.perModel;
  }
  if (assistant?.reasoning != null) {
    return ReasoningChoiceSource.assistant;
  }
  return ReasoningChoiceSource.modelDefault;
}

ReasoningLevel levelForCustomBudget(ModelSpec spec, int budget) {
  final levels = spec.reasoning.levels.isNotEmpty
      ? spec.reasoning.levels
      : const <ReasoningLevel>[
          ReasoningLevel.minimal,
          ReasoningLevel.low,
          ReasoningLevel.medium,
          ReasoningLevel.high,
          ReasoningLevel.xhigh,
          ReasoningLevel.max,
        ];
  var best = levels.first;
  var bestDist = ((resolveBudget(spec, best) ?? 0) - budget).abs();
  for (final level in levels.skip(1)) {
    final resolved = resolveBudget(spec, level) ?? 0;
    final dist = (resolved - budget).abs();
    if (dist < bestDist || (dist == bestDist && level.index < best.index)) {
      best = level;
      bestDist = dist;
    }
  }
  return best;
}

ReasoningRequest requestForCustomBudget(ModelSpec spec, int budget) {
  return ReasoningRequest(
    levelForCustomBudget(spec, budget),
    budgetTokens: budget,
  );
}

/// Writes a per-model override, or clears it when [request] matches the
/// assistant / spec fallback (so the button shows the inherited value).
Future<void> commitReasoningChoice(
  SettingsProvider settings,
  ProviderConfig config,
  String modelId,
  Assistant? assistant,
  ReasoningRequest request,
) {
  final spec = ModelSpecResolver.instance.spec(config, modelId);
  final fallback =
      assistant?.reasoning ?? ReasoningRequest(spec.reasoning.defaultLevel);
  return settings.setReasoningChoice(
    config.id,
    modelId,
    request == fallback ? null : request,
  );
}

String formatReasoningBudgetK(int tokens) {
  if (tokens.abs() < 1000) return tokens.toString();
  if (tokens % 1000 == 0) return '${tokens ~/ 1000}k';
  final k = tokens / 1000;
  return '${k.toStringAsFixed(1)}k';
}

ReasoningLevelPickerSnapshot buildReasoningLevelPickerSnapshot({
  required SettingsProvider settings,
  required ProviderConfig config,
  required String modelId,
  required ModelSpec spec,
  Assistant? assistant,
}) {
  final selected = selectReasoningRequest(
    settings: settings,
    config: config,
    modelId: modelId,
    assistant: assistant,
  );
  final budgetStyle = isBudgetStylePicker(spec.reasoning);
  final customSelected = isCustomBudgetSelection(spec, selected);
  final rows = <ReasoningLevelRow>[
    if (spec.reasoning.canDisable)
      const ReasoningLevelRow(
        kind: ReasoningLevelRowKind.off,
        key: 'reasoning-stop-off',
        level: ReasoningLevel.off,
        request: ReasoningRequest.off,
      ),
    const ReasoningLevelRow(
      kind: ReasoningLevelRowKind.auto,
      key: 'reasoning-stop-auto',
      level: ReasoningLevel.auto,
      request: ReasoningRequest.auto,
    ),
    for (final level in spec.reasoning.levels)
      ReasoningLevelRow(
        kind: ReasoningLevelRowKind.level,
        key: 'reasoning-stop-${level.name}',
        level: level,
        request: ReasoningRequest(level),
        budget: budgetStyle ? resolveBudget(spec, level) : null,
      ),
    if (budgetStyle)
      const ReasoningLevelRow(
        kind: ReasoningLevelRowKind.custom,
        key: 'reasoning-row-custom',
      ),
  ];
  return ReasoningLevelPickerSnapshot(
    spec: spec,
    selected: selected,
    source: reasoningChoiceSource(
      settings: settings,
      config: config,
      modelId: modelId,
      assistant: assistant,
    ),
    hasPerModelMemory: settings.reasoningChoiceFor(config.id, modelId) != null,
    isBudgetStyle: budgetStyle,
    customSelected: customSelected,
    rows: rows,
  );
}

@immutable
class ReasoningButtonPresentation {
  const ReasoningButtonPresentation({
    required this.level,
    required this.dimmed,
    this.compactLabel,
  });

  final ReasoningLevel level;
  final bool dimmed;
  final String? compactLabel;
}

ReasoningButtonPresentation reasoningButtonPresentation({
  required ModelSpec spec,
  required ReasoningRequest request,
  required String Function(ReasoningLevel level) compactLevelLabel,
}) {
  if (request.level == ReasoningLevel.off) {
    return const ReasoningButtonPresentation(
      level: ReasoningLevel.off,
      dimmed: true,
    );
  }
  if (request.level == ReasoningLevel.auto) {
    return const ReasoningButtonPresentation(
      level: ReasoningLevel.auto,
      dimmed: false,
    );
  }
  final custom = isCustomBudgetSelection(spec, request);
  final label = custom && request.budgetTokens != null
      ? formatReasoningBudgetK(request.budgetTokens!)
      : compactLevelLabel(request.level);
  return ReasoningButtonPresentation(
    level: request.level,
    dimmed: false,
    compactLabel: label,
  );
}
