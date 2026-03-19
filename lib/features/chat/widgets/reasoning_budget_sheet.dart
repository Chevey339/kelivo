import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/dialogs/reasoning_budget_custom_dialog.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../core/services/haptics.dart';

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

  void _select(int value) {
    setState(() {
      _selected = value;
    });
    context.read<SettingsProvider>().setThinkingBudget(value);
  }

  bool _isCustomSelected({required bool showXhigh}) {
    final presets = <int>{
      -1, // auto
      0, // off
      1024,
      16000,
      32000,
      if (showXhigh) 64000,
    };
    return !presets.contains(_selected);
  }

  Future<void> _openCustomBudget() async {
    Haptics.light();
    final initialValue = _selected >= 1024 ? _selected : 2048;
    final chosen = await ReasoningBudgetCustomDialog.show(
      context,
      initialValue: initialValue,
    );
    if (!mounted || chosen == null) return;
    _select(chosen);
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Widget _tile(
    IconData icon,
    String title,
    int value, {
    bool deepthink = false,
    required bool active,
    VoidCallback? onTap,
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
          onTap: () {
            if (onTap != null) {
              onTap();
              return;
            }
            Haptics.light();
            _select(value);
            Navigator.of(context).maybePop();
          },
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              deepthink
                  ? SvgPicture.asset(
                      'assets/icons/deepthink.svg',
                      width: 18,
                      height: 18,
                      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                    )
                  : Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
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
    return settings.supportsOpenAIXhighReasoning(
      currentProvider,
      currentModelId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final showXhigh = _showXhighOption(settings);
    final customActive = _isCustomSelected(showXhigh: showXhigh);
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
                        Lucide.X,
                        l10n.reasoningBudgetSheetOff,
                        0,
                        active: _selected == 0,
                      ),
                      _tile(
                        Lucide.Settings2,
                        l10n.reasoningBudgetSheetAuto,
                        -1,
                        active: _selected == -1,
                      ),
                      _tile(
                        Lucide.Brain,
                        l10n.reasoningBudgetSheetLight,
                        1024,
                        deepthink: true,
                        active: _selected == 1024,
                      ),
                      _tile(
                        Lucide.Brain,
                        l10n.reasoningBudgetSheetMedium,
                        16000,
                        deepthink: true,
                        active: _selected == 16000,
                      ),
                      _tile(
                        Lucide.Brain,
                        l10n.reasoningBudgetSheetHeavy,
                        32000,
                        deepthink: true,
                        active: _selected == 32000,
                      ),
                      if (showXhigh)
                        _tile(
                          Lucide.Brain,
                          l10n.reasoningBudgetSheetXhigh,
                          64000,
                          deepthink: true,
                          active: _selected == 64000,
                        ),
                      _tile(
                        Lucide.Hash,
                        l10n.reasoningBudgetSheetCustomLabel,
                        0,
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
                                      fontWeight: FontWeight.w600,
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
