import 'package:flutter/material.dart';

class ChatInputOverlayLayout extends StatelessWidget {
  const ChatInputOverlayLayout({
    super.key,
    required this.topInset,
    required this.content,
    required this.bottomOverlay,
    this.topBackground,
    this.foreground,
    this.backgroundImageActive = false,
  });

  static const double _topOverlayTailHeight = 16;
  static const double _bottomOverlayFadeHeight = 180;
  // Leaves room for badges riding 12px above the composer's top edge.
  static const double _bottomOverlayTopGap = 12;

  final double topInset;
  final Widget content;
  final Widget bottomOverlay;
  final Widget? topBackground;
  final Widget? foreground;
  final bool backgroundImageActive;

  @override
  Widget build(BuildContext context) {
    // Match the composer's SafeArea, including its zero padding above the IME.
    final bottomSafeInset = MediaQuery.paddingOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        // Scaffold removes the IME inset from its body's MediaQuery. Use View
        // here so artwork keeps its full-window size as the body shrinks.
        final view = View.of(context);
        final backgroundSize = Size(
          size.width,
          size.height + view.viewInsets.bottom / view.devicePixelRatio,
        );
        final topHeight = (topInset + _topOverlayTailHeight).clamp(
          0.0,
          size.height,
        );
        final bottomHeight = _bottomOverlayFadeHeight.clamp(0.0, size.height);

        return Stack(
          children: [
            Positioned.fill(
              child: Stack(
                children: [
                  Positioned.fill(child: content),
                  if (backgroundImageActive && topBackground != null)
                    _BackgroundOverlay(
                      overlayKey: const Key(
                        'chat-input-overlay-top-background',
                      ),
                      rect: Rect.fromLTWH(0, 0, size.width, topHeight),
                      backgroundSize: backgroundSize,
                      shaderRect: Rect.fromLTWH(
                        0,
                        0,
                        size.width,
                        topInset + _topOverlayTailHeight,
                      ),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.48, 0.78, 1.0],
                        colors: [
                          Colors.white,
                          Colors.white,
                          Color.fromRGBO(255, 255, 255, 0.9),
                          Color.fromRGBO(255, 255, 255, 0),
                        ],
                      ),
                      child: topBackground!,
                    )
                  else if (!backgroundImageActive)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: topInset + _topOverlayTailHeight,
                      child: const _TopOverlayFade(),
                    ),
                  if (backgroundImageActive && topBackground != null)
                    _BackgroundOverlay(
                      overlayKey: const Key(
                        'chat-input-overlay-bottom-background',
                      ),
                      rect: Rect.fromLTWH(
                        0,
                        size.height - bottomHeight,
                        size.width,
                        bottomHeight,
                      ),
                      backgroundSize: backgroundSize,
                      shaderRect: Rect.fromLTWH(
                        0,
                        bottomHeight - _bottomOverlayFadeHeight,
                        size.width,
                        _bottomOverlayFadeHeight,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.48, 1.0],
                        colors: [
                          const Color.fromRGBO(255, 255, 255, 0),
                          Colors.white.withValues(alpha: isDark ? 0.74 : 0.82),
                          Colors.white.withValues(alpha: isDark ? 0.92 : 0.98),
                        ],
                      ),
                      child: topBackground!,
                    )
                  else if (!backgroundImageActive)
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: _bottomOverlayFadeHeight,
                      child: _BottomOverlayFade(),
                    ),
                  if (foreground != null) Positioned.fill(child: foreground!),
                ],
              ),
            ),
            // The overlay may grow up to the top bar (an expanded composer does)
            // but never behind it.
            Positioned.fill(
              top: topInset + _bottomOverlayTopGap,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: bottomOverlay,
              ),
            ),
            // SafeArea padding is not hit-testable. Keep gestures starting there
            // from reaching the full-height message list behind the composer.
            if (bottomSafeInset > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: bottomSafeInset,
                child: const AbsorbPointer(child: SizedBox.expand()),
              ),
          ],
        );
      },
    );
  }
}

/// Composite only the visible edge strip, rather than masking a full-screen
/// layer and relying on an outer clip to limit it. The artwork itself retains
/// the full-window coordinates used by the background behind the messages.
class _BackgroundOverlay extends StatelessWidget {
  const _BackgroundOverlay({
    required this.overlayKey,
    required this.rect,
    required this.backgroundSize,
    required this.shaderRect,
    required this.gradient,
    required this.child,
  });

  final Key overlayKey;
  final Rect rect;
  final Size backgroundSize;
  // Preserve the full fade range when the keyboard leaves a shorter strip.
  final Rect shaderRect;
  final LinearGradient gradient;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        key: overlayKey,
        child: RepaintBoundary(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (_) => gradient.createShader(shaderRect),
            // Clip inside the mask so its offscreen layer's child paint bounds
            // also stay within the strip, despite the overflowing artwork.
            child: ClipRect(
              // Cover messages even while an image is loading or has alpha.
              // For opaque wallpaper this adds no visible tint.
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: backgroundSize.width,
                  maxWidth: backgroundSize.width,
                  minHeight: backgroundSize.height,
                  maxHeight: backgroundSize.height,
                  child: Transform.translate(
                    offset: -rect.topLeft,
                    child: child,
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

class _TopOverlayFade extends StatelessWidget {
  const _TopOverlayFade();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const [0.0, 0.48, 0.78, 1.0],
      colors: [
        surface.withValues(alpha: 1.0),
        surface.withValues(alpha: isDark ? 0.96 : 0.99),
        surface.withValues(alpha: isDark ? 0.74 : 0.88),
        surface.withValues(alpha: 0),
      ],
    );

    return IgnorePointer(
      key: const Key('chat-input-overlay-top-fade'),
      child: DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
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
