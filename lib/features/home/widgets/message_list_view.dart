import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scrollview_observer/scrollview_observer.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../chat/widgets/chat_message_widget.dart';
import '../../chat/widgets/message_more_sheet.dart';
import '../controllers/stream_controller.dart' as stream_ctrl;
import '../controllers/streaming_content_notifier.dart';
import '../services/ask_user_interaction_service.dart';
import '../utils/chat_layout_constants.dart';
import 'model_icon.dart';

/// Callback types for message list view actions
typedef OnVersionChange = Future<void> Function(String groupId, int version);
typedef OnRegenerateMessage = void Function(ChatMessage message);
typedef OnResendMessage = void Function(ChatMessage message);
typedef OnTranslateMessage = void Function(ChatMessage message);
typedef OnEditMessage = void Function(ChatMessage message);
typedef OnDeleteMessage =
    Future<void> Function(
      ChatMessage message,
      Map<String, List<ChatMessage>> byGroup,
    );
typedef OnDeleteAllVersions =
    Future<void> Function(
      ChatMessage message,
      Map<String, List<ChatMessage>> byGroup,
    );
typedef OnForkConversation = Future<void> Function(ChatMessage message);
typedef OnShareMessage =
    void Function(int messageIndex, List<ChatMessage> messages);
typedef OnSpeakMessage = Future<void> Function(ChatMessage message);
typedef OnSuggestionTap = void Function(String suggestion);
typedef OnRecoveredAskUserAnswer =
    Future<void> Function(
      ChatMessage message,
      ToolUIPart part,
      AskUserResult result,
    );

/// Data class for reasoning UI state
class ReasoningUiState {
  final String? text;
  final bool expanded;
  final bool loading;
  final DateTime? startAt;
  final DateTime? finishedAt;
  final VoidCallback? onToggle;

  const ReasoningUiState({
    this.text,
    this.expanded = false,
    this.loading = false,
    this.startAt,
    this.finishedAt,
    this.onToggle,
  });
}

/// Data class for translation UI state
class TranslationUiState {
  final bool expanded;
  final VoidCallback? onToggle;

  const TranslationUiState({this.expanded = true, this.onToggle});
}

/// Widget that displays the chat message list.
///
/// Accepts pre-collapsed messages and pre-computed byGroup from the controller
/// to avoid redundant computation on every build. Wraps the ListView with
/// ListViewObserver for precise index-based scroll navigation.
class MessageListView extends StatelessWidget {
  const MessageListView({
    super.key,
    required this.scrollController,
    required this.observerController,
    required this.messages,
    required this.byGroup,
    required this.versionSelections,
    this.truncCollapsedIndex = -1,
    required this.reasoning,
    required this.reasoningSegments,
    required this.contentSplits,
    required this.toolParts,
    required this.translations,
    required this.selecting,
    required this.selectedItems,
    required this.dividerPadding,
    this.bottomContentPadding = 16,
    this.pinnedStreamingMessageId,
    this.isPinnedIndicatorActive = false,
    required this.isProcessingFiles,
    this.streamingContentNotifier,
    this.spotlightMessageId,
    this.spotlightToken = 0,
    this.onVersionChange,
    this.onRegenerateMessage,
    this.onResendMessage,
    this.onTranslateMessage,
    this.onEditMessage,
    this.onDeleteMessage,
    this.onDeleteAllVersions,
    this.onForkConversation,
    this.onShareMessage,
    this.onSpeakMessage,
    this.suggestions = const <String>[],
    this.onSuggestionTap,
    this.onRecoveredAskUserAnswer,
    this.onToggleSelection,
    this.onToggleReasoning,
    this.onToggleTranslation,
    this.onToggleReasoningSegment,
    this.buildPinnedStreamingIndicator,
  });

  final ScrollController scrollController;
  final ListObserverController observerController;

  /// Pre-collapsed messages (from ChatController.collapsedMessages).
  final List<ChatMessage> messages;

  /// All messages grouped by groupId (from ChatController.groupedMessages).
  final Map<String, List<ChatMessage>> byGroup;

  /// Selected version per message group (for version navigation controls).
  final Map<String, int> versionSelections;

  /// Pre-computed truncate index in collapsed message space (-1 = none).
  final int truncCollapsedIndex;

  final Map<String, stream_ctrl.ReasoningData> reasoning;
  final Map<String, List<stream_ctrl.ReasoningSegmentData>> reasoningSegments;
  final Map<String, stream_ctrl.ContentSplitData> contentSplits;
  final Map<String, List<ToolUIPart>> toolParts;
  final Map<String, TranslationUiState> translations;
  final bool selecting;
  final Set<String> selectedItems;
  final EdgeInsetsGeometry dividerPadding;
  final double bottomContentPadding;
  final String? pinnedStreamingMessageId;
  final bool isPinnedIndicatorActive;
  final ValueNotifier<bool> isProcessingFiles;

  /// Lightweight notifier for streaming content updates.
  /// When provided, streaming messages will use ValueListenableBuilder
  /// to avoid full page rebuilds.
  final StreamingContentNotifier? streamingContentNotifier;

  /// When set, the message with this ID will receive a spotlight pulse animation.
  final String? spotlightMessageId;

  /// Incremented each time a new spotlight is triggered. Used as an animation key
  /// so re-selecting the same message re-triggers the pulse.
  final int spotlightToken;

  // Callbacks
  final OnVersionChange? onVersionChange;
  final OnRegenerateMessage? onRegenerateMessage;
  final OnResendMessage? onResendMessage;
  final OnTranslateMessage? onTranslateMessage;
  final OnEditMessage? onEditMessage;
  final OnDeleteMessage? onDeleteMessage;
  final OnDeleteAllVersions? onDeleteAllVersions;
  final OnForkConversation? onForkConversation;
  final OnShareMessage? onShareMessage;
  final OnSpeakMessage? onSpeakMessage;
  final List<String> suggestions;
  final OnSuggestionTap? onSuggestionTap;
  final OnRecoveredAskUserAnswer? onRecoveredAskUserAnswer;
  final void Function(String messageId, bool selected)? onToggleSelection;
  final void Function(String messageId)? onToggleReasoning;
  final void Function(String messageId)? onToggleTranslation;
  final void Function(String messageId, int segmentIndex)?
  onToggleReasoningSegment;
  final Widget Function()? buildPinnedStreamingIndicator;

  /// Build the context divider widget shown at truncate position.
  Widget _buildContextDivider(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final label = l10n.homePageClearContext;
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: cs.outlineVariant.withValues(alpha: 0.6),
            height: 1,
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: cs.outlineVariant.withValues(alpha: 0.6),
            height: 1,
            thickness: 1,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPad =
            ((constraints.maxWidth - ChatLayoutConstants.maxContentWidth) / 2)
                .clamp(0.0, double.infinity);

        return ValueListenableBuilder<bool>(
          valueListenable: isProcessingFiles,
          builder: (context, isProcessing, child) {
            final list = ListView.builder(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                horizontalPad,
                8,
                horizontalPad,
                bottomContentPadding + (isPinnedIndicatorActive ? 12 : 0),
              ),
              itemCount: messages.length,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemBuilder: (context, index) {
                if (index < 0 || index >= messages.length) {
                  return const SizedBox.shrink();
                }
                return _buildMessageItem(
                  context,
                  index: index,
                  isProcessingFiles: isProcessing,
                );
              },
            );

            final observedList = ListViewObserver(
              controller: observerController,
              child: list,
            );

            return Stack(
              children: [
                observedList,
                if (isPinnedIndicatorActive &&
                    buildPinnedStreamingIndicator != null)
                  buildPinnedStreamingIndicator!(),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMessageItem(
    BuildContext context, {
    required int index,
    required bool isProcessingFiles,
  }) {
    final message = messages[index];
    final r = reasoning[message.id];
    final t = translations[message.id];
    final chatScale = context.watch<SettingsProvider>().chatFontScale;
    final assistant = context.watch<AssistantProvider>().currentAssistant;
    final useAssistAvatar = assistant?.useAssistantAvatar == true;
    final useAssistName = assistant?.useAssistantName == true;
    final showDivider =
        truncCollapsedIndex >= 0 && index == truncCollapsedIndex;
    final gid = (message.groupId ?? message.id);
    final vers = (byGroup[gid] ?? const <ChatMessage>[]).toList()
      ..sort((a, b) => a.version.compareTo(b.version));
    int selectedIdx =
        versionSelections[gid] ?? (vers.isNotEmpty ? vers.length - 1 : 0);
    final total = vers.length;
    if (selectedIdx < 0) selectedIdx = 0;
    if (total > 0 && selectedIdx > total - 1) selectedIdx = total - 1;
    final latestAssistantIndex = _latestAssistantMessageIndex();
    final messageSuggestions =
        !selecting &&
            index == latestAssistantIndex &&
            message.role == 'assistant' &&
            !message.isStreaming &&
            onSuggestionTap != null
        ? suggestions
        : const <String>[];

    // Check if this is a streaming message that should use ValueListenableBuilder
    final isStreaming =
        message.isStreaming &&
        message.role == 'assistant' &&
        streamingContentNotifier != null &&
        streamingContentNotifier!.hasNotifier(message.id);

    final messageColumn = Column(
      key: ValueKey(message.id),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selecting &&
                (message.role == 'user' || message.role == 'assistant'))
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 6),
                child: IosCheckbox(
                  value: selectedItems.contains(message.id),
                  size: 20,
                  hitTestSize: 28,
                  onChanged: (v) {
                    onToggleSelection?.call(message.id, v);
                  },
                ),
              ),
            Expanded(
              child: (() {
                Widget content = Builder(
                  builder: (context) {
                    final baseMediaQuery = context
                        .getInheritedWidgetOfExactType<MediaQuery>();
                    final baseData = baseMediaQuery?.data;
                    final data = baseData ?? MediaQuery.of(context);
                    final textScale = data.textScaler.scale(1);
                    return MediaQuery(
                      // Keep chat font scaling without rebuilding on keyboard insets.
                      data: data.copyWith(
                        textScaler: TextScaler.linear(textScale * chatScale),
                      ),
                      child: isStreaming
                          ? _buildStreamingMessageWidget(
                              context,
                              message: message,
                              index: index,
                              r: r,
                              t: t,
                              useAssistAvatar: useAssistAvatar,
                              useAssistName: useAssistName,
                              assistant: assistant,
                              gid: gid,
                              selectedIdx: selectedIdx,
                              total: total,
                              isProcessingFiles: isProcessingFiles,
                              suggestions: messageSuggestions,
                            )
                          : _buildChatMessageWidget(
                              context,
                              message: message,
                              index: index,
                              r: r,
                              t: t,
                              useAssistAvatar: useAssistAvatar,
                              useAssistName: useAssistName,
                              assistant: assistant,
                              gid: gid,
                              selectedIdx: selectedIdx,
                              total: total,
                              isProcessingFiles: isProcessingFiles,
                              suggestions: messageSuggestions,
                            ),
                    );
                  },
                );

                final canSelect =
                    (message.role == 'user' || message.role == 'assistant');
                if (selecting && canSelect) {
                  final isSelected = selectedItems.contains(message.id);
                  content = GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        onToggleSelection?.call(message.id, !isSelected),
                    child: IgnorePointer(ignoring: true, child: content),
                  );
                }

                return content;
              })(),
            ),
          ],
        ),
        if (showDivider)
          Padding(
            padding: dividerPadding,
            child: _buildContextDivider(context),
          ),
      ],
    );

    final isSpotlight =
        spotlightMessageId != null && message.id == spotlightMessageId;
    if (!isSpotlight) return messageColumn;

    return TweenAnimationBuilder<double>(
      key: ValueKey('spotlight-$spotlightToken'),
      tween: Tween<double>(begin: 1.0, end: 0.0),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOut,
      builder: (context, opacity, child) {
        return Stack(
          children: [
            child!,
            if (opacity > 0.0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFFFA726,
                      ).withValues(alpha: opacity * 0.30),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: messageColumn,
    );
  }

  int _latestAssistantMessageIndex() {
    for (var i = messages.length - 1; i >= 0; i--) {
      final message = messages[i];
      if (message.role == 'assistant' && !message.isStreaming) return i;
    }
    return -1;
  }

  /// Build a streaming message widget that uses ValueListenableBuilder
  /// to avoid full page rebuilds during streaming.
  Widget _buildStreamingMessageWidget(
    BuildContext context, {
    required ChatMessage message,
    required int index,
    required stream_ctrl.ReasoningData? r,
    required TranslationUiState? t,
    required bool useAssistAvatar,
    required bool useAssistName,
    required dynamic assistant,
    required String gid,
    required int selectedIdx,
    required int total,
    required bool isProcessingFiles,
    required List<String> suggestions,
  }) {
    return ValueListenableBuilder<StreamingContentData>(
      valueListenable: streamingContentNotifier!.getNotifier(message.id),
      builder: (context, data, child) {
        // Use streaming content if available, otherwise fall back to message content
        final displayContent = data.content.isNotEmpty
            ? data.content
            : message.content;
        final displayTokens = data.totalTokens > 0
            ? data.totalTokens
            : message.totalTokens;

        // Create a modified message with streaming content
        final streamingMessage = message.copyWith(
          content: displayContent,
          totalTokens: displayTokens,
          promptTokens: data.promptTokens,
          completionTokens: data.completionTokens,
          cachedTokens: data.cachedTokens,
          durationMs: data.durationMs,
        );

        // Update reasoning text from streaming data while preserving expanded state from r
        // This allows user to toggle expanded state during streaming without it being reset
        stream_ctrl.ReasoningData? streamingReasoning = r;
        if (data.reasoningText != null && data.reasoningText!.isNotEmpty) {
          if (r != null) {
            r.text = data.reasoningText!;
            r.startAt = data.reasoningStartAt;
            if (data.reasoningFinishedAt != null) {
              r.finishedAt = data.reasoningFinishedAt;
            }
            streamingReasoning = r;
          } else {
            streamingReasoning = stream_ctrl.ReasoningData()
              ..text = data.reasoningText!
              ..startAt = data.reasoningStartAt
              ..finishedAt = data.reasoningFinishedAt
              ..expanded = false;
          }
        }

        // Wrap in RepaintBoundary to isolate repaints from affecting other widgets
        return RepaintBoundary(
          child: _buildChatMessageWidget(
            context,
            message: streamingMessage,
            index: index,
            r: streamingReasoning,
            t: t,
            useAssistAvatar: useAssistAvatar,
            useAssistName: useAssistName,
            assistant: assistant,
            gid: gid,
            selectedIdx: selectedIdx,
            total: total,
            isProcessingFiles: isProcessingFiles,
            suggestions: suggestions,
          ),
        );
      },
    );
  }

  /// Build the actual ChatMessageWidget with all its properties.
  Widget _buildChatMessageWidget(
    BuildContext context, {
    required ChatMessage message,
    required int index,
    required stream_ctrl.ReasoningData? r,
    required TranslationUiState? t,
    required bool useAssistAvatar,
    required bool useAssistName,
    required dynamic assistant,
    required String gid,
    required int selectedIdx,
    required int total,
    required bool isProcessingFiles,
    required List<String> suggestions,
  }) {
    return ChatMessageWidget(
      message: message,
      versionIndex: selectedIdx,
      versionCount: total > 0 ? total : 1,
      onPrevVersion: (selectedIdx > 0)
          ? () => onVersionChange?.call(gid, selectedIdx - 1)
          : null,
      onNextVersion: (selectedIdx < total - 1)
          ? () => onVersionChange?.call(gid, selectedIdx + 1)
          : null,
      modelIcon:
          (!useAssistAvatar &&
              message.role == 'assistant' &&
              message.providerId != null &&
              message.modelId != null)
          ? CurrentModelIcon(
              providerKey: message.providerId,
              modelId: message.modelId,
              size: 30,
            )
          : null,
      showModelIcon: useAssistAvatar
          ? false
          : context.watch<SettingsProvider>().showModelIcon,
      useAssistantAvatar: useAssistAvatar && message.role == 'assistant',
      useAssistantName: useAssistName && message.role == 'assistant',
      assistantName: (useAssistAvatar || useAssistName)
          ? (assistant?.name ?? 'Assistant')
          : null,
      assistantAvatar: useAssistAvatar ? (assistant?.avatar ?? '') : null,
      showUserAvatar: context.watch<SettingsProvider>().showUserAvatar,
      showTokenStats: context.watch<SettingsProvider>().showTokenStats,
      hideStreamingIndicator:
          isProcessingFiles ||
          (isPinnedIndicatorActive && (message.id == pinnedStreamingMessageId)),
      reasoningText: (message.role == 'assistant') ? (r?.text ?? '') : null,
      reasoningExpanded: (message.role == 'assistant')
          ? (r?.expanded ?? false)
          : false,
      reasoningLoading: (message.role == 'assistant')
          ? (message.isStreaming &&
                r?.finishedAt == null &&
                (r?.text.isNotEmpty == true))
          : false,
      reasoningStartAt: (message.role == 'assistant') ? r?.startAt : null,
      reasoningFinishedAt: (message.role == 'assistant') ? r?.finishedAt : null,
      onToggleReasoning: (message.role == 'assistant' && r != null)
          ? () => onToggleReasoning?.call(message.id)
          : null,
      translationExpanded: t?.expanded ?? true,
      onToggleTranslation:
          (message.translation != null &&
              message.translation!.isNotEmpty &&
              t != null)
          ? () => onToggleTranslation?.call(message.id)
          : null,
      onRegenerate: message.role == 'assistant'
          ? () => onRegenerateMessage?.call(message)
          : null,
      onResend: message.role == 'user'
          ? () => onResendMessage?.call(message)
          : null,
      onTranslate: message.role == 'assistant'
          ? () => onTranslateMessage?.call(message)
          : null,
      onSpeak: message.role == 'assistant'
          ? () => onSpeakMessage?.call(message)
          : null,
      onEdit: (message.role == 'user' || message.role == 'assistant')
          ? () => onEditMessage?.call(message)
          : null,
      onDelete: message.role == 'user'
          ? () => onDeleteMessage?.call(message, byGroup)
          : null,
      onMore: () async {
        final action = await showMessageMoreSheet(
          context,
          message,
          canDeleteAllVersions: total > 1,
        );
        if (action == MessageMoreAction.deleteCurrentVersion) {
          await onDeleteMessage?.call(message, byGroup);
        } else if (action == MessageMoreAction.deleteAllVersions) {
          await onDeleteAllVersions?.call(message, byGroup);
        } else if (action == MessageMoreAction.edit) {
          onEditMessage?.call(message);
        } else if (action == MessageMoreAction.fork) {
          await onForkConversation?.call(message);
        } else if (action == MessageMoreAction.share) {
          onShareMessage?.call(index, messages);
        }
      },
      toolParts: message.role == 'assistant' ? toolParts[message.id] : null,
      contentSplitOffsets: message.role == 'assistant'
          ? contentSplits[message.id]?.offsets
          : null,
      reasoningCountAtSplit: message.role == 'assistant'
          ? contentSplits[message.id]?.reasoningCounts
          : null,
      toolCountAtSplit: message.role == 'assistant'
          ? contentSplits[message.id]?.toolCounts
          : null,
      reasoningSegments: message.role == 'assistant'
          ? (() {
              final segments = reasoningSegments[message.id];
              if (segments == null || segments.isEmpty) return null;
              return segments
                  .asMap()
                  .entries
                  .map(
                    (entry) => ReasoningSegment(
                      text: entry.value.text,
                      expanded: entry.value.expanded,
                      loading:
                          message.isStreaming &&
                          entry.value.finishedAt == null &&
                          entry.value.text.isNotEmpty,
                      startAt: entry.value.startAt,
                      finishedAt: entry.value.finishedAt,
                      onToggle: () =>
                          onToggleReasoningSegment?.call(message.id, entry.key),
                      toolStartIndex: entry.value.toolStartIndex,
                    ),
                  )
                  .toList();
            })()
          : null,
      isProcessingFiles: isProcessingFiles,
      suggestions: suggestions,
      onSuggestionTap: onSuggestionTap,
      onRecoveredAskUserAnswer: onRecoveredAskUserAnswer == null
          ? null
          : (part, result) => onRecoveredAskUserAnswer!(message, part, result),
    );
  }
}
