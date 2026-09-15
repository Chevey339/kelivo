import 'package:flutter/widgets.dart';

/// Scales a base geometry value (a width, height or box-constraint edge) by
/// the ambient UI font scale.
///
/// Text is scaled automatically by the global `TextScaler` (see `main.dart`),
/// but container geometry is not. Passing every fixed width/height that wraps
/// text through this helper keeps boxes in proportion with their content at
/// elevated UI font scales (e.g. 150%).
///
/// For avatar boxes use [scaledAvatarSize] instead, which additionally keeps
/// the glyph-to-circle ratio.
double scaledDim(BuildContext context, double base) =>
    MediaQuery.textScalerOf(context).scale(base);
