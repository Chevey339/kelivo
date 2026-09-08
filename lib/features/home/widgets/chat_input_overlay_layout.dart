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

  final double topInset;
  final Widget content;
  final Widget bottomOverlay;
  final Widget? topBackground;
  final Widget? foreground;
  final bool backgroundImageActive;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Stack(
            children: [
              Positioned.fill(child: content),
              if (backgroundImageActive && topBackground != null)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: ClipRect(
                      clipper: _TopOverlayClipper(
                        topInset + _topOverlayTailHeight,
                      ),
                      child: _TopBackgroundFade(
                        height: topInset + _topOverlayTailHeight,
                        child: IgnorePointer(
                          key: const Key('chat-input-overlay-top-background'),
                          child: _KeyboardStableBackground(
                            child: topBackground!,
                          ),
                        ),
                      ),
                    ),
                  ),
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
                Positioned.fill(
                  child: RepaintBoundary(
                    child: ClipRect(
                      clipper: const _BottomOverlayClipper(
                        _bottomOverlayFadeHeight,
                      ),
                      child: _BottomBackgroundFade(
                        height: _bottomOverlayFadeHeight,
                        child: IgnorePointer(
                          key: const Key(
                            'chat-input-overlay-bottom-background',
                          ),
                          child: _KeyboardStableBackground(
                            child: topBackground!,
                          ),
                        ),
                      ),
                    ),
                  ),
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
        Align(
          alignment: Alignment.bottomCenter,
          child: UnconstrainedBox(
            constrainedAxis: Axis.horizontal,
            alignment: Alignment.bottomCenter,
            child: bottomOverlay,
          ),
        ),
      ],
    );
  }
}

/// Lays the chat artwork out as if the keyboard were closed, letting the extra
/// height overflow behind the IME instead of shrinking with the Scaffold body.
/// A `BoxFit.cover` background re-crops whenever its box changes height, so
/// without this the whole image visibly jumps upwards as the keyboard opens.
///
/// The inset has to come from the [View]: Scaffold strips the bottom view inset
/// off the MediaQuery it hands to its body, so reading it from MediaQuery here
/// would always yield zero. Reading it inside the [LayoutBuilder] also keeps it
/// in sync, because the body's constraints change on the very same frame.
class _KeyboardStableBackground extends StatelessWidget {
  const _KeyboardStableBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.hasBoundedHeight) return child;
          final view = View.of(context);
          final bottomInset = view.viewInsets.bottom / view.devicePixelRatio;
          if (bottomInset <= 0) return child;
          final height = constraints.maxHeight + bottomInset;
          return OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: height,
            maxHeight: height,
            child: child,
          );
        },
      ),
    );
  }
}

class _TopOverlayClipper extends CustomClipper<Rect> {
  const _TopOverlayClipper(this.height);

  final double height;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width, height.clamp(0, size.height));
  }

  @override
  bool shouldReclip(_TopOverlayClipper oldClipper) {
    return height != oldClipper.height;
  }
}

class _BottomOverlayClipper extends CustomClipper<Rect> {
  const _BottomOverlayClipper(this.height);

  final double height;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(
      0,
      (size.height - height).clamp(0, size.height),
      size.width,
      height.clamp(0, size.height),
    );
  }

  @override
  bool shouldReclip(_BottomOverlayClipper oldClipper) {
    return height != oldClipper.height;
  }
}

class _TopBackgroundFade extends StatelessWidget {
  const _TopBackgroundFade({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.48, 0.78, 1.0],
          colors: [
            surface,
            surface,
            surface.withValues(alpha: 0.9),
            surface.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, bounds.width, height));
      },
      child: child,
    );
  }
}

class _BottomBackgroundFade extends StatelessWidget {
  const _BottomBackgroundFade({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.48, 1.0],
          colors: [
            surface.withValues(alpha: 0),
            surface.withValues(alpha: isDark ? 0.74 : 0.82),
            surface.withValues(alpha: isDark ? 0.92 : 0.98),
          ],
        ).createShader(
          Rect.fromLTWH(0, bounds.height - height, bounds.width, height),
        );
      },
      child: child,
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
