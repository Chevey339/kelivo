import 'package:flutter/widgets.dart';

/// Geometry for initial / emoji avatars follows the ambient UI font scale, so
/// the glyph keeps its proportion inside the circle (≈42% of the diameter)
/// instead of overfilling a fixed-size circle when the UI font scale is raised.
///
/// Only the avatar *box* goes through this helper. The glyph's `fontSize` must
/// stay at its base value, because Flutter applies the text scaler to text
/// automatically — scaling the font size here as well would square the factor.
///
/// To keep every avatar at a fixed size regardless of the UI font scale, simply
/// return [base] unchanged here: all initial / emoji avatars route through this
/// single function.
double scaledAvatarSize(BuildContext context, double base) =>
    MediaQuery.textScalerOf(context).scale(base);

/// How far a glyph's ink sits below the centre of its line box, as a fraction
/// of the font size.
///
/// Measured on the screenshots (Microsoft YaHei, 6 avatars, 100% and 150%):
/// the ink centre lands ≈1.6px low on a 20px font, i.e. ≈8% of the font size —
/// which is clearly visible inside a tight circle even though the text itself
/// is perfectly centred in its box.
const double kAvatarGlyphDropRatio = 0.08;

/// Upward offset that visually centres the initial inside its circle.
///
/// [baseSize] is the avatar's base edge length (the value passed to the
/// widget, before scaling). Avatar initials sit at 42% of it, so the drop is
/// `baseSize * 0.42 * kAvatarGlyphDropRatio`.
///
/// The result is geometry, not text: it is scaled by the ambient text scaler
/// here, while the glyph's own `fontSize` is left for Flutter to scale.
double avatarInitialNudgeY(BuildContext context, double baseSize) =>
    -scaledAvatarSize(context, baseSize) * 0.42 * kAvatarGlyphDropRatio;
