import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/models/context_compression_task.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_text_button.dart';

String compressionStatusLabel(
  AppLocalizations l10n,
  ContextCompressionTask task,
) => switch (task.phase) {
  CompressionPhase.waiting => l10n.contextTaskWait,
  CompressionPhase.preparing => l10n.contextTaskPreparing,
  CompressionPhase.summarizing => l10n.contextTaskProgress(
    task.completedParts,
    task.totalParts,
  ),
  CompressionPhase.merging =>
    '${l10n.contextTaskMerging} · ${task.completedParts}/${task.totalParts}',
  CompressionPhase.applying => l10n.contextTaskApplying,
  CompressionPhase.review => l10n.contextTaskReview,
  CompressionPhase.completed => l10n.contextTaskCompleted,
  CompressionPhase.failed => l10n.contextTaskFailed,
  CompressionPhase.cancelled => l10n.contextTaskCancelled,
  CompressionPhase.interrupted => l10n.contextTaskInterrupted,
};

String compressionErrorLabel(AppLocalizations l10n, String error) {
  if (error.contains('context_budget_exceeded')) {
    return l10n.contextBudgetExceeded;
  }
  if (error.contains('summary_not_smaller')) {
    return l10n.contextSummaryNotSmaller;
  }
  if (error.contains('context_changed')) return l10n.contextChanged;
  if (error.contains('no_messages')) return l10n.compressContextNoMessages;
  if (error.contains('empty_summary')) return l10n.contextSummaryEmpty;
  if (error.contains('in_flight')) return l10n.contextTaskWait;
  return error;
}

class ContextCompressionStatus extends StatelessWidget {
  const ContextCompressionStatus({
    super.key,
    required this.task,
    required this.onCancel,
    required this.onRetry,
    required this.onReview,
    this.onOpenNewChat,
    this.onDismiss,
  });
  final ContextCompressionTask task;
  final VoidCallback onCancel;
  final VoidCallback onRetry;
  final VoidCallback onReview;
  final VoidCallback? onOpenNewChat;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    if (task.phase == CompressionPhase.completed && onOpenNewChat == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (task.active && task.phase != CompressionPhase.review)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  task.phase == CompressionPhase.failed
                      ? LucideIcons.circleAlert
                      : LucideIcons.layers,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  compressionStatusLabel(l10n, task),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          if (task.error != null &&
              (task.phase == CompressionPhase.failed ||
                  task.phase == CompressionPhase.review))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SelectableText(
                compressionErrorLabel(l10n, task.error!),
                style: TextStyle(color: cs.error, fontSize: 12),
              ),
            ),
          if (task.budget case final budget?)
            Text(
              l10n.contextBudgetInfo(
                budget.usedTokens,
                budget.contextWindow?.toString() ?? l10n.contextUnknownLimit,
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              if (task.active && task.phase != CompressionPhase.applying)
                IosTextButton(
                  label: l10n.contextTaskCancel,
                  onPressed: onCancel,
                ),
              if (task.phase == CompressionPhase.review ||
                  (!task.active && task.summary.isNotEmpty))
                IosTextButton(
                  label: l10n.contextSummaryTitle,
                  onPressed: onReview,
                ),
              if (task.phase == CompressionPhase.failed ||
                  task.phase == CompressionPhase.interrupted ||
                  task.phase == CompressionPhase.cancelled)
                IosTextButton(label: l10n.contextTaskRetry, onPressed: onRetry),
              if (!task.active && onDismiss != null)
                IosTextButton(
                  label: l10n.contextTaskDismiss,
                  onPressed: onDismiss,
                ),
              if (onOpenNewChat != null)
                IosTextButton(
                  label: l10n.contextOpenNewChat,
                  onPressed: onOpenNewChat,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
