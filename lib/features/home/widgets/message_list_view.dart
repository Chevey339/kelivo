import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import '../controllers/scroll_controller.dart';
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
typedef OnSelectMessages =
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
class MessageListView extends StatefulWidget {
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
    this.topContentPadding = 8,
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
    this.onSelectMessages,
    this.onSpeakMessage,
    this.suggestions = const <String>[],
    this.onSuggestionTap,
    this.onRecoveredAskUserAnswer,
    this.onToggleSelection,
    this.onToggleReasoning,
    this.onToggleTranslation,
    this.onToggleReasoningSegment,
    this.buildPinnedStreamingIndicator,
    this.hasMoreBefore = false,
    this.onLoadMoreBefore,
    this.hasMoreAfter = false,
    this.onLoadMoreAfter,
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
  final double topContentPadding;
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
  final OnSelectMessages? onSelectMessages;
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
  final bool hasMoreBefore;
  final bool Function({String? keepMessageId})? onLoadMoreBefore;
  final bool hasMoreAfter;
  final bool Function({String? keepMessageId})? onLoadMoreAfter;

  @override
  State<MessageListView> createState() => _MessageListViewState();
}

class _VisibleAnchor {
  const _VisibleAnchor({
    required this.messageId,
    required this.groupId,
    required this.dyFromViewportTop,
    required this.itemExtent,
    required this.itemContentLength,
    required this.estimatedVisualLineCount,
  });

  final String messageId;
  final String groupId;
  final double dyFromViewportTop;
  final double itemExtent;
  final int itemContentLength;
  final int estimatedVisualLineCount;
}

enum _HistoryLoadDirection { before, after }

class _MessageListViewState extends State<MessageListView> {
  static const double _streamingUpdateDeferBottomTolerance = 24.0;
  static const double _historyLoadTopTriggerExtent = 48.0;
  static const double _historyLoadMinPrefetchExtent = 360.0;
  static const double _historyLoadViewportFraction = 0.75;

  final Map<String, GlobalKey> _messageItemKeys = <String, GlobalKey>{};

  bool _historyLoadScheduled = false;
  final ValueNotifier<bool> _deferStreamingMessageUpdates = ValueNotifier<bool>(
    false,
  );
  DateTime? _lastHistoryLoadAt;
  Timer? _scrollIdleTimer;
  bool _pointerScrollActivityCheckScheduled = false;
  _VisibleAnchor? _pendingPrependAnchor;

  @override
  void didUpdateWidget(covariant MessageListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedulePrependLayoutCorrection(oldWidget);
  }

  @override
  void dispose() {
    _scrollIdleTimer?.cancel();
    _deferStreamingMessageUpdates.dispose();
    super.dispose();
  }

  void _schedulePrependLayoutCorrection(MessageListView oldWidget) {
    final anchor = _pendingPrependAnchor;
    if (anchor == null) return;
    _pendingPrependAnchor = null;

    final insertedEnd = _indexOfExistingFirstMessage(oldWidget.messages);
    if (insertedEnd <= 0) return;

    final insertedMessages = widget.messages.sublist(0, insertedEnd);
    final correction = _estimatePrependedExtent(
      insertedMessages: insertedMessages,
      oldMessages: oldWidget.messages,
      anchor: anchor,
    );

    final controller = widget.scrollController;
    if (controller is ChatAutoFollowScrollController) {
      controller.correctNextLayoutBy(correction);
    }
  }

  int _indexOfExistingFirstMessage(List<ChatMessage> oldMessages) {
    if (oldMessages.isEmpty) return -1;
    final first = oldMessages.first;
    final exactIndex = widget.messages.indexWhere(
      (message) => message.id == first.id,
    );
    if (exactIndex >= 0) return exactIndex;

    final firstGroupId = first.groupId ?? first.id;
    return widget.messages.indexWhere(
      (message) => (message.groupId ?? message.id) == firstGroupId,
    );
  }

  double _estimatePrependedExtent({
    required List<ChatMessage> insertedMessages,
    required List<ChatMessage> oldMessages,
    required _VisibleAnchor anchor,
  }) {
    if (insertedMessages.isEmpty) return 0;
    final anchorMessage = oldMessages.cast<ChatMessage?>().firstWhere(
      (message) => message?.id == anchor.messageId,
      orElse: () => null,
    );
    final anchorContentLength = math.max(anchorMessage?.content.length ?? 0, 1);
    var total = 0.0;
    for (final message in insertedMessages) {
      total += _estimateMessageExtent(
        message: message,
        anchor: anchor,
        anchorContentLength: anchorContentLength,
      );
    }
    return total * 1.06;
  }

  double _estimateMessageExtent({
    required ChatMessage message,
    required _VisibleAnchor anchor,
    int? anchorContentLength,
  }) {
    final insertedLineCount = _estimatedVisualLineCount(message.content);
    final safeAnchorLineCount = math.max(anchor.estimatedVisualLineCount, 1);
    const estimatedChromeExtent = 96.0;
    final dynamicAnchorExtent = math.max(
      anchor.itemExtent - estimatedChromeExtent,
      anchor.itemExtent * 0.35,
    );
    final estimatedLineExtent = math.max(
      dynamicAnchorExtent / safeAnchorLineCount,
      24.0,
    );
    final lineBasedExtent =
        estimatedChromeExtent + estimatedLineExtent * insertedLineCount;

    final safeAnchorContentLength =
        anchorContentLength ?? math.max(anchor.itemContentLength, 1);
    final contentRatio =
        math.max(message.content.length, 1) / safeAnchorContentLength;
    final lengthBasedExtent = anchor.itemExtent * contentRatio.clamp(0.35, 8.0);

    return math.max(lineBasedExtent, lengthBasedExtent);
  }

  int _estimatedVisualLineCount(String content) {
    if (content.isEmpty) return 1;
    const charsPerVisualLine = 42;
    var count = 0;
    for (final line in content.split('\n')) {
      final length = math.max(line.runes.length, 1);
      count += (length / charsPerVisualLine).ceil();
    }
    return math.max(count, 1);
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPad =
            ((constraints.maxWidth - ChatLayoutConstants.maxContentWidth) / 2)
                .clamp(0.0, double.infinity);

        _pruneMessageKeys();
        final indexByMessageId = <String, int>{
          for (var i = 0; i < widget.messages.length; i++)
            widget.messages[i].id: i,
        };

        return ValueListenableBuilder<bool>(
          valueListenable: widget.isProcessingFiles,
          builder: (context, isProcessing, child) {
            final list = ListView.builder(
              controller: widget.scrollController,
              padding: EdgeInsets.fromLTRB(
                horizontalPad,
                widget.topContentPadding,
                horizontalPad,
                widget.bottomContentPadding +
                    (widget.isPinnedIndicatorActive ? 12 : 0),
              ),
              itemCount: widget.messages.length,
              scrollCacheExtent: const ScrollCacheExtent.pixels(1200),
              findChildIndexCallback: (key) {
                if (key is ValueKey<String>) {
                  return indexByMessageId[key.value];
                }
                return null;
              },
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemBuilder: (context, index) {
                if (index < 0 || index >= widget.messages.length) {
                  return const SizedBox.shrink();
                }
                final message = widget.messages[index];
                return KeyedSubtree(
                  key: ValueKey<String>(message.id),
                  child: KeyedSubtree(
                    key: _keyForMessage(message.id),
                    child: _buildMessageItem(
                      context,
                      index: index,
                      isProcessingFiles: isProcessing,
                    ),
                  ),
                );
              },
            );

            final observedList = ListViewObserver(
              controller: widget.observerController,
              child: list,
            );

            final historyList = NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: observedList,
            );

            final userScrollAwareList = Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  _schedulePointerScrollActivityCheck();
                }
              },
              child: historyList,
            );

            return Stack(
              children: [
                userScrollAwareList,
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

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollUpdateNotification) {
      if (notification.dragDetails != null) {
        _handleUserScrollActivity(notification.metrics);
      }
      if (_deferStreamingMessageUpdates.value) {
        _scheduleStreamingUpdateResume();
      }
    } else if (notification is OverscrollNotification) {
      if (notification.dragDetails != null) {
        _handleUserScrollActivity(notification.metrics);
      }
      if (_deferStreamingMessageUpdates.value) {
        _scheduleStreamingUpdateResume();
      }
    } else if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _handleUserScrollActivity(notification.metrics);
    }
    if (notification is UserScrollNotification) {
      final shouldDefer = notification.direction != ScrollDirection.idle;
      if (shouldDefer) {
        _handleUserScrollActivity(notification.metrics);
      } else {
        _scheduleStreamingUpdateResume();
      }
    }
    if (notification is ScrollEndNotification) {
      _scheduleStreamingUpdateResume();
    }
    _maybeScheduleHistoryLoad(notification);
    return false;
  }

  void _maybeScheduleHistoryLoad(ScrollNotification notification) {
    if (_historyLoadScheduled) return;
    final now = DateTime.now();
    final last = _lastHistoryLoadAt;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 120)) {
      return;
    }

    final metrics = notification.metrics;
    final bottomPrefetchExtent = math.max(
      _historyLoadMinPrefetchExtent,
      metrics.viewportDimension * _historyLoadViewportFraction,
    );
    final nearTop = metrics.extentBefore <= _historyLoadTopTriggerExtent;
    final nearBottom = metrics.extentAfter <= bottomPrefetchExtent;

    double? scrollDelta;
    if (notification is ScrollUpdateNotification) {
      scrollDelta = notification.scrollDelta;
    } else if (notification is OverscrollNotification) {
      scrollDelta = notification.overscroll;
    }
    if (scrollDelta == null || scrollDelta == 0) return;

    if (scrollDelta < 0 &&
        nearTop &&
        widget.hasMoreBefore &&
        widget.onLoadMoreBefore != null) {
      _scheduleHistoryLoad(direction: _HistoryLoadDirection.before);
    } else if (scrollDelta > 0 &&
        nearBottom &&
        widget.hasMoreAfter &&
        widget.onLoadMoreAfter != null) {
      _scheduleHistoryLoad(direction: _HistoryLoadDirection.after);
    }
  }

  void _schedulePointerScrollActivityCheck() {
    if (_pointerScrollActivityCheckScheduled) return;
    _pointerScrollActivityCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pointerScrollActivityCheckScheduled = false;
      if (!mounted) return;
      _handleUserScrollActivity();
    });
  }

  void _handleUserScrollActivity([ScrollMetrics? metrics]) {
    if (_isWithinStreamingAutoFollowBand(metrics)) {
      _resumeStreamingMessageUpdates();
      return;
    }
    _setDeferStreamingMessageUpdates(true);
    _scheduleStreamingUpdateResume();
  }

  bool _isWithinStreamingAutoFollowBand([ScrollMetrics? metrics]) {
    if (metrics != null) {
      return metrics.maxScrollExtent - metrics.pixels <=
          _streamingUpdateDeferBottomTolerance;
    }
    if (!widget.scrollController.hasClients) return true;
    final position = widget.scrollController.position;
    return position.maxScrollExtent - position.pixels <=
        _streamingUpdateDeferBottomTolerance;
  }

  void _setDeferStreamingMessageUpdates(bool value) {
    if (_deferStreamingMessageUpdates.value == value) return;
    _deferStreamingMessageUpdates.value = value;
  }

  void _scheduleStreamingUpdateResume() {
    _scrollIdleTimer?.cancel();
    _scrollIdleTimer = Timer(
      const Duration(milliseconds: 160),
      _resumeStreamingMessageUpdates,
    );
  }

  void _resumeStreamingMessageUpdates() {
    _scrollIdleTimer?.cancel();
    _scrollIdleTimer = null;
    if (!mounted || !_deferStreamingMessageUpdates.value) return;
    _deferStreamingMessageUpdates.value = false;
  }

  GlobalKey _keyForMessage(String id) {
    return _messageItemKeys.putIfAbsent(id, () => GlobalKey());
  }

  void _pruneMessageKeys() {
    final aliveIds = widget.messages.map((message) => message.id).toSet();
    _messageItemKeys.removeWhere((id, _) => !aliveIds.contains(id));
  }

  _VisibleAnchor? _captureVisibleAnchor() {
    if (!widget.scrollController.hasClients) return null;

    final viewportRender = context.findRenderObject();
    if (viewportRender is! RenderBox || !viewportRender.hasSize) {
      return null;
    }

    final viewportTop = viewportRender.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + viewportRender.size.height;

    for (final message in widget.messages) {
      final itemContext = _messageItemKeys[message.id]?.currentContext;
      final itemRender = itemContext?.findRenderObject();
      if (itemRender is! RenderBox || !itemRender.hasSize) continue;

      final itemTop = itemRender.localToGlobal(Offset.zero).dy;
      final itemBottom = itemTop + itemRender.size.height;
      final intersectsViewport =
          itemBottom >= viewportTop + 8 && itemTop <= viewportBottom - 8;
      if (!intersectsViewport) continue;

      return _VisibleAnchor(
        messageId: message.id,
        groupId: message.groupId ?? message.id,
        dyFromViewportTop: itemTop - viewportTop,
        itemExtent: itemRender.size.height,
        itemContentLength: message.content.length,
        estimatedVisualLineCount: _estimatedVisualLineCount(message.content),
      );
    }

    return null;
  }

  Future<bool> _restoreVisibleAnchor(
    _VisibleAnchor? anchor, {
    required bool allowObserverFallback,
  }) async {
    if (anchor == null || !widget.scrollController.hasClients) return false;

    final correction = _calculateAnchorCorrection(anchor);
    if (correction != null) {
      _applyAnchorCorrection(correction);
      return true;
    }

    if (!allowObserverFallback) return false;

    final anchorIndex = widget.messages.indexWhere(
      (message) => message.id == anchor.messageId,
    );
    if (anchorIndex < 0) return false;

    await widget.observerController.jumpTo(
      index: anchorIndex,
      offset: (_) => anchor.dyFromViewportTop,
    );
    return true;
  }

  double? _calculateAnchorCorrection(_VisibleAnchor anchor) {
    final anchorTop = _currentAnchorTop(anchor);
    if (anchorTop != null) {
      return _correctionForAnchorTop(
        currentAnchorTop: anchorTop,
        anchor: anchor,
      );
    }

    final neighborAnchorTop = _inferredAnchorTopFromNeighbor(anchor);
    if (neighborAnchorTop != null) {
      return _correctionForAnchorTop(
        currentAnchorTop: neighborAnchorTop,
        anchor: anchor,
      );
    }

    return null;
  }

  double? _currentAnchorTop(_VisibleAnchor anchor) {
    final render = _renderBoxForMessage(anchor.messageId);
    return render?.localToGlobal(Offset.zero).dy;
  }

  double? _inferredAnchorTopFromNeighbor(_VisibleAnchor anchor) {
    final anchorIndex = widget.messages.indexWhere(
      (message) => message.id == anchor.messageId,
    );
    if (anchorIndex < 0) return null;

    for (var index = anchorIndex - 1; index >= 0; index--) {
      final render = _renderBoxForMessage(widget.messages[index].id);
      if (render == null) continue;
      var inferredAnchorTop =
          render.localToGlobal(Offset.zero).dy + render.size.height;
      for (var gap = index + 1; gap < anchorIndex; gap++) {
        inferredAnchorTop += _estimateMessageExtent(
          message: widget.messages[gap],
          anchor: anchor,
        );
      }
      return inferredAnchorTop;
    }

    for (var index = anchorIndex + 1; index < widget.messages.length; index++) {
      final render = _renderBoxForMessage(widget.messages[index].id);
      if (render == null) continue;
      var inferredAnchorTop = render.localToGlobal(Offset.zero).dy;
      for (var gap = anchorIndex + 1; gap < index; gap++) {
        inferredAnchorTop -= _estimateMessageExtent(
          message: widget.messages[gap],
          anchor: anchor,
        );
      }
      return inferredAnchorTop - anchor.itemExtent;
    }

    return null;
  }

  double? _correctionForAnchorTop({
    required double currentAnchorTop,
    required _VisibleAnchor anchor,
  }) {
    final viewportRender = context.findRenderObject();
    if (viewportRender is! RenderBox || !viewportRender.hasSize) return null;

    final viewportTop = viewportRender.localToGlobal(Offset.zero).dy;
    final currentDy = currentAnchorTop - viewportTop;
    final correction = currentDy - anchor.dyFromViewportTop;
    if (correction.abs() < 0.5) return 0;
    return correction;
  }

  void _applyAnchorCorrection(double correction) {
    if (correction.abs() < 0.5 || !widget.scrollController.hasClients) return;
    final position = widget.scrollController.position;
    final target = (position.pixels + correction)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((target - position.pixels).abs() <= 0.5) return;
    widget.scrollController.jumpTo(target);
  }

  RenderBox? _renderBoxForMessage(String messageId) {
    final itemContext = _messageItemKeys[messageId]?.currentContext;
    final itemRender = itemContext?.findRenderObject();
    if (itemRender is RenderBox && itemRender.hasSize) return itemRender;
    return null;
  }

  Future<void> _restoreAfterHistoryLoad(
    _VisibleAnchor? anchor, {
    required _HistoryLoadDirection direction,
  }) async {
    try {
      if (mounted) {
        await _restoreVisibleAnchor(
          anchor,
          allowObserverFallback: direction == _HistoryLoadDirection.after,
        );
      }
    } finally {
      if (mounted) {
        _historyLoadScheduled = false;
      }
    }
  }

  void _scheduleHistoryLoad({required _HistoryLoadDirection direction}) {
    _historyLoadScheduled = true;
    _lastHistoryLoadAt = DateTime.now();
    final anchor = _captureVisibleAnchor();
    if (direction == _HistoryLoadDirection.before) {
      _pendingPrependAnchor = anchor;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _historyLoadScheduled = false;
        return;
      }

      final loaded = switch (direction) {
        _HistoryLoadDirection.before => widget.onLoadMoreBefore!(
          keepMessageId: anchor?.messageId,
        ),
        _HistoryLoadDirection.after => widget.onLoadMoreAfter!(
          keepMessageId: anchor?.messageId,
        ),
      };
      if (!loaded) {
        _pendingPrependAnchor = null;
        _historyLoadScheduled = false;
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          _historyLoadScheduled = false;
          return;
        }
        unawaited(_restoreAfterHistoryLoad(anchor, direction: direction));
      });
    });
  }

  Widget _buildMessageItem(
    BuildContext context, {
    required int index,
    required bool isProcessingFiles,
  }) {
    final message = widget.messages[index];
    final r = widget.reasoning[message.id];
    final t = widget.translations[message.id];
    final chatScale = context.watch<SettingsProvider>().chatFontScale;
    final assistant = context.watch<AssistantProvider>().currentAssistant;
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
    final latestAssistantIndex = _latestAssistantMessageIndex();
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
        message.isStreaming &&
        message.role == 'assistant' &&
        widget.streamingContentNotifier != null &&
        widget.streamingContentNotifier!.hasNotifier(message.id);

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
    if (!isSpotlight) return messageColumn;

    return TweenAnimationBuilder<double>(
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
  }

  int _latestAssistantMessageIndex() {
    for (var i = widget.messages.length - 1; i >= 0; i--) {
      final message = widget.messages[i];
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
    return _StreamingMessageDataGate(
      notifier: widget.streamingContentNotifier!.getNotifier(message.id),
      deferUpdates: _deferStreamingMessageUpdates,
      builder: (context, data, deferUpdates) {
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
          streamingReasoning = stream_ctrl.ReasoningData()
            ..text = data.reasoningText!
            ..startAt = data.reasoningStartAt ?? r?.startAt
            ..finishedAt = data.reasoningFinishedAt ?? r?.finishedAt
            ..expanded = r?.expanded ?? false;
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
            enableStreamingTextMotion: !deferUpdates,
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
    bool enableStreamingTextMotion = true,
  }) {
    return ChatMessageWidget(
      message: message,
      enableStreamingTextMotion: enableStreamingTextMotion,
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
          ? () => widget.onToggleReasoning?.call(message.id)
          : null,
      translationExpanded: t?.expanded ?? true,
      onToggleTranslation:
          (message.translation != null &&
              message.translation!.isNotEmpty &&
              t != null)
          ? () => widget.onToggleTranslation?.call(message.id)
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
      onEdit: (message.role == 'assistant' || message.role == 'user')
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
        } else if (action == MessageMoreAction.selectMessages) {
          widget.onSelectMessages?.call(index, widget.messages);
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
                      onToggle: () => widget.onToggleReasoningSegment?.call(
                        message.id,
                        entry.key,
                      ),
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
    );
  }
}

class _StreamingMessageDataGate extends StatefulWidget {
  const _StreamingMessageDataGate({
    required this.notifier,
    required this.deferUpdates,
    required this.builder,
  });

  final ValueNotifier<StreamingContentData> notifier;
  final ValueListenable<bool> deferUpdates;
  final Widget Function(
    BuildContext context,
    StreamingContentData data,
    bool deferUpdates,
  )
  builder;

  @override
  State<_StreamingMessageDataGate> createState() =>
      _StreamingMessageDataGateState();
}

class _StreamingMessageDataGateState extends State<_StreamingMessageDataGate> {
  late StreamingContentData _visibleData;
  late bool _deferUpdates;
  bool _hasDeferredUpdate = false;

  @override
  void initState() {
    super.initState();
    _visibleData = widget.notifier.value;
    _deferUpdates = widget.deferUpdates.value;
    widget.notifier.addListener(_handleNotifierChanged);
    widget.deferUpdates.addListener(_handleDeferUpdatesChanged);
  }

  @override
  void didUpdateWidget(covariant _StreamingMessageDataGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notifier != widget.notifier) {
      oldWidget.notifier.removeListener(_handleNotifierChanged);
      _visibleData = widget.notifier.value;
      _hasDeferredUpdate = false;
      widget.notifier.addListener(_handleNotifierChanged);
    }

    if (oldWidget.deferUpdates != widget.deferUpdates) {
      oldWidget.deferUpdates.removeListener(_handleDeferUpdatesChanged);
      _deferUpdates = widget.deferUpdates.value;
      widget.deferUpdates.addListener(_handleDeferUpdatesChanged);
    }
  }

  void _handleNotifierChanged() {
    if (_deferUpdates) {
      _hasDeferredUpdate = true;
      return;
    }
    if (_visibleData == widget.notifier.value) return;
    setState(() {
      _visibleData = widget.notifier.value;
      _hasDeferredUpdate = false;
    });
  }

  void _handleDeferUpdatesChanged() {
    final next = widget.deferUpdates.value;
    if (_deferUpdates == next) return;
    if (!next) {
      _deferUpdates = next;
      final hadDeferredUpdate = _hasDeferredUpdate;
      _applyLatestDeferredData();
      if (!hadDeferredUpdate && _visibleData == widget.notifier.value) {
        setState(() {});
      }
      return;
    }
    setState(() => _deferUpdates = next);
  }

  void _applyLatestDeferredData({bool notify = true}) {
    if (!_hasDeferredUpdate && _visibleData == widget.notifier.value) return;
    if (!notify) {
      _visibleData = widget.notifier.value;
      _hasDeferredUpdate = false;
      return;
    }
    setState(() {
      _visibleData = widget.notifier.value;
      _hasDeferredUpdate = false;
    });
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_handleNotifierChanged);
    widget.deferUpdates.removeListener(_handleDeferUpdatesChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _visibleData, _deferUpdates);
}
