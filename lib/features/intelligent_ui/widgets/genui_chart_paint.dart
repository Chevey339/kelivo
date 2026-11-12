import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../runtime/ui_chart_data.dart';

const genUiChartDashes = <List<int>?>[
  null,
  [6, 3],
  [2, 3],
  [8, 3, 2, 3],
];

FlDotPainter genUiChartDot(
  int series,
  Color color,
  Color fill, {
  double size = 6,
}) => switch (series % 4) {
  0 => FlDotCirclePainter(
    radius: size / 2,
    color: fill,
    strokeWidth: 1.5,
    strokeColor: color,
  ),
  1 => FlDotSquarePainter(
    size: size,
    color: fill,
    strokeWidth: 1.5,
    strokeColor: color,
  ),
  _ => _PolygonDot(series % 4, color, fill, size),
};

class GenUiChartMarkerPainter extends CustomPainter {
  const GenUiChartMarkerPainter({
    required this.point,
    required this.series,
    required this.color,
    required this.fill,
  });
  final Offset point;
  final int series;
  final Color color, fill;

  @override
  void paint(Canvas canvas, Size size) => genUiChartDot(
    series,
    color,
    fill,
    size: 9,
  ).draw(canvas, const FlSpot(0, 0), point);

  @override
  bool shouldRepaint(GenUiChartMarkerPainter old) =>
      point != old.point ||
      series != old.series ||
      color != old.color ||
      fill != old.fill;
}

/// fl_chart owns positions and hit testing; only two small marker shapes are
/// supplied here because its stock painters provide circle/square/cross.
final class _PolygonDot extends FlDotPainter {
  const _PolygonDot(this.shape, this.color, this.fill, this.size);
  final int shape;
  final Color color, fill;
  final double size;
  @override
  Color get mainColor => color;
  @override
  Size getSize(FlSpot spot) => Size.square(size);
  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    final r = size / 2;
    final path = Path()..moveTo(0, -r);
    if (shape == 2) {
      path
        ..lineTo(r, r)
        ..lineTo(-r, r);
    } else {
      path
        ..lineTo(r, 0)
        ..lineTo(0, r)
        ..lineTo(-r, 0);
    }
    path.close();
    canvas.save();
    canvas.translate(offsetInCanvas.dx, offsetInCanvas.dy);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.restore();
  }

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) => b;
  @override
  List<Object?> get props => [shape, color, fill, size];
}

class GenUiChartLegendPainter extends CustomPainter {
  const GenUiChartLegendPainter({
    required this.series,
    required this.color,
    required this.fill,
    this.pie = false,
  });
  final int series;
  final Color color, fill;
  final bool pie;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    final y = size.height / 2;
    if (pie) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, y),
            width: 10,
            height: 10,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      return;
    }
    final dashes = genUiChartDashes[series % 4];
    if (dashes == null) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    } else {
      var x = 0.0, index = 0;
      while (x < size.width) {
        final next = math.min(size.width, x + dashes[index % dashes.length]);
        if (index.isEven) canvas.drawLine(Offset(x, y), Offset(next, y), paint);
        x = next;
        index++;
      }
    }
    genUiChartDot(
      series,
      color,
      fill,
    ).draw(canvas, const FlSpot(0, 0), Offset(size.width / 2, y));
  }

  @override
  bool shouldRepaint(GenUiChartLegendPainter old) =>
      old.series != series ||
      old.color != color ||
      old.fill != fill ||
      old.pie != pie;
}

class GenUiChartGapPainter extends CustomPainter {
  const GenUiChartGapPainter({
    required this.data,
    required this.fill,
    required this.line,
    required this.label,
    required this.style,
    required this.textScaler,
    required this.direction,
  });
  final UiChartData data;
  final Color fill, line;
  final String label;
  final TextStyle style;
  final TextScaler textScaler;
  final TextDirection direction;
  @override
  void paint(Canvas canvas, Size size) {
    final axis = data.xAxis;
    double x(double value) =>
        (value - axis.minimum) / (axis.maximum - axis.minimum) * size.width;
    for (final gap in data.gaps) {
      final left = x(gap.start).clamp(0.0, size.width);
      final right = x(gap.end).clamp(0.0, size.width);
      final rect = Rect.fromLTRB(
        left,
        0,
        math.max(left + 2, right).clamp(0, size.width),
        size.height,
      );
      canvas.save();
      canvas.clipRect(rect);
      canvas.drawRect(rect, Paint()..color = fill);
      final stroke = Paint()
        ..color = line
        ..strokeWidth = 1;
      for (
        var start = rect.left - size.height;
        start < rect.right;
        start += 8
      ) {
        canvas.drawLine(
          Offset(start, size.height),
          Offset(start + size.height, 0),
          stroke,
        );
      }
      if (rect.width >= 70) {
        final text = TextPainter(
          text: TextSpan(text: label, style: style),
          textScaler: textScaler,
          textDirection: direction,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: math.max(0, rect.width - 8));
        text.paint(
          canvas,
          Offset(rect.left + (rect.width - text.width) / 2, 4),
        );
        text.dispose();
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(GenUiChartGapPainter old) =>
      old.data != data ||
      old.fill != fill ||
      old.line != line ||
      old.label != label ||
      old.style != style ||
      old.textScaler != textScaler ||
      old.direction != direction;
}

/// fl_chart 1.3.0 creates a full-plot saveLayer for every BetweenBars null
/// segment (and two for above/below cutoffs). Fill the straight zero-baseline
/// contours directly; fl_chart still owns the actual line, markers and hits.
final class GenUiChartAreaPainter extends CustomPainter {
  GenUiChartAreaPainter({required this.data, required this.colors});
  final UiChartData data;
  final List<Color> colors;

  @visibleForTesting
  Iterable<Path> pathsForSeries(Size size, int series) sync* {
    var path = Path();
    double x(UiChartRow row) =>
        (data.x(row) - data.xAxis.minimum) /
        (data.xAxis.maximum - data.xAxis.minimum) *
        size.width;
    double y(double value) =>
        (data.yAxis.maximum - data.yAxis.coordinate(value)) /
        (data.yAxis.maximum - data.yAxis.minimum) *
        size.height;
    final zero = y(0);
    double? lastX;
    Path? close() {
      if (lastX != null) {
        path.lineTo(lastX!, zero);
        path.close();
        lastX = null;
        final result = path;
        path = Path();
        return result;
      }
      return null;
    }

    for (final row in data.rows) {
      final value = row.y[series];
      if (value == null) {
        final segment = close();
        if (segment != null) yield segment;
        continue;
      }
      final px = x(row);
      if (lastX == null) path.moveTo(px, zero);
      path.lineTo(px, y(value));
      lastX = px;
    }
    final segment = close();
    if (segment != null) yield segment;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var s = 0; s < colors.length; s++) {
      if (colors[s].a == 0) continue;
      final paint = Paint()..color = colors[s];
      // Separate null-delimited contours may run in opposite X directions;
      // painting them separately prevents nonZero winding cancellation.
      for (final path in pathsForSeries(size, s)) {
        canvas.drawPath(path, paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(GenUiChartAreaPainter old) =>
      old.data != data || !listEquals(old.colors, colors);
}

/// Bars retain the scatter engine's real numeric X positions. fl_chart's stock
/// BarChart spaces groups by category even when their x titles are numeric.
/// This glyph uses one source point per bar, with the same rectangle for drawing
/// and hit testing; no synthetic baseline points enter tooltips or selection.
final class GenUiBarDot extends FlDotPainter {
  const GenUiBarDot({
    required this.width,
    required this.baselineDelta,
    required this.color,
    required this.fill,
    required this.series,
    this.selected = false,
  });
  final double width, baselineDelta;
  final Color color, fill;
  final int series;
  final bool selected;
  Rect _rect(Offset center) => Rect.fromLTRB(
    center.dx - width / 2,
    math.min(center.dy, center.dy + baselineDelta),
    center.dx + width / 2,
    math.max(center.dy, center.dy + baselineDelta),
  );
  @override
  Color get mainColor => color;
  @override
  Size getSize(FlSpot spot) => Size(width, baselineDelta.abs());
  @override
  bool hitTest(
    FlSpot spot,
    Offset touched,
    Offset center,
    double extraThreshold,
  ) {
    if (baselineDelta == 0) {
      return genUiChartDot(
        series,
        color,
        fill,
        size: selected ? 9 : 6,
      ).hitTest(spot, touched, center, extraThreshold);
    }
    return _rect(center).inflate(extraThreshold).contains(touched);
  }

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    if (baselineDelta == 0) {
      genUiChartDot(
        series,
        color,
        fill,
        size: selected ? 9 : 6,
      ).draw(canvas, spot, offsetInCanvas);
      return;
    }
    final rect = _rect(offsetInCanvas);
    final radius = Radius.circular(math.min(3, width / 3));
    final bar = RRect.fromRectAndCorners(
      rect,
      topLeft: baselineDelta > 0 ? radius : Radius.zero,
      topRight: baselineDelta > 0 ? radius : Radius.zero,
      bottomLeft: baselineDelta < 0 ? radius : Radius.zero,
      bottomRight: baselineDelta < 0 ? radius : Radius.zero,
    );
    canvas.drawRRect(bar, Paint()..color = color);
    // Match the legend's shape without an oversized cap outside the bar.
    // A small inset mark keeps grouped series identifiable without color.
    if (rect.height >= 10 && width >= 6) {
      final mark = Offset(
        rect.center.dx,
        baselineDelta > 0 ? rect.top + 6 : rect.bottom - 6,
      );
      canvas.save();
      canvas.clipRRect(bar);
      genUiChartDot(series, fill, color, size: 4).draw(canvas, spot, mark);
      canvas.restore();
    }
    if (selected) {
      canvas.drawRRect(
        bar.inflate(2),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) => b;
  @override
  List<Object?> get props => [
    width,
    baselineDelta,
    color,
    fill,
    series,
    selected,
  ];
}
