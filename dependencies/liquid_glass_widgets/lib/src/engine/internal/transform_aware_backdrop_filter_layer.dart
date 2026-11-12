import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// Updates screen-relative shader uniforms in the scene that moves the glass.
///
/// An ancestor transform can move a retained repaint boundary without painting
/// its render objects again. Updating those uniforms in a post-frame callback
/// is one frame late. This layer refreshes just the filter before submitting it;
/// the geometry texture and foreground display lists remain retained.
class TransformAwareBackdropFilterLayer extends BackdropFilterLayer {
  TransformAwareBackdropFilterLayer({required this.refreshFilter});

  /// Returns a replacement only when compositor coordinates have changed.
  ui.ImageFilter? Function()? refreshFilter;

  ui.ImageFilter? _currentFilter;

  @override
  ui.ImageFilter? get filter => _currentFilter;

  @override
  set filter(ui.ImageFilter? value) {
    // This layer always joins the scene, so it must not call
    // markNeedsAddToScene (which rejects alwaysNeedsAddToScene layers).
    _currentFilter = value;
  }

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    final replacement = refreshFilter?.call();
    if (replacement != null) _currentFilter = replacement;
    super.addToScene(builder);
  }

  @override
  void dispose() {
    refreshFilter = null;
    _currentFilter = null;
    super.dispose();
  }
}
