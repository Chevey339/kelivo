import 'dart:math' as math;

import 'package:Kelivo/features/intelligent_ui/catalog/ui_budgets.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/protocol/ui_diagnostic.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_evaluator.dart';

final class UiChartDataException implements Exception {
  const UiChartDataException(this.code, this.detail);
  final UiDiagnosticCode code;
  final String detail;
}

/// A finite affine scale. Work in normalized coordinates before subtracting,
/// so opposite large endpoints never overflow the native chart's axis span.
final class UiChartAxis {
  UiChartAxis(
    Iterable<double> values, {
    bool includeZero = false,
    bool padGroups = false,
    bool niceTicks = false,
  }) {
    final numbers = [...values, if (includeZero) 0.0];
    final low = numbers.isEmpty ? 0.0 : numbers.reduce(math.min);
    final high = numbers.isEmpty ? 1.0 : numbers.reduce(math.max);
    final span = high - low;
    final magnitude = math.max(low.abs(), high.abs());
    // A narrow same-sign range must subtract its origin first. Dividing two
    // adjacent large values separately would distort their relative spacing.
    // Ordinary Y axes use readable ticks (0, 50, 100 rather than 0, 46.17,
    // 92.34). Keep the normalized precision path for extreme/narrow ranges.
    double? niceLow, niceHigh, niceStep;
    if (niceTicks &&
        span.isFinite &&
        span / 4 > 0 &&
        span > magnitude * 1e-10) {
      final rough = span / 4;
      final power = math
          .pow(10.0, (math.log(rough) / math.ln10).floor())
          .toDouble();
      if (power.isFinite && power > 0) {
        final part = rough / power;
        final step =
            (part <= 1
                ? 1
                : part <= 2
                ? 2
                : part <= 5
                ? 5
                : 10) *
            power;
        final a = (low / step).floorToDouble() * step;
        final b = (high / step).ceilToDouble() * step;
        if (a.isFinite && b.isFinite && (b - a).isFinite && a < b) {
          niceLow = a;
          niceHigh = b;
          niceStep = step;
        }
      }
    }
    if (niceTicks && low == 0 && high == 0) {
      niceLow = 0;
      niceHigh = 1;
      niceStep = .25;
    }
    _origin = niceLow ?? (span.isFinite ? low : 0);
    factor = span.isFinite && span > 0
        ? span
        : (magnitude == 0 ? 1 : magnitude);
    final start = coordinate(low), end = coordinate(high);
    var padding = start == end ? .1 : (end - start) * .04;
    double? groupGap;
    if (padGroups) {
      final distinct = numbers.map(coordinate).toSet().toList()..sort();
      var gap = end - start;
      for (var i = 1; i < distinct.length; i++) {
        gap = math.min(gap, distinct[i] - distinct[i - 1]);
      }
      padding = math.max(padding, gap / 2);
      groupGap = gap;
    }
    // Keep the lowest tick on the border, with a subpixel inset so an exact
    // zero/minimum hit is inside RenderBox's exclusive bottom edge. Retain
    // headroom above the data for markers and labels.
    minimum = niceLow == null ? start - padding : coordinate(niceLow) - 1e-9;
    maximum = niceHigh == null ? end + padding : coordinate(niceHigh) + padding;
    tickInterval = niceStep == null ? null : niceStep / factor;
    groupSpacing = groupGap == null
        ? null
        : groupGap > 0
        ? groupGap
        : maximum - minimum;
  }
  late final double minimum, maximum, factor, _origin;

  /// Cached for grouped bars; pointer hover never re-sorts the source data.
  late final double? groupSpacing;
  late final double? tickInterval;
  double coordinate(double value) => (value - _origin) / factor;
  double? value(double coordinate) {
    final result = _origin + coordinate * factor;
    return result.isFinite ? result : null;
  }

  /// Tick conversion can cancel two near-equal terms around zero. Only labels
  /// snap that rounding residue; data coordinates and source values are intact.
  double? tickValue(double coordinate) {
    final result = value(coordinate);
    final step = tickInterval == null ? null : tickInterval! * factor;
    return result != null && step != null && result.abs() < step.abs() * 1e-9
        ? 0
        : result;
  }

  double fraction(double value) =>
      (coordinate(value) - minimum) / (maximum - minimum);
}

final class UiChartRow {
  UiChartRow({required this.index, required this.x, required List<double?> y})
    : y = List.unmodifiable(y);
  final int index;
  final Object x;
  final List<double?> y;
}

final class UiChartGap {
  const UiChartGap(this.start, this.end);

  /// Normalized X coordinates, bounded by the displayed axis.
  final double start, end;
}

/// One validated data model for rendering, data view and semantic projection.
/// Validation happens in the runtime batch, never in a paint/build callback.
final class UiChartData {
  UiChartData._({
    required this.kind,
    required this.xKey,
    required this.yKeys,
    required this.rows,
    required this.numericX,
    required this.missingCount,
    required this.domainRows,
    required this.xAxis,
    required this.yAxis,
    required this.gaps,
    required this.total,
    required this.sampled,
  });
  final UiChartKind kind;
  final String xKey;
  final List<String> yKeys;
  final List<UiChartRow> rows;
  final bool numericX;
  final int missingCount;
  final Set<int> domainRows;
  final UiChartAxis xAxis, yAxis;
  final List<UiChartGap> gaps;
  final double total;
  final bool sampled;
  bool get isEmpty =>
      rows.isEmpty || rows.every((r) => r.y.every((v) => v == null));
  double x(UiChartRow row) => xAxis.coordinate(
    numericX ? (row.x as num).toDouble() : row.index.toDouble(),
  );

  factory UiChartData.read(
    Map<String, Object?> properties, {
    Iterable<UiSampleGap> sampleGaps = const [],
    bool sampled = false,
  }) {
    Never invalid(String detail) =>
        throw UiChartDataException(UiDiagnosticCode.invalidValue, detail);
    final kind = UiChartKind.values
        .where((k) => k.name == properties['kind'])
        .firstOrNull;
    final xKey = properties['x'];
    final rawKeys = properties['y'];
    final rawRows = properties['data'];
    if (kind == null ||
        xKey is! String ||
        xKey.isEmpty ||
        rawRows is! List ||
        rawKeys is! List ||
        rawKeys.isEmpty ||
        rawKeys.any((v) => v is! String || v.isEmpty)) {
      invalid('chartFields');
    }
    final yKeys = rawKeys.cast<String>();
    if (yKeys.toSet().length != yKeys.length) {
      invalid('chartFields');
    }
    if (kind == UiChartKind.pie
        ? yKeys.length != 1
        : yKeys.length > UiBudgets.chartSeries) {
      throw const UiChartDataException(
        UiDiagnosticCode.dataBudget,
        'chartSeries',
      );
    }
    if (kind == UiChartKind.pie
        ? rawRows.length > UiBudgets.pieItems
        : rawRows.length * yKeys.length > UiBudgets.chartPoints) {
      throw const UiChartDataException(
        UiDiagnosticCode.dataBudget,
        'chartPoints',
      );
    }
    final rows = <UiChartRow>[];
    final presentY = <String>{};
    bool? numericX;
    var missing = 0;
    var total = 0.0;
    for (var i = 0; i < rawRows.length; i++) {
      final raw = rawRows[i];
      if (raw is! Map<String, Object?>) invalid('chartRecords');
      final x = raw[xKey];
      if (x is! String && x is! num) invalid('chartX');
      if (x is num && !x.isFinite) {
        throw const UiChartDataException(UiDiagnosticCode.nonFinite, 'chartX');
      }
      final isNumeric = x is num;
      numericX ??= isNumeric;
      if (numericX != isNumeric || kind == UiChartKind.scatter && !isNumeric) {
        invalid('chartX');
      }
      final y = <double?>[];
      for (final key in yKeys) {
        if (raw.containsKey(key)) presentY.add(key);
        final value = raw[key];
        if (value == null) {
          missing++;
          y.add(null);
        } else {
          if (value is! num) invalid('chartY');
          if (!value.isFinite) {
            throw const UiChartDataException(
              UiDiagnosticCode.nonFinite,
              'chartY',
            );
          }
          if (kind == UiChartKind.pie && value < 0) invalid('chartPieValues');
          y.add(value.toDouble());
          if (kind == UiChartKind.pie) total += value;
        }
      }
      rows.add(UiChartRow(index: i, x: x!, y: y));
    }
    if (rows.isNotEmpty && yKeys.any((key) => !presentY.contains(key))) {
      invalid('chartY');
    }
    if (kind == UiChartKind.pie &&
        rows.isNotEmpty &&
        (!total.isFinite || total <= 0)) {
      invalid('chartPieValues');
    }
    final numeric = numericX ?? true;
    final xAxis = UiChartAxis(
      rows.map((r) => numeric ? (r.x as num).toDouble() : r.index.toDouble()),
      padGroups: kind == UiChartKind.bar,
      niceTicks: numeric && kind != UiChartKind.bar,
    );
    final yAxis = UiChartAxis(
      rows.expand((r) => r.y).whereType<double>(),
      includeZero: kind == UiChartKind.bar || kind == UiChartKind.area,
      niceTicks: true,
    );
    final domainRows = <int>{};
    for (final gap in sampleGaps) {
      if (gap.index >= 0 && gap.index < rows.length) {
        final row = rows[gap.index];
        if (row.x == gap.x && row.y.contains(null)) domainRows.add(gap.index);
      }
    }
    final gaps = <UiChartGap>[];
    if (numeric && domainRows.isNotEmpty) {
      final indices = domainRows.toList()..sort();
      for (var i = 0; i < indices.length; i++) {
        final first = indices[i];
        var last = first;
        while (i + 1 < indices.length && indices[i + 1] == last + 1) {
          last = indices[++i];
        }
        double coordinate(int index) =>
            xAxis.coordinate((rows[index].x as num).toDouble());
        final a = coordinate(first), b = coordinate(last);
        final start = first == 0 ? a : coordinate(first - 1) / 2 + a / 2;
        final end = last == rows.length - 1
            ? b
            : b / 2 + coordinate(last + 1) / 2;
        gaps.add(UiChartGap(math.min(start, end), math.max(start, end)));
      }
    }
    return UiChartData._(
      kind: kind,
      xKey: xKey,
      yKeys: List.unmodifiable(yKeys),
      rows: List.unmodifiable(rows),
      numericX: numeric,
      missingCount: missing,
      domainRows: Set.unmodifiable(domainRows),
      xAxis: xAxis,
      yAxis: yAxis,
      gaps: List.unmodifiable(gaps),
      total: total,
      sampled: sampled,
    );
  }
}
