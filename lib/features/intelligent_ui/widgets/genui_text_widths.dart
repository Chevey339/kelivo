import 'package:flutter/painting.dart';

/// Per-widget, bounded measurements for repeated axis labels/table samples.
/// Keys include appearance so theme, font scale and direction never reuse an
/// obsolete width. Only scalar widths are retained, not native paragraphs.
final class GenUiTextWidths {
  final _widths = <(String, TextStyle, TextScaler, TextDirection), double>{};

  double measure(
    String text,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
  ) {
    final key = (text, style, scaler, direction);
    if (_widths[key] case final width?) return width;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: scaler,
      textDirection: direction,
    )..layout();
    final width = painter.width;
    painter.dispose();
    if (_widths.length == 128) _widths.remove(_widths.keys.first);
    _widths[key] = width;
    return width;
  }
}
