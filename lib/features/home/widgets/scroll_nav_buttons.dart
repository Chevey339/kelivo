import 'package:flutter/material.dart';
import '../../../icons/lucide_adapter.dart';

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
  });

  final bool visible;
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

    return Align(
      alignment: Alignment.bottomRight,
      child: SafeArea(
        top: false,
        bottom: false,
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
              child: Padding(
                padding: EdgeInsets.only(right: 12, bottom: bottomOffset),
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
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark
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
