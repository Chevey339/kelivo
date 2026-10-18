import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/task_execution_binding.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/haptics.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/animated_progress_bar.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../../theme/design_tokens.dart';

/// A ZCode-styled task execution and progress tracking banner displayed above
/// the chat input composer during the execution phase.
class TaskExecutionBanner extends StatefulWidget {
  const TaskExecutionBanner({
    super.key,
    required this.plan,
    required this.conversationId,
  });

  final TaskExecutionPlan plan;
  final String conversationId;

  @override
  State<TaskExecutionBanner> createState() => _TaskExecutionBannerState();
}

class _TaskExecutionBannerState extends State<TaskExecutionBanner> {
  bool _expanded = false;

  void _toggleStep(TaskStep step) {
    Haptics.light();
    final newStatus = step.status == TaskStepStatus.completed
        ? TaskStepStatus.pending
        : TaskStepStatus.completed;
    final updatedPlan = widget.plan.updateStepStatus(step.id, newStatus);
    final binding = TaskExecutionBinding(plan: updatedPlan);

    final chatService = context.read<ChatService>();
    chatService.updateConversationExtras(
      widget.conversationId,
      (extras) => binding.applyTo(extras),
    );
  }

  void _dismissPlan() {
    Haptics.light();
    final chatService = context.read<ChatService>();
    chatService.updateConversationExtras(
      widget.conversationId,
      (extras) => const TaskExecutionBinding(plan: null).applyTo(extras),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final plan = widget.plan;
    final isDark = theme.brightness == Brightness.dark;
    final allCompleted = plan.isCompleted;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xxs,
        AppSpacing.sm,
        AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allCompleted
              ? Colors.green.withValues(alpha: 0.4)
              : theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header summary bar
          InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () {
              Haptics.light();
              setState(() => _expanded = !_expanded);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: (allCompleted ? Colors.green : theme.colorScheme.primary)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      allCompleted ? Lucide.Check : Lucide.ListTodo,
                      size: 15,
                      color: allCompleted
                          ? Colors.green
                          : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                plan.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.taskProgressStepCount(
                                plan.completedCount,
                                plan.totalCount,
                              ),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: allCompleted
                                    ? Colors.green
                                    : theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        AnimatedProgressBar(
                          fraction: plan.progressFraction,
                          height: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded ? Lucide.ChevronUp : Lucide.ChevronDown,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  if (allCompleted) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _dismissPlan,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Lucide.X,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Expanded checklist details
          if (_expanded) ...[
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                itemCount: plan.steps.length,
                separatorBuilder: (_, __) => const SizedBox(height: 2),
                itemBuilder: (context, index) {
                  final step = plan.steps[index];
                  final isDone = step.status == TaskStepStatus.completed;
                  final isInProgress = step.status == TaskStepStatus.inProgress;

                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _toggleStep(step),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IosCheckbox(
                            value: isDone,
                            size: 18,
                            activeColor: Colors.green,
                            onChanged: (_) => _toggleStep(step),
                          ),
                          const SizedBox(width: 8),
                          if (isInProgress) ...[
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              step.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDone
                                    ? theme.colorScheme.onSurface.withValues(
                                        alpha: 0.45,
                                      )
                                    : theme.colorScheme.onSurface,
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                                fontWeight: isInProgress
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
