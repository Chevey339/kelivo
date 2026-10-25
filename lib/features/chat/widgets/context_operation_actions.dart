import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/models/context_operation.dart';
import '../../../core/models/compress_context_options.dart';
import '../../../utils/platform_utils.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/chat/context_compression_service.dart';
import '../../../desktop/desktop_context_menu.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/action_sheet.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import 'context_compression_status.dart';
import 'context_dialog.dart';
import 'context_impact_dialog.dart';
import 'context_operation_widgets.dart';
import '../pages/context_summary_editor_page.dart';

Future<CompressionBudget?> _estimate(
  ChatService chat,
  String id,
  ConversationContextSnapshot snapshot,
  List<ContextOperation> operations,
) async {
  try {
    return await chat.contextCompression.estimateCandidate?.call(
      id,
      ContextHistory.resolve(snapshot.messages, operations),
    );
  } catch (_) {
    return null;
  }
}

Future<bool> confirmContextImpact(
  BuildContext context,
  List<ContextOperation> operations, {
  required Set<String> affectedIds,
  required ContextImpactKind kind,
  String? targetId,
  CompressionBudget? before,
  CompressionBudget? after,
  String? sourceLabel,
}) async {
  if (affectedIds.isEmpty) return true;
  if (!context.mounted) return false;
  final active = operations.where((op) => !op.revoked).toList();
  final first = active.indexWhere((op) => affectedIds.contains(op.id));
  return await showDialog<bool>(
        context: context,
        builder: (_) => ContextImpactDialog(
          operations: active.skip(first < 0 ? 0 : first).toList(),
          affectedIds: affectedIds,
          targetId: targetId,
          kind: kind,
          before: before,
          after: after,
          sourceLabel: sourceLabel,
        ),
      ) ??
      false;
}

Future<String?> confirmContextSourceMutation(
  BuildContext context, {
  required ChatService chat,
  required String conversationId,
  required Set<String> groups,
  Set<String> removedGroups = const {},
  bool deleting = false,
}) async {
  final operations = await chat.loadContextOperations(conversationId);
  if (ContextHistory.affectedOperations(
    operations,
    changedGroups: groups,
    removedGroups: removedGroups,
  ).isEmpty) {
    return ContextHistory.operationsFingerprint(operations);
  }
  // Only hydrate original bodies when an impact preview needs their budget.
  // Recompute against this snapshot in case nodes changed during the await.
  final snapshot = await chat.loadContextSnapshot(conversationId);
  final affected = ContextHistory.affectedOperations(
    snapshot.operations,
    changedGroups: groups,
    removedGroups: removedGroups,
  );
  if (affected.isNotEmpty) {
    final budgets = await Future.wait([
      _estimate(chat, conversationId, snapshot, snapshot.operations),
      _estimate(chat, conversationId, snapshot, [
        for (final op in snapshot.operations)
          affected.contains(op.id) ? op.copyWith(revoked: true) : op,
      ]),
    ]);
    if (!context.mounted ||
        !await confirmContextImpact(
          context,
          snapshot.operations,
          affectedIds: affected,
          kind: deleting
              ? ContextImpactKind.deleteSource
              : ContextImpactKind.source,
          before: budgets.first,
          after: budgets.last,
          sourceLabel: AppLocalizations.of(context)!.contextOriginalMessages,
        )) {
      return null;
    }
  }
  return ContextHistory.operationsFingerprint(snapshot.operations);
}

Future<bool> changeContextOperationWithConfirmation(
  BuildContext context, {
  required ChatService chat,
  required String conversationId,
  required ContextOperation operation,
  String? summary,
}) async {
  final before = await chat.loadContextSnapshot(conversationId);
  final operations = before.operations;
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
  final projected = [
    for (final op in operations)
      if (op.id == operation.id && summary != null)
        op.copyWith(summary: summary)
      else if (affected.contains(op.id))
        op.copyWith(revoked: true)
      else
        op,
  ];
  final budgets = await Future.wait([
    _estimate(chat, conversationId, before, operations),
    _estimate(chat, conversationId, before, projected),
  ]);
  if (!context.mounted) return false;
  final active = operations.where((op) => !op.revoked).toList();
  if (active.last.id != operation.id || affected.length > 1) {
    if (!await confirmContextImpact(
      context,
      operations,
      affectedIds: affected,
      targetId: operation.id,
      kind: summary != null
          ? ContextImpactKind.edit
          : operation.isCompression
          ? ContextImpactKind.undo
          : ContextImpactKind.clear,
      before: budgets.first,
      after: budgets.last,
    )) {
      return false;
    }
  }
  if (!context.mounted) return false;
  if (summary != null &&
      budgets.last?.contextWindow != null &&
      budgets.last!.usedTokens > budgets.last!.contextWindow!) {
    showAppSnackBar(
      context,
      message: AppLocalizations.of(context)!.contextBudgetExceeded,
      type: NotificationType.warning,
    );
    return false;
  }
  final waiting =
      chat.contextCompression.isConversationBusy?.call(conversationId) ?? false;
  final change = chat.changeContextOperation(
    conversationId,
    operation.id,
    summary: summary,
    includeDependents: true,
    expectedState: ContextHistory.operationsFingerprint(operations),
  );
  Future<bool> finish() async {
    try {
      await change;
      if (summary == null) {
        final after = await chat.loadContextSnapshot(conversationId);
        final budget = await _estimate(
          chat,
          conversationId,
          after,
          after.operations,
        );
        if (context.mounted) {
          final l10n = AppLocalizations.of(context)!;
          showAppSnackBar(
            context,
            message: l10n.contextUndoneSnack(
              budgets.first == null
                  ? '—'
                  : contextTokenValue(budgets.first!.usedTokens),
              budget == null ? '—' : contextTokenValue(budget.usedTokens),
            ),
            actionLabel: l10n.contextRestore,
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
                    message: l10n.contextChanged,
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

  if (waiting) {
    showAppSnackBar(
      context,
      message: summary == null
          ? AppLocalizations.of(context)!.contextChangeWaiting
          : AppLocalizations.of(context)!.contextEditPending,
    );
    unawaited(finish());
    return true;
  }
  return finish();
}

Future<void> showContextOperationDetails(
  BuildContext context, {
  required ChatService chat,
  required String conversationId,
  required ContextOperation operation,
  Future<void> Function(String messageId)? onViewOriginal,
  VoidCallback? onRecompress,
  VoidCallback? onContinueNewChat,
}) async {
  final snapshot = await chat.loadContextSnapshot(conversationId);
  final source = snapshot.messages
      .where((m) => operation.sourceGroups.contains(ContextHistory.group(m)))
      .toList();
  final affected = ContextHistory.affectedOperations(
    snapshot.operations,
    operationIds: {operation.id},
  );
  final budgets = await Future.wait([
    _estimate(chat, conversationId, snapshot, snapshot.operations),
    _estimate(chat, conversationId, snapshot, [
      for (final op in snapshot.operations)
        affected.contains(op.id) ? op.copyWith(revoked: true) : op,
    ]),
  ]);
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context)!;
  final range = source.isEmpty
      ? ''
      : l10n.contextDetailRange(
          (snapshot.messages.indexOf(source.first) + 1).toString(),
          (snapshot.messages.indexOf(source.last) + 1).toString(),
          countUserMessages(source),
        );
  final hidden = snapshot.operations
      .skipWhile((op) => op.id != operation.id)
      .skip(1)
      .any(
        (op) =>
            !op.revoked &&
            !op.isCompression &&
            op.sourceGroups.contains(operation.anchorGroupId),
      );
  final superseded = snapshot.operations.any(
    (op) => !op.revoked && op.dependencies.contains(operation.id),
  );
  await _showContextContent(
    context,
    title: operation.isCompression
        ? l10n.contextDetailTitle
        : l10n.contextDetailClearTitle,
    maxWidth: operation.isCompression ? 560 : 500,
    builder: (detailContext) => ContextOperationContent(
      operation: operation,
      rangeLabel: range,
      budget: budgets.first,
      undoBudget: budgets.last,
      showHeader: PlatformUtils.isDesktopTarget,
      statusLabel: hidden
          ? l10n.contextOperationHidden
          : superseded
          ? l10n.contextDetailSuperseded
          : '',
      onClose: () => Navigator.of(detailContext).pop(),
      onSave: operation.revoked
          ? null
          : (summary) => changeContextOperationWithConfirmation(
              context,
              chat: chat,
              conversationId: conversationId,
              operation: operation,
              summary: summary,
            ),
      onUndo: operation.revoked
          ? null
          : () => changeContextOperationWithConfirmation(
              context,
              chat: chat,
              conversationId: conversationId,
              operation: operation,
            ),
      estimateSummary: (summary) => _estimate(chat, conversationId, snapshot, [
        for (final op in snapshot.operations)
          if (op.id == operation.id)
            op.copyWith(summary: summary)
          else if (affected.contains(op.id))
            op.copyWith(revoked: true)
          else
            op,
      ]),
      onViewOriginal: source.isEmpty || onViewOriginal == null
          ? null
          : () {
              Navigator.of(detailContext).pop();
              onViewOriginal(source.first.id);
            },
      onRecompress: onRecompress == null
          ? null
          : () {
              Navigator.of(detailContext).pop();
              onRecompress();
            },
      onContinueNewChat: onContinueNewChat == null
          ? null
          : () {
              Navigator.of(detailContext).pop();
              onContinueNewChat();
            },
    ),
  );
}

Future<void> showContextCompressionMenu(
  BuildContext context, {
  required ChatService chat,
  required ContextCompressionTask task,
  required Offset anchor,
  required VoidCallback onRetry,
  required VoidCallback onAdjust,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final failed = !task.active;
  final details = failed
      ? compressionErrorLabel(l10n, task.error ?? l10n.contextTaskInterrupted)
      : task.totalParts == 0
      ? compressionDividerLabel(l10n, task)
      : l10n.compressTaskElapsed(
          (task.completedParts + 1).clamp(1, task.totalParts),
          task.totalParts,
          DateTime.now().difference(task.startedAt).inSeconds.clamp(0, 864000),
        );
  final items = <ActionSheetItem>[
    if (failed) ...[
      ActionSheetItem(
        icon: LucideIcons.sparkles,
        label: l10n.compressTaskRetry,
        onTap: onRetry,
      ),
      ActionSheetItem(
        icon: LucideIcons.package2,
        label: l10n.compressTaskAdjustRetry,
        onTap: onAdjust,
      ),
      ActionSheetItem(
        icon: LucideIcons.x,
        label: l10n.compressTaskAbandon,
        destructive: true,
        onTap: () => chat.contextCompression.dismiss(task.conversationId),
      ),
    ] else if (task.phase != CompressionPhase.applying)
      ActionSheetItem(
        icon: LucideIcons.x,
        label: l10n.contextTaskCancel,
        destructive: true,
        onTap: () => chat.contextCompression.cancel(task.conversationId),
      ),
  ];
  if (PlatformUtils.isDesktopTarget) {
    await showDesktopContextMenuAt(
      context,
      globalPosition: anchor,
      items: [
        DesktopContextMenuItem(label: details),
        for (final item in items)
          DesktopContextMenuItem(
            icon: item.icon,
            label: item.label,
            danger: item.destructive,
            onTap: item.onTap,
          ),
      ],
    );
  } else {
    await showMobileActionSheet(context, title: details, items: items);
  }
}

Future<void> showCompressionReview(
  BuildContext context, {
  required ChatService chat,
  required ContextCompressionTask task,
  VoidCallback? onRecompress,
}) async {
  final operation = task.candidate;
  if (operation == null) {
    if (task.summary.isEmpty) return;
    await _showContextContent(
      context,
      title: AppLocalizations.of(context)!.contextViewGenerated,
      builder: (detailContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (PlatformUtils.isDesktopTarget)
            Text(AppLocalizations.of(context)!.contextViewGenerated),
          Flexible(
            child: SingleChildScrollView(child: SelectableText(task.summary)),
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
    );
    return;
  }
  Future<bool> save(String summary) async {
    await chat.contextCompression.applyReviewed(task.conversationId, summary);
    return task.phase == CompressionPhase.completed;
  }

  Future<CompressionBudget?> estimate(String summary) async {
    final snapshot = await chat.loadContextSnapshot(task.conversationId);
    return _estimate(chat, task.conversationId, snapshot, [
      ...snapshot.operations,
      operation.copyWith(summary: summary),
    ]);
  }

  if (!PlatformUtils.isDesktopTarget && task.phase == CompressionPhase.review) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ContextSummaryEditorPage(
          summary: task.summary,
          budget: task.budget,
          estimate: estimate,
          onSave: save,
        ),
      ),
    );
    return;
  }
  await _showContextContent(
    context,
    title: AppLocalizations.of(context)!.contextTaskReview,
    builder: (detailContext) => ContextOperationContent(
      operation: operation,
      initiallyEditing: task.phase == CompressionPhase.review,
      budget: task.budget,
      showHeader: PlatformUtils.isDesktopTarget,
      onClose: () => Navigator.of(detailContext).pop(),
      estimateSummary: estimate,
      onSave: task.phase != CompressionPhase.review ? null : save,
      onRecompress: onRecompress == null
          ? null
          : () {
              Navigator.of(detailContext).pop();
              onRecompress();
            },
    ),
  );
}

Future<void> _showContextContent(
  BuildContext context, {
  required String title,
  double maxWidth = 560,
  required WidgetBuilder builder,
}) async {
  if (PlatformUtils.isDesktopTarget) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          ContextDialog(maxWidth: maxWidth, child: builder(dialogContext)),
    );
  } else {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: context.overlaySurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 10, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: AppFontWeights.emphasis,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    IosIconButton(
                      icon: LucideIcons.x,
                      size: 20,
                      padding: const EdgeInsets.all(10),
                      color: cs.onSurfaceVariant,
                      semanticLabel: AppLocalizations.of(
                        sheetContext,
                      )!.commonClose,
                      onTap: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
              ),
              Flexible(child: builder(sheetContext)),
            ],
          ),
        );
      },
    );
  }
}
