import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/models/context_compression_task.dart';
import '../../../l10n/app_localizations.dart';

bool compressionShowsDivider(ContextCompressionTask task) =>
    switch (task.phase) {
      CompressionPhase.waiting ||
      CompressionPhase.preparing ||
      CompressionPhase.summarizing ||
      CompressionPhase.merging ||
      CompressionPhase.review ||
      CompressionPhase.applying ||
      CompressionPhase.failed ||
      CompressionPhase.interrupted => true,
      _ => false,
    };

String compressionDividerLabel(
  AppLocalizations l10n,
  ContextCompressionTask task, {
  bool waitingForApproval = false,
}) => switch (task.phase) {
  CompressionPhase.review => l10n.contextTaskReview,
  CompressionPhase.preparing => l10n.contextTaskPreparing,
  CompressionPhase.applying => l10n.contextTaskApplying,
  CompressionPhase.waiting =>
    waitingForApproval
        ? l10n.compressTaskWaitingApproval
        : l10n.compressTaskWaiting,
  CompressionPhase.merging => l10n.compressTaskMerging,
  CompressionPhase.failed ||
  CompressionPhase.interrupted => l10n.contextDividerFailed,
  _ => l10n.contextDividerRunning,
};

String compressionStatusLabel(
  AppLocalizations l10n,
  ContextCompressionTask task,
) => switch (task.phase) {
  CompressionPhase.review => l10n.contextTaskReview,
  CompressionPhase.interrupted => l10n.contextTaskInterrupted,
  CompressionPhase.cancelled => l10n.contextTaskCancelled,
  CompressionPhase.completed => l10n.contextTaskCompleted,
  _ => compressionDividerLabel(l10n, task),
};

String compressionErrorLabel(AppLocalizations l10n, String error) {
  if (error.contains('native_compaction_originals_unavailable')) {
    return l10n.compressionNativeOriginalsUnavailable;
  }
  if (error.contains('native_compaction_scope_changed')) {
    return l10n.compressionNativeScopeChanged;
  }
  if (error.contains('native_compaction_missing') ||
      error.contains('native_compaction_incomplete')) {
    return l10n.compressionNativeIncomplete;
  }
  if (error.contains('compression_near_limit')) {
    return l10n.compressionNearLimit;
  }
  if (error.contains('compression_request_budget')) {
    return l10n.compressionBudgetError;
  }
  if (error.contains('compression_incomplete')) {
    return l10n.compressionIncomplete;
  }
  if (error.contains('compression_reference_too_large')) {
    return l10n.compressionReferenceTooLarge;
  }
  if (error.contains('compression_reference_changed')) {
    return l10n.compressionReferenceChanged;
  }
  if (error.contains('compression_target_not_reached')) {
    return l10n.compressionTargetNotReached;
  }
  if (error.contains('compression_template_missing')) {
    return l10n.compressionTemplateMissing;
  }
  if (error.contains('context_budget_exceeded')) return l10n.compressOverSnack;
  if (error.contains('summary_not_smaller')) {
    return l10n.contextSummaryNotSmaller;
  }
  if (error.contains('context_changed')) return l10n.compressStaleSnack;
  if (error.contains('no_messages')) return l10n.compressContextNoMessages;
  if (error.contains('empty_summary')) return l10n.contextSummaryEmpty;
  if (error.contains('in_flight')) return l10n.contextTaskWait;
  return error;
}

enum ContextTaskIndicator { running, failed, paused }

ContextTaskIndicator? contextTaskIndicator(
  ContextCompressionTask? task, {
  required bool inputPaused,
}) {
  if (task != null && task.active && task.phase != CompressionPhase.review) {
    return ContextTaskIndicator.running;
  }
  if (task?.phase == CompressionPhase.review) {
    return ContextTaskIndicator.paused;
  }
  if (task != null && compressionShowsDivider(task)) {
    return ContextTaskIndicator.failed;
  }
  return inputPaused ? ContextTaskIndicator.paused : null;
}

class ContextTaskStatusIcon extends StatelessWidget {
  const ContextTaskStatusIcon({super.key, required this.status});
  final ContextTaskIndicator status;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final label = switch (status) {
      ContextTaskIndicator.running => l10n.contextDividerRunning,
      ContextTaskIndicator.failed => l10n.contextDividerFailed,
      ContextTaskIndicator.paused => l10n.chatInputBarQueuedPaused,
    };
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: status == ContextTaskIndicator.running
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: cs.onSurfaceVariant,
                ),
              )
            : Icon(
                status == ContextTaskIndicator.failed
                    ? LucideIcons.circleAlert
                    : LucideIcons.pause,
                size: 16,
                color: status == ContextTaskIndicator.failed
                    ? cs.error
                    : cs.onSurfaceVariant,
              ),
      ),
    );
  }
}
