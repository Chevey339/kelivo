import 'context_dialog.dart';
import 'compression_error_notice.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/models/context_operation.dart';
import '../../../core/models/context_operation_summary.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/chat/context_compression_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/thinking_sheen.dart';
import '../../../theme/app_font_weights.dart';
import '../../../utils/platform_utils.dart';
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
  List<ContextOperationSummary> _operations = const [];
  int _visibleLimit = 3;
  int _loadGeneration = 0;
  String? _operationsRevision;
  bool _loadingOperations = false;
  bool _operationsFailed = false;
  bool _retryAppend = false;
  bool _hasMore = false;
  bool _openingOperation = false;
  Object? _taskState;

  Object _currentTaskState() {
    final task = widget.chat.contextCompression.taskFor(widget.conversationId);
    return (
      task?.id,
      task?.phase,
      task?.completedParts,
      task?.totalParts,
      task?.requestAttempts,
      task?.unknownUsageAttempts,
      task?.usage?.promptTokens,
      task?.usage?.completionTokens,
      task?.error,
      task?.resultConversationId,
    );
  }

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
    _taskState = _currentTaskState();
    Future<ContextMessageCounts> load() async {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return (stored: 0, messages: 0, summaries: 0);
      return widget.chat.loadContextMessageCounts(
        widget.conversationId,
        limit: widget.messageLimit,
      );
    }

    // Queue the small first page before the independent conversation counts.
    _loadOperations();
    _counts = load();
  }

  Future<void> _loadOperations({bool append = false}) async {
    final generation = ++_loadGeneration;
    _loadingOperations = true;
    _operationsFailed = false;
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || generation != _loadGeneration) return;
      var page = await widget.chat.loadContextOperationPage(
        widget.conversationId,
        offset: append ? _operations.length : 0,
        limit: append ? 10 : _visibleLimit,
      );
      if (!mounted || generation != _loadGeneration) return;
      var replace = !append;
      if (append && page.revision != _operationsRevision) {
        // A database write can commit before ChatService notifies listeners.
        // Re-read the expanded window instead of mixing two offset snapshots.
        page = await widget.chat.loadContextOperationPage(
          widget.conversationId,
          offset: 0,
          limit: _operations.length + 10,
        );
        if (!mounted || generation != _loadGeneration) return;
        replace = true;
      }
      setState(() {
        _operations = replace ? page.items : [..._operations, ...page.items];
        if (append && _operations.length > _visibleLimit) {
          _visibleLimit = _operations.length;
        }
        _operationsRevision = page.revision;
        _hasMore = page.hasMore;
        _loadingOperations = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loadingOperations = false;
        _operationsFailed = true;
        _retryAppend = append;
      });
    }
  }

  Future<void> _openOperation(String id) async {
    if (_openingOperation) return;
    final chat = widget.chat;
    final conversationId = widget.conversationId;
    bool current() =>
        mounted &&
        chat == widget.chat &&
        conversationId == widget.conversationId;
    setState(() {
      _openingOperation = true;
      _error = null;
    });
    try {
      final operation = await chat.loadContextOperation(conversationId, id);
      if (!current()) return;
      if (operation == null) throw StateError('context_operation_missing');
      widget.onOpenOperation(operation);
    } catch (_) {
      if (current()) {
        setState(
          () => _error = AppLocalizations.of(
            context,
          )!.contextOperationsLoadFailed,
        );
      }
    } finally {
      if (current()) setState(() => _openingOperation = false);
    }
  }

  void _changed() {
    final revision = widget.chat.contextRevision(widget.conversationId);
    final taskState = _currentTaskState();
    if (revision == _revision && taskState == _taskState) return;
    setState(() {
      _taskState = taskState;
      if (_revision != revision) _load();
    });
  }

  @override
  void didUpdateWidget(covariant ContextOperationsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chat != widget.chat ||
        oldWidget.conversationId != widget.conversationId) {
      oldWidget.chat.removeListener(_changed);
      widget.chat.addListener(_changed);
      _operations = const [];
      _operationsRevision = null;
      _visibleLimit = 3;
      _hasMore = false;
      _openingOperation = false;
      _error = null;
      _load();
    } else if (oldWidget.messageLimit != widget.messageLimit) {
      _load();
    }
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
            CompressionErrorNotice(error: task.error!),
          ],
          Wrap(
            spacing: 8,
            children: [
              if (task.phase == CompressionPhase.review)
                IosTextButton(
                  label: l10n.contextViewGenerated,
                  onPressed: () => widget.onReview(task),
                ),
              if (task.phase == CompressionPhase.review)
                if (compressionRecoveryTarget(
                      task.error,
                      native: task.options.native,
                    )
                    case final target?)
                  IosTextButton(
                    label: target.label(l10n),
                    onPressed: () => widget.onAdjust(task),
                  ),
              if (task.phase == CompressionPhase.failed ||
                  task.phase == CompressionPhase.interrupted) ...[
                for (final action in compressionRecoveryActions(
                  l10n,
                  error: task.error,
                  native: task.options.native,
                  onRetry: () => widget.onRetry(task),
                  onAdjust: () => widget.onAdjust(task),
                ))
                  IosTextButton(label: action.label, onPressed: action.onTap),
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
        final operations = _operations;
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
                itemCount: operations.length + 3,
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
                          if (!_loadingOperations &&
                              !_operationsFailed &&
                              operations.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(l10n.contextOperationsEmpty),
                            ),
                        ],
                      ),
                    );
                  }
                  if (index == operations.length + 2) {
                    return Column(
                      children: [
                        if (_error != null && !showTask)
                          Text(_error!, style: TextStyle(color: cs.error)),
                        if (_loadingOperations)
                          Text(l10n.contextLogLoading)
                        else if (_operationsFailed) ...[
                          Text(
                            l10n.contextOperationsLoadFailed,
                            style: TextStyle(color: cs.error),
                          ),
                          IosTextButton(
                            label: l10n.compressTaskRetry,
                            onPressed: () => setState(() {
                              _loadOperations(append: _retryAppend);
                            }),
                          ),
                        ] else if (_hasMore)
                          IosTextButton(
                            key: const ValueKey('context-operations-load-more'),
                            label: l10n.contextOperationsLoadMore,
                            onPressed: () {
                              if (_loadingOperations) return;
                              setState(() {
                                _loadOperations(append: true);
                              });
                            },
                          ),
                      ],
                    );
                  }
                  final operation = operations[index - 2];
                  final status = operation.revoked
                      ? l10n.contextOperationUndone
                      : operation.hidden
                      ? l10n.contextOperationHidden
                      : operation.superseded
                      ? l10n.contextOperationSuperseded
                      : l10n.contextOperationActive;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: IosCardPress(
                      key: ValueKey('context-operation-${operation.id}'),
                      onTap: _openingOperation
                          ? null
                          : () => _openOperation(operation.id),
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
                              operation.summaryPreview,
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
