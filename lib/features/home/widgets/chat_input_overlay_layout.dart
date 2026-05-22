import 'package:flutter/material.dart';

class ChatInputOverlayLayout extends StatelessWidget {
  const ChatInputOverlayLayout({
    super.key,
    required this.topInset,
    required this.content,
    required this.bottomOverlay,
    this.background,
    this.foreground,
    this.backgroundImageActive = false,
  });

  final double topInset;
  final Widget content;
  final Widget bottomOverlay;
  final Widget? background;
  final Widget? foreground;
  final bool backgroundImageActive;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (background != null) Positioned.fill(child: background!),
        Positioned.fill(
          top: topInset,
          child: Stack(
            children: [
              Positioned.fill(child: content),
              if (!backgroundImageActive)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 180,
                  child: _BottomOverlayFade(),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: UnconstrainedBox(
                  constrainedAxis: Axis.horizontal,
                  alignment: Alignment.bottomCenter,
                  child: bottomOverlay,
                ),
              ),
            ],
          ),
        ),
        if (foreground != null) Positioned.fill(child: foreground!),
      ],
    );
  }
}

class _BottomOverlayFade extends StatelessWidget {
  const _BottomOverlayFade();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const [0.0, 0.48, 1.0],
      colors: [
        surface.withValues(alpha: 0),
        surface.withValues(alpha: isDark ? 0.64 : 0.82),
        surface.withValues(alpha: isDark ? 0.92 : 0.98),
      ],
    );

    return IgnorePointer(
      key: const Key('chat-input-overlay-bottom-fade'),
      child: DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
    );
  }
}
