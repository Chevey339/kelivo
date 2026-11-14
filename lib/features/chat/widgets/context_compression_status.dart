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
  if (error == 'compression_invalid_settings') {
    return l10n.compressionInvalidSettings;
  }
  final timeout = RegExp(r'request_timeout:(\d+)').firstMatch(error);
  if (timeout != null) {
    final microseconds = int.tryParse(timeout.group(1)!);
    if (microseconds != null) {
      final minutes = microseconds / Duration.microsecondsPerMinute;
      return l10n.compressionRequestTimedOut(
        minutes == minutes.truncateToDouble() ? minutes.toInt() : minutes,
      );
    }
  }
  if (error.contains('native_compaction_originals_unavailable')) {
    return l10n.compressionNativeOriginalsUnavailable;
  }
  if (error.contains('native_compaction_scope_changed')) {
    return l10n.compressionNativeScopeChanged;
  }
  if (error.contains('native_compaction_input_overridden')) {
    return l10n.compressionNativeInputOverride;
  }
  if (error.contains('native_compaction_unavailable')) {
    return l10n.compressionNativeHint;
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
  if (error.contains('empty_summary')) return l10n.compressContextEmptySummary;
  if (error.contains('no_model')) return l10n.compressContextNoModel;
  if (error.contains('no_conversation') ||
      error.contains('conversation_not_found')) {
    return l10n.compressContextNoConversation;
  }
  if (error.contains('in_flight')) return l10n.contextTaskWait;
  if (error.contains('interrupted')) return l10n.contextTaskInterrupted;
  final lower = error.toLowerCase();
  if (lower.contains('timeoutexception') || lower.contains('timed out')) {
    return l10n.oauthRequestTimeout;
  }
  if (lower.contains('socketexception') ||
      lower.contains('clientexception') ||
      lower.contains('connection') ||
      lower.contains('network')) {
    return l10n.oauthNetworkError;
  }
  return l10n.compressContextFailed;
}

/// The setting the user can change to address a failed compression. Kept
/// separate from the displayed copy so all entry points offer the same action.
enum CompressionRecoveryTarget {
  outputBudget,
  requestLimit,
  model,
  reference,
  template,
  range,
  summaryLength,
  timeout,
  nativeMode;

  String label(AppLocalizations l10n) => switch (this) {
    outputBudget => l10n.compressionOutputBudget,
    requestLimit => l10n.compressionRequests,
    model => l10n.compressContextModelLabel,
    reference => l10n.compressionSourceSettings,
    template => l10n.compressionTemplate,
    range => l10n.compressionManualRange,
    summaryLength => l10n.compressionLength,
    timeout => l10n.compressionRequestTimeout,
    nativeMode => l10n.compressionNativeTitle,
  };

  bool get advanced => switch (this) {
    outputBudget ||
    requestLimit ||
    reference ||
    summaryLength ||
    timeout => true,
    _ => false,
  };

  bool get details => this == requestLimit || this == reference;
}

CompressionRecoveryTarget? compressionRecoveryTarget(
  String? error, {
  bool native = false,
}) {
  if (error == null) return null;
  if (error.contains('request_timeout:')) {
    return CompressionRecoveryTarget.timeout;
  }
  if (error.contains('native_compaction_unavailable') ||
      error.contains('native_compaction_originals_unavailable')) {
    return CompressionRecoveryTarget.nativeMode;
  }
  if (error.contains('no_messages')) return CompressionRecoveryTarget.range;
  if (error.contains('context_budget_exceeded') ||
      error.contains('compression_target_not_reached') ||
      error.contains('summary_not_smaller')) {
    return native
        ? CompressionRecoveryTarget.range
        : CompressionRecoveryTarget.summaryLength;
  }
  // Server-side compaction does not use the text summary model or its limits.
  if (native) return null;
  if (RegExp(
    r'compression_incomplete:(length|max_tokens|max_output_tokens|max_token)(?:\b|$)',
  ).hasMatch(error)) {
    return CompressionRecoveryTarget.outputBudget;
  }
  if (error.contains('compression_request_budget')) {
    return CompressionRecoveryTarget.requestLimit;
  }
  if (error.contains('compression_reference_too_large')) {
    return CompressionRecoveryTarget.reference;
  }
  if (error.contains('compression_template_missing')) {
    return CompressionRecoveryTarget.template;
  }
  if (error.contains('compression_incomplete') ||
      error.contains('empty_summary') ||
      error.contains('no_model')) {
    return CompressionRecoveryTarget.model;
  }
  return null;
}

bool compressionRetryFirst(CompressionRecoveryTarget? target) =>
    target == null || target == CompressionRecoveryTarget.timeout;

List<({String label, VoidCallback onTap})> compressionRecoveryActions(
  AppLocalizations l10n, {
  required String? error,
  required bool native,
  required VoidCallback onRetry,
  required VoidCallback onAdjust,
}) {
  final target = compressionRecoveryTarget(error, native: native);
  final retry = (label: l10n.compressTaskRetry, onTap: onRetry);
  final adjust = (
    label: target?.label(l10n) ?? l10n.compressTaskAdjustRetry,
    onTap: onAdjust,
  );
  return compressionRetryFirst(target) ? [retry, adjust] : [adjust, retry];
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
