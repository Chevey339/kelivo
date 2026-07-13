import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:scrollview_observer/scrollview_observer.dart';

// ============================================================================
// Auto-follow ScrollController / ScrollPosition
// ============================================================================

/// ScrollController whose positions auto-pin to maxScrollExtent during layout.
///
/// When [shouldAutoFollow] returns true, the created [ScrollPosition] corrects
/// its pixel value to maxScrollExtent inside [applyContentDimensions] — i.e.
/// BEFORE paint — so there is zero visual lag between content growth and scroll
/// position update. This eliminates the 1-frame flicker that post-frame
/// `jumpTo(max)` cannot avoid.
class ChatAutoFollowScrollController extends ScrollController {
  /// Callback checked during layout to decide whether to auto-follow bottom.
  bool Function() shouldAutoFollow = () => false;

  /// One-frame positioning request used when a conversation window is opened.
  ///
  /// Unlike a post-frame `jumpTo`, this is consumed by the scroll position
  /// while the new list is being laid out, so an old conversation offset is
  /// never painted for the new conversation.
  bool _positionAtBottomDuringLayout = false;
  int _layoutBottomRequest = 0;

  int requestPositionAtBottomDuringLayout() {
    _positionAtBottomDuringLayout = true;
    return ++_layoutBottomRequest;
  }

  void finishPositionAtBottomDuringLayout(int request) {
    if (request == _layoutBottomRequest) {
      _positionAtBottomDuringLayout = false;
    }
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _AutoFollowScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
      controller: this,
    );
  }
}

class _AutoFollowScrollPosition extends ScrollPositionWithSingleContext {
  _AutoFollowScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required this.controller,
  });

  final ChatAutoFollowScrollController controller;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final result = super.applyContentDimensions(
      minScrollExtent,
      maxScrollExtent,
    );
    // Also guard on userScrollDirection here in the layout phase, because it
    // updates immediately via the scroll activity — earlier than the scroll-
    // controller listener that sets _isUserScrolling.  Without this check,
    // correctPixels would override the user's drag for one frame, causing a
    // "stuck / can't scroll up" feeling.
    final shouldPositionAtBottom =
        controller._positionAtBottomDuringLayout ||
        (controller.shouldAutoFollow() &&
            userScrollDirection == ScrollDirection.idle);
    if (shouldPositionAtBottom) {
      final gap = this.maxScrollExtent - pixels;
      if (gap > 0.5) {
        correctPixels(this.maxScrollExtent);
        return false; // Force viewport re-layout with corrected position
      }
    }
    return result;
  }
}

// ============================================================================
// ChatScrollController
// ============================================================================

/// Controller for managing scroll behavior in the chat home page.
///
/// This controller handles:
/// - Auto-scroll to bottom during streaming (zero-lag via custom ScrollPosition)
/// - Jump to previous question navigation
/// - Scroll to specific message by ID (via ListObserverController)
/// - Scroll state monitoring (user scrolling detection)
/// - Visibility state for navigation buttons
class ChatScrollController {
  ChatScrollController({
    required this._scrollController,
    required this._onStateChanged,
    required this._getAutoScrollEnabled,
    required this._getAutoScrollIdleSeconds,
    this.isGenerating,
  }) {
    final scrollController = _scrollController;
    _scrollController.addListener(_onScrollControllerChanged);
    _observerController = ListObserverController(controller: scrollController)
      ..cacheJumpIndexOffset = false;

    // Wire auto-follow callback for zero-lag bottom pinning
    if (scrollController is ChatAutoFollowScrollController) {
      scrollController.shouldAutoFollow = () =>
          _getAutoScrollEnabled() &&
          (isGenerating?.call() ?? false) &&
          _autoStickToBottom &&
          !_isUserScrolling &&
          !_explicitBottomAnimationInProgress;
    }
  }

  final ScrollController _scrollController;
  final VoidCallback _onStateChanged;
  final bool Function() _getAutoScrollEnabled;
  final int Function() _getAutoScrollIdleSeconds;
  final bool Function()? isGenerating;

  /// Observer controller for precise index-based scroll navigation.
  late final ListObserverController _observerController;

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

  /// Scheduling state for batched auto-scroll (used by explicit scroll-to-bottom).
  bool _autoScrollScheduled = false;

  /// A driven scroll and the layout-time tail pin must never own pixels in the
  /// same frame.
  bool _explicitBottomAnimationInProgress = false;
  bool get explicitBottomAnimationInProgress =>
      _explicitBottomAnimationInProgress;

  /// Anchor for chained "jump to previous question" navigation.
  String? _lastJumpUserMessageId;
  String? get lastJumpUserMessageId => _lastJumpUserMessageId;

  /// Tolerance for "near bottom" detection.
  static const double _autoScrollSnapTolerance = 56.0;

  // ============================================================================
  // Public Getters
  // ============================================================================

  /// Get the underlying scroll controller.
  ScrollController get scrollController => _scrollController;

  /// Get the observer controller for wrapping ListView.
  ListObserverController get observerController => _observerController;

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

      // Only show when not near bottom
      final atBottom = isNearBottom(24);
      if (!atBottom) {
        _autoStickToBottom = false;
      } else if (_isUserScrolling) {
        // User actively scrolled back to bottom → re-engage auto-follow
        // immediately so streaming content keeps pinning without waiting
        // for the idle timer.
        _isUserScrolling = false;
        _userScrollTimer?.cancel();
        _autoStickToBottom = true;
      } else if (autoScrollEnabled || _autoStickToBottom) {
        _autoStickToBottom = true;
      }
      final shouldShow = !atBottom;
      if (_showJumpToBottom != shouldShow) {
        _showJumpToBottom = shouldShow;
        _onStateChanged();
      }
    } catch (_) {}
  }

  /// Records scroll intent from a real pointer, wheel, or keyboard input.
  /// Programmatic position changes must never call this method.
  void handleUserScrollIntent() {
    _isUserScrolling = true;
    _autoStickToBottom = false;
    _lastJumpUserMessageId = null;
    if (!_showNavButtons) {
      _showNavButtons = true;
      _onStateChanged();
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

  /// Position a newly opened conversation at its tail before the next paint.
  ///
  /// RikkaHub uses the equivalent `requestScrollToItem` operation: the initial
  /// position participates in layout instead of correcting a visible frame
  /// afterward. The flag remains active for the whole frame because a lazy
  /// viewport may refine its max extent more than once during layout.
  void positionAtBottomOnNextLayout() {
    _isUserScrolling = false;
    _userScrollTimer?.cancel();
    _autoStickToBottom = true;
    final controller = _scrollController;
    if (controller is! ChatAutoFollowScrollController) {
      _scheduleExplicitScrollToBottom(animate: false);
      return;
    }
    final request = controller.requestPositionAtBottomDuringLayout();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.finishPositionAtBottomDuringLayout(request);
    });
  }

  /// Scroll to the bottom of the list.
  ///
  /// [animate] - Whether to animate the scroll (default: true).
  void scrollToBottom({bool animate = true}) {
    _autoStickToBottom = true;
    final generating = isGenerating?.call() ?? false;
    _scheduleExplicitScrollToBottom(animate: animate && !generating);
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

  /// Auto-scroll to bottom if conditions are met (called from onStreamTick).
  ///
  /// With [ChatAutoFollowScrollController], the custom [ScrollPosition] handles
  /// bottom-pinning during layout automatically. This method is kept as a
  /// lightweight safety-net for edge cases (e.g. plain ScrollController).
  void autoScrollToBottomIfNeeded() {
    final enabled = _getAutoScrollEnabled();
    if (!enabled || !_autoStickToBottom) return;
    // With the custom ScrollPosition, bottom-pinning happens inside
    // applyContentDimensions (during layout, before paint). No post-frame
    // callback needed for the streaming path.
    // Only schedule an explicit jump as fallback for plain ScrollControllers.
    if (_scrollController is! ChatAutoFollowScrollController) {
      _scheduleExplicitScrollToBottom(animate: false);
    }
  }

  /// Schedule an explicit scroll to bottom (batched via post-frame callback).
  ///
  /// Used for user-triggered "go to bottom" and as fallback for streaming
  /// auto-scroll when the custom [ScrollPosition] is not available.
  void _scheduleExplicitScrollToBottom({bool animate = true}) {
    if (_autoScrollScheduled) return;
    _autoScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _autoScrollScheduled = false;
      await _animateToBottom(animate: animate);
    });
  }

  /// Animate or jump to the bottom of the scroll view.
  ///
  /// Used for explicit scroll-to-bottom requests (user-triggered button,
  /// conversation switch, etc.). Streaming auto-scroll is handled by the
  /// custom [ScrollPosition] instead.
  Future<void> _animateToBottom({bool animate = true}) async {
    try {
      if (!_scrollController.hasClients) return;

      // Prevent using controller while it is still attached to old/new list
      if (_scrollController.positions.length != 1) {
        Future.microtask(() => _animateToBottom(animate: animate));
        return;
      }
      final pos = _scrollController.position;
      final max = pos.maxScrollExtent;
      final distance = (max - pos.pixels).abs();
      if (distance < 0.5) {
        _updateJumpToBottomVisibility(false);
        return;
      }

      if (animate) {
        final durationMs = distance < 500
            ? 250
            : distance < 2000
            ? 350
            : 450;
        _explicitBottomAnimationInProgress = true;
        try {
          await pos.animateTo(
            max,
            duration: Duration(milliseconds: durationMs),
            curve: Curves.easeOutCubic,
          );
        } finally {
          _explicitBottomAnimationInProgress = false;
        }
      } else {
        pos.jumpTo(max);
      }

      _updateJumpToBottomVisibility(false);
      _autoStickToBottom = true;
    } catch (_) {}
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
  /// Uses ListObserverController for precise index-based navigation.
  Future<bool> jumpToPreviousQuestion({
    required List<dynamic> messages,
    required int Function(String id) indexOfId,
  }) async {
    try {
      if (!_scrollController.hasClients) return false;
      if (messages.isEmpty) return false;

      revealNavButtons();

      // Determine anchor index
      int anchor;
      if (_lastJumpUserMessageId != null) {
        final idx = indexOfId(_lastJumpUserMessageId!);
        anchor = idx >= 0 ? idx : messages.length - 1;
      } else {
        // Use observer to find currently visible items
        final result = await _observerController.dispatchOnceObserve(
          isDependObserveCallback: false,
        );
        final visible = result.observeResult?.displayingChildIndexList;
        anchor = (visible != null && visible.isNotEmpty)
            ? visible.last
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
        _lastJumpUserMessageId = null;
        return false;
      }

      await _observerController.animateTo(
        index: target,
        alignment: 0.08,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
      _lastJumpUserMessageId = messages[target].id;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Jump to the next user message (question) below the current viewport.
  ///
  /// Uses ListObserverController for precise index-based navigation.
  Future<bool> jumpToNextQuestion({
    required List<dynamic> messages,
    required int Function(String id) indexOfId,
  }) async {
    try {
      if (!_scrollController.hasClients) return false;
      if (messages.isEmpty) return false;

      revealNavButtons();

      // Determine anchor index
      int anchor;
      if (_lastJumpUserMessageId != null) {
        final idx = indexOfId(_lastJumpUserMessageId!);
        anchor = idx >= 0 ? idx : 0;
      } else {
        // Use observer to find currently visible items
        final result = await _observerController.dispatchOnceObserve(
          isDependObserveCallback: false,
        );
        final visible = result.observeResult?.displayingChildIndexList;
        anchor = (visible != null && visible.isNotEmpty) ? visible.first : 0;
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
        _lastJumpUserMessageId = null;
        return false;
      }

      await _observerController.animateTo(
        index: target,
        alignment: 0.08,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
      _lastJumpUserMessageId = messages[target].id;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Scroll to a specific message by index (from mini map or search).
  ///
  /// Uses ListObserverController for precise index-based scrolling,
  /// replacing the old linear-ratio + paging-loop approach.
  Future<void> scrollToMessageId({
    required String targetId,
    required int targetIndex,
  }) async {
    try {
      if (!_scrollController.hasClients) return;
      if (targetIndex < 0) return;
      await _observerController.animateTo(
        index: targetIndex,
        alignment: 0.1,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
      _lastJumpUserMessageId = targetId;
    } catch (_) {}
  }

  // ============================================================================
  // Observer Cache Management
  // ============================================================================

  /// Clear observer's cached offset data (call on conversation switch).
  void clearObserverCache() {
    _observerController.clearScrollIndexCache();
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
