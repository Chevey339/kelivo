import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Controller for managing scroll behavior in the chat home page.
///
/// This controller handles:
/// - Auto-scroll to bottom during streaming
/// - Jump to previous question navigation
/// - Scroll to specific message by ID
/// - Scroll state monitoring (user scrolling detection)
/// - Visibility state for navigation buttons
class ChatScrollController {
  ChatScrollController({
    required ScrollController scrollController,
    required VoidCallback onStateChanged,
    required bool Function() getAutoScrollEnabled,
    required int Function() getAutoScrollIdleSeconds,
  }) : _scrollController = scrollController,
       _onStateChanged = onStateChanged,
       _getAutoScrollEnabled = getAutoScrollEnabled,
       _getAutoScrollIdleSeconds = getAutoScrollIdleSeconds {
    _scrollController.addListener(_onScrollControllerChanged);
  }

  final ScrollController _scrollController;
  final VoidCallback _onStateChanged;
  final bool Function() _getAutoScrollEnabled;
  final int Function() _getAutoScrollIdleSeconds;

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

  /// Scheduling state for batched auto-scroll.
  bool _autoScrollScheduled = false;
  bool _autoScrollForceNext = false;
  bool _autoScrollAnimateNext = true;

  /// Anchor for chained "jump to previous question" navigation.
  String? _lastJumpUserMessageId;
  String? get lastJumpUserMessageId => _lastJumpUserMessageId;

  /// Tolerance for "near bottom" detection.
  static const double _autoScrollSnapTolerance = 56.0;
  double? _preservedOffsetForPrepend;
  double? _preservedMaxExtentForPrepend;

  // ============================================================================
  // Public Getters
  // ============================================================================

  /// Get the underlying scroll controller.
  ScrollController get scrollController => _scrollController;

  /// Check if scroll controller has clients attached.
  bool get hasClients => _scrollController.hasClients;

  // ============================================================================
  // Scroll State Detection
  // ============================================================================

  /// Check if the scroll position is near the bottom.
  bool isNearBottom([double tolerance = _autoScrollSnapTolerance]) {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    return (pos.maxScrollExtent - pos.pixels) <= tolerance;
  }

  /// Check if the scroll view has enough content to scroll.
  ///
  /// [minExtent] - Minimum scroll extent to consider scrollable (default: 56.0).
  bool hasEnoughContentToScroll([double minExtent = 56.0]) {
    if (!_scrollController.hasClients) return false;
    return _scrollController.position.maxScrollExtent >= minExtent;
  }

  /// Refresh auto-stick-to-bottom state based on current position.
  void refreshAutoStickToBottom() {
    try {
      final nearBottom = isNearBottom();
      if (!nearBottom) {
        _autoStickToBottom = false;
      } else if (!_isUserScrolling) {
        final enabled = _getAutoScrollEnabled();
        if (enabled || _autoStickToBottom) {
          _autoStickToBottom = true;
        }
      }
    } catch (_) {}
  }

  /// Handle scroll controller changes (called from scroll listener).
  void _onScrollControllerChanged() {
    try {
      if (!_scrollController.hasClients) return;
      final autoScrollEnabled = _getAutoScrollEnabled();

      // Detect user scrolling
      if (_scrollController.position.userScrollDirection !=
          ScrollDirection.idle) {
        _isUserScrolling = true;
        _autoStickToBottom = false;
        // Reset chained jump anchor when user manually scrolls
        _lastJumpUserMessageId = null;

        // Show navigation buttons on scroll activity
        if (!_showNavButtons) {
          _showNavButtons = true;
          _onStateChanged();
        }
        _resetNavButtonsHideTimer();

        // Cancel previous timer and set a new one
        _userScrollTimer?.cancel();
        final secs = _getAutoScrollIdleSeconds();
        _userScrollTimer = Timer(Duration(seconds: secs), () {
          _isUserScrolling = false;
          refreshAutoStickToBottom();
          _onStateChanged();
        });
      }

      // Only show when not near bottom
      final atBottom = isNearBottom(24);
      if (!atBottom) {
        _autoStickToBottom = false;
      } else if (!_isUserScrolling &&
          (autoScrollEnabled || _autoStickToBottom)) {
        _autoStickToBottom = true;
      }
      final shouldShow = !atBottom;
      if (_showJumpToBottom != shouldShow) {
        _showJumpToBottom = shouldShow;
        _onStateChanged();
      }
    } catch (_) {}
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

  void preserveScrollPositionForPrepend() {
    try {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      _preservedOffsetForPrepend = pos.pixels;
      _preservedMaxExtentForPrepend = pos.maxScrollExtent;
    } catch (_) {}
  }

  void restoreScrollPositionAfterPrepend() {
    final oldOffset = _preservedOffsetForPrepend;
    final oldMax = _preservedMaxExtentForPrepend;
    _preservedOffsetForPrepend = null;
    _preservedMaxExtentForPrepend = null;
    if (oldOffset == null || oldMax == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (!_scrollController.hasClients) return;
        final pos = _scrollController.position;
        final deltaExtent = pos.maxScrollExtent - oldMax;
        final targetOffset = (oldOffset + deltaExtent).clamp(
          0.0,
          pos.maxScrollExtent,
        );
        pos.jumpTo(targetOffset);
      } catch (_) {}
    });
  }

  // ============================================================================
  // Scroll To Bottom Methods
  // ============================================================================

  /// Scroll to the bottom of the list.
  ///
  /// [animate] - Whether to animate the scroll (default: true).
  void scrollToBottom({bool animate = true}) {
    _autoStickToBottom = true;
    _scheduleAutoScrollToBottom(force: true, animate: animate);
  }

  /// Force scroll to bottom (used when user explicitly clicks the button).
  void forceScrollToBottom() {
    _isUserScrolling = false;
    _userScrollTimer?.cancel();
    _lastJumpUserMessageId = null;
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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => scrollToBottom(animate: animate),
    );
    Future.delayed(postSwitchDelay, () => scrollToBottom(animate: animate));
  }

  /// Ensure scroll reaches bottom even after widget tree transitions.
  void scrollToBottomSoon({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => scrollToBottom(animate: animate),
    );
    Future.delayed(
      const Duration(milliseconds: 120),
      () => scrollToBottom(animate: animate),
    );
  }

  /// Auto-scroll to bottom if conditions are met.
  void autoScrollToBottomIfNeeded() {
    final enabled = _getAutoScrollEnabled();
    if (!enabled && !_autoStickToBottom) return;
    _scheduleAutoScrollToBottom(force: false);
  }

  /// Schedule an auto-scroll to bottom (batched via post-frame callback).
  void _scheduleAutoScrollToBottom({required bool force, bool animate = true}) {
    if (!force) {
      final enabled = _getAutoScrollEnabled();
      if (!enabled && !_autoStickToBottom) return;
    }
    _autoScrollForceNext = _autoScrollForceNext || force;
    _autoScrollAnimateNext = _autoScrollAnimateNext && animate;
    if (_autoScrollScheduled) return;
    _autoScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _autoScrollScheduled = false;
      final forceNow = _autoScrollForceNext;
      final animateNow = _autoScrollAnimateNext;
      _autoScrollForceNext = false;
      _autoScrollAnimateNext = true;
      await _animateToBottom(force: forceNow, animate: animateNow);
    });
  }

  /// Animate or jump to the bottom of the scroll view.
  Future<void> _animateToBottom({
    required bool force,
    bool animate = true,
  }) async {
    try {
      if (!_scrollController.hasClients) return;
      if (!force) {
        if (_isUserScrolling) return;
        if (!_autoStickToBottom && !isNearBottom()) return;
      }

      // Allow forced scrolls to animate when requested for a smoother experience
      final bool doAnimate = animate;
      // Prevent using controller while it is still attached to old/new list simultaneously
      if (_scrollController.positions.length != 1) {
        // Try again after microtask when the previous list detaches
        Future.microtask(
          () => _animateToBottom(force: force, animate: animate),
        );
        return;
      }
      final pos = _scrollController.position;
      final max = pos.maxScrollExtent;
      final distance = (max - pos.pixels).abs();
      if (distance < 0.5) {
        if (_showJumpToBottom) {
          _showJumpToBottom = false;
          _onStateChanged();
        }
        return;
      }
      if (!doAnimate) {
        pos.jumpTo(max);
      } else {
        final durationMs = distance < 36
            ? 120
            : distance < 140
            ? 180
            : 240;
        await pos.animateTo(
          max,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.easeOutCubic,
        );
      }
      if (_showJumpToBottom) {
        _showJumpToBottom = false;
        _onStateChanged();
      }
      _autoStickToBottom = true;
    } catch (_) {}
  }

  // ============================================================================
  // Navigation Methods
  // ============================================================================

  /// Scroll to the top of the list.
  void scrollToTop({bool animate = true}) {
    try {
      if (!_scrollController.hasClients) return;
      _lastJumpUserMessageId = null;
      revealNavButtons();

      if (animate) {
        final pos = _scrollController.position;
        final distance = pos.pixels;
        final durationMs = distance < 200
            ? 150
            : distance < 800
            ? 220
            : 300;
        pos.animateTo(
          0.0,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(0.0);
      }
    } catch (_) {}
  }

  /// Jump to the previous user message (question) above the current viewport.
  ///
  /// [messages] - The collapsed list of messages to navigate through.
  /// [messageKeys] - Map of message IDs to their GlobalKeys for scrolling.
  /// [getViewportBounds] - Function returning (listTop, listBottom) for visibility detection.
  Future<void> jumpToPreviousQuestion({
    required List<dynamic> messages,
    required Map<String, GlobalKey> messageKeys,
    required (double, double) Function() getViewportBounds,
  }) async {
    try {
      if (!_scrollController.hasClients) return;
      if (messages.isEmpty) return;

      // Build an id->index map for quick lookup
      final Map<String, int> idxById = <String, int>{};
      for (int i = 0; i < messages.length; i++) {
        idxById[messages[i].id] = i;
      }

      // Determine anchor index: prefer last jumped user; otherwise bottom-most visible item
      int? anchor;
      if (_lastJumpUserMessageId != null &&
          idxById.containsKey(_lastJumpUserMessageId)) {
        anchor = idxById[_lastJumpUserMessageId!];
      } else {
        final (listTop, listBottom) = getViewportBounds();
        int? firstVisibleIdx;
        int? lastVisibleIdx;
        for (int i = 0; i < messages.length; i++) {
          final key = messageKeys[messages[i].id];
          final ctx = key?.currentContext;
          if (ctx == null) continue;
          final box = ctx.findRenderObject() as RenderBox?;
          if (box == null || !box.attached) continue;
          final top = box.localToGlobal(Offset.zero).dy;
          final bottom = top + box.size.height;
          final visible = bottom > listTop && top < listBottom;
          if (visible) {
            firstVisibleIdx ??= i;
            lastVisibleIdx = i;
          }
        }
        anchor = lastVisibleIdx ?? firstVisibleIdx ?? (messages.length - 1);
      }

      // Search backward for previous user message from the anchor index
      int target = -1;
      for (int i = (anchor ?? 0) - 1; i >= 0; i--) {
        if (messages[i].role == 'user') {
          target = i;
          break;
        }
      }
      if (target < 0) {
        // No earlier user message; jump to top instantly
        _scrollController.jumpTo(0.0);
        _lastJumpUserMessageId = null;
        return;
      }

      // If target widget is not built yet (off-screen far above), page up until it is
      const int maxAttempts = 12; // about 10 pages max
      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        final tKey = messageKeys[messages[target].id];
        final tCtx = tKey?.currentContext;
        if (tCtx != null) {
          await Scrollable.ensureVisible(
            tCtx,
            alignment: 0.08,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOutCubic,
          );
          _lastJumpUserMessageId = messages[target].id;
          return;
        }
        // Step up by ~85% of viewport height
        final pos = _scrollController.position;
        final (_, listBottom) = getViewportBounds();
        final viewH = listBottom;
        final step = viewH * 0.85;
        final newOffset = (pos.pixels - step) < 0 ? 0.0 : (pos.pixels - step);
        if ((pos.pixels - newOffset).abs() < 1) break; // reached top
        _scrollController.jumpTo(newOffset);
        // Let the list build newly visible children
        await WidgetsBinding.instance.endOfFrame;
      }
      // Final fallback: go to top if still not found
      _scrollController.jumpTo(0.0);
      _lastJumpUserMessageId = null;
    } catch (_) {}
  }

  /// Jump to the next user message (question) below the current viewport.
  ///
  /// [messages] - The collapsed list of messages to navigate through.
  /// [messageKeys] - Map of message IDs to their GlobalKeys for scrolling.
  /// [getViewportBounds] - Function returning (listTop, listBottom) for visibility detection.
  Future<void> jumpToNextQuestion({
    required List<dynamic> messages,
    required Map<String, GlobalKey> messageKeys,
    required (double, double) Function() getViewportBounds,
  }) async {
    try {
      if (!_scrollController.hasClients) return;
      if (messages.isEmpty) return;

      revealNavButtons();

      // Build an id->index map for quick lookup
      final Map<String, int> idxById = <String, int>{};
      for (int i = 0; i < messages.length; i++) {
        idxById[messages[i].id] = i;
      }

      // Determine anchor index: prefer last jumped user; otherwise top-most visible item
      int? anchor;
      if (_lastJumpUserMessageId != null &&
          idxById.containsKey(_lastJumpUserMessageId)) {
        anchor = idxById[_lastJumpUserMessageId!];
      } else {
        final (listTop, listBottom) = getViewportBounds();
        int? firstVisibleIdx;
        for (int i = 0; i < messages.length; i++) {
          final key = messageKeys[messages[i].id];
          final ctx = key?.currentContext;
          if (ctx == null) continue;
          final box = ctx.findRenderObject() as RenderBox?;
          if (box == null || !box.attached) continue;
          final top = box.localToGlobal(Offset.zero).dy;
          final bottom = top + box.size.height;
          final visible = bottom > listTop && top < listBottom;
          if (visible) {
            firstVisibleIdx ??= i;
            break;
          }
        }
        anchor = firstVisibleIdx ?? 0;
      }

      // Search forward for next user message from the anchor index
      int target = -1;
      for (int i = (anchor ?? 0) + 1; i < messages.length; i++) {
        if (messages[i].role == 'user') {
          target = i;
          break;
        }
      }
      if (target < 0) {
        // No later user message; jump to bottom
        forceScrollToBottom();
        _lastJumpUserMessageId = null;
        return;
      }

      // If target widget is not built yet (off-screen far below), page down until it is
      const int maxAttempts = 12;
      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        final tKey = messageKeys[messages[target].id];
        final tCtx = tKey?.currentContext;
        if (tCtx != null) {
          await Scrollable.ensureVisible(
            tCtx,
            alignment: 0.08,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOutCubic,
          );
          _lastJumpUserMessageId = messages[target].id;
          return;
        }
        // Step down by ~85% of viewport height
        final pos = _scrollController.position;
        final (_, listBottom) = getViewportBounds();
        final viewH = listBottom;
        final step = viewH * 0.85;
        final newOffset = (pos.pixels + step) > pos.maxScrollExtent
            ? pos.maxScrollExtent
            : (pos.pixels + step);
        if ((pos.pixels - newOffset).abs() < 1) break; // reached bottom
        _scrollController.jumpTo(newOffset);
        // Let the list build newly visible children
        await WidgetsBinding.instance.endOfFrame;
      }
      // Final fallback: go to bottom if still not found
      forceScrollToBottom();
      _lastJumpUserMessageId = null;
    } catch (_) {}
  }

  /// Scroll to a specific message by ID (from mini map selection).
  ///
  /// [targetId] - The ID of the message to scroll to.
  /// [messages] - The collapsed list of messages.
  /// [messageKeys] - Map of message IDs to their GlobalKeys.
  /// [getViewportBounds] - Function returning (listTop, listBottom) for visibility detection.
  /// [getViewHeight] - Function returning the viewport height.
  Future<void> scrollToMessageId({
    required String targetId,
    required List<dynamic> messages,
    required Map<String, GlobalKey> messageKeys,
    required (double, double) Function() getViewportBounds,
    required double Function() getViewHeight,
  }) async {
    try {
      if (!_scrollController.hasClients) return;
      final tIndex = messages.indexWhere((m) => m.id == targetId);
      if (tIndex < 0) return;

      // Try direct ensureVisible first
      final tKey = messageKeys[targetId];
      final tCtx = tKey?.currentContext;
      if (tCtx != null) {
        await Scrollable.ensureVisible(
          tCtx,
          alignment: 0.1,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
        _lastJumpUserMessageId = targetId; // allow chaining with prev-question
        return;
      }

      // Coarse jump based on index ratio to bring target into build range
      final pos0 = _scrollController.position;
      final denom = (messages.length - 1).clamp(1, 1 << 30);
      final ratio = tIndex / denom;
      final coarse = (pos0.maxScrollExtent * ratio).clamp(
        0.0,
        pos0.maxScrollExtent,
      );
      _scrollController.jumpTo(coarse);
      await WidgetsBinding.instance.endOfFrame;
      final tCtxAfterCoarse = messageKeys[targetId]?.currentContext;
      if (tCtxAfterCoarse != null) {
        await Scrollable.ensureVisible(
          tCtxAfterCoarse,
          alignment: 0.1,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
        _lastJumpUserMessageId = targetId;
        return;
      }

      // Determine direction using visible anchor indices
      final (listTop, listBottom) = getViewportBounds();
      int? firstVisibleIdx;
      int? lastVisibleIdx;
      for (int i = 0; i < messages.length; i++) {
        final key = messageKeys[messages[i].id];
        final ctx = key?.currentContext;
        if (ctx == null) continue;
        final box = ctx.findRenderObject() as RenderBox?;
        if (box == null || !box.attached) continue;
        final top = box.localToGlobal(Offset.zero).dy;
        final bottom = top + box.size.height;
        final visible = bottom > listTop && top < listBottom;
        if (visible) {
          firstVisibleIdx ??= i;
          lastVisibleIdx = i;
        }
      }
      final anchor = lastVisibleIdx ?? firstVisibleIdx ?? 0;
      final dirDown = tIndex > anchor; // target below

      // Page in steps until the target builds, then ensureVisible
      const int maxAttempts = 40;
      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        final ctx2 = messageKeys[targetId]?.currentContext;
        if (ctx2 != null) {
          await Scrollable.ensureVisible(
            ctx2,
            alignment: 0.1,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOutCubic,
          );
          _lastJumpUserMessageId = targetId;
          return;
        }
        final pos = _scrollController.position;
        final viewH = getViewHeight();
        final step = viewH * 0.85 * (dirDown ? 1 : -1);
        double newOffset = pos.pixels + step;
        if (newOffset < 0) newOffset = 0;
        if (newOffset > pos.maxScrollExtent) newOffset = pos.maxScrollExtent;
        if ((newOffset - pos.pixels).abs() < 1) break;
        _scrollController.jumpTo(newOffset);
        await WidgetsBinding.instance.endOfFrame;
      }
    } catch (_) {}
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
  }

  // ============================================================================
  // Cleanup
  // ============================================================================

  /// Dispose of resources.
  void dispose() {
    _scrollController.removeListener(_onScrollControllerChanged);
    _userScrollTimer?.cancel();
    _navButtonsHideTimer?.cancel();
  }
}
