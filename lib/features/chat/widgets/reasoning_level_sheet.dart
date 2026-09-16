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
  final l10n = AppLocalizations.of(context)!;
  return showReasoningPickerSheet<void>(
    context: context,
    title: l10n.reasoningLevelSheetTitle,
    builder: (context) => ReasoningLevelPicker(
      config: config,
      modelId: modelId,
      assistant: assistant,
    ),
  );
}

/// Content-sized mobile sheet for the reasoning pickers.
///
/// Matches the app's other mobile sheets (radius 20, handle, overlay
/// surface) but wraps its child instead of locking to a 60 % partial height.
Future<T?> showReasoningPickerSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.overlaySurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ReasoningPickerSheet(title: title, child: builder(ctx)),
  );
}

class ReasoningPickerSheet extends StatelessWidget {
  const ReasoningPickerSheet({
    super.key,
    required this.title,
    required this.child,
  });

  static const panelKey = ValueKey<String>('reasoning_picker_sheet_panel');
  static const closeButtonKey = ValueKey<String>(
    'reasoning_picker_sheet_close_button',
  );
  static const double maxHeightFactor = 0.85;

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * maxHeightFactor;
    final titleStyle = TextStyle(
      color: cs.onSurface,
      fontSize: 15,
      fontWeight: AppFontWeights.emphasis,
      height: 1.2,
    );

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        key: panelKey,
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            SizedBox(
              height: 30,
              child: Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ),
                  SizedBox(
                    key: closeButtonKey,
                    width: 24,
                    height: 24,
                    child: Tooltip(
                      message:
                          l10n?.commonClose ??
                          MaterialLocalizations.of(context).closeButtonTooltip,
                      child: IosIconButton(
                        icon: Lucide.X,
                        size: 20,
                        padding: EdgeInsets.zero,
                        color: cs.onSurface.withValues(alpha: 0.62),
                        semanticLabel: l10n?.commonClose,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

String reasoningChoiceSourceLabel(
  AppLocalizations l10n,
  ReasoningChoiceSource source,
) {
  return switch (source) {
    ReasoningChoiceSource.perModel => l10n.reasoningLevelSourcePerModel,
    ReasoningChoiceSource.assistant => l10n.reasoningLevelSourceAssistant,
    ReasoningChoiceSource.modelDefault => l10n.reasoningLevelSourceModelDefault,
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
    _ => null,
  };
}

class ReasoningLevelPicker extends StatelessWidget {
  const ReasoningLevelPicker({
    super.key,
    required this.config,
    required this.modelId,
    this.assistant,
    this.compact = false,
    this.onClose,
    this.onSuspendedChanged,
  });

  final ProviderConfig config;
  final String modelId;
  final Assistant? assistant;
  final bool compact;
  final Future<void> Function()? onClose;
  final ValueChanged<bool>? onSuspendedChanged;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final spec = ModelSpecResolver.instance.spec(config, modelId);
    if (!spec.supportsReasoning) {
      return _UnsupportedState(compact: compact);
    }
    final snapshot = buildReasoningLevelPickerSnapshot(
      settings: settings,
      config: config,
      modelId: modelId,
      spec: spec,
      assistant: assistant,
    );
    return _SliderPicker(
      snapshot: snapshot,
      config: config,
      modelId: modelId,
      compact: compact,
      onClose: onClose,
      onSuspendedChanged: onSuspendedChanged,
    );
  }
}

class _UnsupportedState extends StatelessWidget {
  const _UnsupportedState({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey('reasoning-unsupported'),
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 20,
        12,
        compact ? 16 : 20,
        20,
      ),
      child: Text(
        l10n.reasoningLevelNoReasoning,
        style: TextStyle(
          fontSize: compact ? 13 : 14,
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
    required this.compact,
    this.onClose,
    this.onSuspendedChanged,
  });

  final ReasoningLevelPickerSnapshot snapshot;
  final ProviderConfig config;
  final String modelId;
  final bool compact;
  final Future<void> Function()? onClose;
  final ValueChanged<bool>? onSuspendedChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final stops = snapshot.sliderStops;
    final children = <Widget>[
      Padding(
        padding: EdgeInsets.fromLTRB(compact ? 20 : 0, 0, compact ? 12 : 0, 6),
        child: _SourceHeader(
          source: snapshot.source,
          showReset: snapshot.hasPerModelMemory,
          compact: compact,
          onReset: () => _reset(context),
        ),
      ),
      if (stops.isNotEmpty)
        EffortSliderGroup(
          selectedIndex: snapshot.sliderIndex,
          customSelected: snapshot.customSelected,
          stopCount: stops.length,
          stopKeys: [for (final stop in stops) stop.key],
          stopLabels: [
            for (final stop in stops)
              reasoningLevelLabel(l10n, stop.level ?? ReasoningLevel.auto),
          ],
          padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 28),
          semanticsValue: (index) {
            if (snapshot.customSelected) {
              return l10n.reasoningLevelCustomBudget;
            }
            final stop = stops[index.clamp(0, stops.length - 1)];
            return reasoningLevelLabel(l10n, stop.level ?? ReasoningLevel.auto);
          },
          onCommit: (index) => _commitStop(context, stops[index]),
          header: (context, visualIndex) {
            if (snapshot.customSelected) {
              return EffortSliderActiveStop(
                icon: Icon(Lucide.Hash, size: 18, color: cs.primary),
                iconKey: 'custom',
                title: l10n.reasoningLevelCustomBudget,
                subtitle: snapshot.selected.budgetTokens?.toString(),
              );
            }
            final stop = stops[visualIndex.clamp(0, stops.length - 1)];
            final level = stop.level ?? ReasoningLevel.auto;
            return EffortSliderActiveStop(
              icon: ReasoningIcons.levelIcon(
                level,
                size: 18,
                color: cs.primary,
              ),
              iconKey: level,
              title: reasoningLevelLabel(l10n, level),
              subtitle: reasoningLevelStopSubtitle(l10n, snapshot, stop),
            );
          },
        ),
      if (snapshot.showCannotDisableHint)
        Padding(
          key: const ValueKey('reasoning-cannot-disable'),
          padding: EdgeInsets.fromLTRB(
            compact ? 20 : 4,
            12,
            compact ? 20 : 4,
            0,
          ),
          child: Text(
            l10n.reasoningLevelCannotDisable,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              color: cs.onSurface.withValues(alpha: 0.55),
              decoration: TextDecoration.none,
            ),
          ),
        ),
      if (snapshot.isBudgetStyle) ...[
        const SizedBox(height: 20),
        _CustomBudgetRow(
          compact: compact,
          selected: snapshot.customSelected,
          budget: snapshot.customSelected
              ? snapshot.selected.budgetTokens
              : null,
          onTap: () => _pickCustomBudget(context),
        ),
      ],
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 0 : 16, 10, compact ? 0 : 16, 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Future<void> _reset(BuildContext context) {
    return context.read<SettingsProvider>().setReasoningChoice(
      config.id,
      modelId,
      null,
    );
  }

  Future<void> _commitStop(BuildContext context, ReasoningLevelRow row) async {
    final request = row.request;
    if (request == null) return;
    await context.read<SettingsProvider>().setReasoningChoice(
      config.id,
      modelId,
      request,
    );
  }

  Future<void> _pickCustomBudget(BuildContext context) async {
    if (!compact) Haptics.light();
    final initial = snapshot.customSelected
        ? (snapshot.selected.budgetTokens ?? 2048)
        : 2048;
    if (compact) onSuspendedChanged?.call(true);
    var restore = compact;
    try {
      final chosen = await ReasoningBudgetCustomDialog.show(
        context,
        initialValue: initial,
      );
      if (!context.mounted || chosen == null) return;
      restore = false;
      await context.read<SettingsProvider>().setReasoningChoice(
        config.id,
        modelId,
        requestForCustomBudget(snapshot.spec, chosen),
      );
      if (!context.mounted) return;
      if (compact) await onClose?.call();
    } finally {
      if (restore && context.mounted) onSuspendedChanged?.call(false);
    }
  }
}

class _SourceHeader extends StatelessWidget {
  const _SourceHeader({
    required this.source,
    required this.showReset,
    required this.compact,
    required this.onReset,
  });

  final ReasoningChoiceSource source;
  final bool showReset;
  final bool compact;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            reasoningChoiceSourceLabel(l10n, source),
            key: const ValueKey('reasoning-source'),
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              color: cs.onSurface.withValues(alpha: 0.55),
              decoration: TextDecoration.none,
            ),
          ),
        ),
        if (showReset)
          IosCardPress(
            key: const ValueKey('reasoning-reset'),
            borderRadius: BorderRadius.circular(10),
            baseColor: Colors.transparent,
            onTap: () {
              if (!compact) Haptics.soft();
              onReset();
            },
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: compact ? 4 : 6,
            ),
            child: Text(
              l10n.reasoningLevelReset,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: AppFontWeights.medium,
                color: cs.primary,
                decoration: TextDecoration.none,
              ),
            ),
          ),
      ],
    );
  }
}

class _CustomBudgetRow extends StatelessWidget {
  const _CustomBudgetRow({
    required this.compact,
    required this.selected,
    required this.onTap,
    this.budget,
  });

  final bool compact;
  final bool selected;
  final VoidCallback onTap;
  final int? budget;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final onColor = selected ? cs.primary : cs.onSurface;
    final row = SizedBox(
      key: const ValueKey('reasoning-row-custom'),
      height: compact ? 40 : 48,
      child: IosCardPress(
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        baseColor: compact ? Colors.transparent : sheetTileColor(context),
        duration: const Duration(milliseconds: 260),
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(
              Lucide.Hash,
              size: compact ? 16 : 20,
              color: selected
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.reasoningLevelCustomBudget,
                style: TextStyle(
                  fontSize: compact ? 13 : 15,
                  fontWeight: compact
                      ? AppFontWeights.regular
                      : AppFontWeights.medium,
                  color: onColor,
                  decoration: TextDecoration.none,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selected && budget != null) ...[
              Text(
                budget.toString(),
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  fontWeight: AppFontWeights.semibold,
                  color: cs.primary,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Lucide.Check, size: compact ? 16 : 18, color: cs.primary),
            ] else
              Icon(
                Lucide.ChevronRight,
                size: compact ? 16 : 18,
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
          ],
        ),
      ),
    );
    if (!compact) return row;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: row,
    );
  }
}
