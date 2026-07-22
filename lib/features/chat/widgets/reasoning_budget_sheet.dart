import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../icons/reasoning_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/dialogs/reasoning_budget_custom_dialog.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../core/services/haptics.dart';
import 'package:KelivoDev/theme/app_font_weights.dart';

Future<void> showReasoningBudgetSheet(
  BuildContext context, {
  String? modelProvider,
  String? modelId,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) =>
        _ReasoningBudgetSheet(modelProvider: modelProvider, modelId: modelId),
  );
}

class _ReasoningBudgetSheet extends StatefulWidget {
  const _ReasoningBudgetSheet({this.modelProvider, this.modelId});
  final String? modelProvider;
  final String? modelId;
  @override
  State<_ReasoningBudgetSheet> createState() => _ReasoningBudgetSheetState();
}

class _ReasoningBudgetSheetState extends State<_ReasoningBudgetSheet> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsProvider>();
    _selected = s.thinkingBudget ?? -1;
  }

  Future<void> _select(int value) async {
    setState(() {
      _selected = value;
    });
    await context.read<SettingsProvider>().setThinkingBudget(value);
  }

  bool _isCustomSelected({required bool showXhigh, required bool showMax}) {
    final presets = <int>{
      -1, // auto
      0, // off
      1024,
      16000,
      32000,
      if (showXhigh) 64000,
      if (showMax) 128000,
    };
    return !presets.contains(_selected);
  }

  Future<void> _openCustomBudget() async {
    Haptics.light();
    final settings = context.read<SettingsProvider>();
    final isCurrentCustom = _isCustomSelected(
      showXhigh: _showXhighOption(settings),
      showMax: _showMaxOption(settings),
    );
    final initialValue = isCurrentCustom ? _selected : 2048;
    final chosen = await ReasoningBudgetCustomDialog.show(
      context,
      initialValue: initialValue,
    );
    if (!mounted || chosen == null) return;
    await _select(chosen);
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Widget _tile(
    String title,
    int value, {
    IconData? icon,
    Widget? leading,
    required bool active,
    Future<void> Function()? onTap,
    Widget? trailing,
  }) {
    final cs = Theme.of(context).colorScheme;
    final Color iconColor = active
        ? cs.primary
        : cs.onSurface.withValues(alpha: 0.7);
    final Color onColor = active ? cs.primary : cs.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SizedBox(
        height: 48,
        child: IosCardPress(
          borderRadius: BorderRadius.circular(14),
          baseColor: cs.surface,
          duration: const Duration(milliseconds: 260),
          onTap: () async {
            if (onTap != null) {
              await onTap();
              return;
            }
            Haptics.light();
            await _select(value);
            if (!mounted) return;
            Navigator.of(context).maybePop();
          },
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              leading ?? Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: AppFontWeights.medium,
                    color: onColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              trailing ??
                  (active
                      ? Icon(Lucide.Check, size: 18, color: cs.primary)
                      : const SizedBox(width: 18)),
            ],
          ),
        ),
      ),
    );
  }

  bool _showXhighOption(SettingsProvider settings) {
    final assistant = context.read<AssistantProvider>().currentAssistant;
    final currentProvider =
        widget.modelProvider ??
        assistant?.chatModelProvider ??
        settings.currentModelProvider;
    final currentModelId =
        widget.modelId ?? assistant?.chatModelId ?? settings.currentModelId;
    if (currentProvider == null || currentModelId == null) return false;
    return settings.supportsXhighReasoning(currentProvider, currentModelId);
  }

  bool _showMaxOption(SettingsProvider settings) {
    final assistant = context.read<AssistantProvider>().currentAssistant;
    final currentProvider =
        widget.modelProvider ??
        assistant?.chatModelProvider ??
        settings.currentModelProvider;
    final currentModelId =
        widget.modelId ?? assistant?.chatModelId ?? settings.currentModelId;
    if (currentProvider == null || currentModelId == null) return false;
    return settings.supportsMaxReasoning(currentProvider, currentModelId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final showXhigh = _showXhighOption(settings);
    final showMax = _showMaxOption(settings);
    final customActive = _isCustomSelected(
      showXhigh: showXhigh,
      showMax: showMax,
    );
    final cs = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
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
                const SizedBox(height: 6),
                // No title per iOS style; keep content close to handle
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      _tile(
                        l10n.reasoningBudgetSheetOff,
                        0,
                        leading: ReasoningIcons.budgetIcon(
                          ReasoningIcons.offBudget,
                          size: 18,
                          color: _selected == 0
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.7),
                        ),
                        active: _selected == 0,
                      ),
                      _tile(
                        l10n.reasoningBudgetSheetAuto,
                        -1,
                        leading: ReasoningIcons.budgetIcon(
                          ReasoningIcons.autoBudget,
                          size: 18,
                          color: _selected == -1
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.7),
                        ),
                        active: _selected == -1,
                      ),
                      _tile(
                        l10n.reasoningBudgetSheetLight,
                        1024,
                        leading: ReasoningIcons.budgetIcon(
                          ReasoningIcons.lightBudget,
                          size: 18,
                          color: _selected == 1024
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.7),
                        ),
                        active: _selected == 1024,
                      ),
                      _tile(
                        l10n.reasoningBudgetSheetMedium,
                        16000,
                        leading: ReasoningIcons.budgetIcon(
                          ReasoningIcons.mediumBudget,
                          size: 18,
                          color: _selected == 16000
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.7),
                        ),
                        active: _selected == 16000,
                      ),
                      _tile(
                        l10n.reasoningBudgetSheetHeavy,
                        32000,
                        leading: ReasoningIcons.budgetIcon(
                          ReasoningIcons.heavyBudget,
                          size: 18,
                          color: _selected == 32000
                              ? cs.primary
                              : cs.onSurface.withValues(alpha: 0.7),
                        ),
                        active: _selected == 32000,
                      ),
                      if (showXhigh)
                        _tile(
                          l10n.reasoningBudgetSheetXhigh,
                          64000,
                          leading: ReasoningIcons.budgetIcon(
                            ReasoningIcons.xhighBudget,
                            size: 18,
                            color: _selected == 64000
                                ? cs.primary
                                : cs.onSurface.withValues(alpha: 0.7),
                          ),
                          active: _selected == 64000,
                        ),
                      if (showMax)
                        _tile(
                          l10n.reasoningBudgetSheetMax,
                          128000,
                          leading: ReasoningIcons.budgetIcon(
                            ReasoningIcons.maxBudget,
                            size: 18,
                            color: _selected == 128000
                                ? cs.primary
                                : cs.onSurface.withValues(alpha: 0.7),
                          ),
                          active: _selected == 128000,
                        ),
                      _tile(
                        l10n.reasoningBudgetSheetCustomLabel,
                        0,
                        icon: Lucide.Hash,
                        active: customActive,
                        onTap: () => _openCustomBudget(),
                        trailing: customActive
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _selected.toString(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: AppFontWeights.semibold,
                                      color: cs.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Lucide.Check,
                                    size: 18,
                                    color: cs.primary,
                                  ),
                                ],
                              )
                            : Icon(
                                Lucide.ChevronRight,
                                size: 18,
                                color: cs.onSurface.withValues(alpha: 0.45),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
