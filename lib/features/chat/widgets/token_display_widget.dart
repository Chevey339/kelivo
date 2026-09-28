import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerPhase;
import '../../../l10n/app_localizations.dart';
import 'token_detail_popup.dart';

/// Compact token display that shows "123 tokens" and pops up a detail bubble.
///
/// - Mobile: tap to toggle popup (transparent barrier closes it)
/// - Desktop: hover with 200ms delay to show, 300ms delay to close
/// - Fade + slight slide animation on show/hide
class TokenDisplayWidget extends StatefulWidget {
  const TokenDisplayWidget({
    super.key,
    required this.totalTokens,
    this.promptTokens,
    this.completionTokens,
    this.cachedTokens,
    this.reasoningTokens,
    this.cacheWriteTokens,
    this.durationMs,
    this.firstTokenMs,
    this.totalCompletionTokens,
    this.providerId,
    this.modelId,
  });

  final int totalTokens;
  final int? promptTokens;
  final int? completionTokens;
  final int? cachedTokens;
  final int? reasoningTokens;
  final int? cacheWriteTokens;
  final int? durationMs;
  final int? firstTokenMs;
  final int? totalCompletionTokens;
  final String? providerId;
  final String? modelId;

  @override
  State<TokenDisplayWidget> createState() => _TokenDisplayWidgetState();
}

class _TokenDisplayWidgetState extends State<TokenDisplayWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final OverlayPortalController _popupController = OverlayPortalController();
  bool _isShowing = false;

  AnimationController? _animController;
  CurvedAnimation? _curvedAnim;

  bool _isHoveringTarget = false;
  bool _isHoveringPopup = false;
  int _showTimerId = 0;
  int _hideTimerId = 0;

  ScrollPosition? _scrollPosition;

  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  bool get _hasDetailData =>
      (widget.promptTokens != null && widget.promptTokens! > 0) ||
      (widget.completionTokens != null && widget.completionTokens! > 0) ||
      (widget.reasoningTokens != null && widget.reasoningTokens! > 0) ||
      (widget.cacheWriteTokens != null && widget.cacheWriteTokens! > 0) ||
      (widget.durationMs != null && widget.durationMs! > 0) ||
      (widget.firstTokenMs != null && widget.firstTokenMs! >= 0);

  /// Lazily create animation controller on first use (when popup actually opens).
  CurvedAnimation _ensureAnimation() {
    _animController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _curvedAnim ??= CurvedAnimation(
      parent: _animController!,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return _curvedAnim!;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // The portal removes its overlay child when this subtree is disposed.
    _detachScrollListener();
    _curvedAnim?.dispose();
    _animController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (_isShowing) _removeOverlayImmediate();
  }

  void _showPopup() {
    if (_isShowing || !mounted) return;
    _ensureAnimation();
    _isShowing = true;
    _attachScrollListener();
    _popupController.show();
    _animController!.forward(from: 0);
  }

  Widget _buildPopup(BuildContext context, OverlayChildLayoutInfo info) {
    final animation = _curvedAnim!;
    // The portal supplies the current transform after the message is laid out,
    // even when only a preceding image resized and this widget did not rebuild.
    final anchor = MatrixUtils.transformRect(
      info.childPaintTransform,
      Offset.zero & info.childSize,
    );
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!_isDesktop)
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _hidePopup(),
              child: const SizedBox.expand(),
            ),
          CustomSingleChildLayout(
            delegate: _TokenPopupLayout(
              anchor: anchor,
              padding:
                  MediaQuery.paddingOf(context) +
                  MediaQuery.viewInsetsOf(context) +
                  const EdgeInsets.all(8),
              animation: animation,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: _AnimatedPopupContent(
                animation: animation,
                isDesktop: _isDesktop,
                onHoverEnter: () {
                  _isHoveringPopup = true;
                  _cancelHideTimer();
                },
                onHoverExit: () {
                  _isHoveringPopup = false;
                  _scheduleHide();
                },
                child: TokenDetailPopup(
                  promptTokens: widget.promptTokens,
                  completionTokens: widget.completionTokens,
                  cachedTokens: widget.cachedTokens,
                  reasoningTokens: widget.reasoningTokens,
                  cacheWriteTokens: widget.cacheWriteTokens,
                  durationMs: widget.durationMs,
                  firstTokenMs: widget.firstTokenMs,
                  totalCompletionTokens: widget.totalCompletionTokens,
                  providerId: widget.providerId,
                  modelId: widget.modelId,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _hidePopup() async {
    if (!_isShowing) return;
    try {
      await _animController?.reverse();
    } catch (_) {}
    _removeOverlayImmediate();
  }

  void _removeOverlayImmediate() {
    _detachScrollListener();
    _isShowing = false;
    _isHoveringTarget = false;
    _isHoveringPopup = false;
    // Scroll-position corrections can notify during layout; portal visibility
    // changes must wait until that frame has completed.
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isShowing) _popupController.hide();
      });
    } else {
      _popupController.hide();
    }
  }

  void _togglePopup() {
    if (_isShowing) {
      _hidePopup();
    } else {
      _showPopup();
    }
  }

  void _scheduleShow() {
    final id = ++_showTimerId;
    Future.delayed(const Duration(milliseconds: 200), () {
      if (id == _showTimerId && _isHoveringTarget && mounted) {
        _showPopup();
      }
    });
  }

  void _scheduleHide() {
    final id = ++_hideTimerId;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (id == _hideTimerId &&
          !_isHoveringTarget &&
          !_isHoveringPopup &&
          mounted) {
        _hidePopup();
      }
    });
  }

  void _cancelHideTimer() {
    _hideTimerId++;
  }

  void _attachScrollListener() {
    _detachScrollListener();
    try {
      final scrollable = Scrollable.maybeOf(context);
      _scrollPosition = scrollable?.position;
      _scrollPosition?.addListener(_onScroll);
    } catch (_) {}
  }

  void _detachScrollListener() {
    try {
      _scrollPosition?.removeListener(_onScroll);
    } catch (_) {}
    _scrollPosition = null;
  }

  void _onScroll() {
    if (_isShowing) {
      _removeOverlayImmediate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final label = Text(
      l10n.tokenDetailTotalTokens(widget.totalTokens),
      style: TextStyle(
        fontSize: 11,
        color: cs.onSurface.withValues(alpha: 0.5),
      ),
    );

    if (!_hasDetailData) {
      return label;
    }

    Widget child = label;

    if (_isDesktop) {
      child = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          _isHoveringTarget = true;
          _cancelHideTimer();
          _scheduleShow();
        },
        onExit: (_) {
          _isHoveringTarget = false;
          _scheduleHide();
        },
        child: child,
      );
    } else {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _togglePopup,
        child: child,
      );
    }

    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _popupController,
      overlayLocation: OverlayChildLocation.rootOverlay,
      overlayChildBuilder: _buildPopup,
      child: child,
    );
  }
}

class _TokenPopupLayout extends SingleChildLayoutDelegate {
  _TokenPopupLayout({
    required this.anchor,
    required this.padding,
    required this.animation,
  }) : super(relayout: animation);

  final Rect anchor;
  final EdgeInsets padding;
  final Animation<double> animation;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen().deflate(padding);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const gap = 8.0;
    final above = anchor.top - padding.top - gap;
    final below = size.height - padding.bottom - anchor.bottom - gap;
    final showBelow = childSize.height > above && below > above;
    final top = showBelow
        ? anchor.bottom + gap
        : anchor.top - gap - childSize.height;
    final slide =
        (showBelow ? -1 : 1) * 0.15 * childSize.height * (1 - animation.value);
    // Use the laid-out card size, including the current text scale. Clamp the
    // animation too, so neither opening nor closing can cross the safe bounds.
    return Offset(
      (anchor.right - childSize.width).clamp(
        padding.left,
        math.max(padding.left, size.width - padding.right - childSize.width),
      ),
      (top + slide).clamp(
        padding.top,
        math.max(padding.top, size.height - padding.bottom - childSize.height),
      ),
    );
  }

  @override
  bool shouldRelayout(_TokenPopupLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      padding != oldDelegate.padding ||
      animation != oldDelegate.animation;
}

class _AnimatedPopupContent extends StatelessWidget {
  const _AnimatedPopupContent({
    required this.animation,
    required this.isDesktop,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.child,
  });

  final Animation<double> animation;
  final bool isDesktop;
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget content = FadeTransition(opacity: animation, child: child);

    if (isDesktop) {
      content = MouseRegion(
        onEnter: (_) => onHoverEnter(),
        onExit: (_) => onHoverExit(),
        child: content,
      );
    }

    return content;
  }
}
