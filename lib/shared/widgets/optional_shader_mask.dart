import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Toggles a shader without replacing its child's element or render subtree.
/// Disabled masks paint directly, without allocating a composited mask layer.
class OptionalShaderMask extends SingleChildRenderObjectWidget {
  const OptionalShaderMask({
    super.key,
    required this.enabled,
    required this.shaderCallback,
    this.blendMode = BlendMode.modulate,
    super.child,
  });

  final bool enabled;
  final ShaderCallback shaderCallback;
  final BlendMode blendMode;

  @override
  RenderShaderMask createRenderObject(BuildContext context) =>
      _RenderOptionalShaderMask(
        enabled,
        shaderCallback: shaderCallback,
        blendMode: blendMode,
      );

  @override
  void updateRenderObject(BuildContext context, RenderShaderMask renderObject) {
    (renderObject as _RenderOptionalShaderMask)
      ..enabled = enabled
      ..shaderCallback = shaderCallback
      ..blendMode = blendMode;
  }
}

class _RenderOptionalShaderMask extends RenderShaderMask {
  _RenderOptionalShaderMask(
    this._enabled, {
    required super.shaderCallback,
    required super.blendMode,
  });

  bool _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _enabled && super.alwaysNeedsCompositing;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_enabled) {
      super.paint(context, offset);
    } else {
      layer = null;
      if (child != null) context.paintChild(child!, offset);
    }
  }
}
