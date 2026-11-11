import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Frozen visible pixels while the only control tree lives in another route.
/// Capture an existing ancestor layer on demand, bounded by the viewport. This
/// adds no repaint boundary or raster work to normal message scrolling.
final class GenUiExpansionSnapshot {
  GenUiExpansionSnapshot._(this.image, this.bounds);
  final ui.Image image;
  final Rect bounds;

  Widget build() => Positioned.fromRect(
    rect: bounds,
    child: RawImage(image: image, fit: BoxFit.fill),
  );

  void dispose() => image.dispose();
}

class GenUiExpansionAnchor extends SingleChildRenderObjectWidget {
  const GenUiExpansionAnchor({super.key, required super.child});
  @override
  RenderGenUiExpansionAnchor createRenderObject(BuildContext context) =>
      RenderGenUiExpansionAnchor();
}

class RenderGenUiExpansionAnchor extends RenderProxyBox {
  GenUiExpansionSnapshot? capture(
    MediaQueryData media, {
    bool includeBackdrop = false,
  }) {
    final target = this;
    if (!target.attached || !target.hasSize) return null;
    final origin = target.localToGlobal(Offset.zero);
    final visible = (origin & target.size).intersect(Offset.zero & media.size);
    if (visible.isEmpty) return null;
    final bounds = visible.shift(-origin);
    RenderObject? ancestor = target;
    while (ancestor != null) {
      // Translucent cards need the composited backdrop in their frozen pixels.
      // Otherwise the return overlay applies the card tint a second time.
      if (!includeBackdrop &&
          ancestor.isRepaintBoundary &&
          ancestor is RenderBox &&
          ancestor.layer is OffsetLayer) {
        final captureBounds = MatrixUtils.transformRect(
          target.getTransformTo(ancestor),
          bounds,
        );
        try {
          final image = (ancestor.layer! as OffsetLayer).toImageSync(
            captureBounds,
            pixelRatio: math.min(media.devicePixelRatio, 2),
          );
          return GenUiExpansionSnapshot._(image, bounds);
        } catch (_) {
          // A surface without a painted layer can still expand safely.
          return null;
        }
      }
      // A simple page/gallery may have no repaint boundary below RenderView.
      // Its root layer includes the view's physical-pixel transform.
      if (ancestor is RenderView && ancestor.layer is OffsetLayer) {
        final ratio = ancestor.configuration.devicePixelRatio;
        final physical = Rect.fromLTRB(
          visible.left * ratio,
          visible.top * ratio,
          visible.right * ratio,
          visible.bottom * ratio,
        );
        try {
          final image = (ancestor.layer! as OffsetLayer).toImageSync(
            physical,
            pixelRatio: math.min(media.devicePixelRatio, 2) / ratio,
          );
          return GenUiExpansionSnapshot._(image, bounds);
        } catch (_) {
          return null;
        }
      }
      ancestor = ancestor.parent;
    }
    return null;
  }
}
