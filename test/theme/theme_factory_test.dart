import 'package:Kelivo/theme/app_semantic_colors.dart';
import 'package:Kelivo/theme/palettes.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('getPlatformFontFallback', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('uses Android system font stack on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      expect(getPlatformFontFallback(), kAndroidFontFamilyFallback);
    });

    test('keeps CJK fallback on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      expect(getPlatformFontFallback(), kDefaultFontFamilyFallback);
    });

    test('keeps Windows fallback on Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      expect(getPlatformFontFallback(), kWindowsFontFamilyFallback);
    });
  });

  group('overlay surface themes', () {
    test('legacy dark overlays use page surface', () {
      final theme = buildDarkThemeForScheme(ThemePalettes.defaultPalette.dark);
      final scheme = theme.colorScheme;
      final colors = theme.extension<AppSemanticColors>()!;
      expect(colors.layered, isFalse);
      expect(theme.dialogTheme.backgroundColor, scheme.surface);
      expect(theme.bottomSheetTheme.backgroundColor, scheme.surface);
      expect(theme.popupMenuTheme.color, scheme.surface);
      expect(colors.overlaySurface(scheme), scheme.surface);
      expect(colors.surfaceCard, isNot(scheme.surface));
    });

    test('layered dark overlays use surfaceCard', () {
      final theme = buildDarkThemeForScheme(
        ThemePalettes.defaultPalette.dark,
        layeredSurfaces: true,
      );
      final scheme = theme.colorScheme;
      final colors = theme.extension<AppSemanticColors>()!;
      expect(colors.layered, isTrue);
      expect(theme.dialogTheme.backgroundColor, colors.surfaceCard);
      expect(theme.bottomSheetTheme.backgroundColor, colors.surfaceCard);
      expect(theme.popupMenuTheme.color, colors.surfaceCard);
      expect(colors.overlaySurface(scheme), colors.surfaceCard);
    });
  });
}
