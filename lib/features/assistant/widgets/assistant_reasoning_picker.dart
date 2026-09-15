import 'package:flutter/material.dart';

import '../../../core/models/model_spec.dart';
import '../../../core/models/reasoning_request.dart';
import '../../../core/services/haptics.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../icons/reasoning_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/custom_bottom_sheet.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../theme/app_font_weights.dart';
import '../../../utils/platform_utils.dart';
import '../../chat/widgets/reasoning_level_sheet.dart';

class AssistantReasoningPick {
  const AssistantReasoningPick(this.request);

  final ReasoningRequest? request;
}

Future<AssistantReasoningPick?> showAssistantReasoningPicker(
  BuildContext context, {
  required ReasoningRequest? current,
}) {
  final l10n = AppLocalizations.of(context)!;
  if (PlatformUtils.isDesktop) {
    return showDialog<AssistantReasoningPick>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.assistantEditThinkingBudgetTitle),
        content: SizedBox(
          width: 380,
          child: AssistantReasoningPicker(
            current: current,
            onSelected: (request) {
              Navigator.of(ctx).pop(AssistantReasoningPick(request));
            },
          ),
        ),
      ),
    );
  }
  return showCustomBottomSheet<AssistantReasoningPick>(
    context: context,
    title: l10n.assistantEditThinkingBudgetTitle,
    builder: (context, controller) => AssistantReasoningPicker(
      current: current,
      scrollController: controller,
      onSelected: (request) {
        Navigator.of(context).pop(AssistantReasoningPick(request));
      },
    ),
  );
}

class AssistantReasoningPicker extends StatelessWidget {
  const AssistantReasoningPicker({
    super.key,
    required this.current,
    required this.onSelected,
    this.scrollController,
  });

  final ReasoningRequest? current;
  final ValueChanged<ReasoningRequest?> onSelected;
  final ScrollController? scrollController;

  static const List<ReasoningLevel> _levels = ReasoningLevel.values;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return ListView(
      controller: scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        Text(
          l10n.assistantEditReasoningClampedSubtitle,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 10),
        _row(
          context,
          key: 'assistant-reasoning-follow-default',
          title: l10n.assistantEditReasoningFollowDefault,
          selected: current == null,
          leading: Icon(
            Lucide.RotateCcw,
            size: 20,
            color: current == null
                ? cs.primary
                : cs.onSurface.withValues(alpha: 0.7),
          ),
          onTap: () => onSelected(null),
        ),
        for (final level in _levels)
          _row(
            context,
            key: 'assistant-reasoning-${level.name}',
            title: reasoningLevelLabel(l10n, level),
            selected: current?.level == level && current != null,
            leading: ReasoningIcons.levelIcon(
              level,
              size: 20,
              color: current?.level == level && current != null
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: 0.7),
            ),
            onTap: () => onSelected(
              level == ReasoningLevel.auto
                  ? ReasoningRequest.auto
                  : level == ReasoningLevel.off
                  ? ReasoningRequest.off
                  : ReasoningRequest(level),
            ),
          ),
      ],
    );
  }

  Widget _row(
    BuildContext context, {
    required String key,
    required String title,
    required bool selected,
    required Widget leading,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final onColor = selected ? cs.primary : cs.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        key: ValueKey(key),
        height: 48,
        child: IosCardPress(
          borderRadius: BorderRadius.circular(14),
          baseColor: sheetTileColor(context),
          duration: const Duration(milliseconds: 260),
          onTap: () {
            Haptics.soft();
            onTap();
          },
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: AppFontWeights.medium,
                    color: onColor,
                  ),
                ),
              ),
              if (selected) Icon(Lucide.Check, size: 18, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}
