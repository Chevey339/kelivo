import 'package:flutter/material.dart';

import '../../../core/models/model_spec.dart';
import '../../../core/models/reasoning_request.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../icons/reasoning_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/effort_slider.dart';
import '../../../utils/platform_utils.dart';
import '../../chat/widgets/reasoning_level_sheet.dart';

class AssistantReasoningPick {
  const AssistantReasoningPick(this.request);

  final ReasoningRequest? request;
}

Future<AssistantReasoningPick?> showAssistantReasoningPicker(
  BuildContext context, {
  required ReasoningRequest? current,
}) async {
  final l10n = AppLocalizations.of(context)!;
  AssistantReasoningPick? picked;
  void onSelected(ReasoningRequest? request) {
    picked = AssistantReasoningPick(request);
  }

  if (PlatformUtils.isDesktop) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.assistantEditThinkingBudgetTitle),
        content: SizedBox(
          width: 380,
          child: AssistantReasoningPicker(
            current: current,
            onSelected: onSelected,
          ),
        ),
      ),
    );
    return picked;
  }
  await showReasoningPickerSheet<void>(
    context: context,
    title: l10n.assistantEditThinkingBudgetTitle,
    builder: (context) =>
        AssistantReasoningPicker(current: current, onSelected: onSelected),
  );
  return picked;
}

class AssistantReasoningPicker extends StatelessWidget {
  const AssistantReasoningPicker({
    super.key,
    required this.current,
    required this.onSelected,
  });

  final ReasoningRequest? current;
  final ValueChanged<ReasoningRequest?> onSelected;

  static const List<ReasoningLevel> _levels = ReasoningLevel.values;

  int _indexFor(ReasoningRequest? current) {
    if (current == null) return 0;
    final index = _levels.indexOf(current.level);
    return index >= 0 ? index + 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final keys = <String>[
      'assistant-reasoning-follow-default',
      for (final level in _levels) 'assistant-reasoning-${level.name}',
    ];
    final titles = <String>[
      l10n.assistantEditReasoningFollowDefault,
      for (final level in _levels) reasoningLevelLabel(l10n, level),
    ];
    final labels = <String>[
      l10n.reasoningLevelSourceModelDefault,
      for (final level in _levels) reasoningLevelLabel(l10n, level),
    ];
    final slider = EffortSliderGroup(
      selectedIndex: _indexFor(current),
      stopCount: keys.length,
      stopKeys: keys,
      stopLabels: labels,
      semanticsValue: (index) => titles[index.clamp(0, titles.length - 1)],
      onCommit: (index) {
        if (index <= 0) {
          onSelected(null);
          return;
        }
        final level = _levels[index - 1];
        onSelected(
          level == ReasoningLevel.auto
              ? ReasoningRequest.auto
              : level == ReasoningLevel.off
              ? ReasoningRequest.off
              : ReasoningRequest(level),
        );
      },
      header: (context, visualIndex) {
        final index = visualIndex.clamp(0, titles.length - 1);
        return EffortSliderActiveStop(
          icon: index == 0
              ? Icon(Lucide.RotateCcw, size: 18, color: cs.primary)
              : ReasoningIcons.levelIcon(
                  _levels[index - 1],
                  size: 18,
                  color: cs.primary,
                ),
          iconKey: index == 0 ? 'follow' : _levels[index - 1],
          title: titles[index],
        );
      },
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: slider,
    );
  }
}
