import 'package:flutter/material.dart';
import '../../../icons/lucide_adapter.dart';

const scrollNavHoverRegionKey = ValueKey('scroll-nav-hover-region');

/// Glassy scroll navigation buttons panel with 4 buttons arranged vertically.
///
/// Buttons (from top to bottom):
/// - Scroll to top (chevrons-up)
/// - Previous user message (chevron-up)
/// - Next user message (chevron-down)
/// - Scroll to bottom (chevrons-down)
///
/// Shows with slide-in animation from right when user scrolls,
/// hides with slide-out animation after user stops scrolling.
class ScrollNavButtonsPanel extends StatelessWidget {
  const ScrollNavButtonsPanel({
    super.key,
    required this.visible,
    required this.onScrollToTop,
    required this.onPreviousMessage,
    required this.onNextMessage,
    required this.onScrollToBottom,
    this.bottomOffset = 80,
    this.iconSize = 16,
    this.buttonPadding = 6,
    this.buttonSpacing = 8,
    this.hoverEnabled = false,
    this.onHoverChanged,
    this.onScrollDragStart,
    this.onScrollDragUpdate,
  });

  final bool visible;
  final bool hoverEnabled;
  final ValueChanged<bool>? onHoverChanged;
  final VoidCallback? onScrollDragStart;
  final ValueChanged<double>? onScrollDragUpdate;
  final VoidCallback onScrollToTop;
  final VoidCallback onPreviousMessage;
  final VoidCallback onNextMessage;
  final VoidCallback onScrollToBottom;
  final double bottomOffset;
  final double iconSize;
  final double buttonPadding;
  final double buttonSpacing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black87;
    final buttonDiameter = iconSize + buttonPadding * 2;
    final hoverHeight = buttonDiameter * 4 + buttonSpacing * 3 + 24;
    final hoverWidth = buttonDiameter + 24;

    return Align(
      alignment: Alignment.bottomRight,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(right: 12, bottom: bottomOffset),
          child: MouseRegion(
            key: scrollNavHoverRegionKey,
            opaque: hoverEnabled,
            onEnter: hoverEnabled ? (_) => onHoverChanged?.call(true) : null,
            onExit: hoverEnabled ? (_) => onHoverChanged?.call(false) : null,
            child: SizedBox(
              width: hoverWidth,
              height: hoverHeight,
              child: Align(
                alignment: Alignment.bottomRight,
                child: IgnorePointer(
                  ignoring: !visible,
                  child: AnimatedSlide(
                    offset: visible ? Offset.zero : const Offset(1.2, 0),
                    duration: const Duration(milliseconds: 280),
                    curve: visible ? Curves.easeOutCubic : Curves.easeInCubic,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      opacity: visible ? 1 : 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _GlassyCircleButton(
                            icon: Lucide.ChevronsUp,
                            iconSize: iconSize,
                            iconColor: iconColor,
                            padding: buttonPadding,
                            isDark: isDark,
                            onScrollDragStart: onScrollDragStart,
                            onScrollDragUpdate: onScrollDragUpdate,
                            onTap: onScrollToTop,
                          ),
                          SizedBox(height: buttonSpacing),
                          _GlassyCircleButton(
                            icon: Lucide.ChevronUp,
                            iconSize: iconSize,
                            iconColor: iconColor,
                            padding: buttonPadding,
                            isDark: isDark,
                            onScrollDragStart: onScrollDragStart,
                            onScrollDragUpdate: onScrollDragUpdate,
                            onTap: onPreviousMessage,
                          ),
                          SizedBox(height: buttonSpacing),
                          _GlassyCircleButton(
                            icon: Lucide.ChevronDown,
                            iconSize: iconSize,
                            iconColor: iconColor,
                            padding: buttonPadding,
                            isDark: isDark,
                            onScrollDragStart: onScrollDragStart,
                            onScrollDragUpdate: onScrollDragUpdate,
                            onTap: onNextMessage,
                          ),
                          SizedBox(height: buttonSpacing),
                          _GlassyCircleButton(
                            icon: Lucide.ChevronsDown,
                            iconSize: iconSize,
                            iconColor: iconColor,
                            padding: buttonPadding,
                            isDark: isDark,
                            onScrollDragStart: onScrollDragStart,
                            onScrollDragUpdate: onScrollDragUpdate,
                            onTap: onScrollToBottom,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Single glassy circle button with semi-transparent background.
/// Uses simple opacity instead of expensive BackdropFilter for better performance.
class _GlassyCircleButton extends StatefulWidget {
  const _GlassyCircleButton({
    required this.icon,
    required this.iconSize,
    required this.iconColor,
    required this.padding,
    required this.isDark,
    required this.onTap,
    this.onScrollDragStart,
    this.onScrollDragUpdate,
  });

  final IconData icon;
  final double iconSize;
  final Color iconColor;
  final double padding;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onScrollDragStart;
  final ValueChanged<double>? onScrollDragUpdate;

  @override
  State<_GlassyCircleButton> createState() => _GlassyCircleButtonState();
}

class _GlassyCircleButtonState extends State<_GlassyCircleButton> {
  static const double _rawDragStartThreshold = 2.0;

  int? _activePointer;
  double _pendingDragDx = 0;
  double _pendingDragDy = 0;
  bool _forwardingDrag = false;
  bool _suppressTap = false;

  bool get _canForwardScrollDrag =>
      widget.onScrollDragStart != null || widget.onScrollDragUpdate != null;

  void _handlePointerDown(PointerDownEvent event) {
    _suppressTap = false;
    if (!_canForwardScrollDrag) return;
    _activePointer = event.pointer;
    _pendingDragDx = 0;
    _pendingDragDy = 0;
    _forwardingDrag = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_canForwardScrollDrag || _activePointer != event.pointer) return;

    _pendingDragDx += event.delta.dx;
    _pendingDragDy += event.delta.dy;

    if (!_forwardingDrag) {
      if (_pendingDragDy.abs() < _rawDragStartThreshold) return;
      if (_pendingDragDy.abs() < _pendingDragDx.abs()) return;

      _forwardingDrag = true;
      _suppressTap = true;
      widget.onScrollDragStart?.call();
      widget.onScrollDragUpdate?.call(_pendingDragDy);
      return;
    }

    widget.onScrollDragUpdate?.call(event.delta.dy);
  }

  void _handlePointerEnd(PointerEvent event) {
    if (_activePointer != event.pointer) return;
    _activePointer = null;
    _pendingDragDx = 0;
    _pendingDragDy = 0;
    _forwardingDrag = false;
  }

  void _handleTap() {
    if (_suppressTap) {
      _suppressTap = false;
      return;
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.black.withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.20),
          width: 1,
        ),
        //  boxShadow: [
        //    BoxShadow(
        //      color: Colors.black.withOpacity(0.01),
        //      blurRadius: 8,
        //      offset: const Offset(0, 2),
        //    ),
        // ],
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerEnd,
          onPointerCancel: _handlePointerEnd,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _handleTap,
            child: Padding(
              padding: EdgeInsets.all(widget.padding),
              child: Icon(
                widget.icon,
                size: widget.iconSize,
                color: widget.iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
