import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:scrollview_observer/scrollview_observer.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/models/assistant.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../chat/widgets/chat_message_widget.dart';
import '../../chat/widgets/message_more_sheet.dart';
import '../controllers/stream_controller.dart' as stream_ctrl;
import '../controllers/streaming_content_notifier.dart';
import '../controllers/timeline_coordinator.dart';
import '../controllers/message_render_model.dart';
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
    this.timelineCoordinator,
    this.chatFontScale = 1,
    this.showModelIcon = true,
    this.showUserAvatar = true,
    this.showTokenStats = false,
    this.assistant,
  });

  final ScrollController scrollController;
  final ListObserverController observerController;

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
  final TimelineCoordinator? timelineCoordinator;
  final double chatFontScale;
  final bool showModelIcon;
  final bool showUserAvatar;
  final bool showTokenStats;
  final Assistant? assistant;

  @override
  State<MessageListView> createState() => _MessageListViewState();
}

class _MessageListViewState extends State<MessageListView>
    with WidgetsBindingObserver {
  static const double _streamingUpdateDeferBottomTolerance = 24.0;
  static const double _programmaticTailViewportFraction = 0.75;

  bool _historyLoadScheduled = false;
  final ValueNotifier<bool> _deferStreamingMessageUpdates = ValueNotifier<bool>(
    false,
  );
  DateTime? _lastHistoryLoadAt;
  Timer? _scrollIdleTimer;
  bool _pointerScrollActivityCheckScheduled = false;
  final Map<String, GlobalKey> _slotKeys = <String, GlobalKey>{};
  bool _programmaticJumpScheduled = false;
  bool _programmaticSpacerUpdateScheduled = false;
  String? _programmaticAnchorSlotId;
  String? _programmaticAnchorConversationId;
  double _programmaticSpacer = 0;
  late List<MessageRenderModel> _effectiveRenderModels;
  final FocusNode _keyboardFocusNode = FocusNode(
    debugLabel: 'timeline-keyboard-scroll-region',
  );

  String _slotId(ChatMessage message) => message.groupId ?? message.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshRenderModels();
  }

  @override
  void didUpdateWidget(covariant MessageListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshRenderModels();
    final active = _effectiveRenderModels.map((model) => model.slotId).toSet();
    _slotKeys.removeWhere((slotId, _) => !active.contains(slotId));
    if (widget.timelineCoordinator?.isGenerating != true) {
      _programmaticAnchorSlotId = null;
      _programmaticAnchorConversationId = null;
      _programmaticSpacer = 0;
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _scrollIdleTimer?.cancel();
    _deferStreamingMessageUpdates.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (widget.timelineCoordinator?.viewportMode ==
        TimelineViewportMode.followingTail) {
      return;
    }
    _captureVisualAnchor();
    _scheduleVisualAnchorRestore();
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
            _scheduleProgrammaticJump();
            final timelineCoordinator = widget.timelineCoordinator;
            final targetPending =
                timelineCoordinator?.programmaticTargetSlotId != null;
            final activeGenerationAnchor =
                timelineCoordinator?.isGenerating == true &&
                _programmaticAnchorSlotId != null &&
                _programmaticAnchorConversationId ==
                    timelineCoordinator?.conversationId;
            final programmaticSpacer = targetPending
                ? constraints.maxHeight * _programmaticTailViewportFraction
                : activeGenerationAnchor
                ? _programmaticSpacer
                : 0.0;
            final list = ListView.builder(
              controller: widget.scrollController,
              padding: EdgeInsets.fromLTRB(
                horizontalPad,
                widget.topContentPadding,
                horizontalPad,
                widget.bottomContentPadding +
                    (widget.isPinnedIndicatorActive ? 12 : 0) +
                    programmaticSpacer,
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

            final observedList = ListViewObserver(
              controller: widget.observerController,
              child: list,
            );

            final sizeAwareList =
                NotificationListener<SizeChangedLayoutNotification>(
                  onNotification: (notification) {
                    _scheduleProgrammaticSpacerUpdate();
                    return false;
                  },
                  child: observedList,
                );

            final historyList = NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: sizeAwareList,
            );

            final userScrollAwareList = Listener(
              onPointerDown: (event) {
                if (_isDesktopPlatform) _keyboardFocusNode.requestFocus();
                if (event.buttons == kSecondaryMouseButton) {
                  _captureVisualAnchor();
                  widget.timelineCoordinator?.userAnchored();
                }
              },
              onPointerMove: (event) {
                if (event.buttons == 0) return;
                _captureVisualAnchor();
                widget.timelineCoordinator?.userAnchored();
              },
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
    _captureVisualAnchor();
    widget.timelineCoordinator?.userAnchored();
    return KeyEventResult.ignored;
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
      widget.timelineCoordinator?.followTail();
      _resumeStreamingMessageUpdates();
      return;
    }
    _captureVisualAnchor();
    widget.timelineCoordinator?.userAnchored();
    _setDeferStreamingMessageUpdates(true);
    _scheduleStreamingUpdateResume();
  }

  void _scheduleProgrammaticJump() {
    final coordinator = widget.timelineCoordinator;
    final targetId = coordinator?.programmaticTargetSlotId;
    if (coordinator?.viewportMode != TimelineViewportMode.programmaticJump ||
        targetId == null ||
        _programmaticJumpScheduled) {
      return;
    }
    _programmaticJumpScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _programmaticJumpScheduled = false;
      if (!mounted || !widget.scrollController.hasClients) return;
      final target = _slotKeys[targetId]?.currentContext?.findRenderObject();
      final viewport = context.findRenderObject();
      if (target is! RenderBox || viewport is! RenderBox) return;
      final delta =
          target.localToGlobal(Offset.zero).dy -
          viewport.localToGlobal(Offset.zero).dy;
      final position = widget.scrollController.position;
      widget.scrollController.jumpTo(
        (widget.scrollController.offset + delta).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
      setState(() {
        _programmaticAnchorSlotId = targetId;
        _programmaticAnchorConversationId = coordinator?.conversationId;
        _programmaticSpacer = _calculateProgrammaticSpacer(targetId, viewport);
      });
      coordinator!.completeProgrammaticJump();
      _captureVisualAnchor();
    });
  }

  double _calculateProgrammaticSpacer(String anchorSlotId, RenderBox viewport) {
    final anchor = _slotKeys[anchorSlotId]?.currentContext?.findRenderObject();
    final lastSlotId = _effectiveRenderModels.isEmpty
        ? null
        : _effectiveRenderModels.last.slotId;
    final tail = lastSlotId == null
        ? null
        : _slotKeys[lastSlotId]?.currentContext?.findRenderObject();
    final maximum = viewport.size.height * _programmaticTailViewportFraction;
    if (anchor is! RenderBox ||
        !anchor.attached ||
        tail is! RenderBox ||
        !tail.attached) {
      return maximum;
    }
    final anchorTop = anchor.localToGlobal(Offset.zero).dy;
    final tailBottom = tail.localToGlobal(Offset(0, tail.size.height)).dy;
    final fixedBottom =
        widget.bottomContentPadding +
        (widget.isPinnedIndicatorActive ? 12.0 : 0.0);
    final occupied = (tailBottom - anchorTop).clamp(0.0, double.infinity);
    return (maximum - occupied - fixedBottom).clamp(0.0, maximum).toDouble();
  }

  void _scheduleProgrammaticSpacerUpdate() {
    if (_programmaticSpacerUpdateScheduled) return;
    _programmaticSpacerUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _programmaticSpacerUpdateScheduled = false;
      if (!mounted || widget.timelineCoordinator?.isGenerating != true) return;
      final anchorSlotId = _programmaticAnchorSlotId;
      final viewport = context.findRenderObject();
      if (anchorSlotId == null ||
          viewport is! RenderBox ||
          !viewport.attached) {
        return;
      }
      final next = _calculateProgrammaticSpacer(anchorSlotId, viewport);
      if ((next - _programmaticSpacer).abs() <= 0.5) return;
      setState(() => _programmaticSpacer = next);
    });
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

  void _scheduleHistoryLoad({required Future<bool> Function() load}) {
    _historyLoadScheduled = true;
    _lastHistoryLoadAt = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _historyLoadScheduled = false;
        return;
      }

      _captureVisualAnchor();

      final loaded = await load();
      if (!mounted) {
        _historyLoadScheduled = false;
        return;
      }
      if (!loaded) {
        _historyLoadScheduled = false;
        return;
      }

      _scheduleVisualAnchorRestore(
        onComplete: () => _historyLoadScheduled = false,
      );
    });
  }

  void _scheduleVisualAnchorRestore({VoidCallback? onComplete}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onComplete?.call();
      if (!mounted || !widget.scrollController.hasClients) return;
      final correction = _visualAnchorCorrection();
      if (correction == null || correction.abs() <= 1) return;
      final target = (widget.scrollController.offset + correction).clamp(
        widget.scrollController.position.minScrollExtent,
        widget.scrollController.position.maxScrollExtent,
      );
      widget.scrollController.jumpTo(target);
    });
  }

  void _captureVisualAnchor() {
    final coordinator = widget.timelineCoordinator;
    final viewport = context.findRenderObject();
    if (coordinator == null || viewport is! RenderBox || !viewport.attached) {
      return;
    }
    final top = viewport.localToGlobal(Offset.zero).dy;
    coordinator.captureVisualAnchor(
      geometries: _slotGeometries(),
      viewportTop: top,
      viewportBottom: top + viewport.size.height,
    );
  }

  double? _visualAnchorCorrection() {
    final coordinator = widget.timelineCoordinator;
    final viewport = context.findRenderObject();
    if (coordinator == null || viewport is! RenderBox || !viewport.attached) {
      return null;
    }
    return coordinator.resolveVisualAnchorCorrection(
      geometries: _slotGeometries(),
      viewportTop: viewport.localToGlobal(Offset.zero).dy,
    );
  }

  List<TimelineSlotGeometry> _slotGeometries() {
    final result = <TimelineSlotGeometry>[];
    for (final entry in _slotKeys.entries) {
      final box = entry.value.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      result.add(
        TimelineSlotGeometry(
          slotId: entry.key,
          top: top,
          bottom: top + box.size.height,
        ),
      );
    }
    return result;
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
    final total = model.versions.length;
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

    Widget messageColumn = Column(
      key: _slotKeys.putIfAbsent(
        _slotId(message),
        () => GlobalKey(debugLabel: 'timeline-slot:${_slotId(message)}'),
      ),
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
    if (isStreaming) {
      messageColumn = SizeChangedLayoutNotifier(child: messageColumn);
    }

    final isSpotlight =
        widget.spotlightMessageId != null &&
        message.id == widget.spotlightMessageId;
    if (!isSpotlight) {
      return RepaintBoundary(key: ValueKey(model.slotId), child: messageColumn);
    }

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
