import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:Kelivo/theme/surface_ladder.dart';

/// Semantic colors that have no dedicated role in [ColorScheme].
///
/// All values are derived from (or harmonized with) the active [ColorScheme]
/// so custom/seed-generated themes get sensible values automatically.
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color surfaceFill;
  final Color surfaceCard;
  final Color surfaceCardFill;
  final Color hairline;
  final Color hairlineStrong;
  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color searchHighlight;
  final List<Color> chartSeries;
  final bool layered;

  const AppSemanticColors({
    required this.surfaceFill,
    required this.surfaceCard,
    required this.surfaceCardFill,
    required this.hairline,
    required this.hairlineStrong,
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.searchHighlight,
    required this.chartSeries,
    this.layered = false,
  });

  /// Dialog / sheet / menu panel fill.
  ///
  /// Layered mode sits on the bright card layer. Legacy uses page
  /// [ColorScheme.surface] so overlays match the old look.
  Color overlaySurface(ColorScheme scheme) =>
      layered ? surfaceCard : scheme.surface;

  factory AppSemanticColors.light(ColorScheme cs, {bool layered = false}) {
    const successBase = Color(0xFF2E7D32);
    const warningBase = Color(0xFFF57C00);
    final ladder = SurfaceLadder.fromScheme(cs, layered: layered);
    return AppSemanticColors(
      surfaceFill: ladder.surfaceFill,
      surfaceCard: ladder.card,
      surfaceCardFill: ladder.surfaceCardFill,
      hairline: ladder.hairline,
      hairlineStrong: ladder.hairlineStrong,
      success: successBase.harmonizeWith(cs.primary),
      successContainer: const Color(0xFFA5D6A7).harmonizeWith(cs.primary),
      onSuccessContainer: const Color(0xFF1B5E20),
      warning: warningBase.harmonizeWith(cs.primary),
      warningContainer: const Color(0xFFFFE0B2).harmonizeWith(cs.primary),
      onWarningContainer: const Color(0xFF4E2600),
      searchHighlight: const Color(0xFFFFD700).withValues(alpha: 0.55),
      layered: layered,
      chartSeries: const [
        Color(0xFF2563EB),
        Color(0xFF0F8F83),
        Color(0xFFEA580C),
        Color(0xFF8B5CF6),
        Color(0xFFE11D48),
        Color(0xFF16A34A),
        Color(0xFFCA8A04),
        Color(0xFF0891B2),
      ],
    );
  }

  factory AppSemanticColors.dark(ColorScheme cs, {bool layered = false}) {
    const successBase = Color(0xFF81C784);
    const warningBase = Color(0xFFFFB74D);
    final ladder = SurfaceLadder.fromScheme(cs, layered: layered);
    return AppSemanticColors(
      surfaceFill: ladder.surfaceFill,
      surfaceCard: ladder.card,
      surfaceCardFill: ladder.surfaceCardFill,
      hairline: ladder.hairline,
      hairlineStrong: ladder.hairlineStrong,
      success: successBase.harmonizeWith(cs.primary),
      successContainer: const Color(0xFF1B5E20).harmonizeWith(cs.primary),
      onSuccessContainer: const Color(0xFFC8E6C9),
      warning: warningBase.harmonizeWith(cs.primary),
      warningContainer: const Color(0xFF8D4E00).harmonizeWith(cs.primary),
      onWarningContainer: const Color(0xFFFFE8CC),
      searchHighlight: const Color(0xFFB8860B).withValues(alpha: 0.55),
      layered: layered,
      chartSeries: const [
        Color(0xFF60A5FA),
        Color(0xFF5EEAD4),
        Color(0xFFFB923C),
        Color(0xFFA78BFA),
        Color(0xFFFB7185),
        Color(0xFF86EFAC),
        Color(0xFFFACC15),
        Color(0xFF67E8F9),
      ],
    );
  }

  @override
  AppSemanticColors copyWith({
    Color? surfaceFill,
    Color? surfaceCard,
    Color? surfaceCardFill,
    Color? hairline,
    Color? hairlineStrong,
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? searchHighlight,
    List<Color>? chartSeries,
    bool? layered,
  }) {
    return AppSemanticColors(
      surfaceFill: surfaceFill ?? this.surfaceFill,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceCardFill: surfaceCardFill ?? this.surfaceCardFill,
      hairline: hairline ?? this.hairline,
      hairlineStrong: hairlineStrong ?? this.hairlineStrong,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      searchHighlight: searchHighlight ?? this.searchHighlight,
      chartSeries: chartSeries ?? this.chartSeries,
      layered: layered ?? this.layered,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    final len = chartSeries.length < other.chartSeries.length
        ? chartSeries.length
        : other.chartSeries.length;
    return AppSemanticColors(
      surfaceFill: Color.lerp(surfaceFill, other.surfaceFill, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceCardFill: Color.lerp(surfaceCardFill, other.surfaceCardFill, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      hairlineStrong: Color.lerp(hairlineStrong, other.hairlineStrong, t)!,
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      searchHighlight: Color.lerp(searchHighlight, other.searchHighlight, t)!,
      chartSeries: List.generate(
        len,
        (i) => Color.lerp(chartSeries[i], other.chartSeries[i], t)!,
      ),
      layered: t < 0.5 ? layered : other.layered,
    );
  }
}

extension AppSemanticColorsX on BuildContext {
  /// The ambient [AppSemanticColors]. Falls back to deriving values from the
  /// ambient [ColorScheme] when the extension is not attached (e.g. in widget
  /// tests that pump a plain MaterialApp).
  AppSemanticColors get appColors {
    final theme = Theme.of(this);
    final ext = theme.extension<AppSemanticColors>();
    if (ext != null) return ext;
    return theme.brightness == Brightness.dark
        ? AppSemanticColors.dark(theme.colorScheme)
        : AppSemanticColors.light(theme.colorScheme);
  }

  /// Dialog / sheet / menu panel. See [AppSemanticColors.overlaySurface].
  Color get overlaySurface =>
      appColors.overlaySurface(Theme.of(this).colorScheme);
}
