import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/platform_utils.dart';

// CJK/Latin fallback to stabilize fontWeight (w100–w600) on iOS for Chinese
const List<String> kDefaultFontFamilyFallback = <String>[
  'PingFang SC',
  'Heiti SC',
  'Hiragino Sans GB',
  'Roboto',
];

// Better CJK fallback for Windows to avoid serif/sim-sun look and ensure glyph coverage.
const List<String> kWindowsFontFamilyFallback = <String>[
  'Microsoft YaHei UI',
  'Microsoft YaHei',
  'Segoe UI Variable',
  'Segoe UI',
  'Noto Sans CJK SC',
  'Roboto',
  'Arial Unicode MS',
];

TextTheme _withFontFallback(TextTheme base, List<String> fallback) {
  TextStyle? f(TextStyle? s) => s?.copyWith(fontFamilyFallback: fallback);
  return base.copyWith(
    displayLarge: f(base.displayLarge),
    displayMedium: f(base.displayMedium),
    displaySmall: f(base.displaySmall),
    headlineLarge: f(base.headlineLarge),
    headlineMedium: f(base.headlineMedium),
    headlineSmall: f(base.headlineSmall),
    titleLarge: f(base.titleLarge),
    titleMedium: f(base.titleMedium),
    titleSmall: f(base.titleSmall),
    bodyLarge: f(base.bodyLarge),
    bodyMedium: f(base.bodyMedium),
    bodySmall: f(base.bodySmall),
    labelLarge: f(base.labelLarge),
    labelMedium: f(base.labelMedium),
    labelSmall: f(base.labelSmall),
  );
}

// String _hex(Color c) => '#${c.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
// String _rgb(Color c) => 'r=${c.red}, g=${c.green}, b=${c.blue}, a=${(c.alpha / 255).toStringAsFixed(3)}';
// String _hsl(Color c) {
//   final hsl = HSLColor.fromColor(c);
//   return 'h=${hsl.hue.toStringAsFixed(1)} s=${(hsl.saturation * 100).toStringAsFixed(1)}% l=${(hsl.lightness * 100).toStringAsFixed(1)}%';
// }
// String _hsv(Color c) {
//   final hsv = HSVColor.fromColor(c);
//   return 'h=${hsv.hue.toStringAsFixed(1)} s=${(hsv.saturation * 100).toStringAsFixed(1)}% v=${(hsv.value * 100).toStringAsFixed(1)}%';
// }
// String _lum(Color c) => 'lum=${c.computeLuminance().toStringAsFixed(4)}';
//
// void _logOne(String tag, String name, Color c) {
//   debugPrint('[Theme/$tag][$name] ${_hex(c)} | ${_rgb(c)} | ${_hsl(c)} | ${_hsv(c)} | ${_lum(c)}');
// }
//
// void _logColorScheme(String tag, ColorScheme s) {
//   // Log a comprehensive dump of the scheme with HEX/RGB/HSL/HSV/Luminance.
//   debugPrint('[Theme/$tag] ================= ColorScheme Dump =================');
//   debugPrint('[Theme/$tag] brightness=${s.brightness}');
//   _logOne(tag, 'primary', s.primary);
//   _logOne(tag, 'onPrimary', s.onPrimary);
//   _logOne(tag, 'primaryContainer', s.primaryContainer);
//   _logOne(tag, 'onPrimaryContainer', s.onPrimaryContainer);
//   _logOne(tag, 'secondary', s.secondary);
//   _logOne(tag, 'onSecondary', s.onSecondary);
//   _logOne(tag, 'secondaryContainer', s.secondaryContainer);
//   _logOne(tag, 'onSecondaryContainer', s.onSecondaryContainer);
//   _logOne(tag, 'tertiary', s.tertiary);
//   _logOne(tag, 'onTertiary', s.onTertiary);
//   _logOne(tag, 'tertiaryContainer', s.tertiaryContainer);
//   _logOne(tag, 'onTertiaryContainer', s.onTertiaryContainer);
//   _logOne(tag, 'surface', s.surface);
//   _logOne(tag, 'onSurface', s.onSurface);
//   _logOne(tag, 'surfaceVariant', s.surfaceVariant);
//   _logOne(tag, 'onSurfaceVariant', s.onSurfaceVariant);
//   _logOne(tag, 'background', s.background);
//   _logOne(tag, 'onBackground', s.onBackground);
//   _logOne(tag, 'error', s.error);
//   _logOne(tag, 'onError', s.onError);
//   _logOne(tag, 'errorContainer', s.errorContainer);
//   _logOne(tag, 'onErrorContainer', s.onErrorContainer);
//   _logOne(tag, 'outline', s.outline);
//   _logOne(tag, 'outlineVariant', s.outlineVariant);
//   _logOne(tag, 'shadow', s.shadow);
//   _logOne(tag, 'scrim', s.scrim);
//   _logOne(tag, 'inverseSurface', s.inverseSurface);
//   _logOne(tag, 'onInverseSurface', s.onInverseSurface);
//   _logOne(tag, 'inversePrimary', s.inversePrimary);
//   _logOne(tag, 'surfaceTint', s.surfaceTint);
//   // Derived/common surfaces used in this app
//   _logOne(tag, 'cardBackground≈surface', s.surface);
//   _logOne(tag, 'scaffoldBackground', s.surface);
//   _logOne(tag, 'appBarBackground', s.surface);
//   // M3 tinted surfaces approximation at common elevations
//   final e1 = ElevationOverlay.applySurfaceTint(s.surface, s.surfaceTint, 1);
//   final e3 = ElevationOverlay.applySurfaceTint(s.surface, s.surfaceTint, 3);
//   final e6 = ElevationOverlay.applySurfaceTint(s.surface, s.surfaceTint, 6);
//   _logOne(tag, 'surface@1dp', e1);
//   _logOne(tag, 'surface@3dp', e3);
//   _logOne(tag, 'surface@6dp', e6);
//   debugPrint('[Theme/$tag] ======================================================');
// }

ThemeData buildLightTheme(ColorScheme? dynamicScheme) {
  final scheme = (dynamicScheme?.harmonized()) ?? const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF4D5C92),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDCE1FF),
    onPrimaryContainer: Color(0xFF03174B),
    secondary: Color(0xFF595D72),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFDEE1F9),
    onSecondaryContainer: Color(0xFF161B2C),
    tertiary: Color(0xFF75546F),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFFD7F6),
    onTertiaryContainer: Color(0xFF2C122A),
    error: Color(0xFFBB0947),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFDDADE),
    onErrorContainer: Color(0xFF400013),
    // background: Color(0xFFFEFBFF),
    // onBackground: Color(0xFF1A1B21),
    surface: Color(0xFFFEFBFF),
    onSurface: Color(0xFF1A1B21),
    // surfaceVariant: Color(0xFFE2E1EC),
    onSurfaceVariant: Color(0xFF45464F),
    outline: Color(0xFF75757F),
    outlineVariant: Color(0xFFC6C6D0),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF2F3036),
    onInverseSurface: Color(0xFFF1F0F7),
    inversePrimary: Color(0xFFB6C4FF),
    surfaceTint: Color(0xFF4D5C92),
  );
  // _logColorScheme('Light ${dynamicScheme != null ? 'Dynamic' : 'Static'}', scheme);

  final fallback = PlatformUtils.isWindows ? kWindowsFontFamilyFallback : kDefaultFontFamilyFallback;
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(
        color: scheme.onInverseSurface,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontFamilyFallback: kDefaultFontFamilyFallback,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      actionTextColor: scheme.primary,
      disabledActionTextColor: scheme.onInverseSurface.withOpacity(0.5),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: Colors.black,
      titleTextStyle: const TextStyle(
        color: Colors.black,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ).copyWith(fontFamilyFallback: fallback),
      iconTheme: const IconThemeData(color: Colors.black),
      actionsIconTheme: const IconThemeData(color: Colors.black),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
    ),
  );
  return theme.copyWith(
    textTheme: _withFontFallback(theme.textTheme, fallback),
    primaryTextTheme: _withFontFallback(theme.primaryTextTheme, fallback),
  );
}

// New: Build themes from a provided static palette (with optional dynamic override)
ThemeData buildLightThemeForScheme(ColorScheme staticScheme, {ColorScheme? dynamicScheme}) {
  final scheme = (dynamicScheme?.harmonized()) ?? staticScheme;
  // Align logging behavior with buildLightTheme so diagnostics are consistent.
  // _logColorScheme('Light ${dynamicScheme != null ? 'Dynamic' : 'Static'}', scheme);
  final fallback = PlatformUtils.isWindows ? kWindowsFontFamilyFallback : kDefaultFontFamilyFallback;
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(
        color: scheme.onInverseSurface,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontFamilyFallback: kDefaultFontFamilyFallback,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      actionTextColor: scheme.primary,
      disabledActionTextColor: scheme.onInverseSurface.withOpacity(0.5),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: Colors.black,
      titleTextStyle: const TextStyle(
        color: Colors.black,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ).copyWith(fontFamilyFallback: fallback),
      iconTheme: const IconThemeData(color: Colors.black),
      actionsIconTheme: const IconThemeData(color: Colors.black),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: scheme.surface,
      ),
    ),
  );
  return theme.copyWith(
    textTheme: _withFontFallback(theme.textTheme, fallback),
    primaryTextTheme: _withFontFallback(theme.primaryTextTheme, fallback),
  );
}

ThemeData buildDarkTheme(ColorScheme? dynamicScheme) {
  final scheme = (dynamicScheme?.harmonized()) ?? const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFB6C4FF),
    onPrimary: Color(0xFF1D2D61),
    primaryContainer: Color(0xFF354479),
    onPrimaryContainer: Color(0xFFDCE1FF),
    secondary: Color(0xFFC2C5DD),
    onSecondary: Color(0xFF2B3042),
    secondaryContainer: Color(0xFF424659),
    onSecondaryContainer: Color(0xFFDEE1F9),
    tertiary: Color(0xFFE3BADA),
    onTertiary: Color(0xFF432740),
    tertiaryContainer: Color(0xFF5B3D57),
    onTertiaryContainer: Color(0xFFFFD7F6),
    error: Color(0xFFFCB4BD),
    onError: Color(0xFF670023),
    errorContainer: Color(0xFF910034),
    onErrorContainer: Color(0xFFFCB4BD),
    // background: Color(0xFF1A1B21),
    // onBackground: Color(0xFFE3E1E9),
    surface: Color(0xFF1A1B21),
    onSurface: Color(0xFFE3E1E9),
    // surfaceVariant: Color(0xFF45464F),
    onSurfaceVariant: Color(0xFFC6C6D0),
    outline: Color(0xFF90909A),
    outlineVariant: Color(0xFF45464F),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE3E1E9),
    onInverseSurface: Color(0xFF2F3036),
    inversePrimary: Color(0xFF4D5C92),
    surfaceTint: Color(0xFFB6C4FF),
  );
  // _logColorScheme('Dark ${dynamicScheme != null ? 'Dynamic' : 'Static'}', scheme);

  final fallback = PlatformUtils.isWindows ? kWindowsFontFamilyFallback : kDefaultFontFamilyFallback;
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(
        color: scheme.onInverseSurface,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontFamilyFallback: kDefaultFontFamilyFallback,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      actionTextColor: scheme.primary,
      disabledActionTextColor: scheme.onInverseSurface.withOpacity(0.6),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ).copyWith(fontFamilyFallback: fallback),
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
    ),
  );
  return theme.copyWith(
    textTheme: _withFontFallback(theme.textTheme, fallback),
    primaryTextTheme: _withFontFallback(theme.primaryTextTheme, fallback),
  );
}

ThemeData buildDarkThemeForScheme(ColorScheme staticScheme, {ColorScheme? dynamicScheme}) {
  final scheme = (dynamicScheme?.harmonized()) ?? staticScheme;
  // Align logging behavior with buildDarkTheme so diagnostics are consistent.
  // _logColorScheme('Dark ${dynamicScheme != null ? 'Dynamic' : 'Static'}', scheme);
  final fallback = PlatformUtils.isWindows ? kWindowsFontFamilyFallback : kDefaultFontFamilyFallback;
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(
        color: scheme.onInverseSurface,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontFamilyFallback: kDefaultFontFamilyFallback,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      actionTextColor: scheme.primary,
      disabledActionTextColor: scheme.onInverseSurface.withOpacity(0.6),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ).copyWith(fontFamilyFallback: fallback),
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: scheme.surface,
      ),
    ),
  );
  return theme.copyWith(
    textTheme: _withFontFallback(theme.textTheme, fallback),
    primaryTextTheme: _withFontFallback(theme.primaryTextTheme, fallback),
  );
}
