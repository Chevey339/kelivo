import 'package:flutter/material.dart';
import '../../../core/models/chat_message.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_font_weights.dart';
import '../../../utils/platform_utils.dart';
import '../../chat/widgets/chat_message_widget.dart'
    show ChatMessageWidget, ReasoningSegment;
import '../../chat/widgets/message_more_sheet.dart'
    show showMessageMoreSheet, MessageMoreAction;

import '../controllers/home_page_controller.dart';

/// Card container for a single multi-AI round (anchor).
/// Shows N model responses in a PageView with Resolve/Drop at top-right.
class MultiAICardGroup extends StatefulWidget {
  const MultiAICardGroup({
    super.key,
    required this.anchorUserMessageId,
    required this.subgroupedMessages,
    required this.controller,
    this.isLatestRound = false,
  });

  final String anchorUserMessageId;
  final Map<String, List<ChatMessage>> subgroupedMessages;
  final HomePageController controller;
  final bool isLatestRound;

  @override
  State<MultiAICardGroup> createState() => _MultiAICardGroupState();
}

class _MultiAICardGroupState extends State<MultiAICardGroup> {
  late PageController _pageCtrl;
  int _activePage = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: _viewportFraction)
      ..addListener(_onPageChanged);
  }

  @override
  void dispose() {
    for (final sgId in widget.subgroupedMessages.keys) {
      _SingleModelCardState.clearSelection(sgId);
    }
    _pageCtrl.removeListener(_onPageChanged);
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onPageChanged() {
    final page = _pageCtrl.page?.round() ?? 0;
    if (page != _activePage) setState(() => _activePage = page);
  }

  double get _viewportFraction => PlatformUtils.isDesktop ? 0.5 : 0.85;

  @override
  Widget build(BuildContext context) {
    final subgroups = widget.subgroupedMessages.keys.toList();
    if (subgroups.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.65,
      child: PageView.builder(
        controller: _pageCtrl,
        itemCount: subgroups.length,
        itemBuilder: (context, index) {
          final sgId = subgroups[index];
          final versions = widget.subgroupedMessages[sgId] ?? [];
          if (versions.isEmpty) return const SizedBox.shrink();

          return Padding(
            padding: EdgeInsets.only(
              right: index < subgroups.length - 1 ? 8 : 0,
              left: index > 0 ? 8 : 0,
            ),
            child: _SingleModelCard(
              key: ValueKey('single-model-$sgId'),
              versions: versions,
              anchorUserMessageId: widget.anchorUserMessageId,
              controller: widget.controller,
              showActions: widget.isLatestRound,
              subgroupId: sgId,
            ),
          );
        },
      ),
    );
  }
}

class _SingleModelCard extends StatefulWidget {
  const _SingleModelCard({
    super.key,
    required this.versions,
    required this.anchorUserMessageId,
    required this.controller,
    required this.showActions,
    required this.subgroupId,
  });

  final List<ChatMessage> versions;
  final String anchorUserMessageId;
  final HomePageController controller;
  final bool showActions;
  final String subgroupId;

  @override
  State<_SingleModelCard> createState() => _SingleModelCardState();
}

class _SingleModelCardState extends State<_SingleModelCard> {
  static final Map<String, int> _selectedIdxByThread = {};

  int get _selectedIdx {
    final stored = _selectedIdxByThread[widget.subgroupId];
    if (stored != null && stored >= 0 && stored < widget.versions.length) {
      return stored;
    }
    return widget.versions.length - 1;
  }

  ChatMessage get _currentMessage => widget.versions[_selectedIdx];

  void _selectVersion(int idx) {
    if (idx < 0 || idx >= widget.versions.length) return;
    _selectedIdxByThread[widget.subgroupId] = idx;
    setState(() {});
  }

  static void clearSelection(String subgroupId) {
    _selectedIdxByThread.remove(subgroupId);
  }

  @override
  void didUpdateWidget(covariant _SingleModelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldLen = oldWidget.versions.length;
    final newLen = widget.versions.length;
    final subgId = widget.subgroupId;

    if (newLen > oldLen) {
      _selectedIdxByThread[subgId] = newLen - 1;
      setState(() {});
    } else if (newLen < oldLen) {
      final stillExists = widget.versions.any(
        (v) => v.id == oldWidget.versions[_selectedIdx].id,
      );
      if (!stillExists) {
        _selectedIdxByThread[subgId] = newLen - 1;
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final message = _currentMessage;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              border: Border(
                bottom: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    message.modelId ?? message.providerId ?? 'AI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: AppFontWeights.medium,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
                if (message.isStreaming) ...[
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                ],
                const Spacer(),
                if (widget.showActions) ...[
                  _ActionBtn(
                    icon: Lucide.X,
                    color: cs.error,
                    tooltip: l10n.multiAIDropThread,
                    onTap: () => widget.controller.multiAIEngine.dropThread(
                      widget.subgroupId,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _ActionBtn(
                    icon: Lucide.Check,
                    color: cs.primary,
                    tooltip: l10n.multiAIAdoptVersion,
                    onTap: () => widget.controller.multiAIEngine.resolveThread(
                      anchorId: widget.anchorUserMessageId,
                      threadId: widget.subgroupId,
                      version: message.version,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Content
          Expanded(child: _buildContent(context)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final controller = widget.controller;
    final message = _currentMessage;
    final reasoning = controller.reasoning[message.id];
    final reasoningSegments = controller.reasoningSegments[message.id];
    final notifier = controller.streamingContentNotifier.getNotifier(
      message.id,
    );
    final hasReasoning =
        message.reasoningText != null && message.reasoningText!.isNotEmpty;

    return AnimatedBuilder(
      animation: notifier,
      builder: (context, _) {
        final data = notifier.value;
        final mergedContent = data.content.isNotEmpty
            ? data.content
            : message.content;
        final mergedReasoning =
            (data.reasoningText != null && data.reasoningText!.isNotEmpty)
            ? data.reasoningText
            : (reasoning?.text ?? message.reasoningText);
        final streamingMsg = message.copyWith(
          content: mergedContent,
          totalTokens: data.totalTokens > 0
              ? data.totalTokens
              : message.totalTokens,
          reasoningText: mergedReasoning,
        );
        final segments = reasoningSegments
            ?.map(
              (s) => ReasoningSegment(
                text: s.text,
                expanded: s.expanded,
                loading:
                    message.isStreaming &&
                    s.finishedAt == null &&
                    s.text.isNotEmpty,
                startAt: s.startAt,
                finishedAt: s.finishedAt,
                toolStartIndex: s.toolStartIndex,
                onToggle: () {
                  final idx = controller.reasoningSegments[message.id]?.indexOf(
                    s,
                  );
                  if (idx != null && idx >= 0) {
                    controller.toggleReasoningSegment(message.id, idx);
                  }
                },
              ),
            )
            .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: ChatMessageWidget(
            message: streamingMsg,
            showTokenStats: false,
            showModelIcon: false,
            versionIndex: _selectedIdx,
            versionCount: widget.versions.length,
            onPrevVersion: _selectedIdx > 0
                ? () => _selectVersion(_selectedIdx - 1)
                : null,
            onNextVersion: _selectedIdx < widget.versions.length - 1
                ? () => _selectVersion(_selectedIdx + 1)
                : null,
            reasoningText: mergedReasoning,
            reasoningExpanded: reasoning?.expanded ?? false,
            reasoningLoading:
                message.isStreaming &&
                reasoning != null &&
                reasoning.finishedAt == null,
            reasoningStartAt: reasoning?.startAt,
            reasoningFinishedAt: reasoning?.finishedAt,
            onToggleReasoning: hasReasoning
                ? () => controller.toggleReasoning(message.id)
                : null,
            reasoningSegments: segments,
            toolParts: controller.toolParts[message.id],
            contentSplitOffsets: controller.contentSplits[message.id]?.offsets,
            reasoningCountAtSplit:
                controller.contentSplits[message.id]?.reasoningCounts,
            toolCountAtSplit: controller.contentSplits[message.id]?.toolCounts,
            onRegenerate: () {
              if (controller.multiAIEngine.isActive) {
                controller.retryMultiAIThread(
                  threadId: widget.subgroupId,
                  anchorUserMsgId: widget.anchorUserMessageId,
                  message: streamingMsg,
                );
              } else {
                controller.regenerateAtMessage(streamingMsg);
              }
            },
            onTranslate: () => controller.translateMessage(streamingMsg),
            onSpeak: () => controller.speakMessage(streamingMsg),
            onMore: () async {
              final action = await showMessageMoreSheet(
                context,
                streamingMsg,
                canDeleteAllVersions: false,
                hideActions: {
                  MessageMoreAction.share,
                  MessageMoreAction.selectMessages,
                  MessageMoreAction.multiAI,
                },
              );
              if (action == MessageMoreAction.fork) {
                await controller.forkConversation(streamingMsg);
              } else if (action == MessageMoreAction.deleteCurrentVersion) {
                await controller.deleteMessage(
                  message: streamingMsg,
                  byGroup: controller.chatController.groupedMessages,
                );
              } else if (action == MessageMoreAction.edit) {
                await controller.editMessage(streamingMsg);
              }
            },
          ),
        );
      },
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        debugPrint('[MultiAI][_ActionBtn] tapped: $tooltip');
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}
