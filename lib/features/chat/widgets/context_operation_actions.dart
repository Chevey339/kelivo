import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/models/context_operation.dart';
import '../../../core/models/chat_message.dart';
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
import 'compression_error_notice.dart';
import 'context_dialog.dart';
import 'context_impact_dialog.dart';
import 'context_operation_widgets.dart';
import 'context_operations_panel.dart';
import '../pages/context_summary_editor_page.dart';

Future<CompressionBudget?> _estimate(
  ChatService chat,
  String id,
  List<ChatMessage> messages,
  List<ContextOperation> operations,
) async {
  try {
    final resolved = await Isolate.run(
      () => ContextHistory.resolve(messages, operations),
    );
    return await chat.contextCompression.estimateCandidate?.call(
      id,
      resolved,
      fixedContextStart: ContextHistory.fixedStart(operations) != null,
    );
  } catch (_) {
    return null;
  }
}

Future<bool> confirmContextImpact(
  BuildContext context,
  List<ContextOperationMetadata> operations, {
  required Set<String> affectedIds,
  required ContextImpactKind kind,
  String? targetId,
  CompressionBudget? before,
  CompressionBudget? after,
  String? sourceLabel,
  Future<List<CompressionBudget?>>? budgets,
}) async {
  if (affectedIds.isEmpty) return true;
  if (!context.mounted) return false;
  final active = operations.where((op) => !op.revoked).toList();
  final first = active.indexWhere((op) => affectedIds.contains(op.id));
  return await showDialog<bool>(
        context: context,
        builder: (_) => FutureBuilder<List<CompressionBudget?>>(
          future: budgets,
          builder: (_, snapshot) => ContextImpactDialog(
            operations: active.skip(first < 0 ? 0 : first).toList(),
            affectedIds: affectedIds,
            targetId: targetId,
            kind: kind,
            before: snapshot.data?.first ?? before,
            after: snapshot.data?.last ?? after,
            sourceLabel: sourceLabel,
          ),
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
  final state = await chat.loadContextMutationState(conversationId);
  final affected = ContextHistory.affectedOperations(
    state.operations,
    changedGroups: groups,
    removedGroups: removedGroups,
  );
  if (affected.isEmpty) {
    return state.revision;
  }
  if (!context.mounted) return null;
  var open = true;
  Future<List<CompressionBudget?>> preview() async {
    // Let the metadata-only confirmation paint before loading any bodies.
    await WidgetsBinding.instance.endOfFrame;
    if (!open) return [null, null];
    try {
      final snapshot = await chat.loadContextMutationPreview(
        conversationId,
        expectedState: state.revision,
      );
      if (!open) return [null, null];
      return await Future.wait([
        _estimate(chat, conversationId, snapshot.messages, snapshot.operations),
        _estimate(chat, conversationId, snapshot.messages, [
          for (final op in snapshot.operations)
            affected.contains(op.id) ? op.copyWith(revoked: true) : op,
        ]),
      ]);
    } catch (_) {
      return [null, null];
    }
  }

  try {
    if (!await confirmContextImpact(
      context,
      state.operations,
      affectedIds: affected,
      kind: deleting
          ? ContextImpactKind.deleteSource
          : ContextImpactKind.source,
      budgets: preview(),
      sourceLabel: AppLocalizations.of(context)!.contextOriginalMessages,
    )) {
      return null;
    }
    return state.revision;
  } finally {
    open = false;
  }
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
  if (current?.isImportedNative == true) {
    showAppSnackBar(
      context,
      message: AppLocalizations.of(
        context,
      )!.compressionNativeOriginalsUnavailable,
      type: NotificationType.warning,
    );
    return false;
  }
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
    _estimate(chat, conversationId, before.messages, operations),
    _estimate(chat, conversationId, before.messages, projected),
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
          : operation.isClear
          ? ContextImpactKind.clear
          : ContextImpactKind.undo,
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
          after.messages,
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
  Future<void> Function(String conversationId)? onOpenConversation,
}) async {
  var open = true;
  Future<
    ({
      ConversationContextHistory history,
      List<ChatMessage> source,
      ChatMessage? anchor,
      Set<String> affected,
    })?
  >
  load() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!open || !context.mounted) return null;
    final snapshot = await chat.loadContextHistory(conversationId);
    if (!open || !context.mounted) return null;
    final groups = operation.sourceGroups.toSet();
    final source = snapshot.messages
        .where((m) => groups.contains(ContextHistory.group(m)))
        .toList();
    final anchor = snapshot.messages
        .where((m) => ContextHistory.group(m) == operation.anchorGroupId)
        .firstOrNull;
    final affected = ContextHistory.affectedOperations(
      snapshot.operations,
      operationIds: {operation.id},
    );
    return (
      history: snapshot,
      source: source,
      anchor: anchor,
      affected: affected,
    );
  }

  final details = load();
  Future<List<CompressionBudget?>> estimateBudgets() async {
    final detail = await details;
    if (detail == null || !open) return [null, null];
    final snapshot = detail.history;
    return Future.wait([
      _estimate(chat, conversationId, snapshot.messages, snapshot.operations),
      operation.canUndo
          ? _estimate(chat, conversationId, snapshot.messages, [
              for (final op in snapshot.operations)
                detail.affected.contains(op.id)
                    ? op.copyWith(revoked: true)
                    : op,
            ])
          : Future<CompressionBudget?>.value(),
    ]);
  }

  final budgets = estimateBudgets();
  final l10n = AppLocalizations.of(context)!;
  try {
    await _showContextContent(
      context,
      title: operation.isFixedStart
          ? l10n.contextFixedStart
          : operation.isCompression
          ? operation.isNative
                ? operation.isImportedNative
                      ? l10n.compressionNativeImported
                      : l10n.compressionNativeLabel
                : l10n.contextDetailTitle
          : l10n.contextDetailClearTitle,
      maxWidth: operation.isCompression ? 560 : 500,
      builder: (detailContext) => FutureBuilder(
        future: details,
        builder: (_, detailSnapshot) {
          final detail = detailSnapshot.data;
          final snapshot = detail?.history;
          final source = detail?.source ?? const <ChatMessage>[];
          final anchor = detail?.anchor;
          final range = source.isEmpty
              ? detailSnapshot.hasError
                    ? l10n.contextOperationsLoadFailed
                    : detailSnapshot.connectionState != ConnectionState.done
                    ? l10n.contextLogLoading
                    : ''
              : l10n.contextDetailRange(
                  (snapshot!.messages.indexOf(source.first) + 1).toString(),
                  (snapshot.messages.indexOf(source.last) + 1).toString(),
                  countUserMessages(source),
                );
          final statuses = ContextHistory.operationStatuses(
            snapshot?.operations ?? const [],
          );
          final status = statuses[operation.id];
          final hidden = status?.hidden ?? false;
          final superseded = status?.superseded ?? false;
          return FutureBuilder<List<CompressionBudget?>>(
            future: budgets,
            builder: (_, budgetSnapshot) => ContextOperationContent(
              operation: operation,
              sourceConversationAvailable:
                  chat.getConversation(
                    operation.nativeSourceConversationId ?? '',
                  ) !=
                  null,
              rangeLabel: range,
              budget: budgetSnapshot.data?.first,
              undoBudget: budgetSnapshot.data?.last,
              showHeader: PlatformUtils.isDesktopTarget,
              statusLabel: hidden
                  ? l10n.contextOperationHidden
                  : superseded
                  ? l10n.contextDetailSuperseded
                  : '',
              onClose: () => Navigator.of(detailContext).pop(),
              onSave: operation.revoked || operation.isNative
                  ? null
                  : (summary) => changeContextOperationWithConfirmation(
                      context,
                      chat: chat,
                      conversationId: conversationId,
                      operation: operation,
                      summary: summary,
                    ),
              onUndo: !operation.canUndo
                  ? null
                  : () => changeContextOperationWithConfirmation(
                      context,
                      chat: chat,
                      conversationId: conversationId,
                      operation: operation,
                    ),
              estimateSummary: (summary) async {
                final detail = await details;
                if (detail == null) return null;
                return _estimate(
                  chat,
                  conversationId,
                  detail.history.messages,
                  [
                    for (final op in detail.history.operations)
                      if (op.id == operation.id)
                        op.copyWith(summary: summary)
                      else if (detail.affected.contains(op.id))
                        op.copyWith(revoked: true)
                      else
                        op,
                  ],
                );
              },
              onViewOriginal: operation.isImportedNative
                  ? onOpenConversation == null ||
                            chat.getConversation(
                                  operation.nativeSourceConversationId ?? '',
                                ) ==
                                null
                        ? null
                        : () {
                            Navigator.of(detailContext).pop();
                            onOpenConversation(
                              operation.nativeSourceConversationId!,
                            );
                          }
                  : source.isEmpty || onViewOriginal == null
                  ? null
                  : () {
                      Navigator.of(detailContext).pop();
                      onViewOriginal(source.first.id);
                    },
              onViewBoundary:
                  operation.isImportedNative ||
                      anchor == null ||
                      onViewOriginal == null
                  ? null
                  : () {
                      Navigator.of(detailContext).pop();
                      onViewOriginal(anchor.id);
                    },
              onRecompress: operation.isImportedNative || onRecompress == null
                  ? null
                  : () {
                      Navigator.of(detailContext).pop();
                      onRecompress();
                    },
              onContinueNewChat:
                  snapshot == null ||
                      onOpenConversation == null ||
                      !operation.isCompression ||
                      operation.revoked ||
                      hidden ||
                      superseded
                  ? null
                  : () async {
                      Navigator.of(detailContext).pop();
                      try {
                        final created = await chat.continueFromContextSummary(
                          conversationId,
                          operation.id,
                        );
                        if (context.mounted &&
                            chat.currentConversationId == conversationId) {
                          await onOpenConversation(created.id);
                        }
                      } catch (error) {
                        if (!context.mounted) return;
                        showAppSnackBar(
                          context,
                          message: compressionErrorLabel(
                            l10n,
                            error.toString(),
                          ),
                          type: NotificationType.error,
                          actionLabel: l10n.ttsServicesDialogErrorTitle,
                          onAction: () => showCompressionErrorDetails(
                            context,
                            error.toString(),
                          ),
                        );
                      }
                    },
            ),
          );
        },
      ),
    );
  } finally {
    open = false;
  }
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
  final details = task.error != null
      ? compressionErrorLabel(l10n, task.error!)
      : failed
      ? compressionStatusLabel(l10n, task)
      : task.totalParts == 0
      ? compressionDividerLabel(l10n, task)
      : l10n.compressTaskElapsed(
          (task.completedParts + 1).clamp(1, task.totalParts),
          task.totalParts,
          DateTime.now().difference(task.startedAt).inSeconds.clamp(0, 864000),
        );
  final items = <ActionSheetItem>[
    if (task.phase == CompressionPhase.review)
      ActionSheetItem(
        icon: LucideIcons.filePenLine,
        label: l10n.contextViewGenerated,
        onTap: () => showCompressionReview(
          context,
          chat: chat,
          task: task,
          onRecompress: onAdjust,
        ),
      ),
    if (task.phase == CompressionPhase.review)
      if (compressionRecoveryTarget(task.error, native: task.options.native)
          case final target?)
        ActionSheetItem(
          icon: LucideIcons.slidersHorizontal,
          label: target.label(l10n),
          onTap: onAdjust,
        ),
    if (failed) ...[
      for (final action in compressionRecoveryActions(
        l10n,
        error: task.error,
        native: task.options.native,
        onRetry: onRetry,
        onAdjust: onAdjust,
      ))
        ActionSheetItem(
          icon: action.onTap == onRetry
              ? LucideIcons.rotateCw
              : LucideIcons.slidersHorizontal,
          label: action.label,
          onTap: action.onTap,
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
    if (task.error != null)
      ActionSheetItem(
        icon: LucideIcons.info,
        label: l10n.ttsServicesDialogErrorTitle,
        onTap: () => showCompressionErrorDetails(context, task.error!),
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

Future<void> showCompressionErrorDetails(BuildContext context, String error) =>
    _showContextContent(
      context,
      title: AppLocalizations.of(context)!.ttsServicesDialogErrorTitle,
      builder: (detailContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (PlatformUtils.isDesktopTarget)
            Text(AppLocalizations.of(context)!.ttsServicesDialogErrorTitle),
          Flexible(
            child: SingleChildScrollView(
              child: CompressionErrorNotice(
                error: error,
                initiallyExpanded: true,
              ),
            ),
          ),
          IosTextButton(
            label: AppLocalizations.of(context)!.contextTaskDismiss,
            onPressed: () => Navigator.of(detailContext).pop(),
          ),
        ],
      ),
    );

Future<void> showContextOperations(
  BuildContext context, {
  required ChatService chat,
  required String conversationId,
  required int messageLimit,
  required ValueChanged<ContextOperation> onOpenOperation,
  required ValueChanged<ContextCompressionTask> onRetry,
  required ValueChanged<ContextCompressionTask> onAdjust,
  required ValueChanged<String> onOpenConversation,
}) async {
  final service = chat.contextCompression;
  final viewedTask = service.taskFor(conversationId);
  await _showContextContent(
    context,
    title: AppLocalizations.of(context)!.contextOperationsTitle,
    builder: (panelContext) {
      void leave(VoidCallback action) {
        Navigator.of(panelContext).pop();
        action();
      }

      return ContextOperationsPanel(
        chat: chat,
        conversationId: conversationId,
        messageLimit: messageLimit,
        onOpenOperation: (operation) => leave(() => onOpenOperation(operation)),
        onRetry: (task) => leave(() => onRetry(task)),
        onAdjust: (task) => leave(() => onAdjust(task)),
        onReview: (task) => leave(
          () => showCompressionReview(
            context,
            chat: chat,
            task: task,
            onRecompress: () => onAdjust(task),
          ),
        ),
        onOpenConversation: (id) => leave(() => onOpenConversation(id)),
      );
    },
  );
  // Viewing a completed result acknowledges its notice. Do not dismiss a task
  // that still needs attention, or a replacement started from this panel.
  if (viewedTask?.phase != CompressionPhase.completed ||
      !identical(service.taskFor(conversationId), viewedTask)) {
    return;
  }
  try {
    await service.dismiss(conversationId);
  } catch (error) {
    if (context.mounted) {
      showAppSnackBar(
        context,
        message: error.toString(),
        type: NotificationType.error,
      );
    }
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
    return _estimate(chat, task.conversationId, snapshot.messages, [
      ...snapshot.operations,
      operation.copyWith(summary: summary),
    ]);
  }

  final canEdit = task.phase == CompressionPhase.review && !operation.isNative;
  if (!PlatformUtils.isDesktopTarget && canEdit) {
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
      initiallyEditing: canEdit,
      budget: task.budget,
      showHeader: PlatformUtils.isDesktopTarget,
      onClose: () => Navigator.of(detailContext).pop(),
      estimateSummary: estimate,
      onSave: canEdit ? save : null,
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
