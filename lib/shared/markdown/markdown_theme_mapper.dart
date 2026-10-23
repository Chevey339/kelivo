import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:markstream/markstream.dart';
import 'package:Kelivo/features/chat/widgets/frosted/chat_frosted_backdrop.dart';
import 'package:Kelivo/shared/widgets/export_capture_scope.dart';
import 'markdown_surface_scope.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
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
  if (backdrop != MarkstreamBackdrop.plain) {
    final customBackground = MarkdownSurfaceScope.maybeOf(
      context,
    )?.customBackground;
    if (customBackground != null) {
      // Only explicit bubble overrides need a local scheme. Pair the fill and
      // syntax brightness with that background, not the surrounding app theme.
      scheme = scheme.copyWith(
        surface: customBackground,
        brightness: ThemeData.estimateBrightnessForColor(customBackground),
      );
    }
  }
  return MarkstreamTheme.fromColorScheme(
    scheme,
    backdrop: backdrop,
    maskStrength: backdrop == MarkstreamBackdrop.plain
        ? 1
        : settings.chatBackgroundMaskStrength,
    bodyStyle: body,
    desktop: desktop,
    codeFontFamily: (settings.codeFontFamily?.isNotEmpty ?? false)
        ? settings.codeFontFamily!
        : 'monospace',
    medium: AppFontWeights.medium,
    semibold: AppFontWeights.semibold,
    strong: AppFontWeights.strong,
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
  // An explicit bubble color can invert the syntax theme. Its translucent
  // surface needs enough coverage for those fixed syntax colors as well.
  if (surface?.customBackground != null &&
      surface!.kind != MarkdownSurfaceKind.solid) {
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
