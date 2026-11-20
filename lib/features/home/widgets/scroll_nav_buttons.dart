import 'package:flutter/material.dart';
import '../../../icons/lucide_adapter.dart';

const scrollNavHoverRegionKey = ValueKey('scroll-nav-hover-region');

/// Glassy scroll navigation buttons panel with 4 buttons arranged vertically.
///
/// Buttons (from top to bottom):
/// - Scroll to top (chevrons-up)
/// - Previous message (chevron-up)
/// - Next message (chevron-down)
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
    this.iconSize = _defaultIconSize,
    this.buttonPadding = _defaultButtonPadding,
    this.buttonSpacing = 8,
    this.hoverEnabled = false,
    this.onHoverChanged,
  });

  static const _defaultIconSize = 16.0;
  static const _defaultButtonPadding = 6.0;
  static const _rightMargin = 12.0;
  static const _hoverExtraWidth = 24.0;

  /// Right-edge space covered by the default panel, including its hover area.
  static const defaultOverlayWidth =
      _rightMargin +
      _defaultIconSize +
      2 * _defaultButtonPadding +
      _hoverExtraWidth;

  final bool visible;
  final bool hoverEnabled;
  final ValueChanged<bool>? onHoverChanged;
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
    final iconColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: isDark ? 1.0 : 0.87);
    final buttonDiameter = iconSize + buttonPadding * 2;
    final hoverHeight = buttonDiameter * 4 + buttonSpacing * 3 + 24;
    final hoverWidth = buttonDiameter + _hoverExtraWidth;

    return Align(
      alignment: Alignment.bottomRight,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(right: _rightMargin, bottom: bottomOffset),
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
                            onTap: onScrollToTop,
                          ),
                          SizedBox(height: buttonSpacing),
                          _GlassyCircleButton(
                            icon: Lucide.ChevronUp,
                            iconSize: iconSize,
                            iconColor: iconColor,
                            padding: buttonPadding,
                            isDark: isDark,
                            onTap: onPreviousMessage,
                          ),
                          SizedBox(height: buttonSpacing),
                          _GlassyCircleButton(
                            icon: Lucide.ChevronDown,
                            iconSize: iconSize,
                            iconColor: iconColor,
                            padding: buttonPadding,
                            isDark: isDark,
                            onTap: onNextMessage,
                          ),
                          SizedBox(height: buttonSpacing),
                          _GlassyCircleButton(
                            icon: Lucide.ChevronsDown,
                            iconSize: iconSize,
                            iconColor: iconColor,
                            padding: buttonPadding,
                            isDark: isDark,
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
class _GlassyCircleButton extends StatelessWidget {
  const _GlassyCircleButton({
    required this.icon,
    required this.iconSize,
    required this.iconColor,
    required this.padding,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final double iconSize;
  final Color iconColor;
  final double padding;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: isDark ? 0.4 : 0.85),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark
              ? cs.onSurface.withValues(alpha: 0.12)
              : cs.outline.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Icon(icon, size: iconSize, color: iconColor),
          ),
        ),
      ),
    );
  }
}
