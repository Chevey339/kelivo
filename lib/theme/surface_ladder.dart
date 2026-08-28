import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

/// Shift [base] in HCT tone space, keeping hue and chroma.
Color shiftTone(Color base, double delta) {
  final hct = Hct.fromInt(base.toARGB32());
  return Color(
    Hct.from(hct.hue, hct.chroma, (hct.tone + delta).clamp(0.0, 100.0)).toInt(),
  );
}

/// HCT tone of [color], 0–100.
double surfaceTone(Color color) => Hct.fromInt(color.toARGB32()).tone;

/// Set HCT tone while keeping hue and chroma of [base].
Color atTone(Color base, double tone) {
  final hct = Hct.fromInt(base.toARGB32());
  return Color(Hct.from(hct.hue, hct.chroma, tone.clamp(0.0, 100.0)).toInt());
}

/// Interpolate HCT tone from [from] toward [to], keeping [from]'s hue+chroma.
Color lerpTone(Color from, Color to, double t) {
  return atTone(
    from,
    surfaceTone(from) + (surfaceTone(to) - surfaceTone(from)) * t,
  );
}

/// Palette-declared `surface` is the card. The page is that color sunk 4 tones
/// in light (skipped for pure white). All tokens and `surfaceContainer*` roles
/// are derived from the **page** [ColorScheme.surface] after that rewrite.
class SurfaceLadder {
  const SurfaceLadder({
    required this.page,
    required this.card,
    required this.surfaceFill,
    required this.surfaceCardFill,
    required this.hairline,
    required this.hairlineStrong,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
  });

  final Color page;
  final Color card;
  final Color surfaceFill;
  final Color surfaceCardFill;
  final Color hairline;
  final Color hairlineStrong;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;

  factory SurfaceLadder.fromScheme(ColorScheme cs, {bool layered = false}) {
    final page = cs.surface;
    final dark = cs.brightness == Brightness.dark;

    if (!layered) {
      const white = Color(0xFFFFFFFF);
      const black = Color(0xFF000000);
      Color over(Color c, double a) =>
          Color.alphaBlend(c.withValues(alpha: a), page);
      final card = dark
          ? Color.alphaBlend(white.withValues(alpha: 0.10), page)
          : Color.alphaBlend(white.withValues(alpha: 0.96), page);
      final surfaceFill = Color.alphaBlend(
        cs.onSurface.withValues(alpha: dark ? 0.16 : 0.05),
        page,
      );
      return SurfaceLadder(
        page: page,
        card: card,
        surfaceFill: surfaceFill,
        surfaceCardFill: surfaceFill,
        hairline: cs.outlineVariant.withValues(alpha: dark ? 0.08 : 0.06),
        hairlineStrong: cs.outlineVariant.withValues(alpha: dark ? 0.26 : 0.38),
        surfaceContainerLowest: dark ? over(black, 0.28) : over(white, 0.72),
        surfaceContainerLow: dark ? over(white, 0.03) : over(white, 0.55),
        surfaceContainer: dark ? over(white, 0.045) : over(white, 0.35),
        surfaceContainerHigh: dark ? over(white, 0.06) : over(white, 0.85),
        surfaceContainerHighest: dark
            ? over(white, 0.09)
            : over(cs.onSurface, 0.05),
      );
    }

    final Color card;
    if (dark) {
      card = shiftTone(page, 11.0);
    } else {
      final headroom = 100.0 - surfaceTone(page);
      card = headroom >= 4.5 ? shiftTone(page, 4.0) : shiftTone(page, -3.5);
    }

    final surfaceCardFill = shiftTone(card, dark ? 9.0 : -3.2);
    final surfaceFill = shiftTone(page, dark ? 9.0 : -2.5);
    final hairline = cs.onSurface.withValues(alpha: dark ? 0.12 : 0.08);
    final hairlineStrong = cs.onSurface.withValues(alpha: dark ? 0.26 : 0.20);

    if (dark) {
      return SurfaceLadder(
        page: page,
        card: card,
        surfaceFill: surfaceFill,
        surfaceCardFill: surfaceCardFill,
        hairline: hairline,
        hairlineStrong: hairlineStrong,
        surfaceContainerLowest: shiftTone(page, -3.0),
        surfaceContainerLow: shiftTone(page, 4.0),
        surfaceContainer: shiftTone(page, 7.0),
        surfaceContainerHigh: shiftTone(page, 11.0),
        surfaceContainerHighest: shiftTone(page, 14.0),
      );
    }

    return SurfaceLadder(
      page: page,
      card: card,
      surfaceFill: surfaceFill,
      surfaceCardFill: surfaceCardFill,
      hairline: hairline,
      hairlineStrong: hairlineStrong,
      surfaceContainerLowest: atTone(page, 100.0),
      surfaceContainerLow: lerpTone(page, card, 0.50),
      surfaceContainer: lerpTone(page, card, 0.75),
      surfaceContainerHigh: card,
      surfaceContainerHighest: surfaceFill,
    );
  }
}
