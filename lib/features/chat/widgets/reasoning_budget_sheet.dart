import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
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
  late int? _selected;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsProvider>();
    _selected = s.thinkingBudget ?? -1;
    _controller = TextEditingController(text: (_selected ?? -1).toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(int value) {
    setState(() {
      _selected = value;
      _controller.text = value.toString();
    });
    context.read<SettingsProvider>().setThinkingBudget(value);
  }

  int _bucket(int? n, {bool allowXhigh = true}) {
    if (n == null) return -1; // treat as auto in UI bucketting
    if (n == -1) return -1;
    if (n < 1024) return 0;
    if (n < 16000) return 1024;
    if (n < 32000) return 16000;
    if (!allowXhigh) return 32000;
    if (n < 64000) return 32000;
    return 64000;
  }

  Widget _tile(
    IconData icon,
    String title,
    int value, {
    bool deepthink = false,
    required int selectedBucket,
  }) {
    final cs = Theme.of(context).colorScheme;
    final active = selectedBucket == value;
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
              if (active)
                Icon(Lucide.Check, size: 18, color: cs.primary)
              else
                const SizedBox(width: 18),
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
    final selectedBucket = _bucket(_selected, allowXhigh: showXhigh);
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
                        selectedBucket: selectedBucket,
                      ),
                      _tile(
                        Lucide.Settings2,
                        l10n.reasoningBudgetSheetAuto,
                        -1,
                        selectedBucket: selectedBucket,
                      ),
                      _tile(
                        Lucide.Brain,
                        l10n.reasoningBudgetSheetLight,
                        1024,
                        deepthink: true,
                        selectedBucket: selectedBucket,
                      ),
                      _tile(
                        Lucide.Brain,
                        l10n.reasoningBudgetSheetMedium,
                        16000,
                        deepthink: true,
                        selectedBucket: selectedBucket,
                      ),
                      _tile(
                        Lucide.Brain,
                        l10n.reasoningBudgetSheetHeavy,
                        32000,
                        deepthink: true,
                        selectedBucket: selectedBucket,
                      ),
                      if (showXhigh)
                        _tile(
                          Lucide.Brain,
                          l10n.reasoningBudgetSheetXhigh,
                          64000,
                          deepthink: true,
                          selectedBucket: selectedBucket,
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
