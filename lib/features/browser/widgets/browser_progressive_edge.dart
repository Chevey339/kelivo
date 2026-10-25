import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../models/browser_models.dart';
import 'browser_glass.dart';

/// Exactly one bounded region at each screen edge. The library uses two
/// separable GPU passes; no stacked blur bands, screenshots or ticking state.
class BrowserProgressiveEdge extends StatelessWidget {
  const BrowserProgressiveEdge({
    super.key,
    required this.top,
    this.filterBackdrop = true,
    this.fadeBehindToolbar = false,
  });
  final bool top;

  /// Native WebViews are composited outside the Flutter backdrop. Their edge
  /// protection uses the translucent gradient without a shader sampling an
  /// unrelated Flutter surface. Flutter tab previews retain progressive blur.
  final bool filterBackdrop;

  /// Keep the native dark toolbar's own glass readable without tinting its
  /// entire backdrop again. The home-indicator edge retains its protection.
  final bool fadeBehindToolbar;

  static Future<void>? _preparation;
  static Future<void> prewarm() => _preparation ??= ProgressiveBlur.preload();

  @override
  Widget build(BuildContext context) {
    final style = BrowserGlassScope.of(context);
    final reduced =
        GlassAccessibilityData.of(context).reduceTransparency ||
        MediaQuery.highContrastOf(context) ||
        style == BrowserSurfaceStyle.solid;
    final theme = Theme.of(context);
    final color = theme.colorScheme.surface;
    final fadeToolbar =
        fadeBehindToolbar &&
        !top &&
        theme.brightness == Brightness.dark &&
        style == BrowserSurfaceStyle.liquid &&
        !filterBackdrop &&
        !reduced;
    return IgnorePointer(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (filterBackdrop &&
                !reduced &&
                ui.ImageFilter.isShaderFilterSupported)
              ProgressiveBlur(
                maxSigma: 10,
                falloff: 1.6,
                direction: top
                    ? ProgressiveBlurDirection.topToBottom
                    : ProgressiveBlurDirection.bottomToTop,
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                  end: top ? Alignment.bottomCenter : Alignment.topCenter,
                  colors: fadeToolbar
                      ? [
                          color.withValues(alpha: .64),
                          color.withValues(alpha: .40),
                          color.withValues(alpha: .06),
                          color.withValues(alpha: 0),
                        ]
                      : [
                          color.withValues(
                            alpha: reduced ? .98 : (filterBackdrop ? .22 : .64),
                          ),
                          color.withValues(
                            alpha: reduced ? .7 : (filterBackdrop ? .06 : .16),
                          ),
                          color.withValues(alpha: 0),
                        ],
                  stops: fadeToolbar
                      ? const [0, .18, .42, 1]
                      : const [0, .55, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
