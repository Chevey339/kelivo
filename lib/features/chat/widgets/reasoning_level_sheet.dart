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
import '../../../shared/widgets/custom_bottom_sheet.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../theme/app_font_weights.dart';

Future<void> showReasoningLevelSheet(
  BuildContext context, {
  required ProviderConfig config,
  required String modelId,
  Assistant? assistant,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showCustomBottomSheet<void>(
    context: context,
    title: l10n.reasoningLevelSheetTitle,
    builder: (context, controller) => ReasoningLevelPicker(
      config: config,
      modelId: modelId,
      assistant: assistant,
      scrollController: controller,
      compact: false,
    ),
  );
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

class ReasoningLevelPicker extends StatelessWidget {
  const ReasoningLevelPicker({
    super.key,
    required this.config,
    required this.modelId,
    this.assistant,
    this.scrollController,
    this.compact = false,
    this.onClose,
    this.onSuspendedChanged,
  });

  final ProviderConfig config;
  final String modelId;
  final Assistant? assistant;
  final ScrollController? scrollController;
  final bool compact;
  final Future<void> Function()? onClose;
  final ValueChanged<bool>? onSuspendedChanged;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final spec = ModelSpecResolver.instance.spec(config, modelId);
    if (!spec.supportsReasoning) {
      return _UnsupportedState(
        compact: compact,
        scrollController: scrollController,
      );
    }
    final snapshot = buildReasoningLevelPickerSnapshot(
      settings: settings,
      config: config,
      modelId: modelId,
      spec: spec,
      assistant: assistant,
    );
    return compact
        ? _CompactPicker(
            snapshot: snapshot,
            config: config,
            modelId: modelId,
            onClose: onClose,
            onSuspendedChanged: onSuspendedChanged,
          )
        : _SheetPicker(
            snapshot: snapshot,
            config: config,
            modelId: modelId,
            scrollController: scrollController,
          );
  }
}

class _UnsupportedState extends StatelessWidget {
  const _UnsupportedState({required this.compact, this.scrollController});

  final bool compact;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final body = Padding(
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
    if (scrollController == null) return body;
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      children: [body],
    );
  }
}

class _SheetPicker extends StatelessWidget {
  const _SheetPicker({
    required this.snapshot,
    required this.config,
    required this.modelId,
    this.scrollController,
  });

  final ReasoningLevelPickerSnapshot snapshot;
  final ProviderConfig config;
  final String modelId;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      children: [
        _SourceHeader(
          source: snapshot.source,
          showReset: snapshot.hasPerModelMemory,
          compact: false,
          onReset: () => _reset(context),
        ),
        const SizedBox(height: 8),
        for (final row in snapshot.rows) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SheetRow(
              row: row,
              selected: snapshot.isSelected(row),
              customBudget: snapshot.customSelected
                  ? snapshot.selected.budgetTokens
                  : null,
              onTap: () => _onRowTap(context, snapshot, row),
            ),
          ),
          if (row.kind == ReasoningLevelRowKind.auto &&
              snapshot.showCannotDisableHint)
            Padding(
              key: const ValueKey('reasoning-cannot-disable'),
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                l10n.reasoningLevelCannotDisable,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _reset(BuildContext context) {
    return context.read<SettingsProvider>().setReasoningChoice(
      config.id,
      modelId,
      null,
    );
  }

  Future<void> _onRowTap(
    BuildContext context,
    ReasoningLevelPickerSnapshot snapshot,
    ReasoningLevelRow row,
  ) async {
    Haptics.soft();
    if (row.kind == ReasoningLevelRowKind.custom) {
      await _pickCustomBudget(context, snapshot);
      return;
    }
    final request = row.request;
    if (request == null) return;
    await context.read<SettingsProvider>().setReasoningChoice(
      config.id,
      modelId,
      request,
    );
  }

  Future<void> _pickCustomBudget(
    BuildContext context,
    ReasoningLevelPickerSnapshot snapshot,
  ) async {
    final initial = snapshot.customSelected
        ? (snapshot.selected.budgetTokens ?? 2048)
        : 2048;
    final chosen = await ReasoningBudgetCustomDialog.show(
      context,
      initialValue: initial,
    );
    if (!context.mounted || chosen == null) return;
    await context.read<SettingsProvider>().setReasoningChoice(
      config.id,
      modelId,
      requestForCustomBudget(snapshot.spec, chosen),
    );
  }
}

class _CompactPicker extends StatelessWidget {
  const _CompactPicker({
    required this.snapshot,
    required this.config,
    required this.modelId,
    this.onClose,
    this.onSuspendedChanged,
  });

  final ReasoningLevelPickerSnapshot snapshot;
  final ProviderConfig config;
  final String modelId;
  final Future<void> Function()? onClose;
  final ValueChanged<bool>? onSuspendedChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 6),
              child: _SourceHeader(
                source: snapshot.source,
                showReset: snapshot.hasPerModelMemory,
                compact: true,
                onReset: () => _reset(context),
              ),
            ),
            for (final row in snapshot.rows) ...[
              _CompactRow(
                row: row,
                selected: snapshot.isSelected(row),
                customBudget: snapshot.customSelected
                    ? snapshot.selected.budgetTokens
                    : null,
                onTap: () => _onRowTap(context, snapshot, row),
              ),
              if (row.kind == ReasoningLevelRowKind.auto &&
                  snapshot.showCannotDisableHint)
                Padding(
                  key: const ValueKey('reasoning-cannot-disable'),
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.reasoningLevelCannotDisable,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.55),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _reset(BuildContext context) {
    return context.read<SettingsProvider>().setReasoningChoice(
      config.id,
      modelId,
      null,
    );
  }

  Future<void> _onRowTap(
    BuildContext context,
    ReasoningLevelPickerSnapshot snapshot,
    ReasoningLevelRow row,
  ) async {
    if (row.kind == ReasoningLevelRowKind.custom) {
      await _pickCustomBudget(context, snapshot);
      return;
    }
    final request = row.request;
    if (request == null) return;
    await context.read<SettingsProvider>().setReasoningChoice(
      config.id,
      modelId,
      request,
    );
    if (!context.mounted) return;
    await onClose?.call();
  }

  Future<void> _pickCustomBudget(
    BuildContext context,
    ReasoningLevelPickerSnapshot snapshot,
  ) async {
    final initial = snapshot.customSelected
        ? (snapshot.selected.budgetTokens ?? 2048)
        : 2048;
    onSuspendedChanged?.call(true);
    var restore = true;
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
      await onClose?.call();
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

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.row,
    required this.selected,
    required this.onTap,
    this.customBudget,
  });

  final ReasoningLevelRow row;
  final bool selected;
  final VoidCallback onTap;
  final int? customBudget;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final onColor = selected ? cs.primary : cs.onSurface;
    final subtitle = _subtitle(l10n);
    final trailing = _trailingText();
    return SizedBox(
      key: ValueKey(row.key),
      height: subtitle == null ? 48 : 56,
      child: IosCardPress(
        borderRadius: BorderRadius.circular(14),
        baseColor: sheetTileColor(context),
        duration: const Duration(milliseconds: 260),
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _leading(onColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: subtitle == null
                  ? Text(
                      _title(l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: AppFontWeights.medium,
                        color: onColor,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title(l10n),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: AppFontWeights.medium,
                            color: onColor,
                          ),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
            ),
            if (trailing != null) ...[
              Text(
                trailing,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: AppFontWeights.semibold,
                  color: selected
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (row.kind == ReasoningLevelRowKind.custom && !selected)
              Icon(
                Lucide.ChevronRight,
                size: 18,
                color: cs.onSurface.withValues(alpha: 0.45),
              )
            else if (selected)
              Icon(Lucide.Check, size: 18, color: cs.primary)
            else
              const SizedBox(width: 18),
          ],
        ),
      ),
    );
  }

  String _title(AppLocalizations l10n) {
    if (row.kind == ReasoningLevelRowKind.custom) {
      return l10n.reasoningLevelCustomBudget;
    }
    return reasoningLevelLabel(l10n, row.level ?? ReasoningLevel.auto);
  }

  String? _subtitle(AppLocalizations l10n) {
    return switch (row.kind) {
      ReasoningLevelRowKind.auto => l10n.reasoningLevelAutoSubtitle,
      ReasoningLevelRowKind.off => l10n.reasoningLevelOffSubtitle,
      _ => null,
    };
  }

  String? _trailingText() {
    if (row.kind == ReasoningLevelRowKind.custom) {
      return customBudget?.toString();
    }
    return row.budget?.toString();
  }

  Widget _leading(Color color, {required double size}) {
    if (row.kind == ReasoningLevelRowKind.custom) {
      return Icon(Lucide.Hash, size: size, color: color);
    }
    return ReasoningIcons.levelIcon(
      row.level ?? ReasoningLevel.auto,
      size: size,
      color: color,
    );
  }
}

class _CompactRow extends StatefulWidget {
  const _CompactRow({
    required this.row,
    required this.selected,
    required this.onTap,
    this.customBudget,
  });

  final ReasoningLevelRow row;
  final bool selected;
  final VoidCallback onTap;
  final int? customBudget;

  @override
  State<_CompactRow> createState() => _CompactRowState();
}

class _CompactRowState extends State<_CompactRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final active = widget.selected;
    final onColor = active ? cs.primary : cs.onSurface;
    final trailing = _trailingText();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            key: ValueKey(widget.row.key),
            duration: const Duration(milliseconds: 120),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _hovered
                  ? cs.onSurface.withValues(alpha: isDark ? 0.12 : 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Center(child: _leading(onColor)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _title(l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: AppFontWeights.regular,
                      color: onColor,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    trailing,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: AppFontWeights.semibold,
                      color: active
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.55),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
                if (widget.row.kind == ReasoningLevelRowKind.custom &&
                    !active) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Lucide.ChevronRight,
                    size: 16,
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ),
                ],
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: active
                      ? Icon(
                          Lucide.Check,
                          key: const ValueKey('check'),
                          size: 16,
                          color: cs.primary,
                        )
                      : const SizedBox(width: 16, key: ValueKey('space')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _title(AppLocalizations l10n) {
    if (widget.row.kind == ReasoningLevelRowKind.custom) {
      return l10n.reasoningLevelCustomBudget;
    }
    return reasoningLevelLabel(l10n, widget.row.level ?? ReasoningLevel.auto);
  }

  String? _trailingText() {
    if (widget.row.kind == ReasoningLevelRowKind.custom) {
      return widget.customBudget?.toString();
    }
    return widget.row.budget?.toString();
  }

  Widget _leading(Color color) {
    if (widget.row.kind == ReasoningLevelRowKind.custom) {
      return Icon(Lucide.Hash, size: 16, color: color);
    }
    return ReasoningIcons.levelIcon(
      widget.row.level ?? ReasoningLevel.auto,
      size: 16,
      color: color,
    );
  }
}
