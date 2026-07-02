import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
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
    this.durationMs,
  });

  final int totalTokens;
  final int? promptTokens;
  final int? completionTokens;
  final int? cachedTokens;
  final int? durationMs;

  @override
  State<TokenDisplayWidget> createState() => _TokenDisplayWidgetState();
}

class _TokenDisplayWidgetState extends State<TokenDisplayWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  OverlayEntry? _barrierEntry;
  bool _isShowing = false;
  bool _showBelow = false;

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
      (widget.durationMs != null && widget.durationMs! > 0);

  static const double _estimatedPopupHeight = 120;

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
    _removeOverlayImmediate();
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
    _isShowing = true;

    final box = context.findRenderObject() as RenderBox?;
    _showBelow = _shouldShowBelow(box);

    final Alignment tAnchor;
    final Alignment fAnchor;
    final Offset offset;
    if (_showBelow) {
      tAnchor = Alignment.bottomRight;
      fAnchor = Alignment.topRight;
      offset = const Offset(0, 8);
    } else {
      tAnchor = Alignment.topRight;
      fAnchor = Alignment.bottomRight;
      offset = const Offset(0, -8);
    }

    // Listen to scroll position to dismiss popup on scroll
    _attachScrollListener();

    final overlay = Overlay.of(context, rootOverlay: true);

    if (!_isDesktop) {
      // Use Listener (onPointerDown) instead of GestureDetector (onTap)
      // so that scroll gestures (which start with pointerDown) also dismiss
      _barrierEntry = OverlayEntry(
        builder: (_) => Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _hidePopup(),
          child: const SizedBox.expand(),
        ),
      );
      overlay.insert(_barrierEntry!);
    }

    _overlayEntry = OverlayEntry(
      builder: (_) => UnconstrainedBox(
        child: CompositedTransformFollower(
          link: _layerLink,
          targetAnchor: tAnchor,
          followerAnchor: fAnchor,
          offset: offset,
          child: Material(
            type: MaterialType.transparency,
            child: _AnimatedPopupContent(
              animation: _ensureAnimation(),
              showBelow: _showBelow,
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
                durationMs: widget.durationMs,
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
    _ensureAnimation();
    _animController!.forward(from: 0);
  }

  bool _shouldShowBelow(RenderBox? box) {
    if (box == null || !box.attached) return false;
    try {
      final topY = box.localToGlobal(Offset.zero).dy;
      final padding = MediaQuery.of(context).padding.top;
      return topY - padding < _estimatedPopupHeight + 16;
    } catch (_) {
      return false;
    }
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
    _barrierEntry?.remove();
    _barrierEntry = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isShowing = false;
    _isHoveringTarget = false;
    _isHoveringPopup = false;
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
      return CompositedTransformTarget(link: _layerLink, child: label);
    }

    Widget child = CompositedTransformTarget(link: _layerLink, child: label);

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

    return child;
  }
}

class _AnimatedPopupContent extends StatelessWidget {
  const _AnimatedPopupContent({
    required this.animation,
    required this.showBelow,
    required this.isDesktop,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.child,
  });

  final Animation<double> animation;
  final bool showBelow;
  final bool isDesktop;
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final begin = Offset(0, showBelow ? -0.15 : 0.15);

    Widget content = SlideTransition(
      position: Tween<Offset>(
        begin: begin,
        end: Offset.zero,
      ).animate(animation),
      child: FadeTransition(opacity: animation, child: child),
    );

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
