import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../core/models/assistant.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../chat/widgets/chat_message_widget.dart';
import '../../chat/widgets/message_more_sheet.dart';
import '../controllers/chat_scroll_position.dart';
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
typedef OnUserScrollIntent =
    void Function(ChatUserScrollIntentDirection direction);
typedef OnUserResizesMessageContent =
    void Function(ChatMessage message, int index);
typedef OnStreamingMessageContentChanged =
    void Function(ChatMessage message, int index);

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
/// to avoid redundant computation on every build. Uses index-based scrolling
/// so large dynamic-height conversations can open and jump without building
/// every earlier message first.
class MessageListView extends StatefulWidget {
  const MessageListView({
    super.key,
    required this.scrollControllers,
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
    this.onUserScrollIntent,
    this.onUserScrollPointerDown,
    this.onUserScrollPointerUp,
    this.onCodeBlockInteractionStart,
    this.onCodeBlockInteractionEnd,
    this.onUserResizesMessageContent,
    this.onStreamingMessageContentChanged,
    this.onMessageVisible,
    this.onBottomAnchorAlignmentChanged,
    this.buildPinnedStreamingIndicator,
    this.itemBuildObserver,
  });

  final ChatIndexedScrollControllers scrollControllers;

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
  final OnUserScrollIntent? onUserScrollIntent;
  final VoidCallback? onUserScrollPointerDown;
  final VoidCallback? onUserScrollPointerUp;
  final VoidCallback? onCodeBlockInteractionStart;
  final VoidCallback? onCodeBlockInteractionEnd;
  final OnUserResizesMessageContent? onUserResizesMessageContent;
  final OnStreamingMessageContentChanged? onStreamingMessageContentChanged;
  final void Function(ChatMessage message, int index)? onMessageVisible;
  final ValueChanged<double>? onBottomAnchorAlignmentChanged;
  final Widget Function()? buildPinnedStreamingIndicator;
  final ValueChanged<int>? itemBuildObserver;

  static const double maxScrollCacheExtent = 720.0;

  static double scrollCacheExtentFor(double viewportHeight) {
    if (viewportHeight <= 0) return 0;
    return (viewportHeight * 0.9).clamp(0.0, maxScrollCacheExtent);
  }

  static double bottomAnchorAlignmentFor({
    required double viewportHeight,
    required double bottomPadding,
  }) {
    if (viewportHeight <= 0) return 1;
    return ((viewportHeight - bottomPadding) / viewportHeight).clamp(0.0, 1.0);
  }

  @override
  State<MessageListView> createState() => _MessageListViewState();
}

class _MessageListSettingsSnapshot {
  const _MessageListSettingsSnapshot({
    required this.chatFontScale,
    required this.showModelIcon,
    required this.showUserAvatar,
    required this.showTokenStats,
  });

  final double chatFontScale;
  final bool showModelIcon;
  final bool showUserAvatar;
  final bool showTokenStats;

  @override
  bool operator ==(Object other) {
    return other is _MessageListSettingsSnapshot &&
        other.chatFontScale == chatFontScale &&
        other.showModelIcon == showModelIcon &&
        other.showUserAvatar == showUserAvatar &&
        other.showTokenStats == showTokenStats;
  }

  @override
  int get hashCode =>
      Object.hash(chatFontScale, showModelIcon, showUserAvatar, showTokenStats);
}

class _MessageItemCacheEntry {
  const _MessageItemCacheEntry({required this.signature, required this.widget});

  final Object signature;
  final Widget widget;
}

class _MessageListViewState extends State<MessageListView> {
  final Set<String> _reportedVisibleMessageIds = <String>{};
  final List<(ChatMessage, int)> _pendingVisibleMessages =
      <(ChatMessage, int)>[];
  final Map<String, StreamingContentData> _lastStreamingContentData =
      <String, StreamingContentData>{};
  final Map<String, _MessageItemCacheEntry> _messageItemCache =
      <String, _MessageItemCacheEntry>{};
  final Set<int> _codeBlockPointerIds = <int>{};
  Timer? _codeBlockUnlockTimer;
  bool _codeBlockUnlockPending = false;
  bool _visibleFlushScheduled = false;
  bool _pointerScrollIntentSent = false;
  double _pointerScrollIntentDx = 0;
  double _pointerScrollIntentDy = 0;

  static const double _pointerScrollIntentThreshold = 4.0;

  @override
  void didUpdateWidget(covariant MessageListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.messages, widget.messages)) {
      if (_conversationIdFor(oldWidget.messages) !=
          _conversationIdFor(widget.messages)) {
        _reportedVisibleMessageIds.clear();
        _pendingVisibleMessages.clear();
        _lastStreamingContentData.clear();
        return;
      }
      final currentIds = widget.messages.map((message) => message.id).toSet();
      _reportedVisibleMessageIds.removeWhere((id) => !currentIds.contains(id));
      _lastStreamingContentData.removeWhere(
        (id, _) => !currentIds.contains(id),
      );
      _messageItemCache.removeWhere((id, _) => !currentIds.contains(id));
    }
  }

  String? _conversationIdFor(List<ChatMessage> messages) {
    return messages.isEmpty ? null : messages.first.conversationId;
  }

  @override
  void dispose() {
    final wasCodeBlockInteractionActive = _isCodeBlockInteractionActive;
    _codeBlockUnlockTimer?.cancel();
    if (wasCodeBlockInteractionActive) {
      widget.onCodeBlockInteractionEnd?.call();
    }
    _codeBlockPointerIds.clear();
    _pendingVisibleMessages.clear();
    _lastStreamingContentData.clear();
    _messageItemCache.clear();
    super.dispose();
  }

  bool get _isCodeBlockInteractionActive =>
      _codeBlockPointerIds.isNotEmpty || _codeBlockUnlockPending;

  void _handleCodeBlockPointerDown(int pointer) {
    final wasActive = _isCodeBlockInteractionActive;
    _codeBlockUnlockTimer?.cancel();
    _codeBlockUnlockTimer = null;
    if (_codeBlockUnlockPending) {
      _codeBlockUnlockPending = false;
      if (mounted) setState(() {});
    }
    if (_codeBlockPointerIds.add(pointer)) {
      if (!wasActive) {
        widget.onCodeBlockInteractionStart?.call();
      }
      if (mounted) setState(() {});
    }
  }

  void _handleCodeBlockPointerFinished(int pointer) {
    if (!_codeBlockPointerIds.remove(pointer)) return;
    if (_codeBlockPointerIds.isNotEmpty) return;
    _codeBlockUnlockPending = true;
    if (mounted) setState(() {});
    _codeBlockUnlockTimer?.cancel();
    _codeBlockUnlockTimer = Timer(const Duration(milliseconds: 400), () {
      _codeBlockUnlockTimer = null;
      if (!_codeBlockUnlockPending) return;
      _codeBlockUnlockPending = false;
      widget.onCodeBlockInteractionEnd?.call();
      if (mounted) setState(() {});
    });
  }

  void _scheduleVisibleMessage(ChatMessage message, int index) {
    if (widget.onMessageVisible == null) return;
    if (!_reportedVisibleMessageIds.add(message.id)) return;
    _pendingVisibleMessages.add((message, index));
    if (_visibleFlushScheduled) return;
    _visibleFlushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibleFlushScheduled = false;
      if (!mounted) {
        _pendingVisibleMessages.clear();
        return;
      }
      if (_pendingVisibleMessages.isEmpty) return;

      final pending = List<(ChatMessage, int)>.of(_pendingVisibleMessages);
      _pendingVisibleMessages.clear();
      final callback = widget.onMessageVisible;
      if (callback == null) return;
      for (final (message, index) in pending) {
        callback(message, index);
      }
    });
  }

  int _latestAssistantMessageIndex() {
    for (var i = widget.messages.length - 1; i >= 0; i--) {
      final message = widget.messages[i];
      if (message.role == 'assistant' && !message.isStreaming) return i;
    }
    return -1;
  }

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
    final settings = context
        .select<SettingsProvider, _MessageListSettingsSnapshot>(
          (settings) => _MessageListSettingsSnapshot(
            chatFontScale: settings.chatFontScale,
            showModelIcon: settings.showModelIcon,
            showUserAvatar: settings.showUserAvatar,
            showTokenStats: settings.showTokenStats,
          ),
        );
    final assistant = context.select<AssistantProvider, Assistant?>(
      (provider) => provider.currentAssistant,
    );
    final latestAssistantIndex = _latestAssistantMessageIndex();

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPad =
            ((constraints.maxWidth - ChatLayoutConstants.maxContentWidth) / 2)
                .clamp(0.0, double.infinity);
        final scrollCacheExtent = MessageListView.scrollCacheExtentFor(
          constraints.maxHeight,
        );

        return ValueListenableBuilder<bool>(
          valueListenable: widget.isProcessingFiles,
          builder: (context, isProcessing, child) {
            final bottomPadding =
                widget.bottomContentPadding +
                (widget.isPinnedIndicatorActive ? 12 : 0);
            final itemCount = widget.messages.length + 1;
            final bottomAnchorIndex = itemCount - 1;
            final bottomAnchorAlignment =
                MessageListView.bottomAnchorAlignmentFor(
                  viewportHeight: constraints.maxHeight,
                  bottomPadding: bottomPadding,
                );
            widget.onBottomAnchorAlignmentChanged?.call(bottomAnchorAlignment);
            final list = Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) {
                _pointerScrollIntentSent = false;
                _pointerScrollIntentDx = 0;
                _pointerScrollIntentDy = 0;
                if (_codeBlockPointerIds.contains(event.pointer)) {
                  return;
                }
              },
              onPointerMove: (event) {
                if (_codeBlockPointerIds.contains(event.pointer)) return;
                if (_pointerScrollIntentSent) return;
                _pointerScrollIntentDx += event.delta.dx;
                _pointerScrollIntentDy += event.delta.dy;
                final absDx = _pointerScrollIntentDx.abs();
                final absDy = _pointerScrollIntentDy.abs();
                if (absDy < _pointerScrollIntentThreshold || absDy < absDx) {
                  return;
                }
                _pointerScrollIntentSent = true;
                widget.onUserScrollPointerDown?.call();
                widget.onUserScrollIntent?.call(
                  _pointerScrollIntentDy > 0
                      ? ChatUserScrollIntentDirection.towardTop
                      : ChatUserScrollIntentDirection.towardBottom,
                );
              },
              onPointerUp: (event) {
                _handleCodeBlockPointerFinished(event.pointer);
                final sentScrollIntent = _pointerScrollIntentSent;
                _pointerScrollIntentSent = false;
                _pointerScrollIntentDx = 0;
                _pointerScrollIntentDy = 0;
                if (sentScrollIntent) {
                  widget.onUserScrollPointerUp?.call();
                }
              },
              onPointerCancel: (event) {
                _handleCodeBlockPointerFinished(event.pointer);
                final sentScrollIntent = _pointerScrollIntentSent;
                _pointerScrollIntentSent = false;
                _pointerScrollIntentDx = 0;
                _pointerScrollIntentDy = 0;
                if (sentScrollIntent) {
                  widget.onUserScrollPointerUp?.call();
                }
              },
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  final absDx = event.scrollDelta.dx.abs();
                  final absDy = event.scrollDelta.dy.abs();
                  if (absDy < 0.5 || absDy < absDx) return;
                  widget.onUserScrollIntent?.call(
                    event.scrollDelta.dy > 0
                        ? ChatUserScrollIntentDirection.towardBottom
                        : ChatUserScrollIntentDirection.towardTop,
                  );
                  return;
                }
                widget.onUserScrollIntent?.call(
                  ChatUserScrollIntentDirection.unknown,
                );
              },
              child: ScrollablePositionedList.builder(
                physics: defaultTargetPlatform == TargetPlatform.iOS
                    ? const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      )
                    : const ClampingScrollPhysics(),
                itemScrollController:
                    widget.scrollControllers.itemScrollController,
                itemPositionsListener:
                    widget.scrollControllers.itemPositionsListener,
                scrollOffsetController:
                    widget.scrollControllers.scrollOffsetController,
                scrollOffsetListener:
                    widget.scrollControllers.scrollOffsetListener,
                initialScrollIndex: bottomAnchorIndex,
                initialAlignment: bottomAnchorAlignment,
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  8,
                  horizontalPad,
                  0,
                ),
                itemCount: itemCount,
                minCacheExtent: scrollCacheExtent,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
                itemBuilder: (context, index) {
                  if (index == bottomAnchorIndex) {
                    widget.itemBuildObserver?.call(index);
                    return SizedBox(
                      key: const ValueKey('message-list-bottom-anchor'),
                      height: bottomPadding,
                    );
                  }
                  if (index < 0 || index >= widget.messages.length) {
                    return const SizedBox.shrink();
                  }
                  widget.itemBuildObserver?.call(index);
                  _scheduleVisibleMessage(widget.messages[index], index);
                  return _buildMessageItem(
                    context,
                    index: index,
                    isProcessingFiles: isProcessing,
                    settings: settings,
                    assistant: assistant,
                    latestAssistantIndex: latestAssistantIndex,
                  );
                },
              ),
            );

            return Stack(
              children: [
                list,
                if (widget.isPinnedIndicatorActive &&
                    widget.buildPinnedStreamingIndicator != null)
                  widget.buildPinnedStreamingIndicator!(),
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
    required _MessageListSettingsSnapshot settings,
    required Assistant? assistant,
    required int latestAssistantIndex,
  }) {
    final message = widget.messages[index];
    final r = widget.reasoning[message.id];
    final t = widget.translations[message.id];
    final chatScale = settings.chatFontScale;
    final useAssistAvatar = assistant?.useAssistantAvatar == true;
    final useAssistName = assistant?.useAssistantName == true;
    final showDivider =
        widget.truncCollapsedIndex >= 0 && index == widget.truncCollapsedIndex;
    final gid = (message.groupId ?? message.id);
    final vers = (widget.byGroup[gid] ?? const <ChatMessage>[]).toList()
      ..sort((a, b) => a.version.compareTo(b.version));
    int selectedIdx =
        widget.versionSelections[gid] ??
        (vers.isNotEmpty ? vers.length - 1 : 0);
    final total = vers.length;
    if (selectedIdx < 0) selectedIdx = 0;
    if (total > 0 && selectedIdx > total - 1) selectedIdx = total - 1;
    final messageSuggestions =
        !widget.selecting &&
            index == latestAssistantIndex &&
            message.role == 'assistant' &&
            !message.isStreaming &&
            widget.onSuggestionTap != null
        ? widget.suggestions
        : const <String>[];

    // Check if this is a streaming message that should use ValueListenableBuilder
    final isStreaming =
        message.role == 'assistant' &&
        widget.streamingContentNotifier != null &&
        widget.streamingContentNotifier!.hasNotifier(message.id);
    final signature = _messageItemSignature(
      message: message,
      index: index,
      isStreaming: isStreaming,
      reasoning: r,
      translation: t,
      settings: settings,
      assistant: assistant,
      useAssistAvatar: useAssistAvatar,
      useAssistName: useAssistName,
      gid: gid,
      selectedIdx: selectedIdx,
      total: total,
      isProcessingFiles: isProcessingFiles,
      suggestions: messageSuggestions,
      showDivider: showDivider,
    );
    final cached = _messageItemCache[message.id];
    if (cached != null && cached.signature == signature) {
      return cached.widget;
    }

    final messageColumn = Column(
      key: ValueKey(message.id),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.selecting &&
                (message.role == 'user' || message.role == 'assistant'))
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 6),
                child: IosCheckbox(
                  value: widget.selectedItems.contains(message.id),
                  size: 20,
                  hitTestSize: 28,
                  onChanged: (v) {
                    widget.onToggleSelection?.call(message.id, v);
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
                              settings: settings,
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
                              settings: settings,
                            ),
                    );
                  },
                );

                final canSelect =
                    (message.role == 'user' || message.role == 'assistant');
                if (widget.selecting && canSelect) {
                  final isSelected = widget.selectedItems.contains(message.id);
                  content = GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        widget.onToggleSelection?.call(message.id, !isSelected),
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
            padding: widget.dividerPadding,
            child: _buildContextDivider(context),
          ),
      ],
    );

    final isSpotlight =
        widget.spotlightMessageId != null &&
        message.id == widget.spotlightMessageId;
    final built = !isSpotlight
        ? messageColumn
        : TweenAnimationBuilder<double>(
            key: ValueKey('spotlight-${widget.spotlightToken}'),
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
    _messageItemCache[message.id] = _MessageItemCacheEntry(
      signature: signature,
      widget: built,
    );
    return built;
  }

  Object _messageItemSignature({
    required ChatMessage message,
    required int index,
    required bool isStreaming,
    required stream_ctrl.ReasoningData? reasoning,
    required TranslationUiState? translation,
    required _MessageListSettingsSnapshot settings,
    required Assistant? assistant,
    required bool useAssistAvatar,
    required bool useAssistName,
    required String gid,
    required int selectedIdx,
    required int total,
    required bool isProcessingFiles,
    required List<String> suggestions,
    required bool showDivider,
  }) {
    return (
      message: _messageSignature(message, isStreaming: isStreaming),
      index: index,
      streamingNotifier: isStreaming ? widget.streamingContentNotifier : null,
      selecting: widget.selecting,
      selected: widget.selectedItems.contains(message.id),
      settings: settings,
      assistantId: assistant?.id,
      assistantName: assistant?.name,
      assistantAvatar: assistant?.avatar,
      useAssistAvatar: useAssistAvatar,
      useAssistName: useAssistName,
      gid: gid,
      selectedIdx: selectedIdx,
      total: total,
      isProcessingFiles: isProcessingFiles,
      pinnedStreamingIndicator:
          widget.isPinnedIndicatorActive &&
          widget.pinnedStreamingMessageId == message.id,
      suggestions: Object.hashAll(suggestions),
      reasoning: isStreaming ? null : _reasoningSignature(reasoning),
      reasoningSegments: isStreaming
          ? 0
          : _reasoningSegmentsSignature(widget.reasoningSegments[message.id]),
      translation: (translation?.expanded, translation != null),
      contentSplits: isStreaming
          ? 0
          : _contentSplitSignature(widget.contentSplits[message.id]),
      toolParts: isStreaming
          ? 0
          : _toolPartsSignature(widget.toolParts[message.id]),
      showDivider: showDivider,
      dividerPadding: showDivider ? widget.dividerPadding : null,
      spotlightToken: widget.spotlightMessageId == message.id
          ? widget.spotlightToken
          : 0,
      callbackShape: (
        widget.onVersionChange != null,
        widget.onRegenerateMessage != null,
        widget.onResendMessage != null,
        widget.onTranslateMessage != null,
        widget.onEditMessage != null,
        widget.onDeleteMessage != null,
        widget.onDeleteAllVersions != null,
        widget.onForkConversation != null,
        widget.onShareMessage != null,
        widget.onSpeakMessage != null,
        widget.onSuggestionTap != null,
        widget.onRecoveredAskUserAnswer != null,
        widget.onToggleSelection != null,
        widget.onToggleReasoning != null,
        widget.onToggleTranslation != null,
        widget.onToggleReasoningSegment != null,
        widget.onCodeBlockInteractionStart != null,
        widget.onCodeBlockInteractionEnd != null,
        widget.onUserResizesMessageContent != null,
      ),
    );
  }

  Object _messageSignature(ChatMessage message, {required bool isStreaming}) {
    if (isStreaming) {
      return (
        message.id,
        message.role,
        message.conversationId,
        message.isStreaming,
        message.modelId,
        message.providerId,
        message.groupId,
        message.version,
      );
    }
    return (
      message.id,
      message.role,
      message.content,
      message.timestamp,
      message.modelId,
      message.providerId,
      message.totalTokens,
      message.conversationId,
      message.isStreaming,
      message.reasoningText,
      message.reasoningStartAt,
      message.reasoningFinishedAt,
      message.translation,
      message.reasoningSegmentsJson,
      message.groupId,
      message.version,
      message.promptTokens,
      message.completionTokens,
      message.cachedTokens,
      message.durationMs,
    );
  }

  Object? _reasoningSignature(stream_ctrl.ReasoningData? reasoning) {
    if (reasoning == null) return null;
    return (
      reasoning.text,
      reasoning.startAt,
      reasoning.finishedAt,
      reasoning.expanded,
    );
  }

  int _reasoningSegmentsSignature(
    List<stream_ctrl.ReasoningSegmentData>? segments,
  ) {
    if (segments == null || segments.isEmpty) return 0;
    return Object.hashAll(
      segments.map(
        (segment) => (
          segment.text,
          segment.startAt,
          segment.finishedAt,
          segment.expanded,
          segment.toolStartIndex,
        ),
      ),
    );
  }

  int _contentSplitSignature(stream_ctrl.ContentSplitData? contentSplit) {
    if (contentSplit == null) return 0;
    return Object.hash(
      Object.hashAll(contentSplit.offsets),
      Object.hashAll(contentSplit.reasoningCounts),
      Object.hashAll(contentSplit.toolCounts),
    );
  }

  int _toolPartsSignature(List<ToolUIPart>? parts) {
    if (parts == null || parts.isEmpty) return 0;
    return Object.hashAll(
      parts.map(
        (part) => (
          part.id,
          part.toolName,
          _mapSignature(part.arguments),
          part.content,
          part.loading,
        ),
      ),
    );
  }

  int _mapSignature(Map<String, dynamic> map) {
    if (map.isEmpty) return 0;
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Object.hashAll(
      entries.map((entry) => (entry.key, entry.value.toString())),
    );
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
    required _MessageListSettingsSnapshot settings,
  }) {
    return ValueListenableBuilder<StreamingContentData>(
      valueListenable: widget.streamingContentNotifier!.getNotifier(message.id),
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

        if (_lastStreamingContentData[message.id] != data) {
          _lastStreamingContentData[message.id] = data;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            widget.onStreamingMessageContentChanged?.call(message, index);
          });
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
            settings: settings,
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
    required _MessageListSettingsSnapshot settings,
  }) {
    return ChatMessageWidget(
      message: message,
      versionIndex: selectedIdx,
      versionCount: total > 0 ? total : 1,
      onPrevVersion: (selectedIdx > 0)
          ? () => widget.onVersionChange?.call(gid, selectedIdx - 1)
          : null,
      onNextVersion: (selectedIdx < total - 1)
          ? () => widget.onVersionChange?.call(gid, selectedIdx + 1)
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
      showModelIcon: useAssistAvatar ? false : settings.showModelIcon,
      useAssistantAvatar: useAssistAvatar && message.role == 'assistant',
      useAssistantName: useAssistName && message.role == 'assistant',
      assistantName: (useAssistAvatar || useAssistName)
          ? (assistant?.name ?? 'Assistant')
          : null,
      assistantAvatar: useAssistAvatar ? (assistant?.avatar ?? '') : null,
      showUserAvatar: settings.showUserAvatar,
      showTokenStats: settings.showTokenStats,
      hideStreamingIndicator:
          isProcessingFiles ||
          (widget.isPinnedIndicatorActive &&
              (message.id == widget.pinnedStreamingMessageId)),
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
          ? () {
              widget.onUserResizesMessageContent?.call(message, index);
              widget.onToggleReasoning?.call(message.id);
            }
          : null,
      translationExpanded: t?.expanded ?? true,
      onToggleTranslation:
          (message.translation != null &&
              message.translation!.isNotEmpty &&
              t != null)
          ? () {
              widget.onUserResizesMessageContent?.call(message, index);
              widget.onToggleTranslation?.call(message.id);
            }
          : null,
      onRegenerate: message.role == 'assistant'
          ? () => widget.onRegenerateMessage?.call(message)
          : null,
      onResend: message.role == 'user'
          ? () => widget.onResendMessage?.call(message)
          : null,
      onTranslate: message.role == 'assistant'
          ? () => widget.onTranslateMessage?.call(message)
          : null,
      onSpeak: message.role == 'assistant'
          ? () => widget.onSpeakMessage?.call(message)
          : null,
      onEdit: (message.role == 'user' || message.role == 'assistant')
          ? () => widget.onEditMessage?.call(message)
          : null,
      onDelete: message.role == 'user'
          ? () => widget.onDeleteMessage?.call(message, widget.byGroup)
          : null,
      onMore: () async {
        final action = await showMessageMoreSheet(
          context,
          message,
          canDeleteAllVersions: total > 1,
        );
        if (action == MessageMoreAction.deleteCurrentVersion) {
          await widget.onDeleteMessage?.call(message, widget.byGroup);
        } else if (action == MessageMoreAction.deleteAllVersions) {
          await widget.onDeleteAllVersions?.call(message, widget.byGroup);
        } else if (action == MessageMoreAction.edit) {
          widget.onEditMessage?.call(message);
        } else if (action == MessageMoreAction.fork) {
          await widget.onForkConversation?.call(message);
        } else if (action == MessageMoreAction.share) {
          widget.onShareMessage?.call(index, widget.messages);
        }
      },
      toolParts: message.role == 'assistant'
          ? widget.toolParts[message.id]
          : null,
      contentSplitOffsets: message.role == 'assistant'
          ? widget.contentSplits[message.id]?.offsets
          : null,
      reasoningCountAtSplit: message.role == 'assistant'
          ? widget.contentSplits[message.id]?.reasoningCounts
          : null,
      toolCountAtSplit: message.role == 'assistant'
          ? widget.contentSplits[message.id]?.toolCounts
          : null,
      reasoningSegments: message.role == 'assistant'
          ? (() {
              final segments = widget.reasoningSegments[message.id];
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
                      onResizeContent: () {
                        widget.onUserResizesMessageContent?.call(
                          message,
                          index,
                        );
                      },
                      onToggle: () {
                        widget.onUserResizesMessageContent?.call(
                          message,
                          index,
                        );
                        widget.onToggleReasoningSegment?.call(
                          message.id,
                          entry.key,
                        );
                      },
                      toolStartIndex: entry.value.toolStartIndex,
                    ),
                  )
                  .toList();
            })()
          : null,
      isProcessingFiles: isProcessingFiles,
      suggestions: suggestions,
      onSuggestionTap: widget.onSuggestionTap,
      onRecoveredAskUserAnswer: widget.onRecoveredAskUserAnswer == null
          ? null
          : (part, result) =>
                widget.onRecoveredAskUserAnswer!(message, part, result),
      onUserResizesMessageContent: () =>
          widget.onUserResizesMessageContent?.call(message, index),
      onCodeBlockPointerDown: _handleCodeBlockPointerDown,
    );
  }
}
