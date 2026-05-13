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
    required int Function() getItemCount,
    required double Function() getBottomAnchorAlignment,
    bool Function()? getAnimationsDisabled,
    ValueChanged<bool>? onUserScrollActiveChanged,
  }) : _indexedControllers = indexedControllers,
       _onStateChanged = onStateChanged,
       _getShouldAutoStickToBottom = getShouldAutoStickToBottom,
       _getAutoScrollEnabled = getAutoScrollEnabled,
       _getItemCount = getItemCount,
       _getBottomAnchorAlignment = getBottomAnchorAlignment,
       _getAnimationsDisabled = getAnimationsDisabled ?? (() => false),
       _onUserScrollActiveChanged = onUserScrollActiveChanged {
    _positionTracker = ChatScrollPositionTracker(
      controllers: indexedControllers,
      itemCount: getItemCount,
      onChanged: _onScrollPositionChanged,
      scrollIdleDelay: const Duration(milliseconds: 180),
    );
  }

  final ChatIndexedScrollControllers _indexedControllers;
  final VoidCallback _onStateChanged;
  final bool Function() _getShouldAutoStickToBottom;
  final bool Function() _getAutoScrollEnabled;
  final int Function() _getItemCount;
  final double Function() _getBottomAnchorAlignment;
  final bool Function() _getAnimationsDisabled;
  final ValueChanged<bool>? _onUserScrollActiveChanged;

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
  Timer? _userScrollIntentIdleTimer;
  static const int _navButtonsHideDelayMs = 2000;
  static const Duration _userScrollIntentIdleDelay = Duration(
    milliseconds: 180,
  );

  /// Whether the user is actively scrolling.
  bool _isUserScrolling = false;
  bool get isUserScrolling => _isUserScrolling;

  /// Whether auto-scroll should stick to bottom.
  bool _autoStickToBottom = true;
  bool get autoStickToBottom => _autoStickToBottom;

  /// Blocks implicit bottom sticking while the user is reading/editing away
  /// from the live tail. Explicit bottom navigation clears this.
  bool _autoStickSuspendedByUser = false;
  bool _autoStickSuspendedByExplicitNavigation = false;

  bool _hasUserScrollMovementSinceIntent = false;
  bool _hasLeftBottomSinceUserIntent = false;
  bool _hasUserScrollIntentTowardBottom = false;
  bool _hasUserScrollIntentTowardTop = false;
  bool _pendingBottomResumeAfterUserScroll = false;

  /// Coalesces repeated bottom scroll requests during streaming into one
  /// jump per frame.
  bool _bottomScrollScheduled = false;
  bool _pendingBottomScrollAnimation = false;
  bool _pendingBottomScrollRequiresAutoStick = false;
  bool _pendingBottomScrollAlignFittingContentToTop = true;
  bool _pendingBottomScrollMaintainFittingContentForGrowth = false;
  bool _pendingBottomScrollForceAnimation = false;
  Duration _pendingBottomScrollDuration = const Duration(milliseconds: 250);
  Curve _pendingBottomScrollCurve = Curves.easeOutCubic;
  int _bottomScrollGeneration = 0;
  final List<Timer> _anchorMaintenanceTimers = <Timer>[];
  bool _autoStickBottomMaintenanceActive = false;
  bool _autoStickBottomMaintenancePending = false;
  bool _autoStickBottomMaintenancePendingAlignFittingContentToTop = true;
  bool _disposed = false;
  bool _userPointerDown = false;
  int _codeBlockInteractionDepth = 0;
  bool _readingAnchorCaptureScheduled = false;
  bool _readingAnchorScheduled = false;
  int? _readingAnchorIndex;
  double? _readingAnchorAlignment;
  bool _explicitNavigationActive = false;
  int _explicitNavigationGeneration = 0;

  /// Anchor for chained "jump to previous question" navigation.
  String? _lastJumpUserMessageId;
  String? get lastJumpUserMessageId => _lastJumpUserMessageId;

  /// Tolerance for "near bottom" detection.
  static const double _autoScrollSnapTolerance = 56.0;
  static const Duration _userSettleScrollDuration = Duration(milliseconds: 520);
  static const Curve _userSettleScrollCurve = Curves.easeInOutCubic;
  static const Duration _explicitNavigationScrollDuration = Duration(
    milliseconds: 380,
  );
  static const Curve _explicitNavigationScrollCurve = Curves.easeInOutCubic;

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

  bool get shouldLiftContentForKeyboardInset =>
      _autoStickToBottom &&
      !_autoStickSuspendedByUser &&
      !_isUserScrolling &&
      !_positionTracker.isUserScrolling &&
      _positionTracker.isAtBottom;

  /// Check if the scroll view has enough content to scroll.
  ///
  /// [minExtent] - Minimum scroll extent to consider scrollable (default: 56.0).
  bool hasEnoughContentToScroll([double minExtent = 56.0]) {
    if (!_positionTracker.hasCurrentVisibleRange) {
      return _getItemCount() > 1;
    }
    final range = _positionTracker.visibleRange;
    return !(range.isAtTop && range.isAtBottom);
  }

  /// Refresh auto-stick-to-bottom state based on current position.
  void refreshAutoStickToBottom() {
    final nearBottom = isNearBottom();
    if (!nearBottom) {
      _autoStickToBottom = false;
    } else if (!_isUserScrolling && !_autoStickSuspendedByUser) {
      _autoStickSuspendedByUser = false;
      final enabled = _getAutoScrollEnabled();
      if (enabled || _autoStickToBottom) {
        _autoStickToBottom = true;
      }
    }
  }

  void _onScrollPositionChanged() {
    final codeBlockInteractionActive = _isCodeBlockInteractionActive;
    if (codeBlockInteractionActive) {
      _cancelPendingBottomScrollMotion();
      if (!_positionTracker.isUserScrolling) {
        _positionTracker.clearUserScrollingSilently();
        if (_isUserScrolling) {
          _setUserScrolling(false);
        }
        return;
      }
    }

    var needsNotify = false;
    final userScrolling = _positionTracker.isUserScrolling;
    if (userScrolling) {
      _cancelPendingBottomScrollsForUser();
      _hasUserScrollMovementSinceIntent = true;
      if (_positionTracker.lastUserScrollWasTowardBottom) {
        if (!_hasUserScrollIntentTowardTop) {
          _pendingBottomResumeAfterUserScroll = true;
        }
      }
      _setUserScrolling(true);
      _autoStickToBottom = false;
      _lastJumpUserMessageId = null;
      if (!_showNavButtons) {
        _showNavButtons = true;
        needsNotify = true;
      }
      _resetNavButtonsHideTimer();
    }

    _realignFittingContentToTop();

    final atBottom = _positionTracker.isAtBottom;
    final allowsBottomResume =
        !_hasUserScrollIntentTowardTop || _hasUserScrollIntentTowardBottom;
    final shouldResumeSuspendedAutoStick =
        _autoStickSuspendedByUser &&
        allowsBottomResume &&
        (_getAutoScrollEnabled() || _autoStickToBottom) &&
        (_hasLeftBottomSinceUserIntent ||
            _hasUserScrollIntentTowardBottom ||
            (!userScrolling &&
                _hasUserScrollMovementSinceIntent &&
                _positionTracker.lastUserScrollWasTowardBottom));
    if (!atBottom) {
      if (userScrolling || _isUserScrolling || _autoStickSuspendedByUser) {
        final keepRecoveredAutoStick =
            _autoStickToBottom && !_autoStickSuspendedByUser && !userScrolling;
        if (!keepRecoveredAutoStick) {
          _autoStickToBottom = false;
          _hasLeftBottomSinceUserIntent = true;
        }
      }
      if (!userScrolling && _isUserScrolling) {
        _finishUserScrollIdleWhenReady();
      }
    } else if (shouldResumeSuspendedAutoStick) {
      _resumeAutoStickToBottom();
    } else if (!userScrolling && _isUserScrolling) {
      _finishUserScrollIdleWhenReady();
    } else if (!userScrolling &&
        !_isUserScrolling &&
        !_autoStickSuspendedByUser &&
        (_getAutoScrollEnabled() || _autoStickToBottom)) {
      _autoStickSuspendedByUser = false;
      _hasUserScrollMovementSinceIntent = false;
      _hasLeftBottomSinceUserIntent = false;
      _hasUserScrollIntentTowardTop = false;
      _autoStickToBottom = true;
      _clearReadingAnchor();
    }

    final showJumpToBottom = !atBottom;
    if (_showJumpToBottom != showJumpToBottom) {
      _showJumpToBottom = showJumpToBottom;
      needsNotify = true;
    }
    if (needsNotify) {
      _onStateChanged();
    }
  }

  void _realignFittingContentToTop() {
    if (_getItemCount() <= 0) return;
    if (_autoStickSuspendedByUser ||
        _isUserScrolling ||
        _positionTracker.isUserScrolling) {
      return;
    }
    if (!_positionTracker.visibleContentFitsInViewport()) return;
    final firstMessageLeadingEdge = _positionTracker.leadingEdgeForIndex(0);
    if (firstMessageLeadingEdge == null) return;
    if (firstMessageLeadingEdge.abs() <= 0.02) return;

    final generation = _bottomScrollGeneration;
    unawaited(
      _positionTracker
          .scrollToIndex(index: 0, alignment: 0, animate: false)
          .then((_) {
            if (_disposed || generation != _bottomScrollGeneration) return;
            _updateJumpToBottomVisibility(false);
            if (_getAutoScrollEnabled() || _autoStickToBottom) {
              _autoStickToBottom = true;
            }
          }),
    );
  }

  /// Reset the auto-hide timer for navigation buttons.
  void _resetNavButtonsHideTimer() {
    _navButtonsHideTimer?.cancel();
    _navButtonsHideTimer = Timer(
      const Duration(milliseconds: _navButtonsHideDelayMs),
      () {
        if (_positionTracker.isUserScrolling) {
          _resetNavButtonsHideTimer();
          return;
        }
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
    _cancelExplicitNavigationIntent();
    _autoStickSuspendedByUser = false;
    _autoStickSuspendedByExplicitNavigation = false;
    _hasUserScrollMovementSinceIntent = false;
    _hasLeftBottomSinceUserIntent = false;
    _hasUserScrollIntentTowardBottom = false;
    _hasUserScrollIntentTowardTop = false;
    _pendingBottomResumeAfterUserScroll = false;
    _autoStickToBottom = true;
    _clearReadingAnchor();
    final shouldAnimate = animate && !_getAnimationsDisabled();
    _scheduleScrollToBottom(
      animate: shouldAnimate,
      forceAnimation: shouldAnimate,
      alignFittingContentToTop: true,
      duration: shouldAnimate
          ? _userSettleScrollDuration
          : const Duration(milliseconds: 250),
      curve: _userSettleScrollCurve,
    );
  }

  void _scheduleScrollToBottom({
    required bool animate,
    bool deferUntilNextFrame = false,
    bool requireAutoStick = false,
    bool alignFittingContentToTop = true,
    bool maintainFittingContentForGrowth = false,
    bool forceAnimation = false,
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.easeOutCubic,
  }) {
    if (_isCodeBlockInteractionActive) return;
    if (!_bottomScrollScheduled) {
      _bottomScrollGeneration++;
    }
    _pendingBottomScrollAnimation = _pendingBottomScrollAnimation || animate;
    _pendingBottomScrollForceAnimation = _bottomScrollScheduled
        ? _pendingBottomScrollForceAnimation || forceAnimation
        : forceAnimation;
    _pendingBottomScrollRequiresAutoStick = _bottomScrollScheduled
        ? _pendingBottomScrollRequiresAutoStick && requireAutoStick
        : requireAutoStick;
    _pendingBottomScrollAlignFittingContentToTop = _bottomScrollScheduled
        ? _pendingBottomScrollAlignFittingContentToTop &&
              alignFittingContentToTop
        : alignFittingContentToTop;
    _pendingBottomScrollMaintainFittingContentForGrowth = _bottomScrollScheduled
        ? _pendingBottomScrollMaintainFittingContentForGrowth ||
              maintainFittingContentForGrowth
        : maintainFittingContentForGrowth;
    if (!_bottomScrollScheduled || duration > _pendingBottomScrollDuration) {
      _pendingBottomScrollDuration = duration;
      _pendingBottomScrollCurve = curve;
    }
    if (_bottomScrollScheduled) return;
    _bottomScrollScheduled = true;
    final generation = _bottomScrollGeneration;
    void flush({int layoutWaitFrames = 2}) {
      if (_disposed) return;
      if (_isCodeBlockInteractionActive) return;
      if (generation != _bottomScrollGeneration) return;
      final shouldWaitForLayout = _pendingBottomScrollAlignFittingContentToTop
          ? (_pendingBottomScrollRequiresAutoStick ||
                !_positionTracker.hasCurrentVisibleRange)
          : (_pendingBottomScrollRequiresAutoStick &&
                !_positionTracker.hasCurrentVisibleRange);
      if (layoutWaitFrames > 0 && shouldWaitForLayout) {
        _runAfterNextFrame(() => flush(layoutWaitFrames: layoutWaitFrames - 1));
        return;
      }
      _bottomScrollScheduled = false;
      final shouldAnimate = _pendingBottomScrollAnimation;
      final shouldRequireAutoStick = _pendingBottomScrollRequiresAutoStick;
      final shouldAlignFittingContentToTop =
          _pendingBottomScrollAlignFittingContentToTop;
      final shouldMaintainFittingContentForGrowth =
          _pendingBottomScrollMaintainFittingContentForGrowth;
      final shouldForceAnimation = _pendingBottomScrollForceAnimation;
      final scrollDuration = _pendingBottomScrollDuration;
      final scrollCurve = _pendingBottomScrollCurve;
      _pendingBottomScrollAnimation = false;
      _pendingBottomScrollRequiresAutoStick = false;
      _pendingBottomScrollAlignFittingContentToTop = true;
      _pendingBottomScrollMaintainFittingContentForGrowth = false;
      _pendingBottomScrollForceAnimation = false;
      _pendingBottomScrollDuration = const Duration(milliseconds: 250);
      _pendingBottomScrollCurve = Curves.easeOutCubic;
      if (_isCodeBlockInteractionActive) return;
      if (shouldRequireAutoStick && !_autoStickToBottom) return;
      final contentFits =
          shouldAlignFittingContentToTop &&
          _positionTracker.hasCurrentVisibleRange &&
          _positionTracker.visibleContentFitsInViewport();
      unawaited(
        _animateToBottom(
          animate: shouldAnimate,
          generation: generation,
          alignFittingContentToTop: shouldAlignFittingContentToTop,
          forceAnimation: shouldForceAnimation,
          duration: scrollDuration,
          curve: scrollCurve,
        ),
      );
      if (shouldRequireAutoStick &&
          (shouldMaintainFittingContentForGrowth ||
              (shouldAlignFittingContentToTop && !contentFits))) {
        _maintainAutoStickBottomAfterLayout(
          generation,
          alignFittingContentToTop: shouldAlignFittingContentToTop,
        );
      }
    }

    if (hasClients && !deferUntilNextFrame) {
      flush();
    } else {
      _runAfterNextFrame(flush);
    }
  }

  void _runAfterNextFrame(VoidCallback callback) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      callback();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _maintainAutoStickBottom(
    int generation, {
    required bool alignFittingContentToTop,
  }) {
    if (_disposed || generation != _bottomScrollGeneration) return;
    if (_isCodeBlockInteractionActive) return;
    if (!_autoStickToBottom) return;
    if (_userPointerDown ||
        _isUserScrolling ||
        _positionTracker.isUserScrolling) {
      return;
    }
    unawaited(
      _animateToBottom(
        animate: false,
        generation: generation,
        alignFittingContentToTop: alignFittingContentToTop,
      ),
    );
  }

  void _maintainAutoStickBottomAfterLayout(
    int generation, {
    required bool alignFittingContentToTop,
  }) {
    if (_autoStickBottomMaintenanceActive) {
      _autoStickBottomMaintenancePending = true;
      _autoStickBottomMaintenancePendingAlignFittingContentToTop =
          _autoStickBottomMaintenancePendingAlignFittingContentToTop &&
          alignFittingContentToTop;
      return;
    }
    _cancelAnchorMaintenanceTimers();
    _autoStickBottomMaintenanceActive = true;
    _autoStickBottomMaintenancePendingAlignFittingContentToTop =
        alignFittingContentToTop;

    void maintain() {
      _maintainAutoStickBottom(
        generation,
        alignFittingContentToTop: alignFittingContentToTop,
      );
    }

    void maintainAfterFrames(int remainingFrames) {
      if (remainingFrames <= 0) return;
      _runAfterNextFrame(() {
        maintain();
        maintainAfterFrames(remainingFrames - 1);
      });
    }

    maintainAfterFrames(5);
    for (final delay in const <Duration>[
      Duration(milliseconds: 80),
      Duration(milliseconds: 160),
      Duration(milliseconds: 260),
      Duration(milliseconds: 340),
    ]) {
      _anchorMaintenanceTimers.add(Timer(delay, maintain));
    }
    _anchorMaintenanceTimers.add(
      Timer(const Duration(milliseconds: 380), () {
        if (_disposed) return;
        _autoStickBottomMaintenanceActive = false;
        final pendingAlignFittingContentToTop =
            _autoStickBottomMaintenancePendingAlignFittingContentToTop;
        if (_autoStickBottomMaintenancePending &&
            _autoStickToBottom &&
            _getAutoScrollEnabled()) {
          _autoStickBottomMaintenancePending = false;
          _autoStickBottomMaintenancePendingAlignFittingContentToTop = true;
          _scheduleScrollToBottom(
            animate: false,
            deferUntilNextFrame: true,
            requireAutoStick: true,
            alignFittingContentToTop: pendingAlignFittingContentToTop,
            maintainFittingContentForGrowth: pendingAlignFittingContentToTop,
          );
        } else {
          _autoStickBottomMaintenancePending = false;
          _autoStickBottomMaintenancePendingAlignFittingContentToTop = true;
        }
      }),
    );
  }

  /// Force scroll to bottom (used when user explicitly clicks the button).
  void forceScrollToBottom() {
    _autoStickSuspendedByUser = false;
    _autoStickSuspendedByExplicitNavigation = false;
    _hasUserScrollMovementSinceIntent = false;
    _hasLeftBottomSinceUserIntent = false;
    _hasUserScrollIntentTowardBottom = false;
    _hasUserScrollIntentTowardTop = false;
    _pendingBottomResumeAfterUserScroll = false;
    _setUserScrolling(false);
    _lastJumpUserMessageId = null;
    _clearReadingAnchor();
    _positionTracker.resetUserScrolling();
    revealNavButtons();
    scrollToBottom(animate: true);
  }

  /// Force scroll after rebuilds when switching topics/conversations.
  void forceScrollToBottomSoon({
    bool animate = true,
    Duration postSwitchDelay = const Duration(milliseconds: 220),
  }) {
    _autoStickSuspendedByUser = false;
    _autoStickSuspendedByExplicitNavigation = false;
    _hasUserScrollMovementSinceIntent = false;
    _hasLeftBottomSinceUserIntent = false;
    _hasUserScrollIntentTowardBottom = false;
    _hasUserScrollIntentTowardTop = false;
    _pendingBottomResumeAfterUserScroll = false;
    _setUserScrolling(false);
    scrollToBottom(animate: animate);
    final generation = _bottomScrollGeneration;
    Future.delayed(postSwitchDelay, () {
      if (_disposed || _isCodeBlockInteractionActive) return;
      if (generation != _bottomScrollGeneration) return;
      scrollToBottom(animate: animate);
    });
  }

  /// Ensure scroll reaches bottom even after widget tree transitions.
  void scrollToBottomSoon({bool animate = true}) {
    scrollToBottom(animate: animate);
    final generation = _bottomScrollGeneration;
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_disposed || _isCodeBlockInteractionActive) return;
      if (generation != _bottomScrollGeneration) return;
      scrollToBottom(animate: animate);
    });
  }

  /// Auto-scroll to bottom if conditions are met (called from onStreamTick).
  void autoScrollToBottomIfNeeded() {
    final enabled = _getAutoScrollEnabled();
    if (!enabled) return;
    if (_isCodeBlockInteractionActive) return;
    if (_userPointerDown) return;
    if (!_autoStickToBottom) {
      _maintainReadingAnchorIfSuspended();
      return;
    }
    if (_isUserScrolling || _positionTracker.isUserScrolling) return;
    if (_autoStickBottomMaintenanceActive) {
      _autoStickBottomMaintenancePending = true;
      return;
    }
    _scheduleScrollToBottom(
      animate: false,
      deferUntilNextFrame: true,
      requireAutoStick: true,
      maintainFittingContentForGrowth: true,
    );
  }

  /// Keep the list pinned after messages are inserted while the user is still
  /// at the bottom. This covers empty/new conversations before streaming ticks.
  void followBottomAfterContentChange() {
    if (_isCodeBlockInteractionActive) return;
    if (!_getAutoScrollEnabled()) {
      _autoStickToBottom = false;
      return;
    }
    final wasAutoSticking = _autoStickToBottom;
    if (_positionTracker.hasCurrentVisibleRange) {
      refreshAutoStickToBottom();
    }
    if (!_autoStickToBottom &&
        !_isUserScrolling &&
        !_autoStickSuspendedByUser &&
        (wasAutoSticking || _getShouldAutoStickToBottom())) {
      _autoStickToBottom = true;
    }
    if (!_autoStickToBottom) return;
    _scheduleScrollToBottom(
      animate: false,
      deferUntilNextFrame: true,
      requireAutoStick: true,
    );
  }

  /// Temporarily disables automatic bottom following for user-triggered UI
  /// expansion/collapse that can resize message content.
  void suspendAutoStickForUserInteraction({
    int? anchorIndex,
    double? anchorAlignment,
  }) {
    if (_isCodeBlockInteractionActive) return;
    handleUserScrollIntent();
    final generation = _bottomScrollGeneration;
    if (anchorIndex != null && hasClients) {
      final alignment =
          anchorAlignment ?? _positionTracker.leadingEdgeForIndex(anchorIndex);
      if (alignment != null && alignment >= 0) {
        final clampedAlignment = alignment.clamp(0.0, 1.0);
        unawaited(
          _positionTracker.scrollToIndex(
            index: anchorIndex,
            alignment: clampedAlignment,
            animate: false,
          ),
        );
        _maintainAnchorDuringResize(
          index: anchorIndex,
          alignment: clampedAlignment,
          generation: generation,
        );
      }
    }
  }

  void handleUserScrollIntent([
    ChatUserScrollIntentDirection direction =
        ChatUserScrollIntentDirection.unknown,
  ]) {
    if (_isCodeBlockInteractionActive) return;
    _beginUserReadingIntent(direction);
    if (_hasUserScrollIntentTowardBottom && _positionTracker.isAtBottom) {
      _resumeAutoStickToBottom(keepUserScrolling: true);
    }
  }

  void _beginUserReadingIntent(
    ChatUserScrollIntentDirection direction, {
    bool clearLastJumpUserMessageId = true,
  }) {
    if (_isCodeBlockInteractionActive) return;
    final preserveCurrentAnchor =
        !(_explicitNavigationActive || _autoStickSuspendedByExplicitNavigation);
    _cancelExplicitNavigationIntent();
    revealNavButtons();
    _cancelPendingBottomScrollsForUser();
    _autoStickSuspendedByExplicitNavigation = false;
    if (preserveCurrentAnchor) {
      _positionTracker.cancelProgrammaticScrollForUser();
    } else {
      _positionTracker.cancelProgrammaticScrollSilently(
        preserveCurrentAnchor: false,
      );
    }
    _hasUserScrollMovementSinceIntent = false;
    _hasLeftBottomSinceUserIntent = false;
    final intentTowardTop =
        direction == ChatUserScrollIntentDirection.towardTop;
    _hasUserScrollIntentTowardBottom =
        direction == ChatUserScrollIntentDirection.towardBottom;
    if (_hasUserScrollIntentTowardBottom) {
      _hasUserScrollIntentTowardTop = false;
      _pendingBottomResumeAfterUserScroll = true;
    } else if (intentTowardTop) {
      _hasUserScrollIntentTowardTop = true;
      _pendingBottomResumeAfterUserScroll = false;
    }
    _setUserScrolling(true);
    _scheduleUserScrollIntentIdle();
    _autoStickToBottom = false;
    if (clearLastJumpUserMessageId) {
      _lastJumpUserMessageId = null;
    }
  }

  bool get _isCodeBlockInteractionActive => _codeBlockInteractionDepth > 0;

  bool get isCodeBlockInteractionActive => _isCodeBlockInteractionActive;

  void handleCodeBlockInteractionStart() {
    _codeBlockInteractionDepth++;
    _cancelExplicitNavigationIntent();
    _userPointerDown = false;
    _setUserScrolling(false);
    _positionTracker.cancelProgrammaticScrollSilently();
    _positionTracker.clearUserScrollingSilently();
    _cancelPendingBottomScrollMotion();
  }

  void handleCodeBlockInteractionEnd() {
    if (_codeBlockInteractionDepth <= 0) return;
    _codeBlockInteractionDepth--;
    if (!_isCodeBlockInteractionActive) {
      _positionTracker.clearUserScrollingSilently();
      if (_isUserScrolling && !_positionTracker.isUserScrolling) {
        _setUserScrolling(false);
      }
    }
  }

  void handleUserScrollPointerDown() {
    if (_isCodeBlockInteractionActive) return;
    final preserveCurrentAnchor =
        !(_explicitNavigationActive || _autoStickSuspendedByExplicitNavigation);
    _cancelExplicitNavigationIntent();
    _userPointerDown = true;
    if (preserveCurrentAnchor) {
      _positionTracker.cancelProgrammaticScrollForUser();
    } else {
      _positionTracker.cancelProgrammaticScrollSilently(
        preserveCurrentAnchor: false,
      );
    }
    _cancelPendingBottomScrollMotion();
  }

  void handleUserScrollPointerUp() {
    if (_isCodeBlockInteractionActive) return;
    _userPointerDown = false;
    if (_isUserScrolling && !_positionTracker.isUserScrolling) {
      _scheduleUserScrollIntentIdle();
    }
  }

  void handleForwardedScrollDragStart([
    ChatUserScrollIntentDirection direction =
        ChatUserScrollIntentDirection.unknown,
  ]) {
    handleUserScrollIntent(direction);
  }

  Future<void> handleForwardedScrollDragUpdate(double delta) {
    return _positionTracker.scrollByOffset(-delta);
  }

  void _cancelPendingBottomScrollMotion() {
    _bottomScrollGeneration++;
    _bottomScrollScheduled = false;
    _pendingBottomScrollAnimation = false;
    _pendingBottomScrollRequiresAutoStick = true;
    _pendingBottomScrollAlignFittingContentToTop = true;
    _pendingBottomScrollMaintainFittingContentForGrowth = false;
    _pendingBottomScrollForceAnimation = false;
    _pendingBottomScrollDuration = const Duration(milliseconds: 250);
    _pendingBottomScrollCurve = Curves.easeOutCubic;
    _cancelAnchorMaintenanceTimers();
  }

  void _cancelPendingBottomScrollsForUser() {
    _autoStickSuspendedByUser = true;
    _cancelPendingBottomScrollMotion();
    _readingAnchorIndex = null;
    _readingAnchorAlignment = null;
  }

  void _resumeAutoStickToBottom({bool keepUserScrolling = false}) {
    if (!keepUserScrolling) {
      _setUserScrolling(false);
    }
    _autoStickSuspendedByUser = false;
    _autoStickSuspendedByExplicitNavigation = false;
    _hasUserScrollMovementSinceIntent = false;
    _hasLeftBottomSinceUserIntent = false;
    _hasUserScrollIntentTowardBottom = false;
    _hasUserScrollIntentTowardTop = false;
    if (!keepUserScrolling) {
      _pendingBottomResumeAfterUserScroll = false;
    }
    _autoStickToBottom = true;
    _clearReadingAnchor();
  }

  void _maintainAnchorDuringResize({
    required int index,
    required double alignment,
    required int generation,
  }) {
    if (_isCodeBlockInteractionActive) return;
    _cancelAnchorMaintenanceTimers();

    void maintain() {
      if (_disposed || _isCodeBlockInteractionActive) return;
      if (generation != _bottomScrollGeneration) return;
      if (!hasClients) return;
      unawaited(
        _positionTracker.scrollToIndex(
          index: index,
          alignment: alignment,
          animate: false,
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => maintain());
    for (final delay in const <Duration>[
      Duration(milliseconds: 80),
      Duration(milliseconds: 180),
      Duration(milliseconds: 320),
    ]) {
      _anchorMaintenanceTimers.add(Timer(delay, maintain));
    }
  }

  void _cancelAnchorMaintenanceTimers() {
    for (final timer in _anchorMaintenanceTimers) {
      timer.cancel();
    }
    _anchorMaintenanceTimers.clear();
    _autoStickBottomMaintenanceActive = false;
    _autoStickBottomMaintenancePending = false;
    _autoStickBottomMaintenancePendingAlignFittingContentToTop = true;
    _readingAnchorCaptureScheduled = false;
    _readingAnchorScheduled = false;
  }

  int? _beginExplicitNavigationIntent(
    ChatUserScrollIntentDirection direction, {
    bool clearLastJumpUserMessageId = true,
  }) {
    if (_isCodeBlockInteractionActive) return null;
    final generation = ++_explicitNavigationGeneration;
    _explicitNavigationActive = true;
    _userScrollIntentIdleTimer?.cancel();
    _userScrollIntentIdleTimer = null;
    revealNavButtons();
    _cancelPendingBottomScrollsForUser();
    _autoStickSuspendedByExplicitNavigation = true;
    _positionTracker.clearUserScrollingSilently();
    _hasUserScrollMovementSinceIntent = false;
    _hasLeftBottomSinceUserIntent = false;
    _hasUserScrollIntentTowardBottom = false;
    _hasUserScrollIntentTowardTop =
        direction == ChatUserScrollIntentDirection.towardTop;
    _pendingBottomResumeAfterUserScroll = false;
    _autoStickToBottom = false;
    if (_isUserScrolling) {
      _setUserScrolling(false);
    }
    if (clearLastJumpUserMessageId) {
      _lastJumpUserMessageId = null;
    }
    return generation;
  }

  bool _isCurrentExplicitNavigation(int generation) {
    return _explicitNavigationActive &&
        generation == _explicitNavigationGeneration;
  }

  void _finishExplicitNavigationIntent(int generation) {
    if (!_isCurrentExplicitNavigation(generation)) return;
    _explicitNavigationActive = false;
  }

  void _cancelExplicitNavigationIntent() {
    if (_explicitNavigationActive) {
      _explicitNavigationActive = false;
      _explicitNavigationGeneration++;
    }
    _autoStickSuspendedByExplicitNavigation = false;
  }

  void _scheduleUserScrollIntentIdle() {
    if (_isCodeBlockInteractionActive) return;
    _userScrollIntentIdleTimer?.cancel();
    _userScrollIntentIdleTimer = Timer(_userScrollIntentIdleDelay, () {
      _userScrollIntentIdleTimer = null;
      if (_disposed || _isCodeBlockInteractionActive) return;
      if (_userPointerDown) {
        _scheduleUserScrollIntentIdle();
        return;
      }
      if (_positionTracker.isUserScrolling) {
        _scheduleUserScrollIntentIdle();
        return;
      }
      if (!_isUserScrolling) return;
      _finishUserScrollIdle();
    });
  }

  void _finishUserScrollIdleWhenReady() {
    if (_isCodeBlockInteractionActive) return;
    if (_userPointerDown || _positionTracker.isUserScrolling) {
      _scheduleUserScrollIntentIdle();
      return;
    }
    _finishUserScrollIdle();
  }

  void _finishUserScrollIdle() {
    if (_isCodeBlockInteractionActive) return;
    _setUserScrolling(false);
    if (_shouldResumeBottomAfterUserScrollIdle()) {
      _resumeAutoStickToBottom();
    }
    if (_autoStickToBottom && _getAutoScrollEnabled()) {
      _scheduleUserSettleScrollToBottom();
      return;
    }
    if (_autoStickSuspendedByUser) {
      _scheduleReadingAnchorCapture();
    }
  }

  bool _shouldResumeBottomAfterUserScrollIdle() {
    if (!_autoStickSuspendedByUser) return false;
    if (!_getAutoScrollEnabled() && !_autoStickToBottom) return false;
    if (!_positionTracker.isAtBottom) return false;
    if (_hasUserScrollIntentTowardTop && !_hasUserScrollIntentTowardBottom) {
      return false;
    }
    return _pendingBottomResumeAfterUserScroll ||
        _hasUserScrollIntentTowardBottom ||
        _positionTracker.lastUserScrollWasTowardBottom;
  }

  void _scheduleUserSettleScrollToBottom() {
    final animationsDisabled = _getAnimationsDisabled();
    _scheduleScrollToBottom(
      animate: !animationsDisabled,
      deferUntilNextFrame: true,
      requireAutoStick: true,
      alignFittingContentToTop: false,
      forceAnimation: !animationsDisabled,
      duration: animationsDisabled ? Duration.zero : _userSettleScrollDuration,
      curve: _userSettleScrollCurve,
    );
  }

  void _clearReadingAnchor() {
    _cancelAnchorMaintenanceTimers();
    _readingAnchorIndex = null;
    _readingAnchorAlignment = null;
  }

  void _scheduleReadingAnchorCapture() {
    if (_isCodeBlockInteractionActive) return;
    if (_readingAnchorCaptureScheduled) return;
    final generation = _bottomScrollGeneration;
    _readingAnchorCaptureScheduled = true;
    _runAfterNextFrame(() {
      _readingAnchorCaptureScheduled = false;
      if (_disposed || generation != _bottomScrollGeneration) return;
      if (!_autoStickSuspendedByUser || _autoStickToBottom) return;
      _captureReadingAnchor();
    });
  }

  void _captureReadingAnchor() {
    if (_isCodeBlockInteractionActive) return;
    if (!hasClients) return;
    // Capture after the drag settles; capturing must not move the list.
    final anchor = _positionTracker.readingAnchorPosition();
    if (anchor == null) return;
    _readingAnchorIndex = anchor.index;
    _readingAnchorAlignment = _normalizedReadingAnchorAlignment(
      index: anchor.index,
      alignment: anchor.itemLeadingEdge,
    );
  }

  double _normalizedReadingAnchorAlignment({
    required int index,
    required double alignment,
  }) {
    if (index == 0 && alignment > 0) return 0;
    return alignment;
  }

  void _maintainReadingAnchorIfSuspended() {
    if (_isCodeBlockInteractionActive) return;
    if (_explicitNavigationActive || _autoStickSuspendedByExplicitNavigation) {
      return;
    }
    if (!_autoStickSuspendedByUser) return;
    if (_realignSuspendedTopGap()) return;
    if (_isUserScrolling || _positionTracker.isUserScrolling) return;
    if (_readingAnchorScheduled) return;
    final index = _readingAnchorIndex;
    final alignment = _readingAnchorAlignment;
    if (index == null || alignment == null) {
      _scheduleReadingAnchorCapture();
      return;
    }
    final generation = _bottomScrollGeneration;
    _readingAnchorScheduled = true;
    _runAfterNextFrame(() {
      _readingAnchorScheduled = false;
      if (_disposed || generation != _bottomScrollGeneration) return;
      if (!_autoStickSuspendedByUser || _autoStickToBottom) return;
      unawaited(
        _positionTracker.scrollToIndex(
          index: index,
          alignment: alignment,
          animate: false,
        ),
      );
    });
  }

  void _restoreReadingAnchorIfSuspended() {
    if (_isCodeBlockInteractionActive) return;
    if (_explicitNavigationActive || _autoStickSuspendedByExplicitNavigation) {
      return;
    }
    if (!_autoStickSuspendedByUser) return;
    if (_realignSuspendedTopGap()) return;
    if (_isUserScrolling || _positionTracker.isUserScrolling) return;
    final index = _readingAnchorIndex;
    final alignment = _readingAnchorAlignment;
    if (index == null || alignment == null) {
      _scheduleReadingAnchorCapture();
      return;
    }
    unawaited(
      _positionTracker.scrollToIndex(
        index: index,
        alignment: alignment,
        animate: false,
      ),
    );
  }

  bool _realignSuspendedTopGap() {
    if (_isCodeBlockInteractionActive) return false;
    if (!_positionTracker.isAtTop) return false;
    final firstMessageLeadingEdge = _positionTracker.leadingEdgeForIndex(0);
    if (firstMessageLeadingEdge == null || firstMessageLeadingEdge <= 0.02) {
      return false;
    }
    // Do not preserve artificial top whitespace as a reading anchor.
    final generation = _bottomScrollGeneration;
    unawaited(
      _positionTracker
          .scrollToIndex(index: 0, alignment: 0, animate: false)
          .then((_) {
            if (_disposed || generation != _bottomScrollGeneration) return;
            _autoStickToBottom = false;
          }),
    );
    return true;
  }

  /// Capture the current reading anchor before frozen streaming content is
  /// displayed, so a height change can be reconciled without a visible bounce.
  void prepareForFrozenStreamingContentFlush() {
    if (_isCodeBlockInteractionActive) return;
    if (_explicitNavigationActive || _autoStickSuspendedByExplicitNavigation) {
      return;
    }
    if (_shouldResumeBottomAfterUserScrollIdle()) {
      _resumeAutoStickToBottom();
      return;
    }
    if (!_autoStickSuspendedByUser || _autoStickToBottom) return;
    if (_isUserScrolling || _positionTracker.isUserScrolling) return;
    _captureReadingAnchor();
  }

  /// Reconcile scroll position after frozen streaming UI content is displayed.
  void handleFrozenStreamingContentFlushed() {
    if (_isCodeBlockInteractionActive) return;
    if (_explicitNavigationActive || _autoStickSuspendedByExplicitNavigation) {
      return;
    }
    if (_shouldResumeBottomAfterUserScrollIdle()) {
      _resumeAutoStickToBottom();
    }
    if (_autoStickToBottom && _getAutoScrollEnabled()) {
      _scheduleUserSettleScrollToBottom();
      return;
    }
    _restoreReadingAnchorIfSuspended();
  }

  /// Animate or jump to the bottom of the scroll view.
  ///
  /// Used for explicit scroll-to-bottom requests (user-triggered button,
  /// conversation switch, etc.).
  Future<void> _animateToBottom({
    bool animate = true,
    required int generation,
    bool alignFittingContentToTop = true,
    bool forceAnimation = false,
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.easeOutCubic,
  }) async {
    if (_isCodeBlockInteractionActive) return;
    final target = _getItemCount();
    if (target < 0) return;
    if (alignFittingContentToTop && !_hasOverflowingContent()) {
      if (_isCodeBlockInteractionActive) return;
      await _positionTracker.scrollToIndex(
        index: 0,
        alignment: 0,
        animate: false,
      );
      if (_isCodeBlockInteractionActive) {
        _cancelPendingBottomScrollMotion();
        return;
      }
      if (generation != _bottomScrollGeneration) return;
      _updateJumpToBottomVisibility(false);
      _autoStickToBottom = true;
      return;
    }
    final useAnimation =
        animate &&
        (forceAnimation || _positionTracker.shouldAnimateToIndex(target));
    if (_isCodeBlockInteractionActive) return;
    await _positionTracker.scrollToIndex(
      index: target,
      alignment: _getBottomAnchorAlignment(),
      animate: useAnimation,
      duration: duration,
      curve: curve,
    );
    if (_isCodeBlockInteractionActive) {
      _cancelPendingBottomScrollMotion();
      return;
    }
    if (generation != _bottomScrollGeneration) return;
    _updateJumpToBottomVisibility(false);
    _autoStickToBottom = true;
  }

  bool _hasOverflowingContent() {
    if (!_positionTracker.hasCurrentVisibleRange) return true;
    if (_positionTracker.visibleContentFitsInViewport()) {
      return false;
    }
    final range = _positionTracker.visibleRange;
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
    final navigationGeneration = _beginExplicitNavigationIntent(
      ChatUserScrollIntentDirection.towardTop,
    );
    if (navigationGeneration == null) return;
    unawaited(
      _scrollToExplicitNavigationTarget(
        index: 0,
        alignment: 0,
        animate: animate,
        navigationGeneration: navigationGeneration,
      ).whenComplete(
        () => _finishExplicitNavigationIntent(navigationGeneration),
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
    final navigationGeneration = _beginExplicitNavigationIntent(
      ChatUserScrollIntentDirection.towardTop,
      clearLastJumpUserMessageId: false,
    );
    if (navigationGeneration == null) return;
    if (target < 0) {
      try {
        await _scrollToExplicitNavigationTarget(
          index: 0,
          alignment: 0,
          navigationGeneration: navigationGeneration,
        );
        if (_isCurrentExplicitNavigation(navigationGeneration)) {
          _lastJumpUserMessageId = null;
        }
      } finally {
        _finishExplicitNavigationIntent(navigationGeneration);
      }
      return;
    }

    try {
      await _scrollToExplicitNavigationTarget(
        index: target,
        alignment: 0.08,
        navigationGeneration: navigationGeneration,
      );
      if (_isCurrentExplicitNavigation(navigationGeneration)) {
        _lastJumpUserMessageId = messages[target].id;
      }
    } finally {
      _finishExplicitNavigationIntent(navigationGeneration);
    }
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

    final navigationGeneration = _beginExplicitNavigationIntent(
      ChatUserScrollIntentDirection.unknown,
      clearLastJumpUserMessageId: false,
    );
    if (navigationGeneration == null) return;
    try {
      await _scrollToExplicitNavigationTarget(
        index: target,
        alignment: 0.08,
        navigationGeneration: navigationGeneration,
      );
      if (_isCurrentExplicitNavigation(navigationGeneration)) {
        _lastJumpUserMessageId = messages[target].id;
      }
    } finally {
      _finishExplicitNavigationIntent(navigationGeneration);
    }
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

    final navigationGeneration = _beginExplicitNavigationIntent(
      ChatUserScrollIntentDirection.unknown,
    );
    if (navigationGeneration == null) return;
    try {
      await _scrollToExplicitNavigationTarget(
        index: targetIndex,
        alignment: 0.1,
        navigationGeneration: navigationGeneration,
      );
      if (_isCurrentExplicitNavigation(navigationGeneration)) {
        _lastJumpUserMessageId = targetId;
      }
    } finally {
      _finishExplicitNavigationIntent(navigationGeneration);
    }
  }

  Future<void> _scrollToExplicitNavigationTarget({
    required int index,
    required double alignment,
    required int navigationGeneration,
    bool animate = true,
  }) {
    if (!_isCurrentExplicitNavigation(navigationGeneration)) {
      return Future<void>.value();
    }
    return _positionTracker.scrollToIndex(
      index: index,
      alignment: alignment,
      animate: animate && !_getAnimationsDisabled(),
      duration: _explicitNavigationScrollDuration,
      curve: _explicitNavigationScrollCurve,
    );
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
    _cancelExplicitNavigationIntent();
    _setUserScrolling(false);
    _autoStickSuspendedByUser = false;
    _autoStickSuspendedByExplicitNavigation = false;
    _hasUserScrollMovementSinceIntent = false;
    _hasLeftBottomSinceUserIntent = false;
    _hasUserScrollIntentTowardBottom = false;
    _hasUserScrollIntentTowardTop = false;
    _pendingBottomResumeAfterUserScroll = false;
    _positionTracker.resetUserScrolling();
  }

  void _setUserScrolling(bool value) {
    if (_isUserScrolling == value) return;
    if (!value) {
      _userScrollIntentIdleTimer?.cancel();
      _userScrollIntentIdleTimer = null;
    }
    _isUserScrolling = value;
    _onUserScrollActiveChanged?.call(value);
  }

  // ============================================================================
  // Cleanup
  // ============================================================================

  /// Dispose of resources.
  void dispose() {
    _disposed = true;
    _positionTracker.dispose();
    _navButtonsHideTimer?.cancel();
    _userScrollIntentIdleTimer?.cancel();
    _cancelAnchorMaintenanceTimers();
  }
}
