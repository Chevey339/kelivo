import 'dart:math' as math;
import '../text/ui_number_display.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import '../catalog/ui_catalog.dart';
import '../runtime/ui_chart_data.dart';
import 'genui_chart_paint.dart';
import 'genui_theme.dart';
import 'genui_text_widths.dart';

typedef GenUiChartPoint = ({int row, int series});
typedef GenUiChartTouch =
    void Function(FlTouchEvent event, GenUiChartPoint? point);

String genUiChartTick(double? value) {
  if (value == null) return '';
  if (value == 0) return '0';
  final parts = value.toStringAsPrecision(4).split('e');
  var number = parts.first;
  if (number.contains('.')) {
    number = number
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return parts.length == 1 ? number : '${number}e${parts.last}';
}

/// This widget owns no source state, animation clock or persistence. Native
/// chart hit responses are translated through explicit raw row/series mappings.
class GenUiChartCanvas extends StatefulWidget {
  const GenUiChartCanvas({
    super.key,
    required this.data,
    required this.properties,
    required this.hidden,
    required this.active,
    required this.highlightedSeries,
    required this.interactive,
    required this.onTouch,
    required this.gapLabel,
  });
  final UiChartData data;
  final Map<String, Object?> properties;
  final Set<int> hidden;
  final GenUiChartPoint? active;
  final int? highlightedSeries;
  final bool interactive;
  final GenUiChartTouch onTouch;
  final String gapLabel;

  @override
  State<GenUiChartCanvas> createState() => _GenUiChartCanvasState();
}

class _GenUiChartCanvasState extends State<GenUiChartCanvas> {
  final _textWidths = GenUiTextWidths();
  Object? _plotSignature;
  Set<int> _plotHidden = const {};
  Widget? _plot;
  UiChartData get data => widget.data;
  Map<String, Object?> get properties => widget.properties;
  Set<int> get hidden => widget.hidden;
  GenUiChartPoint? get active => widget.active;
  int? get highlightedSeries => widget.highlightedSeries;
  bool get interactive => widget.interactive;
  GenUiChartTouch get onTouch => widget.onTouch;
  String get gapLabel => widget.gapLabel;

  Color _color(GenUiTheme theme, int series) {
    final color = data.kind == UiChartKind.pie
        ? theme.pieColor(series)
        : theme.chartColors[series];
    return highlightedSeries == null || highlightedSeries == series
        ? color
        : color.withValues(alpha: .35);
  }

  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    if (data.kind == UiChartKind.pie) return _pie(context, theme);
    final scale = MediaQuery.textScalerOf(context);
    final labelStyle = theme.label.copyWith(color: theme.secondaryInk);
    final axis = data.yAxis;
    var left = 32.0;
    for (var i = 0; i <= 4; i++) {
      final width = _textWidths.measure(
        genUiChartTick(
          axis.tickValue(axis.minimum + (axis.maximum - axis.minimum) * i / 4),
        ),
        labelStyle,
        scale,
        TextDirection.ltr,
      );
      left = math.max(left, width.ceilToDouble() + 12);
    }
    final bottom = scale.scale(labelStyle.fontSize!) * 1.4 + 8;
    return LayoutBuilder(
      builder: (context, constraints) {
        final axisLeft = math.min(left, constraints.maxWidth * .4);
        final plot = Size(
          math.max(1, constraints.maxWidth - axisLeft),
          math.max(1, constraints.maxHeight - bottom - 1),
        );
        final line =
            data.kind == UiChartKind.line || data.kind == UiChartKind.area;
        final signature = (
          data,
          theme,
          scale,
          Directionality.of(context),
          constraints,
          highlightedSeries,
          interactive,
          onTouch,
          gapLabel,
          line ? null : active,
        );
        if (_plot == null ||
            _plotSignature != signature ||
            !setEquals(_plotHidden, hidden)) {
          _plotSignature = signature;
          _plotHidden = Set.of(hidden);
          final titles = _titles(
            theme,
            labelStyle,
            axisLeft,
            bottom,
            plot.width,
          );
          final grid = FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval:
                axis.tickInterval ?? (axis.maximum - axis.minimum) / 4,
            checkToShowHorizontalLine: (value) =>
                (value - axis.minimum).abs() >
                (axis.maximum - axis.minimum) * 1e-8,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: theme.hairline, strokeWidth: 1),
          );
          final border = FlBorderData(
            show: true,
            border: Border(bottom: BorderSide(color: theme.hairlineStrong)),
          );
          final chart =
              data.kind == UiChartKind.scatter || data.kind == UiChartKind.bar
              ? _scatter(theme, titles, grid, border, plot)
              : _line(theme, titles, grid, border, plot.width);
          // The only extra repaint boundary is the chart canvas. Hover paints
          // one marker above this retained base, without redrawing all series.
          _plot = RepaintBoundary(
            child: Stack(
              children: [
                if (data.gaps.isNotEmpty)
                  Positioned.fill(
                    left: axisLeft,
                    bottom: bottom + 1,
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: CustomPaint(
                          painter: GenUiChartGapPainter(
                            data: data,
                            fill: theme.warningContainer.withValues(alpha: .20),
                            line: theme.hairlineStrong,
                            label: gapLabel,
                            style: theme.label.copyWith(
                              color: theme.onWarningContainer,
                            ),
                            textScaler: scale,
                            direction: Directionality.of(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (data.kind == UiChartKind.area)
                  Positioned.fill(
                    left: axisLeft,
                    bottom: bottom + 1,
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: CustomPaint(
                          painter: GenUiChartAreaPainter(
                            data: data,
                            colors: [
                              for (var s = 0; s < data.yKeys.length; s++)
                                hidden.contains(s)
                                    ? theme.transparent
                                    : _color(theme, s).withValues(
                                        alpha: _color(theme, s).a * .12,
                                      ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(child: chart),
              ],
            ),
          );
        }
        final point = active;
        final rawY = point == null
            ? null
            : data.rows[point.row].y[point.series];
        return Directionality(
          // Axes retain data order; legends/tables use the surrounding direction.
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned.fill(child: _plot!),
              if (line && point != null && rawY != null)
                Positioned.fill(
                  left: axisLeft,
                  bottom: bottom + 1,
                  child: IgnorePointer(
                    child: CustomPaint(
                      key: const ValueKey('genui-chart-active-marker'),
                      painter: GenUiChartMarkerPainter(
                        point: Offset(
                          (data.x(data.rows[point.row]) - data.xAxis.minimum) /
                              (data.xAxis.maximum - data.xAxis.minimum) *
                              plot.width,
                          (1 - data.yAxis.fraction(rawY)) * plot.height,
                        ),
                        series: point.series,
                        color: _color(theme, point.series),
                        fill: theme.card,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  FlTitlesData _titles(
    GenUiTheme theme,
    TextStyle style,
    double left,
    double bottom,
    double plotWidth,
  ) {
    final categoryStep = math.max(1, (data.rows.length / 4).ceil());
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: left,
          minIncluded: false,
          maxIncluded: false,
          interval:
              data.yAxis.tickInterval ??
              (data.yAxis.maximum - data.yAxis.minimum) / 4,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            meta: meta,
            space: 6,
            child: SizedBox(
              width: math.max(0, left - 8),
              child: Text(
                genUiChartTick(data.yAxis.tickValue(value)),
                style: style,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: bottom,
          minIncluded: false,
          maxIncluded: false,
          interval: data.numericX
              ? data.xAxis.tickInterval ??
                    (data.xAxis.maximum - data.xAxis.minimum) / 4
              : categoryStep / data.xAxis.factor,
          getTitlesWidget: (value, meta) {
            final raw = data.xAxis.tickValue(value);
            String label;
            if (data.numericX) {
              label = genUiChartTick(raw);
            } else {
              if (raw == null ||
                  (raw - raw.round()).abs() > .000001 ||
                  raw < 0 ||
                  raw >= data.rows.length) {
                return const SizedBox.shrink();
              }
              label = data.rows[raw.round()].x as String;
            }
            return SideTitleWidget(
              meta: meta,
              space: 6,
              child: SizedBox(
                width: math.max(24, plotWidth / 4),
                child: Text(
                  label,
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _line(
    GenUiTheme theme,
    FlTitlesData titles,
    FlGridData grid,
    FlBorderData border,
    double plotWidth,
  ) {
    final series = [
      for (var i = 0; i < data.yKeys.length; i++)
        if (!hidden.contains(i)) i,
    ];
    final bars = <LineChartBarData>[];
    for (final s in series) {
      final spots = [
        for (final row in data.rows)
          row.y[s] == null
              ? FlSpot.nullSpot
              : FlSpot(data.x(row), data.yAxis.coordinate(row.y[s]!)),
      ];
      // Keep every line vertex and hit target. Dense decorative markers would
      // overlap; space those marks along X while retaining gap endpoints,
      // isolated values and the active point. Scatter points are never thinned.
      final marked = Set<FlSpot>.identity();
      final isolated = Set<FlSpot>.identity();
      double? previousX;
      for (var i = 0; i < spots.length; i++) {
        final spot = spots[i];
        if (spot.isNull()) {
          previousX = null;
          continue;
        }
        if ((i == 0 || spots[i - 1].isNull()) &&
            (i == spots.length - 1 || spots[i + 1].isNull())) {
          isolated.add(spot);
        }
        final x =
            (spot.x - data.xAxis.minimum) /
            (data.xAxis.maximum - data.xAxis.minimum) *
            plotWidth;
        if (previousX == null ||
            (x - previousX).abs() >= 12 ||
            i == spots.length - 1 ||
            spots[i + 1].isNull()) {
          marked.add(spot);
          previousX = x;
        }
      }
      final normalDot = genUiChartDot(s, _color(theme, s), theme.card);
      bars.add(
        LineChartBarData(
          spots: spots,
          color: _color(theme, s),
          barWidth: 2,
          isCurved: false,
          dashArray: genUiChartDashes[s],
          dotData: FlDotData(
            checkToShowDot: (spot, bar) =>
                data.sampled ? isolated.contains(spot) : marked.contains(spot),
            getDotPainter: (spot, percent, bar, index) => normalDot,
          ),
        ),
      );
    }
    return LineChart(
      LineChartData(
        lineBarsData: bars,
        minX: data.xAxis.minimum,
        maxX: data.xAxis.maximum,
        minY: data.yAxis.minimum,
        maxY: data.yAxis.maximum,
        titlesData: titles,
        gridData: grid,
        borderData: border,
        backgroundColor: theme.transparent,
        lineTouchData: LineTouchData(
          enabled: interactive,
          handleBuiltInTouches: false,
          touchSpotThreshold: 24,
          distanceCalculator: (a, b) => (a - b).distance,
          touchCallback: !interactive
              ? null
              : (event, response) {
                  final spot = response?.lineBarSpots?.firstOrNull;
                  onTouch(
                    event,
                    spot == null
                        ? null
                        : (row: spot.spotIndex, series: series[spot.barIndex]),
                  );
                },
        ),
      ),
      // State feedback is immediate; node arrival already has a shared host
      // reveal. Interpolating while a slider moves would lag accepted values.
      duration: Duration.zero,
    );
  }

  Widget _scatter(
    GenUiTheme theme,
    FlTitlesData titles,
    FlGridData grid,
    FlBorderData border,
    Size plot,
  ) {
    final bars = data.kind == UiChartKind.bar;
    final mapping = <GenUiChartPoint>[];
    final spots = <ScatterSpot>[];
    final pitch = bars
        ? math.min(
            20.0,
            data.xAxis.groupSpacing! /
                (data.xAxis.maximum - data.xAxis.minimum) *
                plot.width *
                .72 /
                data.yKeys.length,
          )
        : 0.0;
    for (final row in data.rows) {
      for (var series = 0; series < data.yKeys.length; series++) {
        // fl_chart 1.3.0's scatter hit tester does not honor show=false. Remove
        // hidden/missing points entirely and retain this explicit source map.
        final rawY = row.y[series];
        if (hidden.contains(series) || rawY == null) continue;
        final point = (row: row.index, series: series);
        final color = _color(theme, series);
        var x = data.x(row);
        final y = data.yAxis.coordinate(rawY);
        FlDotPainter painter;
        if (bars) {
          x +=
              (series - (data.yKeys.length - 1) / 2) *
              pitch /
              plot.width *
              (data.xAxis.maximum - data.xAxis.minimum);
          painter = GenUiBarDot(
            width: pitch * .82,
            baselineDelta:
                (y - data.yAxis.coordinate(0)) /
                (data.yAxis.maximum - data.yAxis.minimum) *
                plot.height,
            color: color,
            fill: theme.card,
            series: series,
            selected: active == point,
          );
        } else {
          painter = genUiChartDot(
            series,
            color,
            theme.card,
            size: active == point ? 9 : 6,
          );
        }
        mapping.add(point);
        spots.add(ScatterSpot(x, y, dotPainter: painter));
      }
    }
    return ScatterChart(
      key: ValueKey(data.kind),
      ScatterChartData(
        scatterSpots: spots,
        minX: data.xAxis.minimum,
        maxX: data.xAxis.maximum,
        minY: data.yAxis.minimum,
        maxY: data.yAxis.maximum,
        titlesData: titles,
        gridData: grid,
        borderData: border,
        backgroundColor: theme.transparent,
        scatterTouchData: ScatterTouchData(
          enabled: interactive,
          handleBuiltInTouches: false,
          touchSpotThreshold: bars ? 0 : 12,
          touchCallback: !interactive
              ? null
              : (event, response) {
                  final spot = response?.touchedSpot;
                  onTouch(event, spot == null ? null : mapping[spot.spotIndex]);
                },
        ),
      ),
      duration: Duration.zero,
    );
  }

  Widget _pie(BuildContext context, GenUiTheme theme) => LayoutBuilder(
    builder: (context, constraints) {
      final rows = data.rows
          .where(
            (r) =>
                !hidden.contains(r.index) &&
                r.y.single != null &&
                r.y.single! > 0,
          )
          .toList();
      final visibleTotal = rows.fold(0.0, (sum, row) => sum + row.y.single!);
      final radius =
          math.min(constraints.maxWidth, constraints.maxHeight) / 2 - 8;
      final donut = properties['donut'] == true;
      final centerTextScale =
          MediaQuery.textScalerOf(
            context,
          ).scale(theme.chartCenterValue.fontSize!) /
          18;
      final center = donut
          ? radius * (.53 * centerTextScale).clamp(.53, .74)
          : 0.0;
      final selected = active == null ? null : data.rows[active!.row];
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                centerSpaceColor: theme.contentBackground,
                centerSpaceRadius: center,
                sectionsSpace: 2,
                startDegreeOffset: -90,
                sections: [
                  for (final row in rows)
                    PieChartSectionData(
                      value: row.y.single! / visibleTotal,
                      color: _color(theme, row.index),
                      radius:
                          radius - center + (active?.row == row.index ? 4 : 0),
                      // Values and percentages remain in the legend/tooltip with normal
                      // text contrast. Tiny colored sectors never carry unreadable text.
                      showTitle: false,
                    ),
                ],
                pieTouchData: PieTouchData(
                  enabled: interactive,
                  touchCallback: !interactive
                      ? null
                      : (event, response) {
                          final index =
                              response?.touchedSection?.touchedSectionIndex;
                          onTouch(
                            event,
                            index == null || index < 0 || index >= rows.length
                                ? null
                                : (
                                    row: rows[index].index,
                                    series: rows[index].index,
                                  ),
                          );
                        },
                ),
              ),
              duration: Duration.zero,
            ),
            if (donut)
              SizedBox(
                width: center * 1.6,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selected == null
                          ? AppLocalizations.of(context)!.genuiChartTotal
                          : selected.x.toString(),
                      style: theme.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            selected == null
                                ? genUiDisplayTotal(
                                    rows.map((row) => row.y.single!),
                                  )
                                : genUiDisplayNumber(selected.y.single),
                            style: theme.chartCenterValue,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.ltr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (properties['unit'] case final String unit) ...[
                          SizedBox(width: theme.xxs),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: center * .55),
                            child: Text(
                              unit,
                              style: theme.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (selected?.y.single != null)
                      Text(
                        '${genUiChartTick(selected!.y.single! / visibleTotal * 100)}%',
                        style: theme.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}
