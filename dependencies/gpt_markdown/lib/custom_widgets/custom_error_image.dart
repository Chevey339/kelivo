import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A custom widget that displays an error image with customizable colors.
///
/// The [CustomImageError] widget is used to display an error image in the UI.
/// It takes an optional [iconColor], [backgroundColor], and [outlineColor] parameter
/// to customize the appearance of the error image.
///

class CustomImageError extends LeafRenderObjectWidget {
  const CustomImageError({
    super.key,
    this.iconColor,
    this.backgroundColor,
    this.outlineColor,
  });
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? outlineColor;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderCustomImageError(
      iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
      backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHighest,
      outlineColor ?? Theme.of(context).colorScheme.outline,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderCustomImageError renderObject,
  ) {
    renderObject._backgroundColor =
        backgroundColor ??
        Theme.of(context).colorScheme.surfaceContainerHighest;
    renderObject._iconColor =
        iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
    renderObject._outlineColor =
        outlineColor ?? Theme.of(context).colorScheme.outline;
  }
}

/// A custom render object for the [CustomImageError] widget.
///
/// The [RenderCustomImageError] class extends RenderProxyBox and is responsible for
/// painting the error image. It takes a [iconColor], [backgroundColor], and [outlineColor]
/// and uses them to draw an error image in the UI.
///

class RenderCustomImageError extends RenderProxyBox {
  RenderCustomImageError(
    this._iconColor,
    this._backgroundColor,
    this._outlineColor,
  );
  Color _iconColor;
  Color _outlineColor;
  Color _backgroundColor;

  /// The color of the icon.
  set iconColor(Color value) {
    if (value == _iconColor) {
      return;
    }
    _iconColor = value;
    markNeedsPaint();
  }

  /// The background color of the error image.
  set backgroundColor(Color value) {
    if (value == _backgroundColor) {
      return;
    }
    _backgroundColor = value;
    markNeedsPaint();
  }

  /// The outline color of the error image.
  set outlineColor(Color value) {
    if (value == _outlineColor) {
      return;
    }
    _outlineColor = value;
    markNeedsPaint();
  }

  @override
  void performLayout() {
    if (constraints.hasBoundedHeight && constraints.hasBoundedWidth) {
      size = constraints.constrain(
        Size(
          min(constraints.maxWidth, constraints.maxHeight),
          min(constraints.maxHeight, constraints.maxWidth),
        ),
      );
      return;
    }
    if (constraints.hasBoundedHeight || constraints.hasBoundedWidth) {
      size = constraints.constrain(
        Size(
          min(constraints.maxHeight, constraints.maxWidth),
          min(constraints.maxHeight, constraints.maxWidth),
        ),
      );
      return;
    }
    size = constraints.constrain(const Size(80, 80));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.drawRect(offset & size, Paint()..color = _backgroundColor);
    context.canvas.drawRect(
      offset & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _outlineColor,
    );
    const icon = Icons.image_not_supported;
    TextPainter textPainter = TextPainter(textDirection: TextDirection.rtl);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: min(min(size.width, size.height), 35),
        fontFamily: icon.fontFamily,
        color: _iconColor,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      context.canvas,
      offset +
          Offset(
            size.width / 2 - textPainter.size.width / 2,
            size.height / 2 - textPainter.size.height / 2,
          ),
    );
  }
}

/// A custom widget that displays a loading image with customizable colors.
///
/// The [CustomImageLoading] widget is used to display a loading image in the UI.
/// It takes an optional [iconColor], [backgroundColor], [outlineColor], and [progress] parameter
/// to customize the appearance of the loading image.
///

class CustomImageLoading extends LeafRenderObjectWidget {
  const CustomImageLoading({
    super.key,
    this.iconColor,
    this.backgroundColor,
    this.outlineColor,
    this.progress = 1,
  });

  /// The color of the icon.
  final Color? iconColor;

  /// The background color of the loading image.
  final Color? backgroundColor;

  /// The outline color of the loading image.
  final Color? outlineColor;

  /// The progress of the loading image.
  final double progress;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderCustomImageLoading(
      iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
      backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHighest,
      outlineColor ?? Theme.of(context).colorScheme.outline,
      progress,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderCustomImageLoading renderObject,
  ) {
    renderObject._backgroundColor =
        backgroundColor ??
        Theme.of(context).colorScheme.surfaceContainerHighest;
    renderObject._iconColor =
        iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
    renderObject._outlineColor =
        outlineColor ?? Theme.of(context).colorScheme.outline;
    renderObject.progress = progress;
  }
}

/// A custom render object for the [CustomImageLoading] widget.
///
/// The [RenderCustomImageLoading] class extends RenderProxyBox and is responsible for
/// painting the loading image. It takes a [iconColor], [backgroundColor], [outlineColor], and [progress]
/// and uses them to draw a loading image in the UI.
///

class RenderCustomImageLoading extends RenderProxyBox {
  RenderCustomImageLoading(
    this._iconColor,
    this._backgroundColor,
    this._outlineColor,
    this._progress,
  );
  Color _iconColor;
  Color _outlineColor;
  Color _backgroundColor;
  double _progress;
  set iconColor(Color value) {
    if (value == _iconColor) {
      return;
    }
    _iconColor = value;
    markNeedsPaint();
  }

  set backgroundColor(Color value) {
    if (value == _backgroundColor) {
      return;
    }
    _backgroundColor = value;
    markNeedsPaint();
  }

  set outlineColor(Color value) {
    if (value == _outlineColor) {
      return;
    }
    _outlineColor = value;
    markNeedsPaint();
  }

  set progress(double value) {
    if (value == _progress) {
      return;
    }
    _progress = value;
    markNeedsPaint();
  }

  @override
  void performLayout() {
    if (constraints.hasBoundedHeight && constraints.hasBoundedWidth) {
      size = constraints.constrain(
        Size(
          min(constraints.maxWidth, constraints.maxHeight),
          min(constraints.maxHeight, constraints.maxWidth),
        ),
      );
      return;
    }
    if (constraints.hasBoundedHeight || constraints.hasBoundedWidth) {
      size = constraints.constrain(
        Size(
          min(constraints.maxHeight, constraints.maxWidth),
          min(constraints.maxHeight, constraints.maxWidth),
        ),
      );
      return;
    }
    size = constraints.constrain(const Size(80, 80));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.drawRect(offset & size, Paint()..color = _backgroundColor);
    context.canvas.drawRect(
      offset & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _outlineColor,
    );
    const icon = Icons.image;
    TextPainter textPainter = TextPainter(textDirection: TextDirection.rtl);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: min(min(size.width, size.height), 35),
        fontFamily: icon.fontFamily,
        color: _iconColor,
      ),
    );
    textPainter.layout();
    context.canvas.drawRect(
      (offset + Offset(0, size.height - 5)) & Size(size.width * _progress, 5),
      Paint()..color = _iconColor,
    );
    textPainter.paint(
      context.canvas,
      offset +
          Offset(
            size.width / 2 - textPainter.size.width / 2,
            size.height / 2 - textPainter.size.height / 2,
          ),
    );
  }
}
