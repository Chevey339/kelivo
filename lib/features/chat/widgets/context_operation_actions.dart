import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/widgets/ios_text_button.dart';
import 'context_compression_status.dart';

import '../../../core/models/context_operation.dart';
import '../../../utils/platform_utils.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/chat/context_compression_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import '../../../shared/widgets/custom_bottom_sheet.dart';
import '../../../shared/widgets/snackbar.dart';
import 'context_operation_widgets.dart';

Future<bool> confirmContextImpact(
  BuildContext context,
  List<ContextOperation> operations,
) async {
  if (operations.isEmpty) return true;
  if (!context.mounted) return false;
  final l10n = AppLocalizations.of(context)!;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.contextChangeTitle),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.contextChangeImpact(operations.length)),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final operation in operations)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '${operation.isCompression ? l10n.contextCompressMarker : l10n.contextClearMarker} · '
                              '${MaterialLocalizations.of(context).formatShortDate(operation.createdAt.toLocal())}',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IosTextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              label: l10n.homePageCancel,
            ),
            IosTextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              label: l10n.modelDetailSheetConfirmButton,
            ),
          ],
        ),
      ) ??
      false;
}

/// Returns the exact node state approved by the user, checked again inside
/// the source write transaction. Null means the user cancelled.
Future<String?> confirmContextSourceMutation(
  BuildContext context, {
  required ChatService chat,
  required String conversationId,
  required Set<String> groups,
  Set<String> removedGroups = const {},
}) async {
  final operations = await chat.loadContextOperations(
    conversationId,
    refresh: true,
  );
  if (!context.mounted) return null;
  final affected = ContextHistory.affectedOperations(
    operations,
    changedGroups: groups,
    removedGroups: removedGroups,
  );
  if (!await confirmContextImpact(
    context,
    operations.where((op) => affected.contains(op.id)).toList(),
  )) {
    return null;
  }
  return ContextHistory.operationsFingerprint(operations);
}

Future<bool> changeContextOperationWithConfirmation(
  BuildContext context, {
  required ChatService chat,
  required String conversationId,
  required ContextOperation operation,
  String? summary,
}) async {
  final operations = await chat.loadContextOperations(conversationId);
  if (!context.mounted) return false;
  final current = operations.where((op) => op.id == operation.id).firstOrNull;
  if (current == null ||
      current.revoked ||
      current.summary != operation.summary) {
    showAppSnackBar(
      context,
      message: AppLocalizations.of(context)!.contextChanged,
      type: NotificationType.warning,
    );
    return false;
  }
  final affected = ContextHistory.affectedOperations(
    operations,
    operationIds: {operation.id},
  );
  final dependents = operations
      .where(
        (op) =>
            !op.revoked && op.id != operation.id && affected.contains(op.id),
      )
      .toList();
  if (!await confirmContextImpact(context, dependents)) return false;
  final before = await chat.loadContextSnapshot(conversationId);
  if (summary != null && chat.contextCompression.estimateCandidate != null) {
    final projected = [
      for (final op in before.operations)
        if (op.id == operation.id)
          op.copyWith(summary: summary)
        else if (affected.contains(op.id))
          op.copyWith(revoked: true)
        else
          op,
    ];
    final budget = await chat.contextCompression.estimateCandidate!(
      conversationId,
      ContextHistory.resolve(before.messages, projected),
    );
    if (budget.contextWindow != null &&
        budget.usedTokens > budget.contextWindow!) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          message: AppLocalizations.of(context)!.contextBudgetExceeded,
          type: NotificationType.warning,
        );
      }
      return false;
    }
  }
  if (context.mounted &&
      (chat.contextCompression.isConversationBusy?.call(conversationId) ??
          false)) {
    showAppSnackBar(
      context,
      message: AppLocalizations.of(context)!.contextChangeWaiting,
    );
  }
  try {
    await chat.changeContextOperation(
      conversationId,
      operation.id,
      summary: summary,
      includeDependents: true,
      expectedState: ContextHistory.operationsFingerprint(operations),
    );
    if (summary == null) {
      final after = await chat.loadContextSnapshot(conversationId);
      if (context.mounted) {
        showAppSnackBar(
          context,
          message: AppLocalizations.of(context)!.contextOperationUndone,
          actionLabel: AppLocalizations.of(context)!.contextRestoreOperation,
          onAction: () async {
            try {
              await chat.restoreContextOperations(
                conversationId,
                before.operations,
                expectedFingerprint: after.fingerprint,
              );
            } catch (_) {
              if (context.mounted) {
                showAppSnackBar(
                  context,
                  message: AppLocalizations.of(context)!.contextChanged,
                  type: NotificationType.warning,
                );
              }
            }
          },
        );
      }
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      showAppSnackBar(
        context,
        message: '${AppLocalizations.of(context)!.contextChanged}\n$error',
        type: NotificationType.warning,
      );
    }
    return false;
  }
}

Future<void> showContextOperationDetails(
  BuildContext context, {
  required ChatService chat,
  required String conversationId,
  required ContextOperation operation,
  Future<void> Function(String messageId)? onViewOriginal,
}) async {
  final snapshot = await chat.loadContextSnapshot(conversationId);
  if (!context.mounted) return;
  final source = snapshot.messages
      .where((m) => operation.sourceGroups.contains(ContextHistory.group(m)))
      .toList();
  CompressionBudget? budget;
  CompressionBudget? undoBudget;
  final estimate = chat.contextCompression.estimateCandidate;
  if (estimate != null) {
    try {
      budget = await estimate(
        conversationId,
        ContextHistory.resolve(snapshot.messages, snapshot.operations),
      );
      final affected = ContextHistory.affectedOperations(
        snapshot.operations,
        operationIds: {operation.id},
      );
      undoBudget = await estimate(
        conversationId,
        ContextHistory.resolve(snapshot.messages, [
          for (final op in snapshot.operations)
            affected.contains(op.id) ? op.copyWith(revoked: true) : op,
        ]),
      );
    } catch (_) {
      /* Unknown model or unavailable preview: keep history readable. */
    }
  }
  if (!context.mounted) return;
  final range = source.isEmpty
      ? ''
      : '${MaterialLocalizations.of(context).formatShortDate(source.first.timestamp.toLocal())} – '
            '${MaterialLocalizations.of(context).formatShortDate(source.last.timestamp.toLocal())}';
  await _showContextContent(
    context,
    title: operation.isCompression
        ? AppLocalizations.of(context)!.contextSummaryTitle
        : AppLocalizations.of(context)!.contextClearMarker,
    builder: (detailContext, scroll) => ContextOperationContent(
      operation: operation,
      rangeLabel: range,
      statusLabel: operation.revoked
          ? ''
          : snapshot.operations
                .skipWhile((op) => op.id != operation.id)
                .skip(1)
                .any(
                  (op) =>
                      !op.revoked &&
                      !op.isCompression &&
                      op.sourceGroups.contains(operation.anchorGroupId),
                )
          ? AppLocalizations.of(context)!.contextOperationHidden
          : snapshot.operations.any(
              (op) => !op.revoked && op.dependencies.contains(operation.id),
            )
          ? AppLocalizations.of(context)!.contextOperationSuperseded
          : '',
      budget: budget,
      undoBudget: undoBudget,
      scrollController: scroll,
      onClose: () => Navigator.of(detailContext).pop(),
      onSave: operation.revoked
          ? null
          : (summary) => changeContextOperationWithConfirmation(
              detailContext,
              chat: chat,
              conversationId: conversationId,
              operation: operation,
              summary: summary,
            ),
      onUndo: operation.revoked
          ? null
          : () => changeContextOperationWithConfirmation(
              detailContext,
              chat: chat,
              conversationId: conversationId,
              operation: operation,
            ),
      onViewOriginal: source.isEmpty || onViewOriginal == null
          ? null
          : () {
              Navigator.of(detailContext).pop();
              onViewOriginal(source.first.id);
            },
    ),
  );
}

Future<void> showCompressionReview(
  BuildContext context, {
  required ChatService chat,
  required ContextCompressionTask task,
}) async {
  final operation = task.candidate;
  if (operation == null) {
    if (task.summary.isEmpty) return;
    await _showContextContent(
      context,
      title: AppLocalizations.of(context)!.contextViewGenerated,
      builder: (detailContext, scroll) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: scroll,
                child: SelectableText(task.summary),
              ),
            ),
            IosTextButton(
              label: AppLocalizations.of(context)!.assistantSettingsCopyButton,
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: task.summary)),
            ),
            IosTextButton(
              label: AppLocalizations.of(context)!.statsPageClose,
              onPressed: () => Navigator.of(detailContext).pop(),
            ),
          ],
        ),
      ),
    );
    return;
  }
  await _showContextContent(
    context,
    title: AppLocalizations.of(context)!.contextTaskReview,
    builder: (detailContext, scroll) => ContextOperationContent(
      operation: operation,
      initiallyEditing: task.phase == CompressionPhase.review,
      budget: task.budget,
      scrollController: scroll,
      onClose: () => Navigator.of(detailContext).pop(),
      onSave: task.phase != CompressionPhase.review
          ? null
          : (summary) async {
              try {
                await chat.contextCompression.applyReviewed(
                  task.conversationId,
                  summary,
                );
              } catch (error) {
                if (!detailContext.mounted) return false;
                throw StateError(
                  compressionErrorLabel(
                    AppLocalizations.of(detailContext)!,
                    error.toString(),
                  ),
                );
              }
              return task.phase == CompressionPhase.completed;
            },
    ),
  );
}

Future<void> _showContextContent(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext context, ScrollController? scroll)
  builder,
}) async {
  if (PlatformUtils.isDesktopTarget || ResponsiveHelper.isDesktop(context)) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 720,
          height: MediaQuery.sizeOf(dialogContext).height * .85,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  title,
                  style: Theme.of(dialogContext).textTheme.titleLarge,
                ),
              ),
              Expanded(child: builder(dialogContext, null)),
            ],
          ),
        ),
      ),
    );
  } else {
    await showCustomBottomSheet<void>(
      context: context,
      title: title,
      partialHeightFactor: .85,
      expandedHeightFactor: .95,
      builder: (sheetContext, scroll) => builder(sheetContext, scroll),
    );
  }
}
