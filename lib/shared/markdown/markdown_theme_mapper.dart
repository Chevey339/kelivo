import 'package:flutter/material.dart';
import 'package:markstream/markstream.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/theme_factory.dart' show getPlatformFontFallback;

MarkstreamTheme mapMarkdownTheme(
  BuildContext context,
  SettingsProvider settings,
  TextStyle? baseStyle,
) {
  final scheme = Theme.of(context).colorScheme;
  final family = settings.appFontFamily;
  final body =
      (baseStyle ?? Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
          .copyWith(
            fontFamily: family == null || family.isEmpty
                ? baseStyle?.fontFamily
                : family,
            fontFamilyFallback: getPlatformFontFallback(),
            fontSize: baseStyle?.fontSize ?? 15.5,
            height: baseStyle?.height ?? 1.55,
            letterSpacing:
                baseStyle?.letterSpacing ??
                (Localizations.localeOf(context).languageCode == 'zh'
                    ? 0
                    : .05),
            color: DefaultTextStyle.of(context).style.color ?? scheme.onSurface,
          );
  return MarkstreamTheme.fromColorScheme(
    scheme,
    bodyStyle: body,
    codeFontFamily: (settings.codeFontFamily?.isNotEmpty ?? false)
        ? settings.codeFontFamily!
        : 'monospace',
    medium: AppFontWeights.medium,
    semibold: AppFontWeights.semibold,
    strong: AppFontWeights.strong,
  );
}
