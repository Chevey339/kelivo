import 'dart:async';
import 'package:flutter/material.dart';

import 'chat_scroll_position.dart';

// ============================================================================
// ChatScrollController
// ============================================================================

/// Controller for managing scroll behavior in the chat home page.
///
/// This controller handles:
/// - Auto-scroll to bottom during streaming
/// - Jump to previous question navigation
/// - Scroll to specific message by index
/// - Scroll state monitoring (user scrolling detection)
/// - Visibility state for navigation buttons
class ChatScrollController {
  ChatScrollController({
    required ChatIndexedScrollControllers indexedControllers,
    required VoidCallback onStateChanged,
    required bool Function() getShouldAutoStickToBottom,
    required bool Function() getAutoScrollEnabled,
    required int Function() getAutoScrollIdleSeconds,
    required int Function() getItemCount,
    required double Function() getBottomAnchorAlignment,
  }) : _indexedControllers = indexedControllers,
       _onStateChanged = onStateChanged,
       _getShouldAutoStickToBottom = getShouldAutoStickToBottom,
       _getAutoScrollEnabled = getAutoScrollEnabled,
       _getAutoScrollIdleSeconds = getAutoScrollIdleSeconds,
       _getItemCount = getItemCount,
       _getBottomAnchorAlignment = getBottomAnchorAlignment {
    _positionTracker = ChatScrollPositionTracker(
      controllers: indexedControllers,
      itemCount: getItemCount,
      onChanged: _onScrollPositionChanged,
      scrollIdleDelay: Duration(seconds: getAutoScrollIdleSeconds()),
    );
  }

  final ChatIndexedScrollControllers _indexedControllers;
  final VoidCallback _onStateChanged;
  final bool Function() _getShouldAutoStickToBottom;
  final bool Function() _getAutoScrollEnabled;
  final int Function() _getAutoScrollIdleSeconds;
  final int Function() _getItemCount;
  final double Function() _getBottomAnchorAlignment;

  late final ChatScrollPositionTracker _positionTracker;

  // ============================================================================
  // State Fields
  // ============================================================================

  /// Whether to show the jump-to-bottom button.
  bool _showJumpToBottom = false;
  bool get showJumpToBottom => _showJumpToBottom;

  /// Whether the navigation buttons should be visible (based on scroll activity).
  bool _showNavButtons = false;
  bool get showNavButtons => _showNavButtons;

  /// Timer for auto-hiding navigation buttons.
  Timer? _navButtonsHideTimer;
  static const int _navButtonsHideDelayMs = 2000;

  /// Whether the user is actively scrolling.
  bool _isUserScrolling = false;
  bool get isUserScrolling => _isUserScrolling;

  /// Whether auto-scroll should stick to bottom.
  bool _autoStickToBottom = true;
  bool get autoStickToBottom => _autoStickToBottom;

  /// Timer for detecting end of user scroll.
  Timer? _userScrollTimer;

  /// Coalesces repeated bottom scroll requests during streaming into one
  /// jump per frame.
  bool _bottomScrollScheduled = false;
  bool _pendingBottomScrollAnimation = false;

  /// Anchor for chained "jump to previous question" navigation.
  String? _lastJumpUserMessageId;
  String? get lastJumpUserMessageId => _lastJumpUserMessageId;

  /// Tolerance for "near bottom" detection.
  static const double _autoScrollSnapTolerance = 56.0;

  // ============================================================================
  // Public Getters
  // ============================================================================

  /// Get the underlying scroll controller.
  ChatIndexedScrollControllers get indexedControllers => _indexedControllers;

  ChatVisibleRange get visibleRange => _positionTracker.visibleRange;

  /// Check if scroll controller has clients attached.
  bool get hasClients => _positionTracker.isAttached;

  // ============================================================================
  // Scroll State Detection
  // ============================================================================

  /// Check if the scroll position is near the bottom.
  bool isNearBottom([double tolerance = _autoScrollSnapTolerance]) {
    return _positionTracker.isAtBottom;
  }

  /// Check if the scroll view has enough content to scroll.
  ///
  /// [minExtent] - Minimum scroll extent to consider scrollable (default: 56.0).
  bool hasEnoughContentToScroll([double minExtent = 56.0]) {
    final range = _positionTracker.visibleRange;
    if (range.firstIndex < 0 || range.lastIndex < 0) {
      return _getItemCount() > 1;
    }
    return !(range.isAtTop && range.isAtBottom);
  }

  /// Refresh auto-stick-to-bottom state based on current position.
  void refreshAutoStickToBottom() {
    final nearBottom = isNearBottom();
    if (!nearBottom) {
      _autoStickToBottom = false;
    } else if (!_isUserScrolling) {
      final enabled = _getAutoScrollEnabled();
      if (enabled || _autoStickToBottom) {
        _autoStickToBottom = true;
      }
    }
  }

  void _onScrollPositionChanged() {
    final userScrolling = _positionTracker.isUserScrolling;
    if (userScrolling) {
      _isUserScrolling = true;
      _autoStickToBottom = false;
      _lastJumpUserMessageId = null;
      if (!_showNavButtons) {
        _showNavButtons = true;
      }
      _resetNavButtonsHideTimer();
      _userScrollTimer?.cancel();
      final secs = _getAutoScrollIdleSeconds();
      _userScrollTimer = Timer(Duration(seconds: secs), () {
        _isUserScrolling = false;
        refreshAutoStickToBottom();
        _onStateChanged();
      });
    }

    final atBottom = _positionTracker.isAtBottom;
    if (!atBottom) {
      _autoStickToBottom = false;
    } else if (_isUserScrolling) {
      _isUserScrolling = false;
      _userScrollTimer?.cancel();
      _autoStickToBottom = true;
    } else if (_getAutoScrollEnabled() || _autoStickToBottom) {
      _autoStickToBottom = true;
    }

    _showJumpToBottom = !atBottom;
    _onStateChanged();
  }

  /// Reset the auto-hide timer for navigation buttons.
  void _resetNavButtonsHideTimer() {
    _navButtonsHideTimer?.cancel();
    _navButtonsHideTimer = Timer(
      const Duration(milliseconds: _navButtonsHideDelayMs),
      () {
        if (_showNavButtons) {
          _showNavButtons = false;
          _onStateChanged();
        }
      },
    );
  }

  /// Show navigation buttons manually (e.g., when user taps a button).
  void revealNavButtons() {
    if (!_showNavButtons) {
      _showNavButtons = true;
      _onStateChanged();
    }
    _resetNavButtonsHideTimer();
  }

  /// Hide navigation buttons immediately.
  void hideNavButtons() {
    _navButtonsHideTimer?.cancel();
    if (_showNavButtons) {
      _showNavButtons = false;
      _onStateChanged();
    }
  }

  // ============================================================================
  // Scroll To Bottom Methods
  // ============================================================================

  /// Scroll to the bottom of the list.
  ///
  /// [animate] - Whether to animate the scroll (default: true).
  void scrollToBottom({bool animate = true}) {
    _autoStickToBottom = true;
    _scheduleScrollToBottom(animate: animate);
  }

  void _scheduleScrollToBottom({
    required bool animate,
    bool deferUntilNextFrame = false,
  }) {
    _pendingBottomScrollAnimation = _pendingBottomScrollAnimation || animate;
    if (_bottomScrollScheduled) return;
    _bottomScrollScheduled = true;
    void flush() {
      _bottomScrollScheduled = false;
      final shouldAnimate = _pendingBottomScrollAnimation;
      _pendingBottomScrollAnimation = false;
      unawaited(_animateToBottom(animate: shouldAnimate));
    }

    if (hasClients && !deferUntilNextFrame) {
      flush();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => flush());
    }
  }

  /// Force scroll to bottom (used when user explicitly clicks the button).
  void forceScrollToBottom() {
    _isUserScrolling = false;
    _userScrollTimer?.cancel();
    _lastJumpUserMessageId = null;
    _positionTracker.resetUserScrolling();
    revealNavButtons();
    scrollToBottom();
  }

  /// Force scroll after rebuilds when switching topics/conversations.
  void forceScrollToBottomSoon({
    bool animate = true,
    Duration postSwitchDelay = const Duration(milliseconds: 220),
  }) {
    _isUserScrolling = false;
    _userScrollTimer?.cancel();
    scrollToBottom(animate: animate);
    Future.delayed(postSwitchDelay, () {
      scrollToBottom(animate: animate);
    });
  }

  /// Ensure scroll reaches bottom even after widget tree transitions.
  void scrollToBottomSoon({bool animate = true}) {
    scrollToBottom(animate: animate);
    Future.delayed(const Duration(milliseconds: 120), () {
      scrollToBottom(animate: animate);
    });
  }

  /// Auto-scroll to bottom if conditions are met (called from onStreamTick).
  void autoScrollToBottomIfNeeded() {
    final enabled = _getAutoScrollEnabled();
    if (!enabled || !_autoStickToBottom) return;
    scrollToBottom(animate: false);
  }

  /// Keep the list pinned after messages are inserted while the user is still
  /// at the bottom. This covers empty/new conversations before streaming ticks.
  void followBottomAfterContentChange() {
    refreshAutoStickToBottom();
    if (!_autoStickToBottom && _getShouldAutoStickToBottom()) {
      _autoStickToBottom = true;
    }
    if (!_autoStickToBottom) return;
    _scheduleScrollToBottom(animate: false, deferUntilNextFrame: true);
  }

  /// Animate or jump to the bottom of the scroll view.
  ///
  /// Used for explicit scroll-to-bottom requests (user-triggered button,
  /// conversation switch, etc.).
  Future<void> _animateToBottom({bool animate = true}) async {
    final target = _getItemCount();
    if (target < 0) return;
    if (!_hasOverflowingContent()) {
      await _positionTracker.scrollToIndex(
        index: 0,
        alignment: 0,
        animate: false,
      );
      _updateJumpToBottomVisibility(false);
      _autoStickToBottom = true;
      return;
    }
    final useAnimation =
        animate && _positionTracker.shouldAnimateToIndex(target);
    await _positionTracker.scrollToIndex(
      index: target,
      alignment: _getBottomAnchorAlignment(),
      animate: useAnimation,
      duration: const Duration(milliseconds: 250),
    );
    _updateJumpToBottomVisibility(false);
    _autoStickToBottom = true;
  }

  bool _hasOverflowingContent() {
    final range = _positionTracker.visibleRange;
    if (range.firstIndex < 0 || range.lastIndex < 0) return true;
    return !(range.isAtTop && range.isAtBottom);
  }

  void _updateJumpToBottomVisibility(bool show) {
    if (_showJumpToBottom != show) {
      _showJumpToBottom = show;
      _onStateChanged();
    }
  }

  // ============================================================================
  // Navigation Methods
  // ============================================================================

  /// Scroll to the top of the list.
  void scrollToTop({bool animate = true}) {
    if (!hasClients) return;
    _lastJumpUserMessageId = null;
    revealNavButtons();
    final useAnimation = animate && _positionTracker.shouldAnimateToIndex(0);
    unawaited(
      _positionTracker.scrollToIndex(
        index: 0,
        alignment: 0,
        animate: useAnimation,
        duration: const Duration(milliseconds: 220),
      ),
    );
  }

  /// Jump to the previous user message (question) above the current viewport.
  ///
  /// Uses index-based navigation for dynamic-height lists.
  Future<void> jumpToPreviousQuestion({
    required List<dynamic> messages,
    required int Function(String id) indexOfId,
  }) async {
    if (!hasClients) return;
    if (messages.isEmpty) return;

    revealNavButtons();

    // Determine anchor index
    int anchor;
    if (_lastJumpUserMessageId != null) {
      final idx = indexOfId(_lastJumpUserMessageId!);
      anchor = idx >= 0 ? idx : messages.length - 1;
    } else {
      anchor = _positionTracker.firstVisibleIndex >= 0
          ? _positionTracker.firstVisibleIndex
          : messages.length - 1;
    }

    // Search backward for previous user message
    int target = -1;
    for (int i = anchor - 1; i >= 0; i--) {
      if (messages[i].role == 'user') {
        target = i;
        break;
      }
    }
    if (target < 0) {
      await _positionTracker.scrollToIndex(
        index: 0,
        alignment: 0,
        animate: false,
      );
      _lastJumpUserMessageId = null;
      return;
    }

    await _positionTracker.scrollToIndex(
      index: target,
      alignment: 0.08,
      animate: _positionTracker.shouldAnimateToIndex(target),
      duration: const Duration(milliseconds: 200),
    );
    _lastJumpUserMessageId = messages[target].id;
  }

  /// Jump to the next user message (question) below the current viewport.
  ///
  /// Uses index-based navigation for dynamic-height lists.
  Future<void> jumpToNextQuestion({
    required List<dynamic> messages,
    required int Function(String id) indexOfId,
  }) async {
    if (!hasClients) return;
    if (messages.isEmpty) return;

    revealNavButtons();

    // Determine anchor index
    int anchor;
    if (_lastJumpUserMessageId != null) {
      final idx = indexOfId(_lastJumpUserMessageId!);
      anchor = idx >= 0 ? idx : 0;
    } else {
      anchor = _positionTracker.lastVisibleIndex >= 0
          ? _positionTracker.lastVisibleIndex
          : 0;
    }

    // Search forward for next user message
    int target = -1;
    for (int i = anchor + 1; i < messages.length; i++) {
      if (messages[i].role == 'user') {
        target = i;
        break;
      }
    }
    if (target < 0) {
      forceScrollToBottom();
      _lastJumpUserMessageId = null;
      return;
    }

    await _positionTracker.scrollToIndex(
      index: target,
      alignment: 0.08,
      animate: _positionTracker.shouldAnimateToIndex(target),
      duration: const Duration(milliseconds: 200),
    );
    _lastJumpUserMessageId = messages[target].id;
  }

  /// Scroll to a specific message by index (from mini map or search).
  ///
  /// Uses index-based scrolling,
  /// replacing the old linear-ratio + paging-loop approach.
  Future<void> scrollToMessageId({
    required String targetId,
    required int targetIndex,
  }) async {
    if (!hasClients) return;
    if (targetIndex < 0) return;

    revealNavButtons();
    await _positionTracker.scrollToIndex(
      index: targetIndex,
      alignment: 0.1,
      animate: _positionTracker.shouldAnimateToIndex(targetIndex),
      duration: const Duration(milliseconds: 250),
    );
    _lastJumpUserMessageId = targetId;
  }

  // ============================================================================
  // Observer Cache Management
  // ============================================================================

  /// Clear observer's cached offset data (call on conversation switch).
  void clearObserverCache() {
    _lastJumpUserMessageId = null;
  }

  // ============================================================================
  // State Modifiers
  // ============================================================================

  /// Reset the last jump user message ID (e.g., when starting new navigation).
  void resetLastJumpUserMessageId() {
    _lastJumpUserMessageId = null;
  }

  /// Set auto-stick-to-bottom state.
  void setAutoStickToBottom(bool value) {
    _autoStickToBottom = value;
  }

  /// Reset user scrolling state (e.g., when force scrolling).
  void resetUserScrolling() {
    _isUserScrolling = false;
    _userScrollTimer?.cancel();
    _positionTracker.resetUserScrolling();
  }

  // ============================================================================
  // Cleanup
  // ============================================================================

  /// Dispose of resources.
  void dispose() {
    _positionTracker.dispose();
    _userScrollTimer?.cancel();
    _navButtonsHideTimer?.cancel();
  }
}
