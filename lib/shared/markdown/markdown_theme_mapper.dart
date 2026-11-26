import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:markstream/markstream.dart';
import 'package:Kelivo/features/chat/widgets/frosted/chat_frosted_backdrop.dart';
import 'package:Kelivo/shared/widgets/export_capture_scope.dart';
import 'markdown_surface_scope.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/surface_ladder.dart' show atTone, surfaceTone;
import 'package:Kelivo/theme/theme_factory.dart' show getPlatformFontFallback;

MarkstreamTheme mapMarkdownTheme(
  BuildContext context,
  SettingsProvider settings,
  TextStyle? baseStyle,
) {
  var scheme = Theme.of(context).colorScheme;
  final family = settings.appFontFamily;
  final body =
      (baseStyle ?? Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
          .copyWith(
            fontFamily: family == null || family.isEmpty
                ? baseStyle?.fontFamily
                : family,
            fontFamilyFallback:
                baseStyle?.fontFamilyFallback ?? getPlatformFontFallback(),
            fontSize: baseStyle?.fontSize ?? 15.5,
            height: baseStyle?.height ?? 1.55,
            letterSpacing:
                baseStyle?.letterSpacing ??
                (Localizations.localeOf(context).languageCode == 'zh'
                    ? 0
                    : .05),
            color: DefaultTextStyle.of(context).style.color ?? scheme.onSurface,
          );
  final desktop =
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows;
  final backdrop = resolveMarkdownBackdrop(context, settings);
  final surface = MarkdownSurfaceScope.maybeOf(context);
  final customBackground =
      surface != null &&
          surface.hasCustomBackground &&
          !ExportCaptureScope.of(context)
      ? surface.backgroundColor?.withValues(alpha: 1)
      : null;
  if (backdrop != MarkstreamBackdrop.plain) {
    if (customBackground != null) {
      // Fixed syntax colors need a near-dark or near-light block surface, even
      // over arbitrary wallpaper. Retain the bubble's hue, but always follow
      // the app's brightness rather than inferring it from the bubble color.
      final tone = surfaceTone(customBackground);
      final dark = scheme.brightness == Brightness.dark;
      final blockTone = dark ? tone.clamp(0.0, 5.0) : tone.clamp(98.0, 100.0);
      scheme = scheme.copyWith(
        surface: blockTone == tone
            ? customBackground
            : atTone(customBackground, blockTone),
        onSurface: dark ? Colors.white : Colors.black,
      );
    }
  }
  var theme = MarkstreamTheme.fromColorScheme(
    scheme,
    backdrop: backdrop,
    maskStrength: backdrop == MarkstreamBackdrop.plain
        ? 1
        : settings.chatBackgroundMaskStrength,
    // Fixed syntax colors need an opaque surface over arbitrary custom
    // bubbles, including diagram source tabs that use the shared palette.
    blockBackgroundColor:
        customBackground == null || backdrop == MarkstreamBackdrop.plain
        ? null
        : scheme.surface,
    bodyStyle: body,
    desktop: desktop,
    codeFontFamily: (settings.codeFontFamily?.isNotEmpty ?? false)
        ? settings.codeFontFamily!
        : 'monospace',
    fontWeightResolver: AppFontWeights.normalize,
  );
  if (settings.useLegacyCodeBlockStyle) {
    theme = theme.copyWith(
      code: _legacyCodeBlockTheme(
        theme,
        scheme,
        customSurface: customBackground != null,
        exporting: ExportCaptureScope.of(context),
      ),
    );
  }
  if (!settings.useLegacyInlineCodeStyle) return theme;
  final inlineFill = theme.brightness == Brightness.dark
      ? Colors.white12
      : const Color(0x66F1F3F5);
  return theme.copyWith(
    inlineCode: theme.inlineCode.copyWith(
      text: theme.inlineCode.text.copyWith(
        height: 1.4,
        color: theme.colors.ink,
      ),
      inheritBodyColor: _legacyInlineUsesBodyColor(
        theme,
        inlineFill,
        surface?.backgroundColor,
      ),
      // Keep short code within the paragraph's line height while giving
      // wrapped code room between lines.
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      backgroundColor: inlineFill,
      borderColor: theme.colors.border,
    ),
  );
}

bool _legacyInlineUsesBodyColor(
  MarkstreamTheme theme,
  Color inlineFill,
  Color? bubbleFill,
) {
  final bodyInk = theme.body.color;
  final blockInk = theme.colors.ink;
  if (bodyInk == null || bodyInk == blockInk) return false;
  final overWallpaper =
      theme.backdrop == MarkstreamBackdrop.wallpaper ||
      theme.backdrop == MarkstreamBackdrop.frostedBubble;
  // A plain export may omit the wallpaper its body text color was chosen for.
  if (!overWallpaper && (bubbleFill == null || bubbleFill.a == 0)) return false;

  final fill = Color.alphaBlend(inlineFill, bubbleFill ?? Colors.transparent);
  final darkest = Color.alphaBlend(fill, Colors.black);
  final lightest = fill.a < 1 ? Color.alphaBlend(fill, Colors.white) : darkest;
  final low = darkest.computeLuminance() + .05;
  final high = lightest.computeLuminance() + .05;
  double ratio(double a, double b) => a >= b ? a / b : b / a;

  ({double minimum, double bestEndpoint}) contrast(Color ink) {
    final inkLow = Color.alphaBlend(ink, darkest).computeLuminance() + .05;
    final inkHigh = ink.a == 1 || lightest == darkest
        ? inkLow
        : Color.alphaBlend(ink, lightest).computeLuminance() + .05;
    // Overlapping ink and surface luminance ranges can have contrast 1:1.
    final minimum = math.max(1.0, math.max(inkLow / high, low / inkHigh));
    return (
      minimum: minimum,
      bestEndpoint: math.max(ratio(inkLow, low), ratio(inkHigh, high)),
    );
  }

  const readable = 4.5;
  final body = contrast(bodyInk);
  if (body.minimum >= readable) return true;
  final block = contrast(blockInk);
  if (block.minimum >= readable) return false;
  // Plain Markdown can sit on a card with its own canvas. Keep the existing
  // theme ink when a translucent bubble cannot establish a readable body ink.
  if (!overWallpaper && fill.a < 1) return false;
  // If neither ink covers the entire wallpaper range, prefer the user's
  // color when it can work against the wallpaper they chose.
  if (body.bestEndpoint >= readable) return true;
  if (block.bestEndpoint >= readable) return false;
  return body.minimum >= block.minimum;
}

CodeBlockTheme _legacyCodeBlockTheme(
  MarkstreamTheme theme,
  ColorScheme scheme, {
  required bool customSurface,
  required bool exporting,
}) {
  final dark = theme.brightness == Brightness.dark;
  final outline = scheme.outlineVariant;
  final border = outline == Colors.black || outline == Colors.white
      ? Color.alphaBlend(
          scheme.onSurfaceVariant.withValues(alpha: dark ? .32 : .24),
          scheme.surface,
        )
      : outline;
  // Custom chat colors still need the paired block surface/ink resolved above.
  // Other surfaces retain the original theme-container colors and 80% fill.
  final fillAlpha = exporting ? 1.0 : .8;
  final backdropTint = !exporting && theme.backdrop != MarkstreamBackdrop.plain;
  return theme.code.copyWith(
    text: theme.code.text.copyWith(fontSize: 13, height: 1.5),
    margin: const EdgeInsets.symmetric(vertical: 6),
    bodyPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    titlePadding: EdgeInsets.zero,
    actionSpacing: 16,
    radius: 16,
    backgroundColor: customSurface
        ? theme.code.backgroundColor
        : scheme.surfaceContainer.withValues(alpha: fillAlpha),
    borderColor: customSurface ? theme.colors.border : border,
    chrome: theme.code.chrome.copyWith(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      // The code surface already paints the backdrop fill. Use only a light
      // tint here instead of stacking another 80% layer over the wallpaper.
      background: backdropTint
          ? theme.colors.fillHead
          : (customSurface ? scheme.surface : scheme.surfaceContainerHighest)
                .withValues(alpha: fillAlpha),
      divider: Colors.transparent,
      label: theme.code.chrome.label.copyWith(
        fontSize: 12,
        letterSpacing: theme.body.letterSpacing,
        color: backdropTint
            ? theme.colors.ink.withValues(alpha: .9)
            : customSurface
            ? theme.colors.ink2
            : scheme.onSurfaceVariant.withValues(alpha: .72),
      ),
      actionSize: 24,
      actionIconSize: 16,
      actionRadius: 4,
      actionColor: backdropTint
          ? theme.colors.ink2
          : customSurface
          ? theme.colors.ink3
          : scheme.onSurfaceVariant.withValues(alpha: .5),
    ),
  );
}

MarkstreamBackdrop resolveMarkdownBackdrop(
  BuildContext context,
  SettingsProvider settings,
) {
  if (ExportCaptureScope.of(context)) return MarkstreamBackdrop.plain;
  // ChatBackdropSpec already resolves this with stable provider selectors.
  // Reuse that boolean instead of registering another selector per stream tick.
  final scope = ChatFrostedBackdropScope.maybeOf(context);
  if (scope == null || !scope.backgroundActive) return MarkstreamBackdrop.plain;
  final surface = MarkdownSurfaceScope.maybeOf(context);
  // Custom bubbles need the readable block fill even when the outer bubble is
  // opaque: a small tint cannot shield fixed syntax colors from a midtone.
  if (surface?.hasCustomBackground == true) {
    return MarkstreamBackdrop.wallpaper;
  }
  return switch (surface?.kind) {
    MarkdownSurfaceKind.solid => MarkstreamBackdrop.solidBubble,
    MarkdownSurfaceKind.frosted => MarkstreamBackdrop.frostedBubble,
    // User/reasoning tints can be only 8% opaque and cannot shield the text
    // like a frosted bubble. Keep the wallpaper readability guard here.
    MarkdownSurfaceKind.tinted => MarkstreamBackdrop.wallpaper,
    null => MarkstreamBackdrop.wallpaper,
  };
}
