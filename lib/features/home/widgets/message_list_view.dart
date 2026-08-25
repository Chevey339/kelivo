import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/models/message_part.dart';
import '../../../core/models/assistant.dart';
import '../../../core/models/assistant_regex.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/assistant_regex.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../chat/widgets/chat_message_widget.dart';
import '../../chat/widgets/timeline_projection.dart';
import '../../chat/widgets/timeline_visibility.dart';
import '../../chat/utils/thinking_tag_parser.dart';
import '../../chat/widgets/message_more_sheet.dart';
import '../controllers/stream_controller.dart' as stream_ctrl;
import '../controllers/streaming_content_notifier.dart';
import '../controllers/message_render_model.dart';
import '../controllers/scroll_controller.dart' as scroll_ctrl;
import '../services/ask_user_interaction_service.dart';
import '../services/local_tools_service.dart';
import '../services/tool_approval_service.dart';
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
    required this.processingFilesMessageId,
    this.streamingContentNotifier,
    this.spotlightMessageId,
    this.spotlightToken = 0,
    this.removingSlotIds = const <String>{},
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
    this.isLoadingWindow = false,
    this.onLoadMoreBefore,
    this.hasMoreAfter = false,
    this.onLoadMoreAfter,
    this.onUserScrollIntent,
    this.chatFontScale = 1,
    this.collapseThinking = true,
    this.collapseThinkingSteps = false,
    this.showThinkingCards = true,
    this.showToolCards = true,
    this.showToolResultSummary = false,
    this.hideToolResultImages = false,
    this.collapsedCodeLines,
    this.wrapCodeBlocks = false,
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

  /// Assistant message currently parsing its attachments, or null. Scoped to a
  /// single message so the indicator never renders on every assistant reply.
  final ValueNotifier<String?> processingFilesMessageId;

  /// Lightweight notifier for streaming content updates.
  /// When provided, streaming messages will use ValueListenableBuilder
  /// to avoid full page rebuilds.
  final StreamingContentNotifier? streamingContentNotifier;

  /// When set, the message with this ID will receive a spotlight pulse animation.
  final String? spotlightMessageId;

  /// Incremented each time a new spotlight is triggered. Used as an animation key
  /// so re-selecting the same message re-triggers the pulse.
  final int spotlightToken;

  /// Slots currently fading out ahead of their deletion. The slot data stays
  /// in [messages] until the removal animation completes.
  final Set<String> removingSlotIds;

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

  /// True only while a cold initial window load is in flight; fast-path cache
  /// hits resolve within one frame batch and never surface the skeleton.
  final bool isLoadingWindow;
  final Future<bool> Function()? onLoadMoreBefore;
  final bool hasMoreAfter;
  final Future<bool> Function()? onLoadMoreAfter;
  final VoidCallback? onUserScrollIntent;
  final double chatFontScale;

  /// Whether finished thinking blocks render collapsed (display setting).
  final bool collapseThinking;

  /// Whether each timeline block keeps only the last two steps plus an expand
  /// row. Must match the renderer so estimates do not assume every tool header
  /// is visible.
  final bool collapseThinkingSteps;

  /// Whether thinking-process cards render in chat.
  final bool showThinkingCards;

  /// Whether tool-use cards render in chat.
  final bool showToolCards;

  /// Whether collapsed tool cards also show a short result summary.
  final bool showToolResultSummary;

  /// Whether tool-result image thumbnails are hidden under the card.
  final bool hideToolResultImages;

  /// Lines a long code block collapses to, or null when it stays expanded.
  final int? collapsedCodeLines;

  /// Whether code blocks wrap (desktop, or the mobile wrap setting) instead of
  /// scrolling horizontally.
  final bool wrapCodeBlocks;

  final bool showModelIcon;
  final bool showUserAvatar;
  final bool showTokenStats;
  final Assistant? assistant;

  @visibleForTesting
  static const Key windowSkeletonKey = ValueKey<String>(
    'timeline-window-skeleton',
  );

  @override
  State<MessageListView> createState() => _MessageListViewState();
}

class _MessageListViewState extends State<MessageListView> {
  static const double _streamingUpdateDeferBottomTolerance = 56.0;

  bool _historyLoadScheduled = false;
  bool _pointerDragInProgress = false;
  ScrollMetrics? _latestPointerDragMetrics;
  bool _userScrollActive = false;
  final ValueNotifier<bool> _deferStreamingMessageUpdates = ValueNotifier<bool>(
    false,
  );

  /// Frozen streaming payloads keyed by message id, captured when defer
  /// starts. SuperSliverList must not AutomaticKeepAlive the row — that
  /// parks it off-stage, so [find.text] and the on-screen bubble lose the
  /// initial text. The visible item builder paints this snapshot instead.
  final Map<String, StreamingContentData> _deferredStreamingHolds =
      <String, StreamingContentData>{};
  DateTime? _lastHistoryLoadAt;
  Timer? _scrollIdleTimer;
  bool _pointerScrollActivityCheckScheduled = false;
  late List<MessageRenderModel> _effectiveRenderModels;
  late Map<String, int> _slotIndexById;
  late Map<String, int> _messageIndexById;
  final Map<String, int> _lastToolSignatures = <String, int>{};
  final ToolExtentInvalidationQueue _toolExtentQueue =
      ToolExtentInvalidationQueue();
  var _awaitingAttachFlush = false;
  var _attachFlushScheduled = false;
  final FocusNode _keyboardFocusNode = FocusNode(
    debugLabel: 'timeline-keyboard-scroll-region',
  );

  String _slotId(ChatMessage message) => message.groupId ?? message.id;

  @override
  void initState() {
    super.initState();
    _refreshRenderModels();
    _snapshotToolSignatures();
    widget.streamingContentNotifier?.toolHeightEvents.addListener(
      _handleToolHeightEvent,
    );
  }

  @override
  void didUpdateWidget(covariant MessageListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamingContentNotifier != widget.streamingContentNotifier) {
      oldWidget.streamingContentNotifier?.toolHeightEvents.removeListener(
        _handleToolHeightEvent,
      );
      widget.streamingContentNotifier?.toolHeightEvents.addListener(
        _handleToolHeightEvent,
      );
    }
    if (!identical(oldWidget.listController, widget.listController)) {
      _awaitingAttachFlush = _toolExtentQueue.pendingIds.isNotEmpty;
      _scheduleAttachAwareFlush();
    }
    final oldRenderModels = _effectiveRenderModels;
    _refreshRenderModels();
    _synchronizeExtentCache(oldWidget, oldRenderModels);
    _snapshotToolSignatures();
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
    _messageIndexById = <String, int>{
      for (var index = 0; index < _effectiveRenderModels.length; index++)
        _effectiveRenderModels[index].message.id: index,
    };
  }

  void _snapshotToolSignatures() {
    _lastToolSignatures
      ..clear()
      ..addAll({
        for (final model in _effectiveRenderModels)
          model.message.id: _toolEstimateSignature(
            widget.toolParts[model.message.id],
          ),
      });
  }

  void _handleToolHeightEvent() {
    final event = widget.streamingContentNotifier?.toolHeightEvents.value;
    if (event == null) return;
    _invalidateToolExtentForMessage(event.messageId);
  }

  void _onInlineImageAspect(
    String messageId,
    String imageKey,
    double aspectRatio,
  ) {
    if (aspectRatio <= 0 || !aspectRatio.isFinite) return;
    final previous = timelineImageAspects[imageKey];
    if (previous != null && (previous - aspectRatio).abs() < 0.001) return;
    timelineImageAspects[imageKey] = aspectRatio;
    _invalidateToolExtentForMessage(messageId);
  }

  void _invalidateToolExtentForMessage(String messageId) {
    _extentEstimateCache.remove(messageId);
    final controller = widget.listController;
    if (!controller.isAttached) {
      _toolExtentQueue.retain(messageId);
      _awaitingAttachFlush = true;
      _scheduleAttachAwareFlush();
      return;
    }
    if (!controller.isLocked) {
      _applyToolExtentInvalidation(messageId);
      return;
    }
    if (_toolExtentQueue.enqueue(messageId)) {
      _scheduleToolExtentFlush();
    }
  }

  void _scheduleAttachAwareFlush() {
    if (_attachFlushScheduled) return;
    if (!_awaitingAttachFlush && _toolExtentQueue.pendingIds.isEmpty) {
      return;
    }
    _attachFlushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attachFlushScheduled = false;
      if (!mounted) return;
      if (!widget.listController.isAttached) return;
      _awaitingAttachFlush = false;
      if (_toolExtentQueue.pendingIds.isEmpty) return;
      _scheduleToolExtentFlush();
    });
  }

  void _scheduleToolExtentFlush() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = widget.listController;
      final result = _toolExtentQueue.takeForFlush(
        mounted: mounted,
        isAttached: controller.isAttached,
        isLocked: controller.isLocked,
      );
      for (final id in result.ids) {
        _applyToolExtentInvalidation(id);
      }
      if (result.reschedule) {
        _scheduleToolExtentFlush();
      } else if (_toolExtentQueue.pendingIds.isNotEmpty) {
        _awaitingAttachFlush = true;
        _scheduleAttachAwareFlush();
      }
    });
  }

  void _invalidateExtentsForApprovalChange(
    List<PendingApprovalKey> previous,
    List<PendingApprovalKey> next,
  ) {
    final previousSet = previous.toSet();
    final nextSet = next.toSet();
    final changed = <PendingApprovalKey>{
      ...previousSet.difference(nextSet),
      ...nextSet.difference(previousSet),
    };
    if (changed.isEmpty && previous.length != next.length) {
      changed.addAll(nextSet);
    }
    if (changed.isEmpty) return;
    for (final model in _effectiveRenderModels) {
      final parts = widget.toolParts[model.message.id];
      if (parts == null || parts.isEmpty) continue;
      final conversationId = model.message.conversationId;
      final affected = parts.any((part) {
        for (final key in changed) {
          if (key.matches(
            conversationId: conversationId,
            toolCallId: part.id,
          )) {
            return true;
          }
        }
        return false;
      });
      if (affected) {
        _invalidateToolExtentForMessage(model.message.id);
      }
    }
  }

  void _applyToolExtentInvalidation(String messageId) {
    final controller = widget.listController;
    if (!controller.isAttached || controller.isLocked) return;
    final index = _messageIndexById[messageId];
    if (index == null) return;
    final visible = controller.visibleRange;
    final scrollController = widget.scrollController;
    if (visible != null &&
        index < visible.$1 &&
        scrollController is scroll_ctrl.ChatAutoFollowScrollController) {
      final request = scrollController
          .requestPreserveDistanceFromEndDuringLayout();
      if (request != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scrollController.finishPreserveDistanceFromEndDuringLayout(request);
        });
      }
    }
    controller.invalidateExtent(index);
  }

  /// Header row + action bar + vertical margins around a bubble.
  static const double _estimateChrome = 96.0;

  /// Height of a collapsed inline thinking card.
  static const double _estimateCollapsedCard = 44.0;

  /// Expand-steps row shown when a timeline block is collapsed.
  static const double _estimateExpandRow = 36.0;

  /// Characters scanned before a message's line density is extrapolated.
  static const int _estimateScanLimit = 8000;

  /// Font size fenced code renders at, before scaling.
  static const double _estimateCodeFontSize = 13.0;

  /// Longest message the thinking parser is run over.
  static const int _estimateParseLimit = 64000;

  /// Cached estimates kept before the memo is dropped wholesale.
  static const int _extentEstimateCacheLimit = 512;

  final Map<String, _ExtentEstimate> _extentEstimateCache = {};

  /// System accessibility text scale, which multiplies the chat font scale.
  double _systemTextScale = 1.0;

  /// Display settings the estimate depends on, refreshed in [build].
  ToolApprovalService? _approvalForEstimate;
  _EstimateSettings _estimateSettings = const _EstimateSettings(
    collapseThinking: true,
    collapseThinkingSteps: false,
    showThinkingCards: true,
    showToolCards: true,
    showToolResultSummary: false,
    hideToolResultImages: false,
    collapsedCodeLines: null,
    wrapCodeBlocks: false,
    visualRegexSignature: 0,
    pendingApprovals: <PendingApprovalKey>[],
  );

  /// Font scale the currently stored extents were estimated at.
  double? _estimatedFontScale;

  /// Drops stored extents after the system text scale changed.
  ///
  /// Only the widget-driven inputs go through [_synchronizeExtentCache]; a
  /// system accessibility change arrives through MediaQuery without touching
  /// the item count, so SuperSliverList would otherwise keep off-screen
  /// estimates made at the old scale until each of them is scrolled into view.
  void _invalidateEstimatesIfScaleChanged() {
    final scale = widget.chatFontScale * _systemTextScale;
    if (_estimatedFontScale == scale) return;
    final hadEstimates = _estimatedFontScale != null;
    _estimatedFontScale = scale;
    if (!hadEstimates) return;
    final controller = widget.listController;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.isAttached || controller.isLocked) return;
      controller.invalidateAllExtents();
    });
  }

  /// Rough height of a message bubble, used for items that never got laid out.
  ///
  /// SuperSliverList's default estimate is a flat 100px. In a long chat a real
  /// bubble is one to two orders of magnitude taller than that, so every time
  /// layout replaces an estimate with a measurement the total extent — and with
  /// it the bottom-pinned scroll offset — moves by tens of thousands of pixels.
  /// When that lands across two frames the timeline visibly flicks away from
  /// the bottom and back. A content-derived estimate keeps those corrections
  /// small; it does not need to be exact, only the right order of magnitude.
  double _estimateItemExtent(int? index, double crossAxisExtent) {
    // A null index asks whether one extent fits every item. Answering with a
    // positive number makes SuperSliverList apply it to the whole list without
    // ever consulting the per-item branch below, so this has to be 0.
    if (index == null) return 0;
    final models = _effectiveRenderModels;
    if (index < 0 || index >= models.length) return _estimateChrome;

    final message = models[index].message;
    final snapshot = _streamingSnapshot(message);
    final estimateParts = snapshot?.parts ?? message.parts;
    final text = snapshot != null && snapshot.content.isNotEmpty
        ? snapshot.content
        : message.content;
    final reasoning = message.role == 'assistant'
        ? widget.reasoning[message.id]
        : null;
    final reasoningSegments = message.role == 'assistant'
        ? widget.reasoningSegments[message.id]
        : null;
    final hasReasoning =
        (reasoning?.text.isNotEmpty ?? false) ||
        (reasoningSegments?.isNotEmpty ?? false);
    final toolParts = message.role == 'assistant'
        ? widget.toolParts[message.id]
        : null;
    final hasTools = toolParts != null && toolParts.isNotEmpty;
    final hasStructuredTimeline =
        message.role == 'assistant' &&
        estimateParts.any(
          (part) =>
              part is ReasoningPart ||
              part is ToolCallPart ||
              part is ImagePart,
        );
    if (text.isEmpty && !hasReasoning && !hasTools && !hasStructuredTimeline) {
      return _estimateChrome;
    }

    // Layout asks for the same item repeatedly (every resize, every window
    // change), and the scan below is linear in the message length, so a memo
    // keyed by everything the result depends on keeps the layout phase cheap.
    // The content is compared by identity: an edited or streamed message always
    // carries a new string, and equal-length rewrites must not hit the memo.
    final fontScale = widget.chatFontScale * _systemTextScale;
    final settings = _estimateSettings;
    final reasoningSignature = _reasoningEstimateSignature(
      reasoning,
      reasoningSegments,
      isStreaming: message.isStreaming,
    );
    final toolSignature = _toolEstimateSignature(toolParts);
    final partsSignature = _partsEstimateSignature(estimateParts);
    final streamingSignature = Object.hash(
      snapshot?.timelineStructureSignature ?? 0,
      snapshot?.reasoningFinishedAt,
      message.isStreaming,
    );
    final estimateContent = text;
    final cached = _extentEstimateCache[message.id];
    if (cached != null &&
        identical(cached.content, estimateContent) &&
        cached.crossAxisExtent == crossAxisExtent &&
        cached.fontScale == fontScale &&
        cached.settings == settings &&
        cached.reasoningSignature == reasoningSignature &&
        cached.toolSignature == toolSignature &&
        cached.partsSignature == partsSignature &&
        cached.streamingSignature == streamingSignature) {
      return cached.extent;
    }

    // Standalone tool rows render as their own card — or as nothing when the
    // user hid tool cards. Ask-user cards stay up so generation is not blocked.
    // Pending-approval exceptions do not apply here: `_buildToolMessage`
    // always builds these rows with `loading: false`.
    if (message.role == 'tool' &&
        !settings.showToolCards &&
        !_hiddenStandaloneToolMessageRemainsVisible(text)) {
      if (_extentEstimateCache.length > _extentEstimateCacheLimit) {
        _extentEstimateCache.clear();
      }
      _extentEstimateCache[message.id] = _ExtentEstimate(
        content: estimateContent,
        crossAxisExtent: crossAxisExtent,
        fontScale: fontScale,
        settings: settings,
        reasoningSignature: reasoningSignature,
        toolSignature: toolSignature,
        partsSignature: partsSignature,
        streamingSignature: streamingSignature,
        extent: 0,
      );
      return 0;
    }

    // Inline thinking renders as its own card. When it is collapsed — or when
    // thinking cards are hidden entirely — only the visible remainder takes
    // space, so parse it out with the same parser the renderer uses.
    var body = text;
    var collapsedCards = 0;
    final shouldStripInlineThink =
        message.role != 'user' &&
        text.length <= _estimateParseLimit &&
        text.contains('<') &&
        (!settings.showThinkingCards || settings.collapseThinking);
    if (shouldStripInlineThink) {
      final parsed = ThinkingTagParser.parseLegacyInlineBlocks(text);
      if (parsed.hasThinking) {
        body = parsed.visibleContent;
        if (settings.showThinkingCards) {
          collapsedCards = parsed.thinkingTexts.length;
        }
      }
    }

    final fontSize = 15.6 * fontScale;
    final lineHeight = fontSize * 1.5;
    // User bubbles are inset and never span the full width.
    final bubbleWidth = crossAxisExtent * (message.role == 'user' ? 0.85 : 1.0);
    final textWidth = math.max(80.0, bubbleWidth - 28);
    // Wide (CJK) glyphs are about twice as wide as Latin ones, so the mix
    // decides how many characters fit on a line.
    final charWidth = fontSize * (0.5 + 0.55 * _wideCharRatio(body));
    final charsPerLine = math.max(1.0, textWidth / charWidth);
    // Code renders in a fixed 13px monospace face, so it wraps at a different
    // column and stacks at a different row height than the body text.
    final codeFontSize = _estimateCodeFontSize * fontScale;
    final codeCharsPerLine = math.max(1.0, textWidth / (codeFontSize * 0.6));
    // An empty body still reports one wrapped line; skip it so a tools-only
    // assistant turn is chrome + cards, not chrome + a phantom text row.
    final visualBody = _estimateVisualTransform(
      body,
      scope: message.role == 'user'
          ? AssistantRegexScope.user
          : AssistantRegexScope.assistant,
    );
    final timeline = _estimateTimelineExtent(
      message: message,
      parts: estimateParts,
      toolParts: toolParts,
      reasoning: reasoning,
      reasoningSegments: reasoningSegments,
      visualContent: visualBody,
      contentSplitOffsets:
          snapshot?.contentSplitOffsets ??
          widget.contentSplits[message.id]?.offsets,
      reasoningCountAtSplit:
          snapshot?.reasoningCountAtSplit ??
          widget.contentSplits[message.id]?.reasoningCounts,
      toolCountAtSplit:
          snapshot?.toolCountAtSplit ??
          widget.contentSplits[message.id]?.toolCounts,
      textWidth: textWidth,
      fontScale: fontScale,
    );
    final bodyForLines = message.role == 'assistant'
        ? (timeline.extent > 0 ? '' : visualBody)
        : visualBody;
    final bodyLines = bodyForLines.isEmpty
        ? 0.0
        : _wrappedLineCount(
            bodyForLines,
            charsPerLine: charsPerLine,
            codeCharsPerLine: settings.wrapCodeBlocks ? codeCharsPerLine : null,
            codeLineRatio: codeFontSize / fontSize,
            collapsedCodeLines: settings.collapsedCodeLines,
          );
    final extent =
        bodyLines * lineHeight +
        _estimateChrome +
        collapsedCards * _estimateCollapsedCard +
        timeline.extent;

    if (_extentEstimateCache.length > _extentEstimateCacheLimit) {
      _extentEstimateCache.clear();
    }
    _extentEstimateCache[message.id] = _ExtentEstimate(
      content: estimateContent,
      crossAxisExtent: crossAxisExtent,
      fontScale: fontScale,
      settings: settings,
      reasoningSignature: reasoningSignature,
      toolSignature: toolSignature,
      partsSignature: partsSignature,
      streamingSignature: streamingSignature,
      extent: extent,
    );
    return extent;
  }

  /// Timeline height from the same projector the renderer uses.
  StreamingContentData? _streamingSnapshot(ChatMessage message) {
    if (!message.isStreaming) return null;
    if (_deferStreamingMessageUpdates.value) {
      final hold = _deferredStreamingHolds[message.id];
      if (hold != null) return hold;
    }
    final notifier = widget.streamingContentNotifier;
    if (notifier == null || !notifier.hasNotifier(message.id)) return null;
    return notifier.getNotifier(message.id).value;
  }

  ({double extent, bool fromParts}) _estimateTimelineExtent({
    required ChatMessage message,
    required List<MessagePart> parts,
    required List<ToolUIPart>? toolParts,
    required stream_ctrl.ReasoningData? reasoning,
    required List<stream_ctrl.ReasoningSegmentData>? reasoningSegments,
    required String visualContent,
    required List<int>? contentSplitOffsets,
    required List<int>? reasoningCountAtSplit,
    required List<int>? toolCountAtSplit,
    required double textWidth,
    required double fontScale,
  }) {
    if (message.role != 'assistant') {
      return (extent: 0, fromParts: false);
    }
    final settings = _estimateSettings;
    final liveTools = <TimelineToolRef>[
      for (var i = 0; i < (toolParts?.length ?? 0); i++)
        TimelineToolRef(
          providerId: toolParts![i].id,
          fallbackOrdinal: i,
          toolName: toolParts[i].toolName,
          arguments: toolParts[i].arguments,
          content: toolParts[i].content,
          loading: toolParts[i].loading,
          memoToken: identityHashCode(toolParts[i]),
        ),
    ];
    final reasoningRefs = <TimelineReasoningRef>[
      if (reasoningSegments != null && reasoningSegments.isNotEmpty)
        for (final segment in reasoningSegments)
          TimelineReasoningRef(
            text: segment.text,
            expanded: segment.expanded,
            loading: timelineReasoningLoading(
              finishedAt: segment.finishedAt,
              isStreaming: message.isStreaming,
            ),
            startAt: segment.startAt,
            finishedAt: segment.finishedAt,
            toolStartIndex: segment.toolStartIndex,
          )
      else if (reasoning != null && reasoning.text.isNotEmpty)
        TimelineReasoningRef(
          text: reasoning.text,
          expanded: reasoning.expanded,
          loading: timelineReasoningLoading(
            finishedAt: reasoning.finishedAt,
            isStreaming: message.isStreaming,
          ),
          startAt: reasoning.startAt,
          finishedAt: reasoning.finishedAt,
        ),
    ];
    final projected = projectAssistantTimeline(
      parts: parts,
      liveTools: liveTools,
      reasoningSegments: reasoningRefs,
      visualContent: visualContent,
      contentSplitOffsets: contentSplitOffsets,
      reasoningCountAtSplit: reasoningCountAtSplit,
      toolCountAtSplit: toolCountAtSplit,
      transformText: _estimateVisualTransform,
      partsArrivalOrdered: message.isStreaming,
    );
    bool isPending(TimelineToolRef tool) => _isPendingApproval(
      conversationId: message.conversationId,
      toolCallId: tool.providerId,
    );
    var extent = 0.0;
    var visibleBlockCount = 0;
    void addVisible(double height) {
      if (visibleBlockCount > 0) extent += 8.0;
      extent += height;
      visibleBlockCount++;
    }

    final fontSize = 15.6 * fontScale;
    final lineHeight = fontSize * 1.5;
    final codeFontSize = _estimateCodeFontSize * fontScale;
    final codeCharsPerLine = math.max(1.0, textWidth / (codeFontSize * 0.6));
    for (final block in visibleAssistantTimeline(
      projected,
      showThinkingCards: settings.showThinkingCards,
      showToolCards: settings.showToolCards,
      isPendingApproval: isPending,
    )) {
      if (block.isImage) {
        addVisible(
          estimateTimelineImageHeight(
            maxWidth: textWidth,
            aspectRatio:
                block.aspectRatio ?? timelineImageAspects[block.imageKey],
          ),
        );
        continue;
      }
      if (block.isText && block.text != null) {
        final charWidth = fontSize * (0.5 + 0.55 * _wideCharRatio(block.text!));
        final charsPerLine = math.max(1.0, textWidth / charWidth);
        addVisible(
          _wrappedLineCount(
                block.text!,
                charsPerLine: charsPerLine,
                codeCharsPerLine: settings.wrapCodeBlocks
                    ? codeCharsPerLine
                    : null,
                codeLineRatio: codeFontSize / fontSize,
                collapsedCodeLines: settings.collapsedCodeLines,
              ) *
              lineHeight,
        );
        continue;
      }
      if (!block.isThinking) continue;
      final collapsed = collapseTimelineSteps(
        block.thinkingSteps,
        collapseThinkingSteps: settings.collapseThinkingSteps,
      );
      addVisible(
        _estimateVisibleThinkingHeight(
          VisibleTimelineBlock(
            visibleSteps: collapsed.visibleSteps,
            hiddenCount: collapsed.hiddenCount,
          ),
          conversationId: message.conversationId,
          textWidth: textWidth,
          fontScale: fontScale,
        ),
      );
    }
    return (extent: extent, fromParts: projected.fromParts);
  }

  double _estimateVisibleThinkingHeight(
    VisibleTimelineBlock visible, {
    required String conversationId,
    required double textWidth,
    required double fontScale,
  }) {
    final settings = _estimateSettings;
    var extent = 0.0;
    if (visible.hasExpandRow) extent += _estimateExpandRow;
    for (final step in visible.visibleSteps) {
      if (step.isReasoning) {
        extent += _estimateReasoningStepHeight(
          step.reasoning!,
          textWidth: textWidth,
          fontScale: fontScale,
        );
      } else {
        final tool = step.tool!;
        extent += _estimateCollapsedCard;
        extent += estimateToolExtraHeight(
          toolName: tool.toolName,
          arguments: tool.arguments,
          content: tool.content,
          showToolResultSummary: settings.showToolResultSummary,
          hideToolResultImages: settings.hideToolResultImages,
          pendingApproval: _isPendingApproval(
            conversationId: conversationId,
            toolCallId: tool.providerId,
          ),
          textWidth: textWidth,
          fontScale: fontScale,
          wrappedLineCount: _wrappedLineCount,
        );
      }
    }
    return extent;
  }

  String _estimateVisualTransform(
    String text, {
    AssistantRegexScope scope = AssistantRegexScope.assistant,
  }) {
    return applyAssistantRegexes(
      text,
      assistant: widget.assistant,
      scope: scope,
      target: AssistantRegexTransformTarget.visual,
    );
  }

  bool _isPendingApproval({
    required String conversationId,
    required String toolCallId,
  }) {
    return _approvalForEstimate?.pendingFor(
          toolCallId: toolCallId,
          conversationId: conversationId,
        ) !=
        null;
  }

  double _estimateReasoningStepHeight(
    TimelineReasoningRef reasoning, {
    required double textWidth,
    required double fontScale,
  }) {
    if (reasoning.text.isEmpty) return 0;
    var extent = _estimateCollapsedCard;
    if (!reasoning.expanded) {
      if (reasoning.loading) return extent + 100;
      return extent;
    }
    final fontSize = 13.0 * fontScale;
    final charWidth = fontSize * (0.5 + 0.55 * _wideCharRatio(reasoning.text));
    final charsPerLine = math.max(1.0, textWidth / charWidth);
    return extent +
        _wrappedLineCount(
              reasoning.text,
              charsPerLine: charsPerLine,
              codeCharsPerLine: null,
              codeLineRatio: 1.0,
              collapsedCodeLines: null,
            ) *
            (fontSize * 1.5);
  }

  /// Identity of the tool-card inputs an estimate was computed from.
  ///
  /// Stream updates replace each [ToolUIPart] with a new instance, so object
  /// identity is the change signal — the same rule as the live tool map.
  int _partsEstimateSignature(List<MessagePart> parts) {
    if (parts.isEmpty) return 0;
    return Object.hashAll([for (final part in parts) identityHashCode(part)]);
  }

  int _toolEstimateSignature(List<ToolUIPart>? parts) {
    if (parts == null || parts.isEmpty) return 0;
    return Object.hashAll([for (final part in parts) identityHashCode(part)]);
  }

  /// Identity of the reasoning inputs an estimate was computed from.
  ///
  /// Reasoning state objects mutate in place, but their text is replaced with
  /// a new string on every change, so text identity plus the expanded flags
  /// distinguishes every state the estimate depends on.
  int _reasoningEstimateSignature(
    stream_ctrl.ReasoningData? reasoning,
    List<stream_ctrl.ReasoningSegmentData>? segments, {
    required bool isStreaming,
  }) {
    if (reasoning == null && (segments == null || segments.isEmpty)) return 0;
    return Object.hashAll([
      isStreaming,
      if (reasoning != null) ...[
        identityHashCode(reasoning.text),
        reasoning.expanded,
        reasoning.finishedAt,
        timelineReasoningLoading(
          finishedAt: reasoning.finishedAt,
          isStreaming: isStreaming,
        ),
      ],
      if (segments != null)
        for (final segment in segments) ...[
          identityHashCode(segment.text),
          segment.expanded,
          segment.finishedAt,
          timelineReasoningLoading(
            finishedAt: segment.finishedAt,
            isStreaming: isStreaming,
          ),
        ],
    ]);
  }

  /// Rendered height in body lines, wrapping each hard line separately.
  ///
  /// Dividing the whole length by [charsPerLine] would collapse blank lines and
  /// short lines, which is exactly the shape chat messages tend to have. Two
  /// constructs would otherwise be counted wrong: a Markdown link hides its
  /// target, and a fenced code block renders in its own font — wrapping at
  /// [codeCharsPerLine] when the renderer wraps, or staying one row per source
  /// line when it scrolls horizontally instead ([codeCharsPerLine] null), each
  /// row [codeLineRatio] of a body line tall. A block may also be collapsed to
  /// [collapsedCodeLines] source lines.
  double _wrappedLineCount(
    String text, {
    required double charsPerLine,
    required double? codeCharsPerLine,
    required double codeLineRatio,
    required int? collapsedCodeLines,
  }) {
    var lines = 0.0;
    var visible = 0; // rendered characters on the current line
    var fenceRows = 0.0; // rendered rows inside the open code fence
    var fenceSourceLines = 0; // hard lines inside the open code fence
    var inFence = false;
    var index = 0;

    void endLine() {
      if (inFence) {
        fenceSourceLines++;
        fenceRows += visible == 0 || codeCharsPerLine == null
            ? 1.0 // one row per source line: code scrolls sideways
            : (visible / codeCharsPerLine).ceilToDouble();
      } else {
        lines += visible == 0 ? 1.0 : (visible / charsPerLine).ceilToDouble();
      }
      visible = 0;
    }

    void endFence() {
      // Collapsing hides source lines, so the wrapped rows shrink with them.
      final shown = collapsedCodeLines == null || fenceSourceLines == 0
          ? fenceRows
          : fenceRows * math.min(1.0, collapsedCodeLines / fenceSourceLines);
      lines += shown * codeLineRatio;
      fenceRows = 0;
      fenceSourceLines = 0;
    }

    // Very long messages only need the right order of magnitude, so the scan is
    // budgeted per character — a single-line megabyte of JSON must not walk the
    // whole string — and the tail is extrapolated at the observed density.
    while (index < text.length && index < _estimateScanLimit) {
      final unit = text.codeUnitAt(index);
      if (unit == 0x0A) {
        endLine();
        index++;
        continue;
      }
      if (unit == 0x60 && _isFenceMarker(text, index)) {
        if (inFence) {
          endLine();
          endFence();
          inFence = false;
        } else {
          endLine();
          inFence = true;
        }
        index += 3;
        continue;
      }
      if (unit == 0x5D && index + 1 < text.length) {
        // A Markdown link renders its label, never its target.
        if (text.codeUnitAt(index + 1) == 0x28) {
          final close = text.indexOf(')', index + 2);
          if (close > 0) {
            visible++;
            index = close + 1;
            continue;
          }
        }
      }
      visible++;
      index++;
    }
    endLine();
    if (inFence) endFence();
    if (index >= text.length) return lines;
    return lines * (text.length / math.max(1, index));
  }

  /// Whether a ``` fence marker starts at [index].
  bool _isFenceMarker(String text, int index) {
    if (index + 2 >= text.length) return false;
    if (text.codeUnitAt(index + 1) != 0x60 ||
        text.codeUnitAt(index + 2) != 0x60) {
      return false;
    }
    return index == 0 || text.codeUnitAt(index - 1) == 0x0A;
  }

  /// Fraction of wide glyphs, sampled so the cost stays flat for huge messages.
  double _wideCharRatio(String text) {
    const samples = 256;
    final step = math.max(1, text.length ~/ samples);
    var wide = 0;
    var seen = 0;
    for (var index = 0; index < text.length; index += step) {
      if (text.codeUnitAt(index) >= 0x2E80) wide++;
      seen++;
    }
    return seen == 0 ? 0 : wide / seen;
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
        oldWidget.collapseThinking != widget.collapseThinking ||
        oldWidget.collapseThinkingSteps != widget.collapseThinkingSteps ||
        oldWidget.showThinkingCards != widget.showThinkingCards ||
        oldWidget.showToolCards != widget.showToolCards ||
        oldWidget.showToolResultSummary != widget.showToolResultSummary ||
        oldWidget.hideToolResultImages != widget.hideToolResultImages ||
        oldWidget.collapsedCodeLines != widget.collapsedCodeLines ||
        oldWidget.wrapCodeBlocks != widget.wrapCodeBlocks ||
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
        _restoreVisibleAnchorAfterLayout(
          controller,
          index: anchor.index + added,
          alignment: anchor.alignment,
        );
      }
      return;
    }
    if (newModels.length < oldModels.length &&
        _isPrefix(newModels, oldModels)) {
      return;
    }
    if (newModels.length < oldModels.length) {
      final removedOldIndices = _removedOldIndices(oldModels, newModels);
      if (removedOldIndices != null) {
        // Removing the extents at the deleted indices keeps every surviving
        // slot's measured height attached to its new index; the fallback
        // below would instead drop all measurements and let the list drift
        // while it re-measures the whole window over several frames.
        final anchor = _captureVisibleAnchorForRemoval(
          controller,
          removedOldIndices,
        );
        for (var index = removedOldIndices.length - 1; index >= 0; index--) {
          controller.removeItem(removedOldIndices[index]);
        }
        if (anchor != null) {
          _restoreVisibleAnchorAfterLayout(
            controller,
            index: anchor.index,
            alignment: anchor.alignment,
          );
        }
        return;
      }
    }

    if (oldModels.length == newModels.length) {
      final added = _leadingShiftForEqualWindow(oldModels, newModels);
      if (added != null) {
        final anchor = _captureVisibleAnchor(controller);
        for (var index = 0; index < added; index++) {
          controller.addItem(index);
        }
        for (var index = 0; index < added; index++) {
          controller.removeItem(newModels.length);
        }
        if (anchor != null && anchor.index + added < newModels.length) {
          _restoreVisibleAnchorAfterLayout(
            controller,
            index: anchor.index + added,
            alignment: anchor.alignment,
          );
        }
        return;
      }

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
        } else {
          final messageId = newModels[index].message.id;
          if (_lastToolSignatures[messageId] !=
              _toolEstimateSignature(widget.toolParts[messageId])) {
            changedIndices.add(index);
          }
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

  /// Whether a layout-phase positioning request (bottom pin, preserved
  /// distance, streaming auto-follow) owns the scroll position this frame.
  /// Anchor restoration must stand down instead of fighting it.
  bool get _layoutPositionOwnedElsewhere {
    final scrollController = widget.scrollController;
    return scrollController is scroll_ctrl.ChatAutoFollowScrollController &&
        (scrollController.hasActiveLayoutPositioningRequest ||
            scrollController.shouldAutoFollow());
  }

  ({int index, double alignment})? _captureVisibleAnchor(
    ListController controller,
  ) {
    if (!widget.scrollController.hasClients) return null;
    if (_layoutPositionOwnedElsewhere) return null;
    final visible = controller.visibleRange;
    if (visible == null) return null;
    return _anchorAtIndex(controller, visible.$1);
  }

  /// Captures the topmost visible slot that survives a removal, as an anchor
  /// expressed in post-removal index space.
  ///
  /// When every visible slot is being removed, the anchor falls to the
  /// nearest surviving slot below, whose content slides up into the vacated
  /// viewport; failing that, the nearest surviving slot above.
  ({int index, double alignment})? _captureVisibleAnchorForRemoval(
    ListController controller,
    List<int> removedOldIndices,
  ) {
    if (!widget.scrollController.hasClients) return null;
    if (_layoutPositionOwnedElsewhere) return null;
    final visible = controller.visibleRange;
    if (visible == null) return null;
    final removed = removedOldIndices.toSet();
    final itemCount = controller.numberOfItems;
    int? anchorOldIndex;
    for (var index = visible.$1; index < itemCount; index++) {
      if (!removed.contains(index)) {
        anchorOldIndex = index;
        break;
      }
    }
    if (anchorOldIndex == null) {
      for (var index = visible.$1 - 1; index >= 0; index--) {
        if (!removed.contains(index)) {
          anchorOldIndex = index;
          break;
        }
      }
    }
    if (anchorOldIndex == null) return null;
    final anchor = _anchorAtIndex(controller, anchorOldIndex);
    var anchorNewIndex = anchorOldIndex;
    for (final removedIndex in removedOldIndices) {
      if (removedIndex < anchorOldIndex) anchorNewIndex--;
    }
    return (index: anchorNewIndex, alignment: anchor.alignment);
  }

  ({int index, double alignment}) _anchorAtIndex(
    ListController controller,
    int index,
  ) {
    final position = widget.scrollController.position;
    final itemExtent = controller.extentForIndex(index).$1;
    // The scroll position is defined by where children were actually painted,
    // while the extent list's offsets partly derive from estimated heights of
    // rows that never entered layout. Mixing the two frames would bake their
    // accumulated difference into the alignment, and the restore jump would
    // land the anchor shifted by exactly that error — with estimate-heavy
    // histories (long reasoning payloads, huge messages) that reads as the
    // viewport jumping to a random place. Anchor on the painted offset and
    // only fall back to the estimated one when the child is not built.
    final itemLeading =
        _paintedLeadingOffset(index) ??
        // This is the same offset query used by jumpToItem. It is safe here,
        // before the new child list enters layout.
        // ignore: invalid_use_of_visible_for_testing_member
        controller.getOffsetToReveal(index, 0);
    final availableAlignmentExtent = position.viewportDimension - itemExtent;
    final alignment = availableAlignmentExtent.abs() < 0.5
        ? 0.0
        : (itemLeading - position.pixels) / availableAlignmentExtent;
    return (index: index, alignment: alignment);
  }

  /// The scroll offset at which the child for [index] was actually laid out,
  /// or null when that child is not currently built.
  double? _paintedLeadingOffset(int index) {
    final root = context.findRenderObject();
    if (root == null) return null;
    RenderSliverMultiBoxAdaptor? sliver;
    void visit(RenderObject node) {
      if (sliver != null) return;
      if (node is RenderSliverMultiBoxAdaptor) {
        sliver = node;
        return;
      }
      node.visitChildren(visit);
    }

    visit(root);
    final list = sliver;
    if (list == null || list.geometry == null) return null;
    for (
      var child = list.firstChild;
      child != null;
      child = list.childAfter(child)
    ) {
      final parentData = child.parentData;
      if (parentData is! SliverMultiBoxAdaptorParentData) continue;
      if (parentData.index != index) continue;
      if (parentData.keptAlive) return null;
      final layoutOffset = parentData.layoutOffset;
      if (layoutOffset == null) return null;
      return layoutOffset + list.constraints.precedingScrollExtent;
    }
    return null;
  }

  /// Old-list indices whose slots are absent from the new list, or null when
  /// the new list is not simply the old list with some slots removed.
  List<int>? _removedOldIndices(
    List<MessageRenderModel> oldModels,
    List<MessageRenderModel> newModels,
  ) {
    final removed = <int>[];
    var newIndex = 0;
    for (var oldIndex = 0; oldIndex < oldModels.length; oldIndex++) {
      if (newIndex < newModels.length &&
          oldModels[oldIndex].slotId == newModels[newIndex].slotId) {
        newIndex++;
      } else {
        removed.add(oldIndex);
      }
    }
    if (newIndex != newModels.length || removed.isEmpty) return null;
    return removed;
  }

  void _restoreVisibleAnchorAfterLayout(
    ListController controller, {
    required int index,
    required double alignment,
  }) {
    final scrollController = widget.scrollController;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !controller.isAttached ||
          controller.isLocked ||
          !scrollController.hasClients ||
          index < 0 ||
          index >= _effectiveRenderModels.length) {
        return;
      }
      controller.jumpToItem(
        index: index,
        scrollController: scrollController,
        alignment: alignment,
      );
    });
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
        old.durationMs != current.durationMs ||
        _partsIdentityChanged(old.parts, current.parts);
  }

  bool _partsIdentityChanged(List<MessagePart> old, List<MessagePart> current) {
    if (identical(old, current)) return false;
    if (old.length != current.length) return true;
    for (var i = 0; i < old.length; i++) {
      if (!identical(old[i], current[i])) return true;
    }
    return false;
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

  int? _leadingShiftForEqualWindow(
    List<MessageRenderModel> oldModels,
    List<MessageRenderModel> newModels,
  ) {
    if (oldModels.isEmpty || oldModels.length != newModels.length) return null;
    final shift = newModels.indexWhere(
      (model) => model.slotId == oldModels.first.slotId,
    );
    if (shift <= 0) return null;
    for (var index = 0; index < oldModels.length - shift; index++) {
      if (oldModels[index].slotId != newModels[index + shift].slotId) {
        return null;
      }
    }
    return shift;
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
    widget.streamingContentNotifier?.toolHeightEvents.removeListener(
      _handleToolHeightEvent,
    );
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
    // Items render at the system scale times the chat scale (see the MediaQuery
    // override in _buildMessageItem), so the estimate has to use both.
    _systemTextScale = MediaQuery.textScalerOf(context).scale(1);
    var pendingApprovals = const <PendingApprovalKey>[];
    try {
      _approvalForEstimate = context.read<ToolApprovalService>();
      pendingApprovals = context.select<ToolApprovalService, _EstimateIdSet>((
        approval,
      ) {
        return _EstimateIdSet([
          for (final req in approval.pendingRequests)
            PendingApprovalKey(
              conversationId: req.conversationId ?? '',
              toolCallId: req.toolCallId,
            ),
        ]);
      }).ids;
    } catch (_) {
      _approvalForEstimate = null;
    }
    final previousApprovals = _estimateSettings.pendingApprovals;
    _estimateSettings = _EstimateSettings(
      collapseThinking: widget.collapseThinking,
      collapseThinkingSteps: widget.collapseThinkingSteps,
      showThinkingCards: widget.showThinkingCards,
      showToolCards: widget.showToolCards,
      showToolResultSummary: widget.showToolResultSummary,
      hideToolResultImages: widget.hideToolResultImages,
      collapsedCodeLines: widget.collapsedCodeLines,
      wrapCodeBlocks: widget.wrapCodeBlocks,
      visualRegexSignature: _visualRegexEstimateSignature(widget.assistant),
      pendingApprovals: pendingApprovals,
    );
    if (!listEquals(previousApprovals, pendingApprovals)) {
      _invalidateExtentsForApprovalChange(previousApprovals, pendingApprovals);
    }
    _invalidateEstimatesIfScaleChanged();
    if (_awaitingAttachFlush && widget.listController.isAttached) {
      _scheduleAttachAwareFlush();
    }
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

        return Builder(
          builder: (context) {
            final list = SuperListView.builder(
              controller: widget.scrollController,
              listController: widget.listController,
              cacheExtent: 600,
              delayPopulatingCacheArea: false,
              addRepaintBoundaries: false,
              findChildIndexCallback: _findMessageIndexByKey,
              extentEstimation: _estimateItemExtent,
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
                  _setDeferStreamingMessageUpdates(true);
                }
              },
              onPointerUp: (_) => _settlePointerDrag(),
              onPointerCancel: (_) => _settlePointerDrag(),
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  _setDeferStreamingMessageUpdates(true);
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
                if (_effectiveRenderModels.isEmpty && widget.isLoadingWindow)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _WindowLoadingSkeleton(
                        key: MessageListView.windowSkeletonKey,
                        horizontalPadding: horizontalPad,
                        topPadding: widget.topContentPadding,
                      ),
                    ),
                  ),
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
      final gap = metrics.maxScrollExtent - metrics.pixels;
      return gap <= _streamingUpdateDeferBottomTolerance;
    }
    if (!widget.scrollController.hasClients) return true;
    final position = widget.scrollController.position;
    final gap = position.maxScrollExtent - position.pixels;
    return gap <= _streamingUpdateDeferBottomTolerance;
  }

  void _setDeferStreamingMessageUpdates(bool value) {
    if (_deferStreamingMessageUpdates.value == value) return;
    if (value) {
      _captureDeferredStreamingHolds();
    } else {
      _deferredStreamingHolds.clear();
    }
    _deferStreamingMessageUpdates.value = value;
  }

  void _captureDeferredStreamingHolds() {
    _deferredStreamingHolds.clear();
    final notifier = widget.streamingContentNotifier;
    if (notifier == null) return;
    for (final message in widget.messages) {
      if (!message.isStreaming || !notifier.hasNotifier(message.id)) {
        continue;
      }
      final data = notifier.getNotifier(message.id).value;
      _deferredStreamingHolds[message.id] =
          data.content.isEmpty && message.content.isNotEmpty
          ? StreamingContentData(
              content: message.content,
              totalTokens: data.totalTokens,
              parts: data.parts,
              reasoningText: data.reasoningText,
              reasoningStartAt: data.reasoningStartAt,
              reasoningFinishedAt: data.reasoningFinishedAt,
              contentSplitOffsets: data.contentSplitOffsets,
              reasoningCountAtSplit: data.reasoningCountAtSplit,
              toolCountAtSplit: data.toolCountAtSplit,
              toolPartsVersion: data.toolPartsVersion,
              uiVersion: data.uiVersion,
              promptTokens: data.promptTokens,
              completionTokens: data.completionTokens,
              cachedTokens: data.cachedTokens,
              durationMs: data.durationMs,
            )
          : data;
    }
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
    _setDeferStreamingMessageUpdates(false);
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

      // Keep pagination locked through the rebuild and anchor restoration.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      _historyLoadScheduled = false;
    });
  }

  Widget _buildMessageItem(
    BuildContext context, {
    required int index,
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
    final availableVersions = model.availableVersions;
    final selectedVersion = model.selectedVersion;
    final selectedIdx = model.selectedVersionIndex;
    final total = availableVersions.length;
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
                Widget buildContent(bool isProcessingFiles) => Builder(
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
                              availableVersions: availableVersions,
                              selectedVersion: selectedVersion,
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
                              availableVersions: availableVersions,
                              selectedVersion: selectedVersion,
                              selectedIdx: selectedIdx,
                              total: total,
                              isProcessingFiles: isProcessingFiles,
                              suggestions: messageSuggestions,
                              presentation: presentation,
                            ),
                    );
                  },
                );

                // Only the assistant message that owns the indicator listens,
                // so parsing never rebuilds the rest of the timeline.
                Widget content = message.role == 'assistant'
                    ? ValueListenableBuilder<String?>(
                        valueListenable: widget.processingFilesMessageId,
                        builder: (context, processingId, _) =>
                            buildContent(processingId == message.id),
                      )
                    : buildContent(false);

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
    final Widget item = isSpotlight
        ? RepaintBoundary(
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
          )
        : RepaintBoundary(child: messageColumn);

    // The animator wraps the item's RepaintBoundary so the fade only
    // re-composites the boundary's cached layer instead of repainting the
    // message subtree every animation frame.
    return _SlotRemovalAnimator(
      key: ValueKey<String>(model.slotId),
      removing: widget.removingSlotIds.contains(model.slotId),
      child: item,
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
    required List<int> availableVersions,
    required int selectedVersion,
    required int selectedIdx,
    required int total,
    required bool isProcessingFiles,
    required List<String> suggestions,
    required _MessagePresentation presentation,
  }) {
    return _StreamingMessageDataGate(
      notifier: widget.streamingContentNotifier!.getNotifier(message.id),
      deferUpdates: _deferStreamingMessageUpdates,
      deferredHold: _deferredStreamingHolds[message.id],
      builder: (context, data, deferUpdates) {
        final painted = deferUpdates
            ? (_deferredStreamingHolds[message.id] ?? data)
            : data;
        // Use streaming content if available, otherwise fall back to message content
        final displayContent = painted.content.isNotEmpty
            ? painted.content
            : message.content;
        final displayTokens = painted.totalTokens > 0
            ? painted.totalTokens
            : message.totalTokens;

        // Create a modified message with streaming content
        final streamingMessage = message.copyWith(
          parts: painted.parts,
          content: painted.parts == null ? displayContent : null,
          totalTokens: displayTokens,
          promptTokens: painted.promptTokens,
          completionTokens: painted.completionTokens,
          cachedTokens: painted.cachedTokens,
          durationMs: painted.durationMs,
        );

        // Update reasoning text from streaming data while preserving expanded state from r
        // This allows user to toggle expanded state during streaming without it being reset
        stream_ctrl.ReasoningData? streamingReasoning = r;
        if (painted.reasoningText != null &&
            painted.reasoningText!.isNotEmpty) {
          streamingReasoning = stream_ctrl.ReasoningData()
            ..text = painted.reasoningText!
            ..startAt = painted.reasoningStartAt ?? r?.startAt
            ..finishedAt = painted.reasoningFinishedAt ?? r?.finishedAt
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
            availableVersions: availableVersions,
            selectedVersion: selectedVersion,
            selectedIdx: selectedIdx,
            total: total,
            isProcessingFiles: isProcessingFiles,
            suggestions: suggestions,
            presentation: presentation,
            enableStreamingTextMotion: !deferUpdates,
            contentSplitOffsets: painted.contentSplitOffsets,
            reasoningCountAtSplit: painted.reasoningCountAtSplit,
            toolCountAtSplit: painted.toolCountAtSplit,
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
    required List<int> availableVersions,
    required int selectedVersion,
    required int selectedIdx,
    required int total,
    required bool isProcessingFiles,
    required List<String> suggestions,
    required _MessagePresentation presentation,
    bool enableStreamingTextMotion = true,
    List<int>? contentSplitOffsets,
    List<int>? reasoningCountAtSplit,
    List<int>? toolCountAtSplit,
  }) {
    final currentIdx = availableVersions.indexOf(selectedVersion);
    return ChatMessageWidget(
      message: message,
      enableStreamingTextMotion: enableStreamingTextMotion,
      versionIndex: currentIdx < 0 ? selectedIdx : currentIdx,
      versionCount: total > 0 ? total : 1,
      onPrevVersion: (currentIdx > 0)
          ? () => widget.onVersionChange?.call(
              gid,
              availableVersions[currentIdx - 1],
            )
          : null,
      onNextVersion:
          (currentIdx >= 0 && currentIdx < availableVersions.length - 1)
          ? () => widget.onVersionChange?.call(
              gid,
              availableVersions[currentIdx + 1],
            )
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
          canCreateBranch: widget.onForkConversation != null,
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
          ? (contentSplitOffsets ?? widget.contentSplits[message.id]?.offsets)
          : null,
      reasoningCountAtSplit: message.role == 'assistant'
          ? (reasoningCountAtSplit ??
                widget.contentSplits[message.id]?.reasoningCounts)
          : null,
      toolCountAtSplit: message.role == 'assistant'
          ? (toolCountAtSplit ?? widget.contentSplits[message.id]?.toolCounts)
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
                      loading: timelineReasoningLoading(
                        finishedAt: entry.value.finishedAt,
                        isStreaming: message.isStreaming,
                      ),
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
      showThinkingCards: widget.showThinkingCards,
      showToolCards: widget.showToolCards,
      onInlineImageAspect: (imageKey, aspectRatio) {
        _onInlineImageAspect(message.id, imageKey, aspectRatio);
      },
    );
  }

  /// Whether a hidden standalone tool row still occupies height.
  ///
  /// Mirrors `_shouldShowToolCard` for `role == 'tool'` messages: ask-user
  /// cards stay visible so generation is not blocked. Pending-approval cards
  /// do not apply — those rows are never built as loading.
  bool _hiddenStandaloneToolMessageRemainsVisible(String content) {
    try {
      final obj = jsonDecode(content);
      if (obj is Map) {
        return (obj['tool'] ?? '').toString() == LocalToolNames.askUser;
      }
    } catch (_) {}
    return false;
  }

  int _visualRegexEstimateSignature(Assistant? assistant) {
    if (assistant == null || assistant.regexRules.isEmpty) return 0;
    return Object.hashAll([
      for (final rule in assistant.regexRules)
        Object.hash(
          rule.enabled,
          rule.pattern,
          rule.replacement,
          rule.visualOnly,
          rule.replaceOnly,
          Object.hashAll(rule.scopes.map((scope) => scope.index)),
        ),
    ]);
  }
}

final class _EstimateIdSet {
  const _EstimateIdSet(this.ids);
  final List<PendingApprovalKey> ids;

  @override
  bool operator ==(Object other) =>
      other is _EstimateIdSet && listEquals(other.ids, ids);

  @override
  int get hashCode => Object.hashAll(ids);
}

/// Display settings that change how tall a message renders.
final class _EstimateSettings {
  const _EstimateSettings({
    required this.collapseThinking,
    required this.collapseThinkingSteps,
    required this.showThinkingCards,
    required this.showToolCards,
    required this.showToolResultSummary,
    required this.hideToolResultImages,
    required this.collapsedCodeLines,
    required this.wrapCodeBlocks,
    required this.visualRegexSignature,
    required this.pendingApprovals,
  });

  /// Whether finished thinking blocks render as a collapsed card.
  final bool collapseThinking;

  /// Whether each timeline block keeps only the last two steps plus expand.
  final bool collapseThinkingSteps;

  /// Whether thinking-process cards contribute to estimated height.
  final bool showThinkingCards;

  /// Whether tool-use cards contribute to estimated height.
  final bool showToolCards;

  /// Whether collapsed tool cards also show a short result summary.
  final bool showToolResultSummary;

  /// Whether tool-result image thumbnails are hidden under the card.
  final bool hideToolResultImages;

  /// Lines a long code block collapses to, or null when it stays expanded.
  final int? collapsedCodeLines;

  /// Whether code blocks wrap instead of scrolling horizontally.
  final bool wrapCodeBlocks;

  /// Identity of assistant visual-regex rules used by the estimate transform.
  final int visualRegexSignature;

  /// Pending approvals snapshotted during [build], scoped by conversation.
  ///
  /// A list so two unscoped same-id requests stay distinct. [Set] would merge
  /// them and make the estimate say pending while the renderer says not.
  final List<PendingApprovalKey> pendingApprovals;

  @override
  bool operator ==(Object other) =>
      other is _EstimateSettings &&
      other.collapseThinking == collapseThinking &&
      other.collapseThinkingSteps == collapseThinkingSteps &&
      other.showThinkingCards == showThinkingCards &&
      other.showToolCards == showToolCards &&
      other.showToolResultSummary == showToolResultSummary &&
      other.hideToolResultImages == hideToolResultImages &&
      other.collapsedCodeLines == collapsedCodeLines &&
      other.wrapCodeBlocks == wrapCodeBlocks &&
      other.visualRegexSignature == visualRegexSignature &&
      listEquals(other.pendingApprovals, pendingApprovals);

  @override
  int get hashCode => Object.hash(
    collapseThinking,
    collapseThinkingSteps,
    showThinkingCards,
    showToolCards,
    showToolResultSummary,
    hideToolResultImages,
    collapsedCodeLines,
    wrapCodeBlocks,
    visualRegexSignature,
    Object.hashAll(pendingApprovals),
  );
}

/// A memoized extent estimate together with everything it was derived from.
final class _ExtentEstimate {
  const _ExtentEstimate({
    required this.content,
    required this.crossAxisExtent,
    required this.fontScale,
    required this.settings,
    required this.reasoningSignature,
    required this.toolSignature,
    required this.partsSignature,
    required this.streamingSignature,
    required this.extent,
  });

  final String content;
  final double crossAxisExtent;
  final double fontScale;
  final _EstimateSettings settings;
  final int reasoningSignature;
  final int toolSignature;
  final int partsSignature;
  final int streamingSignature;
  final double extent;
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

/// Fades out and collapses a timeline slot ahead of its deletion.
///
/// The fade runs first so the message visually disappears, then the height
/// collapses so the neighbouring messages splice together. The slot's data is
/// removed only after [ChatLayoutConstants.slotRemovalAnimationDuration], at
/// which point the slot is already zero-height and its removal is invisible.
class _SlotRemovalAnimator extends StatefulWidget {
  const _SlotRemovalAnimator({
    super.key,
    required this.removing,
    required this.child,
  });

  final bool removing;
  final Widget child;

  @override
  State<_SlotRemovalAnimator> createState() => _SlotRemovalAnimatorState();
}

class _SlotRemovalAnimatorState extends State<_SlotRemovalAnimator>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.removing) _startRemoval();
  }

  @override
  void didUpdateWidget(covariant _SlotRemovalAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.removing && !oldWidget.removing) {
      _startRemoval();
    } else if (!widget.removing && oldWidget.removing) {
      // The deletion was aborted (the slot usually unmounts instead of ever
      // reaching this), so restore the message. A rebuild of this element is
      // already in progress, so no setState is needed.
      _controller?.dispose();
      _controller = null;
    }
  }

  void _startRemoval() {
    final controller = AnimationController(
      vsync: this,
      duration: ChatLayoutConstants.slotRemovalAnimationDuration,
    );
    controller.addListener(() => setState(() {}));
    _controller = controller;
    controller.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final removing = controller != null;
    final progress = controller?.value ?? 0.0;
    final opacity = removing
        ? 1.0 - Curves.easeOut.transform(math.min(1.0, progress / 0.6))
        : 1.0;
    final heightFactor = removing
        ? 1.0 -
              Curves.easeInOutCubic.transform(
                math.max(0.0, (progress - 0.2) / 0.8),
              )
        : 1.0;
    // The wrapper chain is present even when idle: swapping widget types when
    // the animation starts would reparent — and therefore rebuild — the whole
    // message subtree, which for a huge message is a visible hitch. All
    // wrappers are pass-throughs at their idle values.
    return ClipRect(
      clipBehavior: removing ? Clip.hardEdge : Clip.none,
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: heightFactor.clamp(0.0, 1.0),
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: IgnorePointer(ignoring: removing, child: widget.child),
        ),
      ),
    );
  }
}

class _StreamingMessageDataGate extends StatefulWidget {
  const _StreamingMessageDataGate({
    required this.notifier,
    required this.deferUpdates,
    this.deferredHold,
    required this.builder,
  });

  final ValueNotifier<StreamingContentData> notifier;
  final ValueListenable<bool> deferUpdates;
  final StreamingContentData? deferredHold;
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
    _deferUpdates = widget.deferUpdates.value;
    final hold = widget.deferredHold;
    _visibleData = _deferUpdates && hold != null ? hold : widget.notifier.value;
    super.initState();
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
  Widget build(BuildContext context) {
    return widget.builder(context, _visibleData, _deferUpdates);
  }
}

/// Bubble-shaped shimmer skeleton shown only while a cold initial window
/// load is in flight and the list has no messages yet.
class _WindowLoadingSkeleton extends StatefulWidget {
  const _WindowLoadingSkeleton({
    super.key,
    required this.horizontalPadding,
    required this.topPadding,
  });

  final double horizontalPadding;
  final double topPadding;

  @override
  State<_WindowLoadingSkeleton> createState() => _WindowLoadingSkeletonState();
}

class _WindowLoadingSkeletonState extends State<_WindowLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bubbleColor = cs.onSurface.withValues(alpha: 0.08);

    Widget bubble({required bool alignEnd, required double widthFactor}) {
      return Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: widthFactor,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.horizontalPadding + 12,
        widget.topPadding + 24,
        widget.horizontalPadding + 12,
        0,
      ),
      child: FadeTransition(
        opacity: _pulse.drive(Tween<double>(begin: 0.45, end: 1.0)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            bubble(alignEnd: false, widthFactor: 0.62),
            const SizedBox(height: 14),
            bubble(alignEnd: true, widthFactor: 0.48),
            const SizedBox(height: 14),
            bubble(alignEnd: false, widthFactor: 0.7),
            const SizedBox(height: 14),
            bubble(alignEnd: true, widthFactor: 0.55),
          ],
        ),
      ),
    );
  }
}

/// Coalesces SuperList extent invalidations that cannot run while locked.
///
/// IDs stay queued until a flush observes an unlocked, attached controller.
/// At most one next-frame callback is scheduled at a time.
@visibleForTesting
class ToolExtentInvalidationQueue {
  final Set<String> _pending = <String>{};
  var _scheduled = false;

  @visibleForTesting
  Set<String> get pendingIds => Set<String>.unmodifiable(_pending);

  @visibleForTesting
  bool get isScheduled => _scheduled;

  /// Returns true when the caller should schedule a next-frame flush.
  bool enqueue(String id) {
    _pending.add(id);
    if (_scheduled) return false;
    _scheduled = true;
    return true;
  }

  /// Keep [id] queued without treating a flush as scheduled.
  ///
  /// Used when the list controller is detached so a later attach can drain
  /// the queue without spinning every frame.
  void retain(String id) {
    _pending.add(id);
  }

  ({List<String> ids, bool reschedule}) takeForFlush({
    required bool mounted,
    required bool isAttached,
    required bool isLocked,
  }) {
    _scheduled = false;
    if (!mounted || !isAttached) {
      return (ids: const <String>[], reschedule: false);
    }
    if (isLocked) {
      if (_pending.isEmpty) {
        return (ids: const <String>[], reschedule: false);
      }
      _scheduled = true;
      return (ids: const <String>[], reschedule: true);
    }
    final ids = List<String>.of(_pending);
    _pending.clear();
    return (ids: ids, reschedule: false);
  }
}
