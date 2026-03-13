import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../chat/widgets/chat_message_widget.dart';
import '../../chat/widgets/message_more_sheet.dart';
import '../controllers/stream_controller.dart' as stream_ctrl;
import '../controllers/streaming_content_notifier.dart';
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
typedef OnForkConversation = Future<void> Function(ChatMessage message);
typedef OnShareMessage = void Function(ChatMessage message);
typedef OnSpeakMessage = Future<void> Function(ChatMessage message);

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
/// This widget extracts the ListView.builder logic from HomePageState
/// to reduce coupling and improve maintainability.
class MessageListView extends StatelessWidget {
  const MessageListView({
    super.key,
    required this.scrollController,
    required this.messages,
    required this.byGroup,
    required this.versionSelections,
    required this.truncateVisibleIndex,
    required this.messageKeys,
    required this.reasoning,
    required this.reasoningSegments,
    required this.toolParts,
    required this.translations,
    required this.selecting,
    required this.selectedItems,
    required this.dividerPadding,
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
    this.onForkConversation,
    this.onShareMessage,
    this.onSpeakMessage,
    this.onToggleSelection,
    this.onToggleReasoning,
    this.onToggleTranslation,
    this.onToggleReasoningSegment,
    this.buildPinnedStreamingIndicator,
  });

  final ScrollController scrollController;
  final List<ChatMessage> messages;
  final Map<String, List<ChatMessage>> byGroup;
  final Map<String, int> versionSelections;
  final int truncateVisibleIndex;
  final Map<String, GlobalKey> messageKeys;
  final Map<String, stream_ctrl.ReasoningData> reasoning;
  final Map<String, List<stream_ctrl.ReasoningSegmentData>> reasoningSegments;
  final Map<String, List<ToolUIPart>> toolParts;
  final Map<String, TranslationUiState> translations;
  final bool selecting;
  final Set<String> selectedItems;
  final EdgeInsetsGeometry dividerPadding;
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
  final OnForkConversation? onForkConversation;
  final OnShareMessage? onShareMessage;
  final OnSpeakMessage? onSpeakMessage;
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
            color: cs.outlineVariant.withOpacity(0.6),
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
              color: cs.onSurface.withOpacity(0.6),
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: cs.outlineVariant.withOpacity(0.6),
            height: 1,
            thickness: 1,
          ),
        ),
      ],
    );
  }

  GlobalKey _keyForMessage(String id) =>
      messageKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'msg:$id'));

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
                isPinnedIndicatorActive ? 28 : 16,
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
                  messages: messages,
                  byGroup: byGroup,
                  truncCollapsed: truncateVisibleIndex,
                  isProcessingFiles: isProcessing,
                );
              },
            );

            return Stack(
              children: [
                list,
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
    required List<ChatMessage> messages,
    required Map<String, List<ChatMessage>> byGroup,
    required int truncCollapsed,
    required bool isProcessingFiles,
  }) {
    final message = messages[index];
    final r = reasoning[message.id];
    final t = translations[message.id];
    final chatScale = context.watch<SettingsProvider>().chatFontScale;
    final assistant = context.watch<AssistantProvider>().currentAssistant;
    final useAssistAvatar = assistant?.useAssistantAvatar == true;
    final useAssistName = assistant?.useAssistantName == true;
    final showDivider = truncCollapsed >= 0 && index == truncCollapsed;
    final gid = (message.groupId ?? message.id);
    final vers = (byGroup[gid] ?? const <ChatMessage>[]).toList()
      ..sort((a, b) => a.version.compareTo(b.version));
    int selectedIdx =
        versionSelections[gid] ?? (vers.isNotEmpty ? vers.length - 1 : 0);
    final total = vers.length;
    if (selectedIdx < 0) selectedIdx = 0;
    if (total > 0 && selectedIdx > total - 1) selectedIdx = total - 1;

    // Check if this is a streaming message that should use ValueListenableBuilder
    final isStreaming =
        message.isStreaming &&
        message.role == 'assistant' &&
        streamingContentNotifier != null &&
        streamingContentNotifier!.hasNotifier(message.id);

    final messageColumn = Column(
      key: _keyForMessage(message.id),
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
                    final textScale = MediaQuery.textScaleFactorOf(context);
                    final baseMediaQuery = context
                        .getInheritedWidgetOfExactType<MediaQuery>();
                    final baseData = baseMediaQuery?.data;
                    return MediaQuery(
                      // Keep chat font scaling without rebuilding on keyboard insets.
                      data: (baseData ?? MediaQuery.of(context)).copyWith(
                        textScaleFactor: textScale * chatScale,
                      ),
                      child: isStreaming
                          ? _buildStreamingMessageWidget(
                              context,
                              message: message,
                              index: index,
                              messages: messages,
                              byGroup: byGroup,
                              r: r,
                              t: t,
                              useAssistAvatar: useAssistAvatar,
                              useAssistName: useAssistName,
                              assistant: assistant,
                              gid: gid,
                              selectedIdx: selectedIdx,
                              total: total,
                              isProcessingFiles: isProcessingFiles,
                            )
                          : _buildChatMessageWidget(
                              context,
                              message: message,
                              index: index,
                              messages: messages,
                              byGroup: byGroup,
                              r: r,
                              t: t,
                              useAssistAvatar: useAssistAvatar,
                              useAssistName: useAssistName,
                              assistant: assistant,
                              gid: gid,
                              selectedIdx: selectedIdx,
                              total: total,
                              isProcessingFiles: isProcessingFiles,
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
                      ).withOpacity(opacity * 0.30),
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

  /// Build a streaming message widget that uses ValueListenableBuilder
  /// to avoid full page rebuilds during streaming.
  Widget _buildStreamingMessageWidget(
    BuildContext context, {
    required ChatMessage message,
    required int index,
    required List<ChatMessage> messages,
    required Map<String, List<ChatMessage>> byGroup,
    required stream_ctrl.ReasoningData? r,
    required TranslationUiState? t,
    required bool useAssistAvatar,
    required bool useAssistName,
    required dynamic assistant,
    required String gid,
    required int selectedIdx,
    required int total,
    required bool isProcessingFiles,
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
        );

        // Update reasoning text from streaming data while preserving expanded state from r
        // This allows user to toggle expanded state during streaming without it being reset
        stream_ctrl.ReasoningData? streamingReasoning = r;
        if (data.reasoningText != null && data.reasoningText!.isNotEmpty) {
          if (r != null) {
            // Update the existing ReasoningData object's text fields
            // but preserve the expanded state that user may have toggled
            r.text = data.reasoningText!;
            r.startAt = data.reasoningStartAt;
            if (data.reasoningFinishedAt != null) {
              r.finishedAt = data.reasoningFinishedAt;
            }
            streamingReasoning = r;
          } else {
            // No existing reasoning data, create new one
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
            messages: messages,
            byGroup: byGroup,
            r: streamingReasoning,
            t: t,
            useAssistAvatar: useAssistAvatar,
            useAssistName: useAssistName,
            assistant: assistant,
            gid: gid,
            selectedIdx: selectedIdx,
            total: total,
            isProcessingFiles: isProcessingFiles,
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
    required List<ChatMessage> messages,
    required Map<String, List<ChatMessage>> byGroup,
    required stream_ctrl.ReasoningData? r,
    required TranslationUiState? t,
    required bool useAssistAvatar,
    required bool useAssistName,
    required dynamic assistant,
    required String gid,
    required int selectedIdx,
    required int total,
    required bool isProcessingFiles,
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
          ? (r?.finishedAt == null && (r?.text.isNotEmpty == true))
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
        final action = await showMessageMoreSheet(context, message);
        if (action == MessageMoreAction.delete) {
          await onDeleteMessage?.call(message, byGroup);
        } else if (action == MessageMoreAction.edit) {
          onEditMessage?.call(message);
        } else if (action == MessageMoreAction.fork) {
          await onForkConversation?.call(message);
        } else if (action == MessageMoreAction.share) {
          onShareMessage?.call(message);
        }
      },
      toolParts: message.role == 'assistant' ? toolParts[message.id] : null,
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
    );
  }
}
