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

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: _viewportFraction);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  bool get _isDesktop => PlatformUtils.isDesktop;

  double get _viewportFraction => _isDesktop ? 1.0 : 0.85;

  @override
  Widget build(BuildContext context) {
    final subgroups = widget.subgroupedMessages.keys.toList();
    if (subgroups.isEmpty) return const SizedBox.shrink();

    final pageCount = _isDesktop
        ? (subgroups.length / 2).ceil()
        : subgroups.length;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.65,
      child: PageView.builder(
        controller: _pageCtrl,
        itemCount: pageCount,
        itemBuilder: (context, pageIndex) {
          if (_isDesktop) {
            return _buildDesktopPage(subgroups, pageIndex);
          }
          return _buildMobileCard(subgroups, pageIndex);
        },
      ),
    );
  }

  Widget _buildDesktopPage(List<String> subgroups, int pageIndex) {
    final i1 = pageIndex * 2;
    final i2 = i1 + 1;
    final hasSecond = i2 < subgroups.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(child: _buildCardForSubgroup(subgroups[i1])),
          if (hasSecond) ...[
            const SizedBox(width: 8),
            Expanded(child: _buildCardForSubgroup(subgroups[i2])),
          ] else
            const Spacer(),
        ],
      ),
    );
  }

  Widget _buildMobileCard(List<String> subgroups, int index) {
    final sgId = subgroups[index];
    final card = _buildCardForSubgroup(sgId);

    return Padding(
      padding: EdgeInsets.only(
        right: index < subgroups.length - 1 ? 8 : 0,
        left: index > 0 ? 8 : 0,
      ),
      child: card,
    );
  }

  Widget _buildCardForSubgroup(String sgId) {
    final versions = widget.subgroupedMessages[sgId] ?? [];
    final latest = versions.isNotEmpty ? versions.last : null;
    if (latest == null) return const SizedBox.shrink();

    return _SingleModelCard(
      message: latest,
      anchorUserMessageId: widget.anchorUserMessageId,
      controller: widget.controller,
      showActions: widget.isLatestRound,
      subgroupId: sgId,
    );
  }
}

class _SingleModelCard extends StatelessWidget {
  const _SingleModelCard({
    required this.message,
    required this.anchorUserMessageId,
    required this.controller,
    required this.showActions,
    required this.subgroupId,
  });

  final ChatMessage message;
  final String anchorUserMessageId;
  final HomePageController controller;
  final bool showActions;
  final String subgroupId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

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
                if (showActions) ...[
                  _ActionBtn(
                    icon: Lucide.X,
                    color: cs.error,
                    tooltip: l10n.multiAIDropThread,
                    onTap: () =>
                        controller.multiAIEngine.dropThread(subgroupId),
                  ),
                  const SizedBox(width: 4),
                  _ActionBtn(
                    icon: Lucide.Check,
                    color: cs.primary,
                    tooltip: l10n.multiAIAdoptVersion,
                    onTap: () => controller.multiAIEngine.resolveThread(
                      anchorId: anchorUserMessageId,
                      threadId: subgroupId,
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
            versionIndex: null,
            versionCount: null,
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
                  threadId: subgroupId,
                  anchorUserMsgId: anchorUserMessageId,
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
