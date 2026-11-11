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
  final customBackground = ExportCaptureScope.of(context)
      ? null
      : MarkdownSurfaceScope.maybeOf(context)?.customBackground;
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
  final translucent =
      backdrop == MarkstreamBackdrop.wallpaper ||
      backdrop == MarkstreamBackdrop.frostedBubble;
  return theme.copyWith(
    inlineCode: theme.inlineCode.copyWith(
      text: theme.inlineCode.text.copyWith(
        height: 1.4,
        color: theme.colors.ink,
      ),
      // Keep short code within the paragraph's line height while giving
      // wrapped code room between lines.
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      backgroundColor: translucent
          ? theme.colors.fillBlock
          : theme.brightness == Brightness.dark
          ? Colors.white12
          : const Color(0x66F1F3F5),
      borderColor: theme.colors.border,
    ),
  );
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
  if (surface?.customBackground != null) {
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
