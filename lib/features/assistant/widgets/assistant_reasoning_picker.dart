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

  static const List<ReasoningLevel> _levels = [
    ReasoningLevel.off,
    ReasoningLevel.auto,
    ReasoningLevel.minimal,
    ReasoningLevel.low,
    ReasoningLevel.medium,
    ReasoningLevel.high,
    ReasoningLevel.xhigh,
    ReasoningLevel.max,
  ];

  int _indexFor(ReasoningRequest? current) {
    if (current == null) return 0;
    final index = _levels.indexOf(current.level);
    return index >= 0 ? index + 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: EffortSliderGroup(
        selectedIndex: _indexFor(current),
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
        stops: [
          EffortSliderStop(
            stopKey: 'assistant-reasoning-follow-default',
            icon: Icon(Lucide.RotateCcw, size: 18, color: cs.primary),
            iconKey: 'follow',
            title: l10n.assistantEditReasoningFollowDefault,
            subtitle: l10n.reasoningLevelFollowModelDefaultSubtitle,
          ),
          for (final level in _levels)
            EffortSliderStop(
              stopKey: 'assistant-reasoning-${level.name}',
              icon: ReasoningIcons.levelIcon(
                level,
                size: 18,
                color: cs.primary,
              ),
              iconKey: level,
              title: reasoningLevelLabel(l10n, level),
              subtitle: reasoningLevelEffortSubtitle(l10n, level),
            ),
        ],
      ),
    );
  }
}
