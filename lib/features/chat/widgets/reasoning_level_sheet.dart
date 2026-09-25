import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/assistant.dart';
import '../../../core/models/model_spec.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/api/reasoning/reasoning_level_options.dart';
import '../../../core/services/haptics.dart';
import '../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../icons/reasoning_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/dialogs/reasoning_budget_custom_dialog.dart';
import '../../../shared/widgets/effort_slider.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';

Future<void> showReasoningLevelSheet(
  BuildContext context, {
  required ProviderConfig config,
  required String modelId,
  Assistant? assistant,
}) {
  return showReasoningPickerSheet<void>(
    context: context,
    builder: (context) => ReasoningLevelPicker(
      config: config,
      modelId: modelId,
      assistant: assistant,
    ),
  );
}

/// Plain content-sized mobile sheet: handle + child, no title or close.
Future<T?> showReasoningPickerSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.overlaySurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ReasoningPickerSheet(child: builder(ctx)),
  );
}

class ReasoningPickerSheet extends StatelessWidget {
  const ReasoningPickerSheet({super.key, required this.child});

  static const panelKey = ValueKey<String>('reasoning_picker_sheet_panel');

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          key: panelKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

String reasoningLevelLabel(AppLocalizations l10n, ReasoningLevel level) {
  return switch (level) {
    ReasoningLevel.auto => l10n.reasoningLevelAuto,
    ReasoningLevel.off => l10n.reasoningLevelOff,
    ReasoningLevel.minimal => l10n.reasoningLevelMinimal,
    ReasoningLevel.low => l10n.reasoningLevelLow,
    ReasoningLevel.medium => l10n.reasoningLevelMedium,
    ReasoningLevel.high => l10n.reasoningLevelHigh,
    ReasoningLevel.xhigh => l10n.reasoningLevelXhigh,
    ReasoningLevel.max => l10n.reasoningLevelMax,
  };
}

String reasoningLevelCompactLabel(AppLocalizations l10n, ReasoningLevel level) {
  return switch (level) {
    ReasoningLevel.auto => l10n.reasoningLevelAuto,
    ReasoningLevel.off => l10n.reasoningLevelOff,
    ReasoningLevel.minimal => l10n.reasoningLevelCompactMin,
    ReasoningLevel.low => l10n.reasoningLevelCompactLow,
    ReasoningLevel.medium => l10n.reasoningLevelCompactMid,
    ReasoningLevel.high => l10n.reasoningLevelCompactHigh,
    ReasoningLevel.xhigh => l10n.reasoningLevelCompactXhigh,
    ReasoningLevel.max => l10n.reasoningLevelCompactMax,
  };
}

String reasoningLevelEffortSubtitle(
  AppLocalizations l10n,
  ReasoningLevel level,
) {
  return switch (level) {
    ReasoningLevel.auto => l10n.reasoningLevelAutoSubtitle,
    ReasoningLevel.off => l10n.reasoningLevelOffSubtitle,
    ReasoningLevel.minimal => l10n.reasoningLevelMinimalSubtitle,
    ReasoningLevel.low => l10n.reasoningLevelLowSubtitle,
    ReasoningLevel.medium => l10n.reasoningLevelMediumSubtitle,
    ReasoningLevel.high => l10n.reasoningLevelHighSubtitle,
    ReasoningLevel.xhigh => l10n.reasoningLevelXhighSubtitle,
    ReasoningLevel.max => l10n.reasoningLevelMaxSubtitle,
  };
}

String? reasoningLevelStopSubtitle(
  AppLocalizations l10n,
  ReasoningLevelPickerSnapshot snapshot,
  ReasoningLevelRow row,
) {
  return switch (row.kind) {
    ReasoningLevelRowKind.auto => l10n.reasoningLevelAutoSubtitle,
    ReasoningLevelRowKind.off => l10n.reasoningLevelOffSubtitle,
    ReasoningLevelRowKind.level
        when snapshot.isBudgetStyle && row.budget != null =>
      l10n.reasoningLevelBudgetTokens(formatReasoningBudgetK(row.budget!)),
    ReasoningLevelRowKind.level when row.level != null =>
      reasoningLevelEffortSubtitle(l10n, row.level!),
    _ => null,
  };
}

class ReasoningLevelPicker extends StatelessWidget {
  const ReasoningLevelPicker({
    super.key,
    required this.config,
    required this.modelId,
    this.assistant,
  });

  final ProviderConfig config;
  final String modelId;
  final Assistant? assistant;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final spec = ModelSpecResolver.instance.spec(config, modelId);
    if (!spec.supportsReasoning) {
      return const _UnsupportedState();
    }
    final snapshot = buildReasoningLevelPickerSnapshot(
      settings: settings,
      config: config,
      modelId: modelId,
      spec: spec,
      assistant: assistant,
    );
    if (snapshot.sliderStops.isEmpty) {
      return const _UnsupportedState();
    }
    return _SliderPicker(
      snapshot: snapshot,
      config: config,
      modelId: modelId,
      assistant: assistant,
    );
  }
}

class _UnsupportedState extends StatelessWidget {
  const _UnsupportedState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey('reasoning-unsupported'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Text(
        l10n.reasoningLevelNoReasoning,
        style: TextStyle(
          fontSize: 14,
          color: cs.onSurface.withValues(alpha: 0.62),
        ),
      ),
    );
  }
}

class _SliderPicker extends StatelessWidget {
  const _SliderPicker({
    required this.snapshot,
    required this.config,
    required this.modelId,
    this.assistant,
  });

  final ReasoningLevelPickerSnapshot snapshot;
  final ProviderConfig config;
  final String modelId;
  final Assistant? assistant;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final stops = snapshot.sliderStops;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EffortSliderGroup(
          selectedIndex: snapshot.sliderIndex,
          customSelected: snapshot.customSelected,
          customIcon: Icon(Lucide.Hash, size: 18, color: cs.primary),
          customIconKey: 'custom',
          customTitle: l10n.reasoningLevelCustomBudget,
          customSubtitle: snapshot.selected.budgetTokens?.toString(),
          onCommit: (index) => _commitStop(context, stops[index]),
          stops: [
            for (final stop in stops)
              EffortSliderStop(
                stopKey: stop.key,
                icon: ReasoningIcons.levelIcon(
                  stop.level ?? ReasoningLevel.auto,
                  size: 18,
                  color: cs.primary,
                ),
                iconKey: stop.level ?? ReasoningLevel.auto,
                title: reasoningLevelLabel(
                  l10n,
                  stop.level ?? ReasoningLevel.auto,
                ),
                subtitle: reasoningLevelStopSubtitle(l10n, snapshot, stop),
              ),
          ],
        ),
        if (snapshot.isBudgetStyle) ...[
          const SizedBox(height: 20),
          _CustomBudgetRow(
            selected: snapshot.customSelected,
            budget: snapshot.customSelected
                ? snapshot.selected.budgetTokens
                : null,
            onTap: () => _pickCustomBudget(context),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _commitStop(BuildContext context, ReasoningLevelRow row) async {
    final request = row.request;
    if (request == null) return;
    await commitReasoningChoice(
      context.read<SettingsProvider>(),
      config,
      modelId,
      assistant,
      request,
    );
  }

  Future<void> _pickCustomBudget(BuildContext context) async {
    Haptics.light();
    final initial = snapshot.customSelected
        ? (snapshot.selected.budgetTokens ?? 2048)
        : 2048;
    final chosen = await ReasoningBudgetCustomDialog.show(
      context,
      initialValue: initial,
    );
    if (!context.mounted || chosen == null) return;
    await commitReasoningChoice(
      context.read<SettingsProvider>(),
      config,
      modelId,
      assistant,
      requestForCustomBudget(snapshot.spec, chosen),
    );
  }
}

class _CustomBudgetRow extends StatelessWidget {
  const _CustomBudgetRow({
    required this.selected,
    required this.onTap,
    this.budget,
  });

  final bool selected;
  final VoidCallback onTap;
  final int? budget;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        key: const ValueKey('reasoning-row-custom'),
        height: 48,
        child: IosCardPress(
          borderRadius: BorderRadius.circular(14),
          baseColor: sheetTileColor(context),
          duration: const Duration(milliseconds: 260),
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                Lucide.Hash,
                size: 20,
                color: selected
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.reasoningLevelCustomBudget,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: AppFontWeights.medium,
                    color: selected ? cs.primary : cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selected && budget != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      budget.toString(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: AppFontWeights.semibold,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Lucide.Check, size: 18, color: cs.primary),
                  ],
                )
              else
                Icon(
                  Lucide.ChevronRight,
                  size: 18,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
