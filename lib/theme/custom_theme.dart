import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

import 'palettes.dart';

/// A user-defined theme: a primary color plus optional secondary/tertiary
/// accents. Colors are stored as ARGB ints so the list can be persisted as
/// JSON and shared between devices (copy/import).
///
/// Palette generation uses a Material You TONAL_SPOT
/// [DynamicScheme] whose primary (and optionally secondary/tertiary) tonal
/// palettes are built from the picked colors via HCT.
class CustomTheme {
  final String id;
  final String name;
  final int primaryArgb;
  final int? secondaryArgb;
  final int? tertiaryArgb;

  const CustomTheme({
    required this.id,
    required this.name,
    required this.primaryArgb,
    this.secondaryArgb,
    this.tertiaryArgb,
  });

  Color get primary => Color(primaryArgb);
  Color? get secondary => secondaryArgb != null ? Color(secondaryArgb!) : null;
  Color? get tertiary => tertiaryArgb != null ? Color(tertiaryArgb!) : null;

  CustomTheme copyWith({
    String? id,
    String? name,
    int? primaryArgb,
    int? Function()? secondaryArgb,
    int? Function()? tertiaryArgb,
  }) {
    return CustomTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      primaryArgb: primaryArgb ?? this.primaryArgb,
      secondaryArgb: secondaryArgb != null
          ? secondaryArgb()
          : this.secondaryArgb,
      tertiaryArgb: tertiaryArgb != null ? tertiaryArgb() : this.tertiaryArgb,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'primaryColorArgb': primaryArgb,
    if (secondaryArgb != null) 'secondaryColorArgb': secondaryArgb,
    if (tertiaryArgb != null) 'tertiaryColorArgb': tertiaryArgb,
  };

  /// Accepts both this app's export format and RikkaHub's
  /// (`primaryColorArgb` etc.; extra keys ignored, id optional).
  factory CustomTheme.fromJson(Map<String, dynamic> json) {
    final primary = json['primaryColorArgb'];
    if (primary is! int) {
      throw const FormatException('missing primaryColorArgb');
    }
    return CustomTheme(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      primaryArgb: primary,
      secondaryArgb: json['secondaryColorArgb'] as int?,
      tertiaryArgb: json['tertiaryColorArgb'] as int?,
    );
  }

  String export() => jsonEncode(toJson());

  static CustomTheme parse(String source) {
    final decoded = jsonDecode(source.trim());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('expected a JSON object');
    }
    return CustomTheme.fromJson(decoded);
  }

  @override
  bool operator ==(Object other) =>
      other is CustomTheme &&
      other.id == id &&
      other.name == name &&
      other.primaryArgb == primaryArgb &&
      other.secondaryArgb == secondaryArgb &&
      other.tertiaryArgb == tertiaryArgb;

  @override
  int get hashCode =>
      Object.hash(id, name, primaryArgb, secondaryArgb, tertiaryArgb);
}

/// Generate the light/dark [ColorScheme]s for a custom theme.
ColorScheme customThemeColorScheme(CustomTheme theme, {required bool dark}) {
  final sourceHct = Hct.fromInt(theme.primaryArgb);
  final scheme = DynamicScheme(
    sourceColorHct: sourceHct,
    variant: Variant.tonalSpot,
    isDark: dark,
    contrastLevel: 0.0,
    primaryPalette: TonalPalette.fromHct(sourceHct),
    secondaryPalette: theme.secondaryArgb != null
        ? TonalPalette.fromHct(Hct.fromInt(theme.secondaryArgb!))
        : TonalPalette.of(sourceHct.hue, 16.0),
    tertiaryPalette: theme.tertiaryArgb != null
        ? TonalPalette.fromHct(Hct.fromInt(theme.tertiaryArgb!))
        : TonalPalette.of(
            MathUtils.sanitizeDegreesDouble(sourceHct.hue + 60.0),
            24.0,
          ),
    neutralPalette: TonalPalette.of(sourceHct.hue, 3.5),
    neutralVariantPalette: TonalPalette.of(sourceHct.hue, 5.0),
  );

  Color pick(DynamicColor c) => Color(c.getArgb(scheme));

  return ColorScheme(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: pick(MaterialDynamicColors.primary),
    onPrimary: pick(MaterialDynamicColors.onPrimary),
    primaryContainer: pick(MaterialDynamicColors.primaryContainer),
    onPrimaryContainer: pick(MaterialDynamicColors.onPrimaryContainer),
    primaryFixed: pick(MaterialDynamicColors.primaryFixed),
    primaryFixedDim: pick(MaterialDynamicColors.primaryFixedDim),
    onPrimaryFixed: pick(MaterialDynamicColors.onPrimaryFixed),
    onPrimaryFixedVariant: pick(MaterialDynamicColors.onPrimaryFixedVariant),
    secondary: pick(MaterialDynamicColors.secondary),
    onSecondary: pick(MaterialDynamicColors.onSecondary),
    secondaryContainer: pick(MaterialDynamicColors.secondaryContainer),
    onSecondaryContainer: pick(MaterialDynamicColors.onSecondaryContainer),
    secondaryFixed: pick(MaterialDynamicColors.secondaryFixed),
    secondaryFixedDim: pick(MaterialDynamicColors.secondaryFixedDim),
    onSecondaryFixed: pick(MaterialDynamicColors.onSecondaryFixed),
    onSecondaryFixedVariant: pick(
      MaterialDynamicColors.onSecondaryFixedVariant,
    ),
    tertiary: pick(MaterialDynamicColors.tertiary),
    onTertiary: pick(MaterialDynamicColors.onTertiary),
    tertiaryContainer: pick(MaterialDynamicColors.tertiaryContainer),
    onTertiaryContainer: pick(MaterialDynamicColors.onTertiaryContainer),
    tertiaryFixed: pick(MaterialDynamicColors.tertiaryFixed),
    tertiaryFixedDim: pick(MaterialDynamicColors.tertiaryFixedDim),
    onTertiaryFixed: pick(MaterialDynamicColors.onTertiaryFixed),
    onTertiaryFixedVariant: pick(MaterialDynamicColors.onTertiaryFixedVariant),
    error: pick(MaterialDynamicColors.error),
    onError: pick(MaterialDynamicColors.onError),
    errorContainer: pick(MaterialDynamicColors.errorContainer),
    onErrorContainer: pick(MaterialDynamicColors.onErrorContainer),
    surface: pick(MaterialDynamicColors.surface),
    onSurface: pick(MaterialDynamicColors.onSurface),
    onSurfaceVariant: pick(MaterialDynamicColors.onSurfaceVariant),
    surfaceDim: pick(MaterialDynamicColors.surfaceDim),
    surfaceBright: pick(MaterialDynamicColors.surfaceBright),
    surfaceContainerLowest: pick(MaterialDynamicColors.surfaceContainerLowest),
    surfaceContainerLow: pick(MaterialDynamicColors.surfaceContainerLow),
    surfaceContainer: pick(MaterialDynamicColors.surfaceContainer),
    surfaceContainerHigh: pick(MaterialDynamicColors.surfaceContainerHigh),
    surfaceContainerHighest: pick(
      MaterialDynamicColors.surfaceContainerHighest,
    ),
    outline: pick(MaterialDynamicColors.outline),
    outlineVariant: pick(MaterialDynamicColors.outlineVariant),
    shadow: pick(MaterialDynamicColors.shadow),
    scrim: pick(MaterialDynamicColors.scrim),
    inverseSurface: pick(MaterialDynamicColors.inverseSurface),
    onInverseSurface: pick(MaterialDynamicColors.inverseOnSurface),
    inversePrimary: pick(MaterialDynamicColors.inversePrimary),
    surfaceTint: pick(MaterialDynamicColors.surfaceTint),
  );
}

/// Build the runtime palette for a custom theme (resolved in main.dart).
ThemePalette buildCustomThemePalette(CustomTheme theme) {
  return ThemePalette(
    id: ThemePalettes.customPaletteId,
    zhName: theme.name.isEmpty ? '自定义' : theme.name,
    enName: theme.name.isEmpty ? 'Custom' : theme.name,
    light: customThemeColorScheme(theme, dark: false),
    dark: customThemeColorScheme(theme, dark: true),
  );
}
