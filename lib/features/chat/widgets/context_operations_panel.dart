import 'context_dialog.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/models/context_operation.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/chat/context_compression_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/thinking_sheen.dart';
import '../../../theme/app_font_weights.dart';
import '../../../utils/platform_utils.dart';
import '../../../utils/utf16_safe_cut.dart';
import 'context_compression_status.dart';

/// Stays outside the locked composer and the loaded history window.
class ContextTaskBar extends StatelessWidget {
  const ContextTaskBar({
    super.key,
    required this.conversationId,
    required this.onOpen,
  });
  final String conversationId;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final (phase, _, resultId) = context
        .select<ChatService?, (CompressionPhase?, String?, String?)>((chat) {
          final task = chat?.contextCompression.taskFor(conversationId);
          return (task?.phase, task?.error, task?.resultConversationId);
        });
    if (phase == null ||
        (phase == CompressionPhase.completed && resultId == null) ||
        phase == CompressionPhase.cancelled) {
      return const SizedBox.shrink();
    }
    final task = context.read<ChatService>().contextCompression.taskFor(
      conversationId,
    )!;
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final status = contextTaskIndicator(task, inputPaused: false);
    final running = status == ContextTaskIndicator.running;
    final label = compressionStatusLabel(l10n, task);
    final color = status == ContextTaskIndicator.failed
        ? cs.error
        : cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Semantics(
        button: true,
        liveRegion: true,
        label: label,
        hint: l10n.contextOperationsTitle,
        onTap: onOpen,
        excludeSemantics: true,
        child: Tooltip(
          message: l10n.contextOperationsTitle,
          excludeFromSemantics: true,
          child: IosCardPress(
            key: const ValueKey('context-task-bar'),
            onTap: onOpen,
            focusable: true,
            baseColor: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: PlatformUtils.isDesktopTarget ? 20 : 36,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    phase == CompressionPhase.completed
                        ? LucideIcons.gitBranch
                        : switch (status) {
                            ContextTaskIndicator.failed =>
                              LucideIcons.circleAlert,
                            ContextTaskIndicator.paused => LucideIcons.pause,
                            _ => LucideIcons.package,
                          },
                    size: 14,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: ThinkingSheen(
                      enabled: running,
                      color: color,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: AppFontWeights.medium,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(LucideIcons.chevronRight, size: 14, color: color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reads operation metadata independently of the timeline's loaded messages.
class ContextOperationsPanel extends StatefulWidget {
  const ContextOperationsPanel({
    super.key,
    required this.chat,
    required this.conversationId,
    required this.messageLimit,
    required this.onOpenOperation,
    required this.onRetry,
    required this.onAdjust,
    required this.onReview,
    required this.onOpenConversation,
  });
  final ChatService chat;
  final String conversationId;
  final int messageLimit;
  final ValueChanged<ContextOperation> onOpenOperation;
  final ValueChanged<ContextCompressionTask> onRetry;
  final ValueChanged<ContextCompressionTask> onAdjust;
  final ValueChanged<ContextCompressionTask> onReview;
  final ValueChanged<String> onOpenConversation;

  @override
  State<ContextOperationsPanel> createState() => _ContextOperationsPanelState();
}

class _ContextOperationsPanelState extends State<ContextOperationsPanel> {
  late Future<ContextMessageCounts> _counts;
  late int _revision;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    widget.chat.addListener(_changed);
  }

  void _load() {
    _revision = widget.chat.contextRevision(widget.conversationId);
    _counts = widget.chat.loadContextMessageCounts(
      widget.conversationId,
      limit: widget.messageLimit,
    );
  }

  void _changed() {
    setState(() {
      if (_revision != widget.chat.contextRevision(widget.conversationId)) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    widget.chat.removeListener(_changed);
    super.dispose();
  }

  Future<void> _stop(ContextCompressionTask task) async {
    if (_busy ||
        widget.chat.contextCompression.taskFor(widget.conversationId)?.id !=
            task.id) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = widget.chat.contextCompression;
      if (task.active) {
        await service.cancel(widget.conversationId);
      } else {
        await service.dismiss(widget.conversationId);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _task(ContextCompressionTask task) {
    final l10n = AppLocalizations.of(context)!;
    return SectionCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            compressionStatusLabel(l10n, task),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (task.requestAttempts > 0)
            Text(l10n.compressionCalls(task.requestAttempts)),
          if (task.usage != null)
            Text(
              l10n.compressionUsageValues(
                contextTokenValue(task.usage!.promptTokens),
                contextTokenValue(task.usage!.completionTokens),
              ),
            ),
          if (task.unknownUsageAttempts > 0)
            Text(l10n.compressionUsageUnknown(task.unknownUsageAttempts)),
          if (task.error != null) ...[
            const SizedBox(height: 6),
            Text(
              compressionErrorLabel(l10n, task.error!),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          Wrap(
            spacing: 8,
            children: [
              if (task.phase == CompressionPhase.review)
                IosTextButton(
                  label: l10n.compressAdjust,
                  onPressed: () => widget.onReview(task),
                ),
              if (task.phase == CompressionPhase.failed ||
                  task.phase == CompressionPhase.interrupted) ...[
                IosTextButton(
                  label: l10n.compressTaskRetry,
                  onPressed: () => widget.onRetry(task),
                ),
                IosTextButton(
                  label: l10n.compressTaskAdjustRetry,
                  onPressed: () => widget.onAdjust(task),
                ),
              ],
              if (task.resultConversationId != null)
                IosTextButton(
                  label: l10n.contextOpenNewChat,
                  onPressed: () =>
                      widget.onOpenConversation(task.resultConversationId!),
                ),
              if (task.phase != CompressionPhase.applying &&
                  task.phase != CompressionPhase.completed)
                IosTextButton(
                  label: task.active
                      ? l10n.contextTaskCancel
                      : l10n.contextTaskDismiss,
                  onPressed: _busy ? null : () => _stop(task),
                ),
            ],
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final task = widget.chat.contextCompression.taskFor(widget.conversationId);
    final showTask =
        task != null &&
        (compressionShowsDivider(task) || task.resultConversationId != null);
    return FutureBuilder<ContextMessageCounts>(
      future: _counts,
      builder: (context, snapshot) {
        final operations = widget.chat.contextOperationsFor(
          widget.conversationId,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (PlatformUtils.isDesktopTarget)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.contextOperationsTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IosIconButton(
                    icon: LucideIcons.x,
                    semanticLabel: l10n.commonClose,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(12),
                itemCount: operations.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return showTask ? _task(task) : const SizedBox.shrink();
                  }
                  if (index == 1) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (snapshot.connectionState ==
                                  ConnectionState.done &&
                              snapshot.hasData) ...[
                            Text(
                              l10n.contextOperationsStored(
                                snapshot.data!.stored,
                              ),
                            ),
                            Text(
                              l10n.contextOperationsEffective(
                                snapshot.data!.summaries,
                                snapshot.data!.messages,
                              ),
                            ),
                          ],
                          Text(
                            l10n.contextOperationsScope,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          if (snapshot.hasError) ...[
                            Text(
                              l10n.contextOperationsLoadFailed,
                              style: TextStyle(color: cs.error),
                            ),
                            IosTextButton(
                              label: l10n.compressTaskRetry,
                              onPressed: () => setState(_load),
                            ),
                          ],
                          if (snapshot.connectionState ==
                                  ConnectionState.done &&
                              !snapshot.hasError &&
                              operations.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(l10n.contextOperationsEmpty),
                            ),
                        ],
                      ),
                    );
                  }
                  final operation =
                      operations[operations.length - (index - 2) - 1];
                  final hidden = operations
                      .skipWhile((op) => op.id != operation.id)
                      .skip(1)
                      .any(
                        (op) =>
                            !op.revoked &&
                            (op.isFixedStart ||
                                (op.isClear &&
                                    op.sourceGroups.contains(
                                      operation.anchorGroupId,
                                    ))),
                      );
                  final superseded =
                      operation.isCompression &&
                      operations.any(
                        (op) =>
                            !op.revoked &&
                            op.dependencies.contains(operation.id),
                      );
                  final status = operation.revoked
                      ? l10n.contextOperationUndone
                      : hidden
                      ? l10n.contextOperationHidden
                      : superseded
                      ? l10n.contextOperationSuperseded
                      : l10n.contextOperationActive;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: IosCardPress(
                      key: ValueKey('context-operation-${operation.id}'),
                      onTap: () => widget.onOpenOperation(operation),
                      baseColor: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            operation.isFixedStart
                                ? l10n.contextFixedStart
                                : operation.isCompression
                                ? operation.isNative
                                      ? operation.isImportedNative
                                            ? l10n.compressionNativeImported
                                            : l10n.compressionNativeLabel
                                      : l10n.contextDividerCompressed
                                : l10n.contextDetailClearTitle,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            '${MaterialLocalizations.of(context).formatShortDate(operation.createdAt.toLocal())} · $status',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          if (operation.isCompression &&
                              !operation.isNative) ...[
                            const SizedBox(height: 6),
                            Text(
                              truncateHeadUtf16Safe(operation.summary, 240),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
