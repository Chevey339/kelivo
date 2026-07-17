import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/models/assistant.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../chat/widgets/chat_message_widget.dart';
import '../../chat/widgets/message_more_sheet.dart';
import '../controllers/stream_controller.dart' as stream_ctrl;
import '../controllers/streaming_content_notifier.dart';
import '../controllers/message_render_model.dart';
import '../controllers/scroll_controller.dart' as scroll_ctrl;
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
/// to avoid redundant computation on every build. Uses a variable-extent lazy
/// list so large histories can scroll and navigate by index without laying out
/// every preceding message.
class MessageListView extends StatefulWidget {
  const MessageListView({
    super.key,
    required this.scrollController,
    required this.listController,
    required this.messages,
    this.renderModels,
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
    this.onUserScrollIntent,
    this.chatFontScale = 1,
    this.showModelIcon = true,
    this.showUserAvatar = true,
    this.showTokenStats = false,
    this.assistant,
  });

  final ScrollController scrollController;
  final ListController listController;

  /// Pre-collapsed messages (from ChatController.collapsedMessages).
  final List<ChatMessage> messages;

  /// Precomputed one-per-slot renderer inputs. Must match [messages] order.
  final List<MessageRenderModel>? renderModels;

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
  final Future<bool> Function()? onLoadMoreBefore;
  final bool hasMoreAfter;
  final Future<bool> Function()? onLoadMoreAfter;
  final VoidCallback? onUserScrollIntent;
  final double chatFontScale;
  final bool showModelIcon;
  final bool showUserAvatar;
  final bool showTokenStats;
  final Assistant? assistant;

  @override
  State<MessageListView> createState() => _MessageListViewState();
}

class _MessageListViewState extends State<MessageListView> {
  static const double _streamingUpdateDeferBottomTolerance = 56.0;

  bool _historyLoadScheduled = false;
  bool _pointerDragInProgress = false;
  bool _userScrollActive = false;
  ScrollMetrics? _latestPointerDragMetrics;
  final ValueNotifier<bool> _deferStreamingMessageUpdates = ValueNotifier<bool>(
    false,
  );
  DateTime? _lastHistoryLoadAt;
  Timer? _scrollIdleTimer;
  bool _pointerScrollActivityCheckScheduled = false;
  late List<MessageRenderModel> _effectiveRenderModels;
  late Map<String, int> _slotIndexById;
  final FocusNode _keyboardFocusNode = FocusNode(
    debugLabel: 'timeline-keyboard-scroll-region',
  );

  String _slotId(ChatMessage message) => message.groupId ?? message.id;

  @override
  void initState() {
    super.initState();
    _refreshRenderModels();
  }

  @override
  void didUpdateWidget(covariant MessageListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldRenderModels = _effectiveRenderModels;
    _refreshRenderModels();
    _synchronizeExtentCache(oldWidget, oldRenderModels);
  }

  void _refreshRenderModels() {
    _effectiveRenderModels =
        widget.renderModels ??
        MessageRenderModelProjector.project(
          messages: widget.messages,
          byGroup: widget.byGroup,
          versionSelections: widget.versionSelections,
          contextDividerIndex: widget.truncCollapsedIndex,
        );
    _slotIndexById = <String, int>{
      for (var index = 0; index < _effectiveRenderModels.length; index++)
        _effectiveRenderModels[index].slotId: index,
    };
  }

  int? _findMessageIndexByKey(Key key) {
    if (key is! ValueKey<String>) return null;
    return _slotIndexById[key.value];
  }

  void _synchronizeExtentCache(
    MessageListView oldWidget,
    List<MessageRenderModel> oldModels,
  ) {
    final controller = widget.listController;
    if (!identical(controller, oldWidget.listController) ||
        !controller.isAttached) {
      return;
    }
    if (controller.isLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.isAttached && !controller.isLocked) {
          controller.invalidateAllExtents();
        }
      });
      return;
    }

    final newModels = _effectiveRenderModels;
    final metricInputsChanged =
        oldWidget.chatFontScale != widget.chatFontScale ||
        oldWidget.selecting != widget.selecting ||
        oldWidget.showModelIcon != widget.showModelIcon ||
        oldWidget.showUserAvatar != widget.showUserAvatar ||
        oldWidget.showTokenStats != widget.showTokenStats ||
        !identical(oldWidget.assistant, widget.assistant);
    if (metricInputsChanged) {
      controller.invalidateAllExtents();
      return;
    }

    if (oldModels.length < newModels.length &&
        _isPrefix(oldModels, newModels)) {
      return;
    }
    if (oldModels.length < newModels.length &&
        _isSuffix(oldModels, newModels)) {
      final anchor = _captureVisibleAnchor(controller);
      final added = newModels.length - oldModels.length;
      for (var index = 0; index < added; index++) {
        controller.addItem(index);
      }
      if (anchor != null) {
        controller.jumpToItem(
          index: anchor.index + added,
          scrollController: widget.scrollController,
          alignment: anchor.alignment,
        );
      }
      return;
    }
    if (newModels.length < oldModels.length &&
        _isPrefix(newModels, oldModels)) {
      return;
    }
    if (newModels.length < oldModels.length &&
        _isSuffix(newModels, oldModels)) {
      final anchor = _captureVisibleAnchor(controller);
      final removed = oldModels.length - newModels.length;
      for (var index = 0; index < removed; index++) {
        controller.removeItem(0);
      }
      if (anchor != null && anchor.index >= removed) {
        controller.jumpToItem(
          index: anchor.index - removed,
          scrollController: widget.scrollController,
          alignment: anchor.alignment,
        );
      }
      return;
    }

    if (oldModels.length == newModels.length) {
      var slotsMatch = true;
      final changedIndices = <int>[];
      for (var index = 0; index < newModels.length; index++) {
        if (oldModels[index].slotId != newModels[index].slotId) {
          slotsMatch = false;
          break;
        }
        if (_messageExtentMayHaveChanged(
          oldModels[index].message,
          newModels[index].message,
        )) {
          changedIndices.add(index);
        }
      }
      if (slotsMatch) {
        final visible = controller.visibleRange;
        final scrollController = widget.scrollController;
        if (changedIndices.length == 1 &&
            visible != null &&
            changedIndices.single < visible.$1 &&
            scrollController is scroll_ctrl.ChatAutoFollowScrollController) {
          final request = scrollController
              .requestPreserveDistanceFromEndDuringLayout();
          if (request != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              scrollController.finishPreserveDistanceFromEndDuringLayout(
                request,
              );
            });
          }
        }
        for (final index in changedIndices) {
          controller.invalidateExtent(index);
        }
        return;
      }
    }

    controller.invalidateAllExtents();
  }

  ({int index, double alignment})? _captureVisibleAnchor(
    ListController controller,
  ) {
    if (!widget.scrollController.hasClients) return null;
    final visible = controller.visibleRange;
    if (visible == null) return null;
    final index = visible.$1;
    final position = widget.scrollController.position;
    final itemExtent = controller.extentForIndex(index).$1;
    // This is the same offset query used by jumpToItem. It is safe here,
    // before the new child list enters layout.
    // ignore: invalid_use_of_visible_for_testing_member
    final itemLeading = controller.getOffsetToReveal(index, 0);
    final availableAlignmentExtent = position.viewportDimension - itemExtent;
    final alignment = availableAlignmentExtent.abs() < 0.5
        ? 0.0
        : (itemLeading - position.pixels) / availableAlignmentExtent;
    return (index: index, alignment: alignment);
  }

  bool _messageExtentMayHaveChanged(ChatMessage old, ChatMessage current) {
    return old.id != current.id ||
        old.role != current.role ||
        old.content != current.content ||
        old.reasoningText != current.reasoningText ||
        old.translation != current.translation ||
        old.reasoningSegmentsJson != current.reasoningSegmentsJson ||
        old.modelId != current.modelId ||
        old.providerId != current.providerId ||
        old.totalTokens != current.totalTokens ||
        old.promptTokens != current.promptTokens ||
        old.completionTokens != current.completionTokens ||
        old.cachedTokens != current.cachedTokens ||
        old.durationMs != current.durationMs;
  }

  bool _isPrefix(
    List<MessageRenderModel> prefix,
    List<MessageRenderModel> values,
  ) {
    if (prefix.length > values.length) return false;
    for (var index = 0; index < prefix.length; index++) {
      if (prefix[index].slotId != values[index].slotId) return false;
    }
    return true;
  }

  bool _isSuffix(
    List<MessageRenderModel> suffix,
    List<MessageRenderModel> values,
  ) {
    if (suffix.length > values.length) return false;
    final offset = values.length - suffix.length;
    for (var index = 0; index < suffix.length; index++) {
      if (suffix[index].slotId != values[offset + index].slotId) return false;
    }
    return true;
  }

  bool get _isDesktopPlatform =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  ScrollViewKeyboardDismissBehavior get _keyboardDismissBehavior {
    if (_isDesktopPlatform) {
      return ScrollViewKeyboardDismissBehavior.manual;
    }
    return ScrollViewKeyboardDismissBehavior.onDrag;
  }

  @override
  void dispose() {
    _scrollIdleTimer?.cancel();
    _deferStreamingMessageUpdates.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
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
    final presentation = _MessagePresentation(
      chatFontScale: widget.chatFontScale,
      showModelIcon: widget.showModelIcon,
      showUserAvatar: widget.showUserAvatar,
      showTokenStats: widget.showTokenStats,
      assistant: widget.assistant,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPad =
            ((constraints.maxWidth - ChatLayoutConstants.maxContentWidth) / 2)
                .clamp(0.0, double.infinity);

        return ValueListenableBuilder<bool>(
          valueListenable: widget.isProcessingFiles,
          builder: (context, isProcessing, child) {
            final list = SuperListView.builder(
              controller: widget.scrollController,
              listController: widget.listController,
              cacheExtent: 600,
              delayPopulatingCacheArea: false,
              addRepaintBoundaries: false,
              findChildIndexCallback: _findMessageIndexByKey,
              padding: EdgeInsets.fromLTRB(
                horizontalPad,
                widget.topContentPadding,
                horizontalPad,
                widget.bottomContentPadding +
                    (widget.isPinnedIndicatorActive ? 12 : 0),
              ),
              itemCount: _effectiveRenderModels.length,
              keyboardDismissBehavior: _keyboardDismissBehavior,
              itemBuilder: (context, index) {
                if (index < 0 || index >= _effectiveRenderModels.length) {
                  return const SizedBox.shrink();
                }
                return _buildMessageItem(
                  context,
                  index: index,
                  isProcessingFiles: isProcessing,
                  presentation: presentation,
                );
              },
            );

            final historyList = NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: list,
            );

            final userScrollAwareList = Listener(
              onPointerDown: (event) {
                if (_isDesktopPlatform) _keyboardFocusNode.requestFocus();
                if (event.buttons != 0 &&
                    event.buttons != kSecondaryMouseButton) {
                  _pointerDragInProgress = true;
                  _latestPointerDragMetrics = null;
                }
              },
              onPointerUp: (_) => _settlePointerDrag(),
              onPointerCancel: (_) => _settlePointerDrag(),
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  _schedulePointerScrollActivityCheck();
                }
              },
              child: Focus(
                key: const ValueKey('timeline-keyboard-scroll-region'),
                focusNode: _keyboardFocusNode,
                onKeyEvent: _handleTimelineKeyEvent,
                child: historyList,
              ),
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

  KeyEventResult _handleTimelineKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.arrowUp &&
        key != LogicalKeyboardKey.arrowDown &&
        key != LogicalKeyboardKey.pageUp &&
        key != LogicalKeyboardKey.pageDown &&
        key != LogicalKeyboardKey.home &&
        key != LogicalKeyboardKey.end) {
      return KeyEventResult.ignored;
    }
    widget.onUserScrollIntent?.call();
    return KeyEventResult.ignored;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollUpdateNotification) {
      if (notification.dragDetails != null) {
        _recordPointerDrag(notification.metrics);
      }
    } else if (notification is OverscrollNotification) {
      if (notification.dragDetails != null) {
        _recordPointerDrag(notification.metrics);
      }
    } else if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _recordPointerDrag(notification.metrics);
    }
    if (notification is UserScrollNotification) {
      final shouldDefer = notification.direction != ScrollDirection.idle;
      if (shouldDefer) {
        _userScrollActive = true;
        _scrollIdleTimer?.cancel();
        _scrollIdleTimer = null;
        _setDeferStreamingMessageUpdates(true);
      } else {
        _userScrollActive = false;
        _scheduleStreamingUpdateResume();
      }
    }
    if (notification is ScrollEndNotification) {
      _userScrollActive = false;
      _scheduleStreamingUpdateResume();
    }
    if (_historyLoadScheduled) return false;
    final now = DateTime.now();
    final last = _lastHistoryLoadAt;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 120)) {
      return false;
    }

    final isNearTop = notification.metrics.pixels <= 96;
    final isNearBottom =
        notification.metrics.maxScrollExtent - notification.metrics.pixels <=
        96;
    if (isNearTop && widget.hasMoreBefore && widget.onLoadMoreBefore != null) {
      _scheduleHistoryLoad(load: widget.onLoadMoreBefore!);
    } else if (isNearBottom &&
        widget.hasMoreAfter &&
        widget.onLoadMoreAfter != null) {
      _scheduleHistoryLoad(load: widget.onLoadMoreAfter!);
    }
    return false;
  }

  void _recordPointerDrag(ScrollMetrics metrics) {
    _pointerDragInProgress = true;
    _latestPointerDragMetrics = metrics;
  }

  void _settlePointerDrag([ScrollMetrics? metrics]) {
    if (!_pointerDragInProgress) return;
    _pointerDragInProgress = false;
    final settledMetrics = metrics ?? _latestPointerDragMetrics;
    _latestPointerDragMetrics = null;
    _handleUserScrollActivity(settledMetrics);
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
    widget.onUserScrollIntent?.call();
    if (_isWithinStreamingAutoFollowBand(metrics)) {
      _resumeStreamingMessageUpdates();
      return;
    }
    _setDeferStreamingMessageUpdates(true);
    _scheduleStreamingUpdateResume();
  }

  bool _isWithinStreamingAutoFollowBand([ScrollMetrics? metrics]) {
    if (metrics != null) {
      final gap = _contentMaxScrollExtent(metrics) - metrics.pixels;
      return gap <= _streamingUpdateDeferBottomTolerance;
    }
    if (!widget.scrollController.hasClients) return true;
    final position = widget.scrollController.position;
    final gap = _contentMaxScrollExtent(position) - position.pixels;
    return gap <= _streamingUpdateDeferBottomTolerance;
  }

  double _contentMaxScrollExtent(ScrollMetrics metrics) {
    return metrics.maxScrollExtent;
  }

  void _setDeferStreamingMessageUpdates(bool value) {
    if (_deferStreamingMessageUpdates.value == value) return;
    _deferStreamingMessageUpdates.value = value;
  }

  void _scheduleStreamingUpdateResume() {
    if (_pointerDragInProgress || _userScrollActive) return;
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

  void _scheduleHistoryLoad({required Future<bool> Function() load}) {
    _historyLoadScheduled = true;
    _lastHistoryLoadAt = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _historyLoadScheduled = false;
        return;
      }

      final loaded = await load();
      if (!mounted) {
        _historyLoadScheduled = false;
        return;
      }
      if (!loaded) {
        _historyLoadScheduled = false;
        return;
      }

      _historyLoadScheduled = false;
    });
  }

  Widget _buildMessageItem(
    BuildContext context, {
    required int index,
    required bool isProcessingFiles,
    required _MessagePresentation presentation,
  }) {
    final model = _effectiveRenderModels[index];
    final message = model.message;
    final r = widget.reasoning[message.id];
    final t = widget.translations[message.id];
    final assistant = presentation.assistant;
    final useAssistAvatar = assistant?.useAssistantAvatar == true;
    final useAssistName = assistant?.useAssistantName == true;
    final gid = model.slotId;
    final selectedIdx = model.selectedVersionIndex;
    final total = model.versionCount;
    final messageSuggestions =
        !widget.selecting &&
            model.isLatestCompleteAssistant &&
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
      key: ValueKey<String>('timeline-slot:${_slotId(message)}'),
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
                        textScaler: TextScaler.linear(
                          textScale * presentation.chatFontScale,
                        ),
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
                              presentation: presentation,
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
                              presentation: presentation,
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
        if (model.showContextDivider)
          Padding(
            padding: widget.dividerPadding,
            child: _buildContextDivider(context),
          ),
      ],
    );
    final isSpotlight =
        widget.spotlightMessageId != null &&
        message.id == widget.spotlightMessageId;
    if (!isSpotlight) {
      return RepaintBoundary(
        key: ValueKey<String>(model.slotId),
        child: messageColumn,
      );
    }

    return RepaintBoundary(
      key: ValueKey<String>(model.slotId),
      child: TweenAnimationBuilder<double>(
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
      ),
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
    required _MessagePresentation presentation,
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
            presentation: presentation,
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
    required _MessagePresentation presentation,
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
      showModelIcon: useAssistAvatar ? false : presentation.showModelIcon,
      useAssistantAvatar: useAssistAvatar && message.role == 'assistant',
      useAssistantName: useAssistName && message.role == 'assistant',
      assistantName: (useAssistAvatar || useAssistName)
          ? (assistant?.name ?? 'Assistant')
          : null,
      assistantAvatar: useAssistAvatar ? (assistant?.avatar ?? '') : null,
      showUserAvatar: presentation.showUserAvatar,
      showTokenStats: presentation.showTokenStats,
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

final class _MessagePresentation {
  const _MessagePresentation({
    required this.chatFontScale,
    required this.showModelIcon,
    required this.showUserAvatar,
    required this.showTokenStats,
    required this.assistant,
  });

  final double chatFontScale;
  final bool showModelIcon;
  final bool showUserAvatar;
  final bool showTokenStats;
  final Assistant? assistant;
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
